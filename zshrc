# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnoster"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(
  git
  history-substring-search
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# User configuration

export EDITOR="vim"

# Aliases
alias py="python3"
alias mv="mv -i"

check(){ cd ~/dev/rust; ./x.py check; }
build_all(){ cd ~/dev/rust; ./x.py build -i --stage 1 src/libstd; }
build_keep(){ cd ~/dev/rust; ./x.py build -i --stage 1 src/libstd --keep-stage 1; }

build() {
  cd ~/dev/rust;
  ./x.py check && echo "Check passed, building..."; ./x.py build -i --stage 1 src/libstd --keep-stage 1;
}

# Vi mode
bindkey -v
export KEYTIMEOUT=1

mergepdf() { gs -q -sPAPERSIZE=letter -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=output.pdf "$@"; }

# Rust
export PATH="$HOME/.cargo/bin:$PATH"

# Add .dotfiles binaries to PATH
export PATH="$HOME/.dotfiles/bin:$PATH"

# Add Ruby to path
export PATH="/usr/local/opt/ruby/bin:$PATH"
