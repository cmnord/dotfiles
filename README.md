# My dotfiles :black_circle:

MIT License: https://cnord.mit-license.org/

## Conductor cloud computer

```bash
bash "$HOME/dotfiles/install-cloud"
```

Links the portable configuration without replacing Conductor's Git credentials
and keeps Bash as the login shell. Keep the computer install script a thin
wrapper around this and rebuild the snapshot after changing it.

### Codex on Sail

Sail is off by default: `install-cloud` runs `codex-sail.py off`, so Codex uses
Conductor's own login. `codex-sail.py on` points Codex at the Sail load
balancer. It needs these Conductor cloud environment variables; none are
committed here:

- `SAIL_CLB_API_KEY` -- the Sail key. Not `CODEX_API_KEY`, which Conductor
  reserves.
- `SAIL_BASE_URL` -- e.g. `https://<your-box>.sail.box/backend-api/codex`.
- `OPENAI_BASE_URL` -- the same URL again. Without it Conductor insists on its
  own ChatGPT login and sessions fail with `CODEX_AUTH_REQUIRED`.

With Sail on, put Conductor's Codex agent on the **Manual** provider (Settings
-> Agents -> Codex). With it off, use any other provider and remove
`OPENAI_BASE_URL`, or Conductor skips its own login. Locally, keep the two Sail
values in the Keychain instead:

```bash
varlock keychain set SAIL_CLB_API_KEY --project codex --profile local
varlock keychain set SAIL_BASE_URL --project codex --profile local
codex-sail.py on
```

Varlock resolves them only for `codex-sail.py on`. Codex itself reads
`SAIL_CLB_API_KEY` from its own environment, with no `auth.json` fallback, so
the key has to be set wherever Codex runs, locally as well as in the cloud.

When Sail hangs, run `codex-sail.py off` and restart Codex. `codex-sail.py help`
has the details.
