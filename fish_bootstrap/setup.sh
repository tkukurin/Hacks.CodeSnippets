#!/bin/bash

function waituser() {
	echo $@ '> '
	read __discard
}

CURDIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
waituser "Current directory set to $CURDIR"

sudo apt-get update
sudo apt-get upgrade
sudo apt-add-repository ppa:fish-shell/release-3
sudo apt-get install \
  build-essential \
  cargo \
  fzf \
  ripgrep \
  git \
  tmux \
  fish \
  python3-pip

sudo snap install go --classic  # can't just untar go due to ARM

cargo install exa
cargo install bat

# oh-my-fish
curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | \
  argv='--noninteractive' fish

# see some packages https://github.com/oh-my-fish/packages-main/tree/master/packages
# omf install fzf ?
# Ctrl-t	Ctrl-o	Find a file.
# Ctrl-r	Ctrl-r	Search through command history.
# Alt-c	Alt-c	cd into sub-directories (recursively searched).
# Alt-Shift-c	Alt-Shift-c	cd into sub-directories, including hidden ones.
# Ctrl-o	Alt-o	Open a file/dir using default editor ($EDITOR)
# Ctrl-g	Alt-Shift-o	Open a file/dir using xdg-open or open command

mkdir -p ~/.config/fish/functions/
echo fzf_key_bindings > ~/.config/fish/functions/fish_user_key_bindings.fish
cat >> ~/.config/fish/config.fish << EOF
source $CURDIR/.aliasrc
EOF


# tmux
mkdir -p $CURDIR/tmux/plugins
[[ -d ~/.tmux ]] || ln -s $CURDIR/tmux ~/.tmux
[[ -f ~/.tmux.conf ]] || ln -s $CURDIR/.tmux.conf ~/.tmux.conf
[[ -d ~/.tmux/plugins/tpm ]] || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm


# node
#GH=https://raw.githubusercontent.com
#waituser "Installing NVM"
#curl -o- $GH/nvm-sh/nvm/v0.39.1/install.sh | bash

[[ ! -d ~/.nvm ]] && export NVM_DIR="$HOME/.nvm" && (
  git clone https://github.com/nvm-sh/nvm.git "$CURDIR/nvm"
  ln -s "$CURDIR/nvm" "$NVM_DIR"
  cd "$NVM_DIR"
  git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
) && . "$NVM_DIR/nvm.sh"

omf install nvm  # bindings (note: some SHLVL error)

# vim
curl -fLo ./vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
[[ -d ~/.vim ]] || ln -s $CURDIR/vim ~/.vim


if grep -q "START inserted by install script" ~/.bashrc; then
	echo "Already found .bashrc modification!"
else
	# 'EOF' to prevent expansion
	cat >> ~/.bashrc << 'EOF'

# START inserted by install script {{{

if [ -d "$HOME/.cargo/bin" ]; then
  PATH="$HOME/.cargo/bin:$PATH"
fi

export PATH="$HOME/.local/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export EDITOR=vim
[[ $(which bat) ]] && export PAGER=bat || export PAGER=less
[[ $(which fish) ]] && exec -l fish "$@"

# END inserted by install script }}}

EOF
fi
