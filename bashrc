# Interactive Bash configuration. Keep this file compatible with the Bash 3.2
# shipped by macOS as well as current Bash releases on Linux.
case $- in
  *i*) ;;
  *) return ;;
esac

# macOS displays a migration notice when its system Bash is started directly.
# Selecting Bash intentionally here keeps interactive startup quiet.
case $OSTYPE in
  darwin*) export BASH_SILENCE_DEPRECATION_WARNING=1 ;;
esac

# Readline is shared by many programs through ~/.inputrc. Select Emacs editing
# and silence the bell here so these Bash preferences do not affect them.
set -o emacs
bind 'set editing-mode emacs'
bind 'set bell-style none'

# Keep history useful across simultaneous shells without recording consecutive
# or older duplicates. Atuin composes with this and gets Ctrl-R below.
HISTCONTROL=ignoredups:erasedups
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend

export EDITOR="vim"
# -R preserves ANSI colors, -i searches case-insensitively with smart casing,
# and -q uses a visual bell.
export LESS="-Riq"

alias py="python3"
alias mv="mv -i"
if command -v eza >/dev/null 2>&1; then
  alias ls="eza"
fi

# Bash aliases expand only in command position; unlike Zsh global aliases,
# these are directory-changing commands rather than path fragments.
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

mergepdf() {
  gs -q -sPAPERSIZE=letter -dNOPAUSE -dBATCH -sDEVICE=pdfwrite \
    -sOutputFile=output.pdf "$@"
}

# Direct PATH assignments work in Bash, but these helpers avoid duplicate
# entries when bashrc is sourced repeatedly while preserving path priority.
_dotfiles_path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1${PATH:+:$PATH}" ;;
  esac
}

_dotfiles_path_append() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="${PATH:+$PATH:}$1" ;;
  esac
}

# User toolchains and binaries.
_dotfiles_path_prepend "$HOME/go/bin"
_dotfiles_path_prepend "$HOME/.local/bin"
_dotfiles_path_prepend "$HOME/.dotfiles/bin"
_dotfiles_path_prepend "$HOME/.cargo/bin"
if [[ -d /Applications/Postgres.app/Contents/Versions/latest/bin ]]; then
  _dotfiles_path_prepend /Applications/Postgres.app/Contents/Versions/latest/bin
fi
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export HOMEBREW_NO_ANALYTICS=1

# Homebrew's unversioned Python commands live in libexec/bin.
if command -v brew >/dev/null 2>&1; then
  _dotfiles_brew_python="$(brew --prefix python 2>/dev/null || :)"
  if [[ -n "$_dotfiles_brew_python" ]]; then
    _dotfiles_path_prepend "$_dotfiles_brew_python/libexec/bin"
  fi
  unset _dotfiles_brew_python
fi

export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
fi
if [[ -s "$NVM_DIR/bash_completion" ]]; then
  # shellcheck source=/dev/null
  . "$NVM_DIR/bash_completion"
fi

_dotfiles_path_append "$HOME/.rvm/bin"
if [[ -s "$HOME/.rvm/scripts/rvm" ]]; then
  # shellcheck source=/dev/null
  . "$HOME/.rvm/scripts/rvm"
fi

# The SDK can be installed directly or by Homebrew. Its scripts handle PATH
# and command completion without producing output when sourced normally.
for _dotfiles_gcloud_dir in \
  /opt/homebrew/share/google-cloud-sdk \
  /usr/local/share/google-cloud-sdk \
  /usr/share/google-cloud-sdk \
  "$HOME/google-cloud-sdk"; do
  if [[ -r "$_dotfiles_gcloud_dir/path.bash.inc" ]]; then
    # shellcheck source=/dev/null
    . "$_dotfiles_gcloud_dir/path.bash.inc"
    if [[ -r "$_dotfiles_gcloud_dir/completion.bash.inc" ]]; then
      # shellcheck source=/dev/null
      . "$_dotfiles_gcloud_dir/completion.bash.inc"
    fi
    break
  elif [[ -d "$_dotfiles_gcloud_dir/bin" ]]; then
    _dotfiles_path_prepend "$_dotfiles_gcloud_dir/bin"
    break
  fi
done
unset _dotfiles_gcloud_dir
export PATH

# Load native command completion from common Linux and Homebrew locations.
for _dotfiles_completion in \
  /usr/share/bash-completion/bash_completion \
  /etc/bash_completion \
  /opt/homebrew/etc/profile.d/bash_completion.sh \
  /opt/homebrew/etc/bash_completion \
  /usr/local/etc/profile.d/bash_completion.sh \
  /usr/local/etc/bash_completion; do
  if [[ -r "$_dotfiles_completion" ]]; then
    # shellcheck source=/dev/null
    . "$_dotfiles_completion"
    break
  fi
done
unset _dotfiles_completion

if command -v pyenv >/dev/null 2>&1; then
  _dotfiles_pyenv_init="$(pyenv init - bash 2>/dev/null || pyenv init - 2>/dev/null || :)"
  if [[ -n "$_dotfiles_pyenv_init" ]]; then
    eval "$_dotfiles_pyenv_init"
  fi
  unset _dotfiles_pyenv_init
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi

# Keep the native prompt implementation separate from tool initialization.
_dotfiles_prompt_file="$HOME/.bash/prompt"
if [[ ! -r "$_dotfiles_prompt_file" ]]; then
  _dotfiles_bashrc_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _dotfiles_prompt_file="$_dotfiles_bashrc_dir/bash/prompt"
  unset _dotfiles_bashrc_dir
fi
if [[ -r "$_dotfiles_prompt_file" ]]; then
  # shellcheck source=bash/prompt
  . "$_dotfiles_prompt_file"
fi
unset _dotfiles_prompt_file

# Initialize fzf before Atuin: Atuin owns Ctrl-R while fzf retains Ctrl-T and
# Alt-C. Both commands emit Bash-native setup code.
if command -v fzf >/dev/null 2>&1; then
  _dotfiles_fzf_init="$(fzf --bash 2>/dev/null)"
  # Some minimal Linux /dev layouts omit /dev/fd. fzf's generated completion
  # setup uses it only to preserve prior completions; skip that optional step
  # there so key bindings and fuzzy completion still initialize quietly.
  if [[ ! -e /dev/fd ]]; then
    _dotfiles_fzf_init="$(printf '%s\n' "$_dotfiles_fzf_init" | sed \
      '/^__fzf_orig_completion < <(complete -p \$d_cmds /d')"
  fi
  eval "$_dotfiles_fzf_init"
  unset _dotfiles_fzf_init
fi

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init bash --disable-up-arrow)"
fi

# Prefix-based history search is Bash's closest built-in equivalent to Zsh's
# history-substring-search. These bindings deliberately leave Ctrl-R to Atuin.
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\eOA": history-search-backward'
bind '"\eOB": history-search-forward'

# Keep zoxide last so it can append its directory-tracking prompt hook after
# every other PROMPT_COMMAND integration.
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

unset -f _dotfiles_path_prepend _dotfiles_path_append
