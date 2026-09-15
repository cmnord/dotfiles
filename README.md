# My dotfiles :black_circle:

MIT License: https://cnord.mit-license.org/

## Conductor cloud computer

Bootstrap the cloud computer with:

```bash
bash "$HOME/dotfiles/install-cloud"
```

It links the portable configuration without replacing Conductor's Git
credentials and keeps Bash as the login shell.

Set three Conductor cloud environment variables. None of the values are
committed to this public repository:

- `SAIL_CLB_API_KEY` -- the Sail key. Codex reads it at request time through the
  provider's `env_key`.
- `SAIL_BASE_URL` -- the Sail endpoint, e.g.
  `https://<your-box>.sail.box/backend-api/codex`. The bootstrap writes it into
  the provider block.
- `OPENAI_BASE_URL` -- the same endpoint a second time, and easy to miss.
  Conductor only skips its own ChatGPT login when it sees a Codex API key or a
  base URL, so without this every session dies before the agent starts with
  `CODEX_AUTH_REQUIRED` / `Codex ChatGPT auth not found`.

Do not name the key `CODEX_API_KEY`: Conductor reserves that name and refuses it
as a cloud environment variable.

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
