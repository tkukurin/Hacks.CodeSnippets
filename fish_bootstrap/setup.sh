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
sudo snap install --classic nvim
sudo snap install --classic emacs

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
  # conda config --set channel_priority false
  conda install -y conda-libmamba-solver
  conda install -y -c conda-forge mamba
  additional_install="\
    jupyter \
    jupyterlab \
    nb_conda_kernels \
    pdm\
  "
  log "Installing via mamba:\n$additional_install"
  mamba install -y -c conda-forge $additional_install
else
  "Skip conda install"
fi

log "PDM setup"
pdm --pep582 >> ~/.bashrc
pdm completion fish > ~/.config/fish/completions/pdm.fish


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


log "Vim setup"
curl -fLo ./vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
[[ -d ~/.vim ]] || ln -s $CURDIR/vim ~/.vim


log "Emacs setup"
[[ -d ~/.emacs.d ]] || ln -s "$CURDIR/emacs" ~/.emacs.d


if grep -q "START inserted by install script" ~/.bashrc; then
  log "Already found .bashrc modification!"
else
  log "Bashrc setup"
  # 'EOF' to prevent expansion
  cat >> ~/.bashrc << 'EOF'

# START inserted by install script {{{

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

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export EDITOR=vim
[[ $(which bat) ]] && export PAGER=bat || export PAGER=less
[[ $(which fish) ]] && exec -l fish "$@"

# END inserted by install script }}}

EOF
fi
