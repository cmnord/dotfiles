# Native zsh completion
autoload -Uz compinit
[[ -d "$HOME/.cache/zsh" ]] || mkdir -p "$HOME/.cache/zsh"
compinit -d "$HOME/.cache/zsh/zcompdump"

# ZSH plugins
source ~/.zsh/plugins/agnoster-zsh-theme/agnoster.zsh-theme

# Agnoster's context uses the terminal's default foreground on black, which is
# unreadable in Conductor cloud's light terminal palette. Use explicit
# high-contrast foregrounds there without changing the local terminal theme.
if [[ "${CONDUCTOR_IS_LOCAL:-}" == "0" ]]; then
  prompt_context() {
    local user
    user="$(whoami)"

    if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CONNECTION" ]]; then
      prompt_segment black white " %(!.%{%F{yellow}%}.)$user@%m "
    fi
  }

  prompt_dir() {
    prompt_segment blue white ' %~ '
  }
fi

source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# Global aliases for directory traversal (from oh-my-zsh).
# Expands anywhere on the command line, e.g. `cd ...` or `ls .../foo`.
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'

# User configuration

# Load agnoster theme
setopt prompt_subst
setopt NO_BEEP
unsetopt LIST_BEEP
# Remove prompt_virtualenv from default
AGNOSTER_PROMPT_SEGMENTS=(prompt_status prompt_context prompt_dir prompt_git prompt_end)
# Default fg=8 is invisible on Solarized Dark (same color as background)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#586e75"

export EDITOR="vim"

# Aliases
alias py="python3"
alias mv="mv -i"
if (( $+commands[eza] )); then
  alias ls="eza"
fi

export KEYTIMEOUT=1

# emacs mode
bindkey -e

mergepdf() { gs -q -sPAPERSIZE=letter -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=output.pdf "$@"; }

# pyenv
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

# ensure compatibility tmux <-> direnv
if [[ -n $TMUX ]] && [[ -n $DIRENV_DIR ]]; then
  unset -m "DIRENV_*" # unset env vars starting with DIRENV_
fi
# direnv
if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

# PATH additions

# Rust
export PATH="$HOME/.cargo/bin:$PATH"

# .dotfiles binaries
export PATH="$HOME/.dotfiles/bin:$PATH"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Postgres.app
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

# RVM
export PATH="$PATH:$HOME/.rvm/bin"
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# Go
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export PATH="$PATH:$GOBIN"

# Homebrew
export HOMEBREW_NO_ANALYTICS=1

# Python
if (( $+commands[brew] )); then
  export PATH="$(brew --prefix python)/libexec/bin:$PATH"
fi

# Claude Code
export PATH="$HOME/.local/bin:$PATH"

# -R: maintain ANSI color sequences
# -i: case-insensitive search with smart-casing
# -q: visual bell instead of audio
export LESS=-Riq

# Set up fzf key bindings and fuzzy completion first.
# Initialization order matters: atuin also binds Ctrl-R, so loading it after
# fzf keeps fzf's Ctrl-T/Alt-C while letting atuin own history search.
if (( $+commands[fzf] )); then
  source <(fzf --zsh)
fi

if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

# zoxide (smart cd)
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# Google Cloud SDK
export PATH="/opt/homebrew/share/google-cloud-sdk/bin:$PATH"

# Keep this last: zsh-syntax-highlighting must wrap widgets created by the
# rest of the configuration. Conductor cloud's terminal currently applies its
# per-character style reset to the entire prompt line, so disable it there.
if [[ "${CONDUCTOR_IS_LOCAL:-}" != "0" ]]; then
  source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
