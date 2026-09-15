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
bootstrap points the Sail model provider at the endpoint and has Codex read the
key from `SAIL_CLB_API_KEY` at request time via `env_key`, without committing
either value to this public repository.

Do not rename these to `CODEX_API_KEY` or `OPENAI_BASE_URL`. Conductor reserves
both names and refuses to pass them through as cloud environment variables.

Conductor's Codex agent has to be on the **Manual** custom provider
(Settings -> Agents -> Codex), which brokers no credential and leaves
authentication to this configuration. It does not, however, read
`~/.codex/auth.json` the way that setting's description suggests. Conductor
drives `codex app-server` and only sends `account/login/start` when it holds a
credential of its own, so a provider that relies on `requires_openai_auth` gets
no Authorization header and every request fails with:

```
401 Unauthorized: Missing API key in Authorization header
```

`env_key` sidesteps that, at the cost of having no fallback: wherever Codex
runs, `SAIL_CLB_API_KEY` has to be in its environment or it fails with
`Missing environment variable` instead of reading `auth.json`.

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
