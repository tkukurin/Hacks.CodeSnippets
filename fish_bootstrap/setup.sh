#!/bin/bash

CURDIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
echo Current directory set to $CURDIR
read x

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
  fish

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

# vim
curl -fLo ./vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
[[ -d ~/.vim ]] || ln -s $CURDIR/vim ~/.vim


# 'EOF' to prevent expansion
# TODO check if this exists in bashrc or something?
cat >> ~/.bashrc << 'EOF'

if [ -d "$HOME/.cargo/bin" ]; then
  PATH="$HOME/.cargo/bin:$PATH"
fi

[[ $(which bat) ]] && export PAGER=bat || export PAGER=less
[[ $(which fish) ]] && exec -l fish "$@"

EOF

