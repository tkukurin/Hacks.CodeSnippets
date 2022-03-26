#!/bin/bash
# Some Bash script to bootstrap a Fish-based Ubuntu install.
# Untested, the best comment I can make is that it seems to work.
# Installs everything to $CURDIR and makes symlinks from `~/.xyz`.
# IME this approach is preferable for long-term maintenance.
#
# Instead of `chsh`, we source Fish at the end of `.bashrc`.
# This approach facilitates sharing paths and whatnot.

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

# pyenv requirements to build Python
sudo apt-get install --no-install-recommends \
  make \
  build-essential \
  libssl-dev \
  zlib1g-dev \
  libbz2-dev \
  libreadline-dev \
  libsqlite3-dev \
  wget \
  curl \
  llvm \
  libncurses5-dev \
  xz-utils \
  tk-dev \
  libxml2-dev \
  libxmlsec1-dev \
  libffi-dev \
  liblzma-dev

sudo snap install go --classic  # can't just untar go due to ARM

# Just a bunch of Rust impls of things
cargo install exa
cargo install bat
cargo install viu  # view images in terminal
cargo install fd-find
# cargo install procs?
# cargo install bartib?
# cargo install pier?
# cargo install zoxide? z instead of cd
# cargo install bottom?
# cargo install du-dust?
# cargo install gitui?

# nnn with plugins ?
# sudo apt-get install nnn
# curl -Ls https://raw.githubusercontent.com/jarun/nnn/master/plugins/getplugs | sh
# curl https://raw.githubusercontent.com/jarun/nnn/master/misc/quitcd/quitcd.fish --output $CURDIR/fishfn/n.fish

# pdftotext
sudo apt-get install poppler-utils

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

[[ -d ~/.config/fish/functions ]] \
  && rmdir ~/.config/fish/functions \
  && ln -s $CURDIR/fishfn ~/.config/fish/functions
cat >> ~/.config/fish/config.fish << EOF
source $CURDIR/.aliasrc
EOF

# pyenv
omf install pyenv
git clone https://github.com/pyenv/pyenv.git $CURDIR/pyenv
ln -s $CURDIR/pyenv/ ~/.pyenv


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

export PATH="$HOME/.local/bin:$PATH"
pip install --user pdm
pdm --pep582 >> ~/.bashrc
pdm completion fish > ~/.config/fish/completions/pdm.fish


if grep -q "START inserted by install script" ~/.bashrc; then
  echo "Already found .bashrc modification!"
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
