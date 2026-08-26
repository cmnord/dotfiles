# My dotfiles :black_circle:

MIT License: https://cnord.mit-license.org/

## Conductor cloud computer

Bootstrap the cloud computer with:

```bash
bash "$HOME/dotfiles/install-cloud"
```

It links the portable configuration without replacing Conductor's Git
credentials. Terminals stay in Bash because zsh redraws render incorrectly.
Keep the computer install script as a thin wrapper around this entrypoint and
rebuild the snapshot after changing it.
