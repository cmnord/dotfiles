# My dotfiles :black_circle:

MIT License: https://cnord.mit-license.org/

## Conductor cloud computer

Bootstrap the cloud computer with:

```bash
bash "$HOME/dotfiles/install-cloud"
```

It installs the shared Linux development stack and checksum-verified CLI
tools, links the portable configuration without replacing Conductor's Git
credentials, and keeps Bash as the login shell.

Keep the computer install script as a thin wrapper around this entrypoint and
rebuild the snapshot after changing it.
