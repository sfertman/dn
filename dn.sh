#!/bin/bash
shopt -s extglob
set -e

## useful resource: https://hackernoon.com/inspecting-docker-images-without-pulling-them-4de53d34a604
# "inspecting docker image without pulling"

DN_INSTALL_DIR="$(eval echo '~/.dn')"
DN_SCRIPT_VERSION="0.1.0"
DN_INSTALLED_VERSION="$(< "${DN_INSTALL_DIR}"/.version)"

echoerr() { echo "$@" 1>&2; }
ERRNIMPL() { echoerr "ERROR: Not implemented"; }

dn_help() {
  echoerr "
Usage:

  dn [OPTIONS] VERSION
    Switch to specified version x.y.z (install if missing.)

  dn COMMAND ...
    Manage versions using available commands below.

Options:

  -g, --global   Affect global node version when switching
  -v, --version  Show installed dn version

Commands:
  add      Install one or more versions
  ls       List installed versions
  rm       Delete a version
  search   Search available versions
  show     Display information about current version
  switch   Switch to installed version
  version  Show dn version information

Run 'dn COMMAND --help' for more information on a command.";
}

dn_install() {
  # Installs dn on your system
  ERRNIMPL;
}

dn_uninstall() {
  # Uninstalls dn from your system
  ERRNIMPL;
}

validate_version() {
  # echoes input if semver version x.y.z and nothing otherwize
  echo "${1}" | grep -Eo '^[0-9]+(\.[0-9]+){0,2}$'
  ### TODO: make this work like an idiomatic validation fn.
  ### Should return no result if valid and "INVALID_VERSION" otherwise
}

is_installed_version() {
  # echoes input if version installed and nothing otherwize
  local version="${1}"
  if [ ! -z $(docker images node:${version}-alpine -q) ] ; then
    echo "${version}"
  fi
}

dn_add() {
  _help() { echoerr "
Usage:  dn add VERSION [VERSION...]

Install one or more node versions.";}

  if [ "$#" -le 0 ] ; then
    _help
  else
    case "$1" in
      -h|--help)
        _help
        ;;
      *)
        for v ; do
          docker pull "library/node:${v}-alpine";
        done
        ;;
    esac
  fi
}

dn_rm() {
  _help() { echoerr "
Usage:  dn rm VERSION [VERSION...]

Uninstall one or more node versions from your system.";}

  if [ $# -le 0 ] ; then
    _help
  else
    case "$1" in
      -h|--help)
        _help
        ;;
      *)
        for v ; do
          docker rmi "node:${v}-alpine"
        done
        ;;
    esac
  fi
}

dn_run() {
  _help() { echoerr "
Usage: dn run COMMAND [ARG...]

Commands:
  node  Run node [ARG...]
  npm   Run npm [ARG...]
  npx   Run npx [ARG...]
  yarn  Run yarn [ARG...]";}

  validate_command() {
    if [[ ! $1 =~ ^(node|npm|npx|yarn)$ ]]; then
      echo 'INVALID_COMMAND';
    fi
  }

  if [[ "$#" -le 0 || "$1" = '-h' || "$1" = '--help' ]]; then
    _help;
  else
    local node_version=$(get_active_version)
    local CMD=(docker run -it --rm);
    CMD=(${CMD[*]} -it);
    CMD=(${CMD[*]} -w "/.dnode${PWD}");
    CMD=(${CMD[*]} -v "${PWD}:/.dnode${PWD}");
    ## TODO: mount external node_modules
    CMD=(${CMD[*]} "node:${node_version}-alpine");
    if [ -z $(validate_command $1) ]; then
      CMD=(${CMD[*]} $@);
    else
      echoerr "Unknown command $1";
      return 1
    fi
    ${CMD[*]}
  fi
}

dn_switch_local() {
  local local_version="$1";
  if [ ! -z $(validate_version "${local_version}") ]; then
    printf "${local_version}" > .dnode_version;
  fi
}

dn_switch_global() {
  local global_version="$1";
  if [ ! -z $(validate_version "${global_version}") ]; then
    printf "${global_version}" > "${DN_INSTALL_DIR}.dnode_version";
  fi
}

dn_switch() {
  _help() { echoerr "
Usage:  dn switch [OPTIONS] VERSION

Switch to specified installed VERSION. Will fail if VERSION is not installed.

Options:

  -g, --global  Affect global version when switching";}

  if [ $# -le 0 ] ; then
    _help;
  else
    local is_global;
    local is_help;

    while [[ $# -gt 0 && $1 == -* ]]; do
      case "$1" in
        -g|--global)
          is_global=1
          ;;
        -h|--help)
          is_help=1
          ;;
        *)
          echoerr "Unknown option $1";
          return 1
          ;;
      esac
      shift
    done

    args=$@;
    if [ ! -z $is_help ]; then
      _help;
    elif [ ! -z $is_global ]; then
      dn_switch_global ${args[*]}
    else
      dn_switch_local ${args[*]}
    fi
  fi
}

dn_use_global() {
  rm -f .dnode_version
}

dn_version() {
  echoerr "
Script version:     $DN_SCRIPT_VERSION
Installed version:  $DN_INSTALLED_VERSION"
}

dn_add_and_switch() {
  ## FIXME: do not install if exists; add always tries to pull
  dn_add $@
  dn_switch $@
}

dn_ls() {
  _help() {echoerr "
Usage:  dn ls

List installed versions.";}

  case "$1" in
    -h|--help)
      _help
      ;;
    *)
    local tag_versions=( $(docker images "node:*-alpine" --format={{.Tag}} \
                            | tag_to_version \
                            | sort --version-sort) )
    local img_tags=( $(version_to_tag ${tag_versions[*]}) )
    local full_versions=( $(docker image inspect ${img_tags[*]} \
                             | jq -r '.[].Config.Env[]' \
                             | grep NODE_VERSION \
                             | grep -Eo --color=never '[0-9]+(\.[0-9]+){0,2}') )
      for i in ${!tag_versions[*]} ; do
        if [ -z $(echo ${tag_versions[$i]} | grep -Eo '^[0-9]+(\.[0-9]+){2}$' ) ]; then
          echo -e "${tag_versions[$i]}\t(${full_versions[$i]})"
        else
          echo "${tag_versions[$i]}"
        fi
      done
      ;;
  esac
}

get_active_version_local() {
  # returns the active node version. If no local version found, returns the global configured

  local this_dir="$1"

  if [ -z "$this_dir" ]; then
    this_dir="$PWD"
  fi

  if [ -f "$this_dir/.dnode_version" ]; then
    echo "$(<$this_dir/.dnode_version)"
  elif [ "/" != "$this_dir" ]; then
    get_active_version_local $(dirname $this_dir)
  fi
}

# make something that can write: (maybe dn info or something)
#   12.0.1 (LOCAL: this_dir)
#   12.13.14 (GLOBAL)

get_active_version_global() {
  echo "$(< "${DN_INSTALL_DIR}"/.dnode_version)"
}

get_active_version() {
  local local_version="$(get_active_version_local)";
  if [ ! -z "${local_version}" ]; then
    echo "${local_version}"
  else
    get_active_version_global;
  fi
}

dn_show() {
  _help() { echoerr "
Usage:  dn show

Display information about currently active node version.";}

  case "$1" in
    -h|--help)
      _help
      ;;
    *)
      local active_version=$(get_active_version)
      docker images "node:$active_version-alpine"
      # ^ can possibly make it fancier?
      ;;
  esac
}

get_auth_token() {
  # returns a docker hub annonymous auth token to pull from $repo
  # Example: get_auth_token library/node
  local repo=$1
  curl \
    --silent \
    "https://auth.docker.io/token?scope=repository:$repo:pull&service=registry.docker.io" \
    | jq -r '.token'
}

get_tags() {
  # Retrieves all $repo tags from dockerhub
  # Exapmple: get_tags library/node
  local repo=$1
  local token=$(get_auth_token $repo)
  curl\
    --silent \
    --header "Authorization: Bearer $token" \
    "https://registry-1.docker.io/v2/$repo/tags/list" \
    | jq -r '.tags[]'
}

tag_to_version() {
  # Converts x[.y[.z]]-alpine tags to versions. Accepts pipe.
  # Example: tag_to_version 12-alpine 12.1.3-alpine 14.0.4-alpine
  #          docker images "node:*-alpine" --format={{.Tag}} | tag_to_version
  if [ "$#" -gt 0 ]; then
    for t in $@ ; do
      echo "$t"
    done | grep -E '^[0-9]+(\.[0-9]+){0,2}-alpine$' | grep --color=never -Eo '^[0-9]+(\.[0-9]+){0,2}'
  else
    while read t ; do
      echo "$t"
    done | grep -E '^[0-9]+(\.[0-9]+){0,2}-alpine$' | grep --color=never -Eo '^[0-9]+(\.[0-9]+){0,2}'
  fi
}

version_to_tag() {
  if [ "$#" -gt 0 ]; then
    for v; do
      echo "node:$v-alpine"
    done
  else
    while read v ; do
      echo "node:$v-alpine"
    done
  fi
}

get_node_versions() {
  # Retrieves all available alpine versions from docker-hub
  get_tags library/node | tag_to_version | sort --version-sort
}


dn_search() {
  _help() { echoerr "
Usage:  dn search VERSION_PREFIX

Search available versions. Will display any matching versions starting with VERSION_PREFIX.";}

  if [ $# -le 0 ]; then
    _help;
  else
    case "${1}" in
      -h|--help)
        _help
        ;;
      *)
        local prefix="${1}";
        if [ -z $(validate_version ${prefix}) ]; then
          _help;
        else
          get_node_versions | grep --color=never -Eo "^${prefix}.*"
        fi
        ;;
    esac
  fi
}

ARGS=("$@")
REST_ARGS=${ARGS[*]:1}
## TODO: encapsulate this into a "main" fn
case "$1" in
  -h|--help)
    dn_help
    ;;
  -v|--version)
    echo "$DN_INSTALLED_VERSION"
    ;;
  # TODO: add is_global here too
  +([0-9])?(\.+([0-9]))?(\.+([0-9])))
    dn_add_and_switch ${ARGS[*]}
    ;;
  add) #+
    dn_add ${REST_ARGS[*]}
    ;;
  install) # TODO
    dn_install ## args?
    ;;
  ls) #+
    dn_ls ${REST_ARGS[*]}
    ;;
  rm) #+
    dn_rm ${REST_ARGS[*]}
    ;;
  run) # TODO: almost done
    dn_run ${REST_ARGS[*]}
    ;;
  search) #+
    dn_search ${REST_ARGS[*]}
    ;;
  show) #+
    dn_show ${REST_ARGS[*]}
    ;;
  switch) #+
    dn_switch ${REST_ARGS[*]}
    ;;
  uninstall) # TODO
    dn_uninstall
    ;;
  use-global) # TODO: create dn_use_global_help
    dn_use_global
    ;;
  version) #+
    dn_version
    ;;
  *) #+
    dn_help
    ;;
esac

## this is how I want my cli to look like

# # install itself on your system
# dn install

# # uninstall itself from your system
# dn uninstall

# # to search all available resources online and mark the ones already installed (a-la brew)
# dn search <some regexp>

# # to get the *latest* version of node 11.x.y if doesn't exist on machine or switch to whatever node 11.x.y already exists on machine
# dn 11

# # to get/switch a specific version
# dn 11.4.5

# # to add a node version explicitly
# dn add x.y.z

#  # to remove a node version
# dn rm 11.4.5

#  # to switch to a node version explicitly
# dn switch x.y.z

# # to list all installed node versoins
# dn ls

# # to display details about the version I currently have active
# dn show

# # to modify global environment
# jm [-g|--global] ...
