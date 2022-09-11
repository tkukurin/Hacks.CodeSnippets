#!/bin/bash
# Just some helper scripts
# Usage: `source ${this_file}`

# if already set, use $me; else, use this file's name
me=${me:-$(readlink -f "${BASH_SOURCE[0]}")}

function log() { echo -e "\e[1m\e[32m[LOG::${me}]\e[0m\n$@"; }
function logi() { echo -e "\e[1m\e[32m[LOG::${me}]\e[0m\n$@"; }
function logw() { echo -e "\e[1m\e[33m[WARN::${me}]\e[0m\n$@"; }
function loge() { echo -e "\e[1m\e[34m[ERR::${me}]\e[0m\n$@"; }
function die() { loge "$@"; exit 1; }

function user_ok() {
	log "$@"
  read -p "Continue ([y]es or [N]o) > "
  case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
    y|yes) return 0 ;;
    *)     return 1 ;;
  esac
}

function ok_or_die() {
	if ! user_ok "$@"; then
		log "Exiting due to non-confirm from user"
		exit 1
	fi
}

