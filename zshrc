# Path to your oh-my-zsh installation.
export ZSH="/Users/cnord/.oh-my-zsh"

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

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Aliases
alias py="python3"

# Vi mode
bindkey -v
export KEYTIMEOUT=1
