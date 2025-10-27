# ZSH plugins
source ~/.zsh/plugins/agnoster-zsh-theme/agnoster.zsh-theme
source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# User configuration

# Load agnoster theme
setopt prompt_subst
# Remove prompt_virtualenv from default
AGNOSTER_PROMPT_SEGMENTS=(prompt_status prompt_context prompt_dir prompt_git prompt_end)

export EDITOR="vim"

# Aliases
alias py="python3"
alias mv="mv -i"

# Vi mode
bindkey -v
export KEYTIMEOUT=1

mergepdf() { gs -q -sPAPERSIZE=letter -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=output.pdf "$@"; }

# pyenv
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
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

# Go
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export PATH="$PATH:$GOBIN"