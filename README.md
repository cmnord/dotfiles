# My dotfiles :black_circle:

MIT License: https://cnord.mit-license.org/

## Conductor cloud computer

Bootstrap the cloud computer with:

```bash
bash "$HOME/dotfiles/install-cloud"
```

It links the portable Bash and zsh configuration and includes `gitconfig`
without replacing Conductor's injected global Git credentials. Bash remains
the account's login and interactive shell; the checked-in `bashrc` supports
both Linux Bash 5.2 and macOS Bash 3.2.

Keep the computer install script as a thin wrapper around this entrypoint and
rebuild the snapshot after changing it.
