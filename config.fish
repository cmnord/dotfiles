# Path to Oh My Fish install.
set -q XDG_DATA_HOME
  and set -gx OMF_PATH "$XDG_DATA_HOME/omf"
  or set -gx OMF_PATH "$HOME/.local/share/omf"

# Load Oh My Fish configuration.
source $OMF_PATH/init.fish

eval (python -m virtualfish)
alias python "python3"
alias pip "pip3"
alias py "python"

function sudo!!
    eval sudo $history[1]
end

# Go
set -gx PATH (go env GOPATH)/bin $PATH
set -gx GOPATH $PWD

# Rust
set -gx PATH $HOME/.cargo/bin $PATH
set -gx PATH /usr/local/opt/riscv-gnu-toolchain/bin $PATH

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/clairenord/Downloads/google-cloud-sdk/path.fish.inc' ]; . '/Users/clairenord/Downloads/google-cloud-sdk/path.fish.inc'; end

# editor
set -gx EDITOR vim
