#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function start_anno_backend () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  cd -- "$SELFPATH" || return $?
  local ABE_CMD=()

  verify_watchers_limit || return $?
  [ -f users.yml ] || return 4$(
    echo "E: No users.yml. An examplefile can be found in" \
      "anno-common/anno-plugins/users-example.yml" >&2)
  local LINT_YAMLS=(
    users.yml
    )

  local PM2_HOME="$(dirname -- "$SELFPATH")"
  local WANT_USER="$(stat -c '%U#%u' -- "$PM2_HOME")"
  local CRNT_USER="$(id --user --name)#$(id --user)"
  if [ "$1" == --sudo ]; then
    shift
    [ "$CRNT_USER" == "$WANT_USER" ] || ABE_CMD+=(
      sudo
      --preserve-env
      --user "${WANT_USER%\#*}"
      )
  elif [ "$CRNT_USER" == "$WANT_USER" ]; then
    true
  else
    echo "E: Currently running as user $CRNT_USER, but $PM2_HOME" \
      "is owned by $WANT_USER, please make them match." >&2
    return 4
  fi

  ABE_CMD+=(
    env
    HOME="$PM2_HOME"

    npm run sh --

    pm2
    )

  case "$1" in
    pm2.*.yml ) local PM2_CFG="$1"; shift;;
  esac

  [ -z "$PM2_CFG" ] || LINT_YAMLS+=( "$PM2_CFG" )
  npm run check-yaml-syntax "${LINT_YAMLS[@]}" || return $?

  if [ "$#" == 0 ]; then
    [ -n "$PM2_CFG" ] || return 4$(
      echo "E: Please set env var PM2_CFG to a config file path/name," \
        "e.g. pm2.test.yml" >&2)
    ABE_CMD+=(
      --no-daemon
      start
      "$PM2_CFG"
      )
  fi

  ABE_CMD=( exec "${ABE_CMD[@]}" "$@" )
  echo "D: gonna ${ABE_CMD[@]}" || return $?
  "${ABE_CMD[@]}" || return $?
}


function verify_watchers_limit () {
  local KEY='fs.inotify.max_user_watches'
  local VAL="$(sysctl --values "$KEY")"
  local LIMIT="${PM2_WATCHERS_LIMIT:-524288}"
  [ "$VAL" -ge "$LIMIT" ] && return 0
  echo "E: $KEY = $VAL is lower than recommended." \
    "This will often result in chokidar error" \
    '"ENOSPC: System limit for number of file watchers reached".' >&2
  echo "H: To adjust the limit: sudo sysctl $KEY=$LIMIT"
  return 3
}










start_anno_backend "$@"; exit $?
