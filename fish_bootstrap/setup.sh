#!/bin/bash
# Some Bash script to bootstrap a Fish-based Ubuntu install.
# Untested, the best comment I can make is that it seems to work.
# Installs everything to $CURDIR and makes symlinks from `~/.xyz`.
# IME this approach is preferable for long-term maintenance.
#
# Instead of `chsh`, we source Fish at the end of `.bashrc`.
# This approach facilitates sharing paths and whatnot.

me="${BASH_SOURCE[0]}"
CURDIR=$(cd -- "$(dirname -- "${me}")" &> /dev/null && pwd)

function log() { echo "\e[1m[LOG::${me}]\e[0m"; }
function waituser() {
	echo $@ ' (waiting OK) > '
  read __discard
}

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
  python3-pip \
  nginx \
  fail2ban \
  default-jre \
  poppler-utils

sudo snap install go --classic  # can't just untar go due to ARM
sudo snap install nvim --classic
sudo snap install emacs --classic

# Just a bunch of Rust impls of things
cargo install exa
cargo install bat
cargo install viu  # view images in terminal
cargo install fd-find
cargo install zoxide  # ? z instead of cd
# cargo install procs?
# cargo install bartib?
# cargo install pier?
# cargo install bottom?
# cargo install du-dust?
# cargo install gitui?

GH=https://raw.githubusercontent.com

# nnn with plugins ?
# sudo apt-get install nnn
# curl -Ls https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs | sh
# curl https://raw.githubusercontent.com/jarun/nnn/master/misc/quitcd/quitcd.fish --output $CURDIR/fishfn/n.fish

# oh-my-fish / omf
# curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install \
#   | argv='--noninteractive' fish
# vs. fisher
curl -sL https://git.io/fisher | source
fisher install jorgebucaran/fisher
fisher install wfxr/forgit
fisher install jorgebucaran/nvm.fish

# docker/docker-slim on ARM
# https://www.docker.com/blog/getting-started-with-docker-for-arm-on-linux/
curl -fsSL test.docker.com -o get-docker.sh && sh get-docker.sh
sudo usermod -aG docker $USER
curl -sL $GH/docker-slim/docker-slim/master/scripts/install-dockerslim.sh \
	| sudo -E bash -
# need to logout and back in

# see some packages https://github.com/oh-my-fish/packages-main/tree/master/packages
# omf install fzf ?
# Ctrl-t	Ctrl-o	Find a file.
# Ctrl-r	Ctrl-r	Search through command history.
# Alt-c	Alt-c	cd into sub-directories (recursively searched).
# Alt-Shift-c	Alt-Shift-c	cd into sub-directories, including hidden ones.
# Ctrl-o	Alt-o	Open a file/dir using default editor ($EDITOR)
# Ctrl-g	Alt-Shift-o	Open a file/dir using xdg-open or open command

[[ -d ~/.config/fish/functions ]] \
  && rmdir ~/.config/fish/functions \
  && ln -s $CURDIR/fishfn ~/.config/fish/functions
cat >> ~/.config/fish/config.fish << EOF

# START inserted by install script {{{
source $CURDIR/.aliasrc

set -Ux forgit_reset_head fgrh
set -Ux forgit_log fgl
set -Ux forgit_diff fgd
set -Ux forgit_ignore fgi
set -Ux forgit_checkout_file fgcf
set -Ux forgit_checkout_branch fgcb
set -Ux forgit_clean fgclean
set -Ux forgit_stash_show fgss
set -Ux forgit_cherry_pick fgcp
set -Ux forgit_rebase fgrb
set -Ux forgit_fixup fgfu
set -Ux forgit_checkout_commit fgco
set -Ux forgit_revert_commit fgrc

zoxide init fish | source

# END inserted by install script }}}

EOF

# pyenv
# sudo apt-get install --no-install-recommends \
#   make \
#   build-essential \
#   libssl-dev \
#   zlib1g-dev \
#   libbz2-dev \
#   libreadline-dev \
#   libsqlite3-dev \
#   wget \
#   curl \
#   llvm \
#   libncurses5-dev \
#   xz-utils \
#   tk-dev \
#   libxml2-dev \
#   libxmlsec1-dev \
#   libffi-dev \
#   liblzma-dev
# git clone https://github.com/pyenv/pyenv.git $CURDIR/pyenv
# ln -s $CURDIR/pyenv/ ~/.pyenv


# conda
wget https://repo.anaconda.com/miniconda/Miniconda3-py39_4.11.0-Linux-aarch64.sh | bash
conda update conda
conda init fish
conda config --add channels conda-forge
conda config --set channel_priority strict
conda install -c conda-forge mamba
mamba install -c conda-forge \
	jupyter \
	jupyter-lab \
	nb_conda_kernels


# tmux
mkdir -p $CURDIR/tmux/plugins
[[ -d ~/.tmux ]] || ln -s $CURDIR/tmux ~/.tmux
[[ -f ~/.tmux.conf ]] || ln -s $CURDIR/.tmux.conf ~/.tmux.conf
[[ -d ~/.tmux/plugins/tpm ]] || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm


# node
#waituser "Installing NVM"
#curl -o- $GH/nvm-sh/nvm/v0.39.1/install.sh | bash

[[ ! -d ~/.nvm ]] && export NVM_DIR="$HOME/.nvm" && (
  git clone https://github.com/nvm-sh/nvm.git "$CURDIR/nvm"
  ln -s "$CURDIR/nvm" "$NVM_DIR"
  cd "$NVM_DIR"
  git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
) && . "$NVM_DIR/nvm.sh"

# omf install nvm  # bindings (note: some SHLVL error)

# vim
curl -fLo ./vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
[[ -d ~/.vim ]] || ln -s $CURDIR/vim ~/.vim

export PATH="$HOME/.local/bin:$PATH"
pip install --user pdm
pdm --pep582 >> ~/.bashrc
pdm completion fish > ~/.config/fish/completions/pdm.fish


if grep -q "START inserted by install script" ~/.bashrc; then
  log "Already found .bashrc modification!"
else
  # 'EOF' to prevent expansion
  cat >> ~/.bashrc << 'EOF'

# START inserted by install script {{{

if [ -d "$HOME/go/bin" ]; then
  PATH="$HOME/go/bin:$PATH"
fi

if [ -d "$HOME/.cargo/bin" ]; then
  PATH="$HOME/.cargo/bin:$PATH"
fi

# Set rg and allow multi-file match
if type rg &> /dev/null; then
  export FZF_DEFAULT_COMMAND='rg --files'
  export FZF_DEFAULT_OPTS='-m --height 50% --border'
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
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
