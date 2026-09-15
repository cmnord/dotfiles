# My dotfiles :black_circle:

MIT License: https://cnord.mit-license.org/

## Conductor cloud computer

Bootstrap the cloud computer with:

```bash
bash "$HOME/dotfiles/install-cloud"
```

It links the portable configuration without replacing Conductor's Git
credentials and keeps Bash as the login shell.

Set `SAIL_CLB_API_KEY` and `SAIL_BASE_URL` as Conductor cloud secrets. The
bootstrap writes the key to Codex's private `~/.codex/auth.json` and points the
Sail model provider at the endpoint, without committing either value to this
public repository.

For local setup, store both through Varlock's macOS Keychain integration:

```bash
varlock keychain set SAIL_CLB_API_KEY --project codex --profile local
varlock keychain set SAIL_BASE_URL --project codex --profile local
bin/configure-codex-sail
```

`SAIL_BASE_URL` is the Sail box's Codex endpoint, e.g.
`https://<your-box>.sail.box/backend-api/codex`.

The managed `~/.env.codex` contains only `keychain(...)` references. The helper
resolves them for the one setup process, so nothing needs to be exported into
every development shell. If either value is missing, the helper skips Sail
setup instead of failing the install.

Keep the computer install script as a thin wrapper around this entrypoint and
rebuild the snapshot after changing it.
