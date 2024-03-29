#!/bin/bash
# Some Bash script to bootstrap a Fish-based Ubuntu install.
# Untested, the best comment I can make is that it seems to work.
# Installs everything to $CURDIR and makes symlinks from `~/.xyz`.
# IME this approach is preferable for long-term maintenance.
#
# Instead of `chsh`, we source Fish at the end of `.bashrc`.
# This approach facilitates sharing paths and whatnot.

set -ueo pipefail

me=$(readlink -f "${BASH_SOURCE[0]}")
CURDIR=$(cd -- "$(dirname -- "${me}")" &> /dev/null && pwd)
source "$CURDIR/helpers.sh"

# build nvim:
# sudo apt-get install ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip curl doxygen
#
# dirvish (emacs):
# https://github.com/alexluigit/dirvish
# sudo apt install fd-find poppler-utils ffmpegthumbnailer mediainfo imagemagick tar unzip

apt_pkgs="\
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
  poppler-utils \
  # `vterm` for emacs
  cmake \
  libtool-bin \
  libvterm-dev
"
log "Installing from apt:\n$apt_pkgs"

sudo apt-get install software-properties-common
sudo apt-add-repository --yes ppa:fish-shell/release-3
sudo apt update
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install $apt_pkgs
sudo apt autoremove --yes

# can't just untar go due to ARM
sudo snap install --classic go
# Potential problem on ARM?
# https://github.com/NixOS/nixpkgs/issues/128959
sudo snap install --classic nvim
sudo snap install --classic emacs

# find latest version on https://www.brow.sh/downloads/
# Used to work, now maybe doesn't...
# browsh_url="https://github.com/browsh-org/browsh/releases/download/v1.8.0/browsh_1.8.0_linux_arm64.deb"
# sudo apt-get install firefox && \
# wget "$browsh_url" -O browsh.deb && \
# sudo apt install ./browsh.deb && \
# rm ./browsh.deb

# Just a bunch of Rust impls of things
rust_plugins="exa \
  bat \
  viu \
  fd-find \
  zoxide"
# procs?
# bartib?
# pier?
# bottom?
# du-dust?
# gitui?

for p in $rust_plugins; do
  # some pkgs fail because rustc versioning
  cargo install "$p" || logw "Failed installing $p\n"
done

GH=https://raw.githubusercontent.com

# docker/docker-slim on ARM
# https://www.docker.com/blog/getting-started-with-docker-for-arm-on-linux/
if ! which docker; then
  log "Docker setup"
  curl -fsSL test.docker.com -o get-docker.sh && sh get-docker.sh && rm get-docker.sh
  sudo usermod -aG docker $USER
  curl -sL $GH/docker-slim/docker-slim/master/scripts/install-dockerslim.sh \
    | sudo -E bash -
else
  log "Skipping Docker setup"
fi
# need to logout and back in

# see some packages https://github.com/oh-my-fish/packages-main/tree/master/packages
# omf install fzf ?
# Ctrl-t  Ctrl-o  Find a file.
# Ctrl-r  Ctrl-r  Search through command history.
# Alt-c  Alt-c  cd into sub-directories (recursively searched).
# Alt-Shift-c  Alt-Shift-c  cd into sub-directories, including hidden ones.
# Ctrl-o  Alt-o  Open a file/dir using default editor ($EDITOR)
# Ctrl-g  Alt-Shift-o  Open a file/dir using xdg-open or open command

log "Symlinking fish functions"
fishcfg=~/.config/fish/config.fish
fishfns=~/.config/fish/functions

[[ -d "$fishfns" ]] \
  && mv "$fishfns" "fishfn_backup" \
  && ln -s "$CURDIR/fishfn/" "$fishfns"

# oh-my-fish / omf
# curl $GH/oh-my-fish/oh-my-fish/master/bin/install \
#   | argv='--noninteractive' fish
# vs. fisher (will just ignore if already installed)
fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher"
fish -c "fisher install edm/bass"
fish -c "fisher install wfxr/forgit"
fish -c "fisher install jorgebucaran/nvm.fish"

touch $fishcfg
if grep -q "START inserted by install script" "$fishcfg"; then
  log "Already found $fishcfg modification!"
else
  log "Appending some values to $fishcfg"
  cat >> "$fishcfg" << EOF
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

zoxide init fish | source || echo "WARN: zoxide plugin fail?"
fish_ssh_agent || echo "WARN: fish_ssh_agent missing?"
fish_vi_key_bindings

abbr pullall 'for d in *; echo $d ; cd $d && git pull && cd -; end'

# END inserted by install script }}}
EOF
fi

# don't have to ssh-add, cf.
# https://github.com/ivakyb/fish_ssh_agent
if ! grep -q "AddKeysToAgent" ~/.ssh/config; then
  echo "AddKeysToAgent yes" >> ~/.ssh/config
fi

if ! which conda; then
  log "Conda install"
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O miniconda.sh &&
    bash miniconda.sh && rm miniconda.sh
  condabin=$HOME/miniconda3/bin
  [[ -d "$condabin" ]] \
    || die "Expected conda bin not found: $condabin"
  log "Adding conda bin $condabin to path"
  export PATH="$condabin:$PATH"
  conda update -n base -y conda
  conda init fish
  conda init bash
  conda config --add channels conda-forge
  log "Installing mamba"
  # https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-channels.html#strict-channel-priority
  # Libmamba should suffice in the future.
  conda install -y conda-libmamba-solver
  export CONDA_SOLVER=libmamba
  conda install -y -c conda-forge mamba
  additional_install="\
    jupyter \
    jupyterlab \
    nb_conda_kernels \
    pdm \
    cookiecutter \
    poetry
  "
  log "Installing via mamba:\n$additional_install"
  mamba install -y -c conda-forge $additional_install
else
  log "Skip conda install"
fi

_ipy=$(ipython locate)
mkdir -p "${_ipy}/profile_default/"
cat > "${_ipy}/profile_default/ipython_config.py" <<'EOF'
lines = [x.strip() for x in '''
  import logging
  import warnings; warnings.filterwarnings("once")
  import datetime as dt

  import json
  import numpy as np
  import pandas as pd
  import scipy as sp
  import matplotlib.pyplot as plt

  import transformers
  import datasets
  import evaluate

  import requests as req
  import functools as ft
  import itertools as it
  import collections as cols
  import dataclasses as dcls

  from types import SimpleNamespace as ns
  from collections import namedtuple as nt

  from pathlib import Path
'''.split('\n')]

c.InteractiveShellApp.exec_lines = [
    '%load_ext autoreload',
    '%autoreload 2',
    'import logging; '
    'logging.basicConfig('
        'format="[%(levelname)s:%(asctime)s] %(message)s", '
        'datefmt="%m%d@%H%M", '
        'level=logging.INFO); '
    'L = logging.getLogger("notebook");'
    'L.setLevel(logging.DEBUG)',
    *lines
]

c.TerminalInteractiveShell.editing_mode = 'vi'
EOF


echo > ~/.cookiecutterrc <<EOF
# https://cookiecutter.readthedocs.io/en/2.1.1/advanced/user_config.html#user-config	
default_context:
  full_name: "Toni Kukurin"
  name: "Toni Kukurin"
  author_name: "Toni Kukurin"
  email: "tkukurin@gmail.com"
  github_username: tkukurin
  username: tkukurin

cookiecutters_dir: $HOME/proj/

replay_dir: $HOME/proj/cookiecutter_replays

abbreviations:
  gh: https://github.com/{0}.git

EOF

log "PDM setup"
grep -q "pep582" ~/.bashrc \
  || (pdm --pep582 >> ~/.bashrc)
pdm completion fish > "$HOME/.config/fish/completions/pdm.fish"

log "tmux setup"
mkdir -p $CURDIR/tmux/plugins
[[ -d ~/.tmux ]] || ln -s $CURDIR/tmux ~/.tmux
[[ -f ~/.tmux.conf ]] || ln -s $CURDIR/.tmux.conf ~/.tmux.conf
[[ -d ~/.tmux/plugins/tpm ]] || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm


log "NVM setup"
[[ ! -d ~/.nvm ]] && export NVM_DIR="$HOME/.nvm" && (
  git clone https://github.com/nvm-sh/nvm.git "$CURDIR/nvm"
  ln -s "$CURDIR/nvm" "$NVM_DIR"
  cd "$NVM_DIR"
  git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
) && . "$NVM_DIR/nvm.sh"
# omf install nvm  # bindings (note: some SHLVL error)
nvm install latest || logw "nvm latest install failed"
export nvm_default_version='latest'

log "Downloading some configs from git"
_addon_dir="$CURDIR/addon"
mkdir -p "$_addon_dir"
cd "$_addon_dir"
git clone https://github.com/NvChad/NvChad --depth 1
git clone git@github.com:syl20bnr/spacemacs.git --depth 1
git clone git@github.com:doomemacs/doomemacs.git --depth 1
git clone git@github.com:seagle0128/.emacs.d.git centauremacs --depth 1
git clone git@github.com:rememberYou/.emacs.d.git rememberyouemacs --depth 1

log "Trying doomemacs installation"
cd doomemacs
bin/doom install || loge "failed doomemacs install"
bin/doom sync || loge "failed doomemacs sync"
cd ..

cd "$CURDIR"

log "Vim setup"
curl -fLo ./vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
[[ -d ~/.vim ]] || ln -s $CURDIR/vim ~/.vim

# TODO?
log "nvim setup" 
[[ -d ~/.config/nvim ]] \
  || git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1
# https://nvchad.com/config/Walkthrough


log "Emacs setup"
# cf. https://wikemacs.org/wiki/Emacs_server
# if you want to setup systemd.
# otherwise https://stackoverflow.com/questions/5570451/how-to-start-emacs-server-only-if-it-is-not-started
[[ -d ~/.emacs.default ]] || ln -s "$CURDIR/emacs" ~/.emacs.default

# c/p from the chemacs2 install suggestion:
# https://github.com/plexus/chemacs2 for easy profile switching
# 
# == Example ==
# emacs --daemon &  # default
# emacs --with-profile doom --daemon &
# emacsclient -c -s gnu -a emacs
# emacsclient -c -s doom -a emacs
# =============
#
# [ -f ~/.emacs ] && mv ~/.emacs ~/.emacs.bak
# [ -d ~/.emacs.d ] && mv ~/.emacs.d ~/.emacs.default
log "Chemacs setup for profile switching"
[[ -d ~/.emacs.d ]] || git clone https://github.com/plexus/chemacs2.git ~/.emacs.d
[[ -f "$HOME/.emacs-profiles.el" ]] || cat >> $HOME/.emacs-profiles.el << EOF
(("default" . ((user-emacs-directory . "~/.emacs.default")))
 ("spacemacs" . ((user-emacs-directory . "$_addon_dir/spacemacs")))
 ("doom" . ((user-emacs-directory . "$_addon_dir/doomemacs")
            (env . (("DOOMDIR" . "$_addon_dir/doomemacs/cfg")))))
)
EOF

# LSPs in the emacs org config
npm install -g typescript-language-server typescript
# NOTE: python-language-server is unmaintained
mamba install python-lsp-server python-lsp-server-base

if grep -q "START inserted by install script" ~/.bashrc; then
  log "Already found .bashrc modification!"
else
  log "Bashrc setup"
  # 'EOF' to prevent expansion
  cat >> ~/.bashrc << 'EOF'

# START inserted by install script {{{

alias pullall='for d in *; echo $d ; cd $d && git pull && cd -; end'

if [ -d "$HOME/go/bin" ]; then
  export PATH="$HOME/go/bin:$PATH"
fi

if [ -d "$HOME/.cargo/bin" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

# Set rg and allow multi-file match
if type rg &> /dev/null; then
  export FZF_DEFAULT_COMMAND='rg --files'
  export FZF_DEFAULT_OPTS='-m --height 50% --border'
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# make sure conda uses the fast resolver
# https://github.com/conda-incubator/conda-libmamba-solver
export CONDA_SOLVER=libmamba
export CONDA_EXPERIMENTAL_SOLVER=libmamba

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export nvm_default_version='latest'

export EDITOR=vim
[[ $(which bat) ]] && export PAGER=bat || export PAGER=less
[[ $(which fish) ]] && exec -l fish "$@"

# END inserted by install script }}}

EOF
fi
