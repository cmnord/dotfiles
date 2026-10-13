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
saved_auth_path = codex_home / "auth.json.chatgpt"


def read_auth_mode():
    try:
        return json.loads(auth_path.read_text()).get("auth_mode")
    except (OSError, ValueError):
        return None


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

    # Keep the ChatGPT credential so "off" can restore it without a fresh login.
    # A ChatGPT auth.json is only ever written here, never read, so an existing
    # copy is the newer one unless Codex has logged in again since.
    if read_auth_mode() == "chatgpt":
        shutil.copy2(auth_path, saved_auth_path)
        saved_auth_path.chmod(0o600)

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
    print("Codex is on Sail. Restart Codex to pick it up.")


# Uses no secrets, Varlock, network or Keychain, so it works while any of them
# is unavailable.
def off():
    # Leave [model_providers.sail] in place; only the root selection decides which
    # provider is used. Any other provider selection is the user's own and stays.
    removed = False
    if config_path.exists():
        kept = []
        before_first_table = True
        for line in config_path.read_text().splitlines(keepends=True):
            stripped = line.strip()
            if before_first_table and re.match(r'^model_provider\s*=\s*"sail"', stripped):
                removed = True
                continue
            if stripped.startswith("["):
                before_first_table = False
            kept.append(line)
        if removed:
            config_path.write_text("".join(kept))
            config_path.chmod(0o600)

    auth_mode = read_auth_mode()

    # Only swap credentials when this run turned Sail off. Once it is off,
    # auth.json is whatever the user has logged in with since, so leave it alone.
    if not removed:
        print("Codex is already off Sail. Left auth.json as it is.")
    elif auth_mode == "chatgpt":
        print("Codex is off Sail, on its ChatGPT login.")
    elif saved_auth_path.exists():
        shutil.copy2(saved_auth_path, auth_path)
        auth_path.chmod(0o600)
        print("Codex is off Sail. Restored the saved ChatGPT login.")
    else:
        # Without a provider selection Codex sends an API-key auth.json to
        # api.openai.com, so move the Sail key aside.
        if auth_mode == "apikey":
            auth_path.replace(codex_home / "auth.json.sail")
        print("Codex is off Sail, but no saved ChatGPT login was found.")
        print("Run `codex login` if Codex reports missing credentials.")
    print("Restart Codex to pick it up.")


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

    add_command("off", "fall back to the ChatGPT login", lambda args: off())

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
