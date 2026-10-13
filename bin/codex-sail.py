#!/usr/bin/env python3

import argparse
import json
import os
import re
import shutil
import sys
from pathlib import Path

codex_home = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex")
config_path = codex_home / "config.toml"
auth_path = codex_home / "auth.json"


# Codex reads the key from the environment via the provider's env_key, so both
# values are needed. Re-exec through Varlock once to resolve them.
def require_secrets(if_configured=False):
    api_key = os.environ.get("SAIL_CLB_API_KEY")
    base_url = os.environ.get("SAIL_BASE_URL")
    if api_key and base_url:
        return api_key, base_url

    env_file = Path.home() / ".env.codex"
    if (
        os.environ.get("CODEX_SAIL_RESOLVED") != "1"
        and shutil.which("varlock")
        and os.access(env_file, os.R_OK)
    ):
        os.environ["CODEX_SAIL_RESOLVED"] = "1"
        os.execvp(
            "varlock",
            [
                "varlock", "run",
                "--inject", "vars",
                "--filter", "SAIL_CLB_API_KEY,SAIL_BASE_URL",
                "-p", str(env_file),
                "--", sys.executable, os.path.abspath(__file__), *sys.argv[1:],
            ],
        )

    if if_configured:
        print(
            "Skipping Sail Codex setup: SAIL_CLB_API_KEY and SAIL_BASE_URL are "
            "not both available from the environment or ~/.env.codex",
            file=sys.stderr,
        )
        sys.exit(0)

    print(
        "codex-sail.py: SAIL_CLB_API_KEY and SAIL_BASE_URL are not both available\n"
        "               from the environment or ~/.env.codex",
        file=sys.stderr,
    )
    sys.exit(1)


def on(if_configured):
    api_key, base_url = require_secrets(if_configured)

    codex_home.mkdir(parents=True, exist_ok=True)
    codex_home.chmod(0o700)
    os.umask(0o077)

    auth_path.write_text(
        json.dumps(
            {
                "auth_mode": "apikey",
                "OPENAI_API_KEY": api_key,
            },
            indent=2,
        )
        + "\n"
    )
    auth_path.chmod(0o600)

    lines = config_path.read_text().splitlines(keepends=True) if config_path.exists() else []

    # Remove a previous managed provider block and the root provider selection.
    filtered = []
    inside_sail_provider = False
    before_first_table = True
    for line in lines:
        stripped = line.strip()
        if stripped in {
            "# Managed by ~/dotfiles/bin/codex-sail.py",
            "# Managed by ~/dotfiles/bin/configure-codex-sail",
            "# Managed by ~/dotfiles/bin/configure-codex-sail-cloud",
        }:
            continue
        if stripped == "[model_providers.sail]":
            inside_sail_provider = True
            before_first_table = False
            continue
        if inside_sail_provider and stripped.startswith("["):
            inside_sail_provider = False
        if inside_sail_provider:
            continue
        if before_first_table and re.match(r"^model_provider\s*=", stripped):
            continue
        if stripped.startswith("["):
            before_first_table = False
        filtered.append(line)

    first_table = next(
        (index for index, line in enumerate(filtered) if line.strip().startswith("[")),
        len(filtered),
    )
    filtered.insert(first_table, 'model_provider = "sail"\n')

    config = "".join(filtered).strip() + "\n\n"
    config += f"""# Managed by ~/dotfiles/bin/codex-sail.py
[model_providers.sail]
name = "openai"
base_url = "{base_url}"
wire_api = "responses"
env_key = "SAIL_CLB_API_KEY"
supports_websockets = false
"""
    config_path.write_text(config)
    config_path.chmod(0o600)
    print("Configured Codex to use Sail")


def main():
    parser = argparse.ArgumentParser(
        prog="codex-sail.py",
        description="Toggle Codex between the Sail CLB provider and its own ChatGPT login.",
    )
    commands = parser.add_subparsers(dest="command", metavar="COMMAND", required=True)

    def add_command(name, about, run):
        command = commands.add_parser(name, help=about, description=about)
        command.set_defaults(run=run)
        return command

    on_command = add_command("on", "point Codex at Sail", lambda args: on(args.if_configured))
    on_command.add_argument(
        "--if-configured",
        action="store_true",
        help="succeed without changes when the secrets are absent, for bootstraps",
    )

    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
