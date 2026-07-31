# My dotfiles :black_circle:

MIT License: https://cnord.mit-license.org/

## Conductor cloud computer

The cloud bootstrap installs zsh, Vim, and the Linux builds needed by `zshrc`,
then uses the cloud-specific Dotbot manifest to link the portable configuration:

```bash
bash "$HOME/dotfiles/install-cloud"
```

The script includes `gitconfig` from the existing global Git configuration
instead of replacing `~/.gitconfig`. This preserves Conductor's injected GitHub
credential helper while still loading the aliases, identity, pager, and other
personal preferences in this repository.

Cloud terminal tabs that Conductor launches with Bash hand off to zsh when
they have a real interactive TTY. Non-interactive setup and run scripts remain
in Bash. Run `CONDUCTOR_KEEP_BASH=1 bash` when an interactive Bash shell is
needed intentionally.

The Conductor computer install script should remain a thin invocation of this
entrypoint. Rebuild the computer snapshot after changing the cloud setup here.
