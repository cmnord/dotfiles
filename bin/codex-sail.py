#!/usr/bin/env python3
"""Toggle Codex between the Sail CLB provider and its own ChatGPT login.

examples:
  codex-sail.py status                   which provider is Codex using?
  codex-sail.py probe || codex-sail.py off
                                         get off Sail if it is down

When the Sail endpoint is down, TLS completes and the response stream opens,
but only codex.keepalive events arrive and never a completion. Codex waits on
the stream indefinitely.

"off" takes no arguments, reads no secrets, and uses neither Varlock, the
Keychain nor the network. It removes the root model_provider = "sail" line
and restores the ChatGPT auth.json that "on" saved to auth.json.chatgpt.
With no saved login it moves the Sail key to auth.json.sail, because Codex
would otherwise send it to api.openai.com. The [model_providers.sail] block
stays in config.toml; "on" still needs both secrets, from the environment or
the Keychain. Restart Codex after either command.

"probe" reports up only when the endpoint completes a streamed response,
because a down endpoint still returns 200 and then sends keepalives.

On a cloud computer "off" leaves Codex with no credential at all, since
there is no ChatGPT login there to fall back to. To keep working through an
outage there, also switch Conductor's Codex provider away from Manual and
remove the OPENAI_BASE_URL cloud environment variable, so Conductor brokers
its own ChatGPT login again. Reverse both when Sail is back.
"""

import argparse
import json
import os
import re
import shutil
import signal
import sys
import urllib.error
import urllib.request
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


def status():
    provider = None
    base_url = None
    if config_path.exists():
        before_first_table = True
        inside_sail_provider = False
        for line in config_path.read_text().splitlines():
            stripped = line.strip()
            if stripped == "[model_providers.sail]":
                inside_sail_provider = True
                before_first_table = False
                continue
            if stripped.startswith("["):
                inside_sail_provider = False
                before_first_table = False
                continue
            if before_first_table:
                match = re.match(r'^model_provider\s*=\s*"([^"]*)"', stripped)
                if match:
                    provider = match.group(1)
            if inside_sail_provider:
                match = re.match(r'^base_url\s*=\s*"([^"]*)"', stripped)
                if match:
                    base_url = match.group(1)

    auth_mode = read_auth_mode()

    print("Sail:      " + ("ON" if provider == "sail" else "off"))
    print("provider:  " + (provider or "(default)"))
    print("auth_mode: " + (auth_mode or "(unreadable)"))
    if base_url:
        print("endpoint:  " + base_url)
    if saved_auth_path.exists():
        print("saved ChatGPT login available for `codex-sail.py off`")
    elif provider == "sail":
        print("no saved ChatGPT login: `codex-sail.py off` will need `codex login`")


def probe(timeout_seconds, model):
    api_key, base_url = require_secrets()

    # The endpoint rejects non-streaming requests, and a down backend returns 200
    # and then sends keepalives without closing, so only a completed stream
    # counts as up. Keepalives also reset a socket timeout, so an alarm bounds
    # the whole request.
    request = urllib.request.Request(
        base_url.rstrip("/") + "/responses",
        data=json.dumps({"model": model, "input": "hi", "stream": True}).encode(),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )

    def give_up(signum, frame):
        raise TimeoutError(f"no completion within {timeout_seconds}s")

    response = ""
    signal.signal(signal.SIGALRM, give_up)
    signal.alarm(timeout_seconds)
    try:
        with urllib.request.urlopen(request) as stream:
            for line in stream:
                response += line.decode(errors="replace")
                if '"type":"response.completed"' in response:
                    break
    except urllib.error.HTTPError as error:
        response = error.read().decode(errors="replace")
    except (OSError, TimeoutError):
        pass
    finally:
        signal.alarm(0)

    if '"type":"response.completed"' in response:
        print("Sail is UP (completed a streamed response)")
        return

    if not response:
        print(f"Sail is DOWN (no response within {timeout_seconds}s)", file=sys.stderr)
    elif "codex.keepalive" in response:
        print("Sail is DOWN (stream opened, only keepalives, never completed)", file=sys.stderr)
    else:
        print("Sail is DOWN (unexpected response):", file=sys.stderr)
        redacted = re.sub(r"sk-[A-Za-z0-9_-]+", "sk-REDACTED", response)
        print("\n".join(redacted.splitlines()[:5]), file=sys.stderr)
    print("Run `codex-sail.py off` to fall back to the ChatGPT login.", file=sys.stderr)
    sys.exit(1)


def main():
    summary, _, details = __doc__.strip().partition("\n\n")
    parser = argparse.ArgumentParser(
        prog="codex-sail.py",
        description=summary,
        epilog=details,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    commands = parser.add_subparsers(dest="command", metavar="COMMAND", required=True)

    def add_command(name, about, run):
        command = commands.add_parser(name, help=about, description=about)
        command.set_defaults(run=run)
        return command

    add_command("status", "show which provider is active, and the endpoint", lambda args: status())

    probe_command = add_command(
        "probe",
        "ask the endpoint for a real completion",
        lambda args: probe(args.timeout, args.model),
    )
    probe_command.add_argument(
        "--timeout",
        type=int,
        default=os.environ.get("CODEX_SAIL_PROBE_TIMEOUT", "25"),
        metavar="SECONDS",
        help="give up after this long (default: %(default)s, or $CODEX_SAIL_PROBE_TIMEOUT)",
    )
    probe_command.add_argument(
        "--model",
        default=os.environ.get("CODEX_SAIL_PROBE_MODEL", "gpt-6-luna"),
        help="model to ask (default: %(default)s, or $CODEX_SAIL_PROBE_MODEL)",
    )

    add_command("off", "fall back to the ChatGPT login", lambda args: off())

    on_command = add_command("on", "point Codex at Sail", lambda args: on(args.if_configured))
    on_command.add_argument(
        "--if-configured",
        action="store_true",
        help="succeed without changes when the secrets are absent, for bootstraps",
    )

    help_command = add_command(
        "help",
        "show help for a command",
        lambda args: (commands.choices[args.topic] if args.topic else parser).print_help(),
    )
    help_command.add_argument(
        "topic", nargs="?", choices=["status", "probe", "off", "on"], metavar="COMMAND"
    )

    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
