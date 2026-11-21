"""run_sql.py: runs a .sql file on the Databricks SQL warehouse (one statement at a time)

Usage (from the repo root):
    python scripts/run_sql.py infra/03_setup_unity_catalog.sql

- Placeholders like {{DATABRICKS_CATALOG}} are replaced with values from .env
- Uses the Databricks CLI admin profile (DATABRICKS_ADMIN_PROFILE) and the warehouse (DATABRICKS_WAREHOUSE_ID)
- Statements are split on ';'. Full-line comments (--) are ignored
- Query results (e.g. SHOW / SELECT) are printed as a table
- Stops at the first failing statement
"""

import json
import re
import subprocess
import sys
import time
from pathlib import Path


def load_env(path: Path = Path(".env")) -> dict:
    if not path.exists():
        sys.exit("ERROR: .env not found. Run from the repo root (see .env.example).")
    env = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip().strip("'\"")
    return env


def render(sql: str, env: dict) -> list[str]:
    """Replace {{VAR}} placeholders, drop comment lines, split into statements."""

    def replace(match):
        key = match.group(1)
        if key not in env:
            sys.exit(f"ERROR: placeholder {{{{{key}}}}} has no value in .env")
        return env[key]

    sql = re.sub(r"\{\{\s*(\w+)\s*\}\}", replace, sql)
    lines = [line for line in sql.splitlines() if not line.strip().startswith("--")]
    return [s.strip() for s in "\n".join(lines).split(";") if s.strip()]


def cli(profile: str, *args: str) -> dict:
    result = subprocess.run(["databricks", "api", *args, "-p", profile], capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"ERROR: databricks CLI failed:\n{result.stderr.strip()}")
    return json.loads(result.stdout)


def run_statement(statement: str, profile: str, warehouse_id: str) -> dict:
    body = json.dumps(
        {"warehouse_id": warehouse_id, "statement": statement, "wait_timeout": "50s", "on_wait_timeout": "CONTINUE"}
    )
    response = cli(profile, "post", "/api/2.0/sql/statements", "--json", body)
    # A stopped warehouse needs time to start: poll until the statement is finished
    while response["status"]["state"] in ("PENDING", "RUNNING"):
        time.sleep(5)
        response = cli(profile, "get", f"/api/2.0/sql/statements/{response['statement_id']}")
    return response


def print_table(response: dict) -> None:
    columns = [c["name"] for c in response.get("manifest", {}).get("schema", {}).get("columns", [])]
    rows = response.get("result", {}).get("data_array", []) or []
    if not columns or not rows:
        return
    rows = [["" if v is None else str(v) for v in row] for row in rows]
    widths = [max(len(c), *(len(r[i]) for r in rows)) for i, c in enumerate(columns)]
    print("   " + "  ".join(c.ljust(w) for c, w in zip(columns, widths, strict=True)))
    print("   " + "  ".join("-" * w for w in widths))
    for row in rows:
        print("   " + "  ".join(v.ljust(w) for v, w in zip(row, widths, strict=True)))


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("Usage: python scripts/run_sql.py <file.sql>")
    env = load_env()
    for key in ("DATABRICKS_ADMIN_PROFILE", "DATABRICKS_WAREHOUSE_ID"):
        if not env.get(key) or set(env[key]) <= {"0"}:
            sys.exit(f"ERROR: {key} is not set in .env (run infra/02_setup_compute.sh first)")

    statements = render(Path(sys.argv[1]).read_text(), env)
    for i, statement in enumerate(statements, 1):
        print(f"[{i}/{len(statements)}] {statement.splitlines()[0][:90]}")
        response = run_statement(statement, env["DATABRICKS_ADMIN_PROFILE"], env["DATABRICKS_WAREHOUSE_ID"])
        state = response["status"]["state"]
        if state != "SUCCEEDED":
            message = response["status"].get("error", {}).get("message", state)
            sys.exit(f"   FAILED: {message}")
        print_table(response)
    print("Done.")


if __name__ == "__main__":
    main()
