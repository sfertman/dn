#!/usr/bin/env bash
shopt -s extglob
set -e

## useful resource: https://hackernoon.com/inspecting-docker-images-without-pulling-them-4de53d34a604
# "inspecting docker image without pulling"

DN_SCRIPT_VERSION='0.1.0'
DN_INSTALL_NODE_VERSION=14
DN_PREFIX=/usr/local
DN_INSTALL_DIR=${DN_PREFIX}/lib/dn
DN_BIN_DIR=${DN_PREFIX}/bin
DN_REPO_URL='https://github.com/sfertman/dn'

dn_version() {
  if [ -f "${DN_INSTALL_DIR}/.version" ]; then
    echo "$(< "${DN_INSTALL_DIR}/.version")"
  else
    echo "N/A"
  fi
}

echoerr() { echo "$@" 1>&2; }
ERRNIMPL() { echoerr "ERROR: Not implemented! 🤖"; }

dn_install() {
  echo "Installing DN...";
  echo "";
  mkdir -p ${DN_INSTALL_DIR};
  local script_path;
  case "${SHELL}" in
    */zsh)
      script_path="${0}"
      ;;
    */bash|*/sh)
      script_path="$(realpath "${0}")"
      ;;
    *)
      echoerr "Shell ${SHELL} is not supported! Installation FAILED 😱"
      echoerr
      echoerr "To add support for ${SHELL} asap, please open an issue at:"
      echoerr
      echoerr "  ${DN_REPO_URL}/issues"
      echoerr

      return 1
      ;;
  esac

  cp -afp "${script_path}" "${DN_INSTALL_DIR}";
  printf "${DN_SCRIPT_VERSION}" > ${DN_INSTALL_DIR}/.version;
  chmod +x ${DN_INSTALL_DIR}/dn.sh;
  ln -sf ${DN_INSTALL_DIR}/dn.sh ${DN_BIN_DIR}/dn;
  dn_add $DN_INSTALL_NODE_VERSION
  dn_switch -g $DN_INSTALL_NODE_VERSION
  echo
  echo "DN has been successfully INSTALLED. 🎉"
  dn_info
  echo
  echo "Run 'dn --help' to get started. 📖";
}

dn_uninstall() {
  read -p "This will UNINSTALL DN from your system; proceed (y/N)? " -n 1 -r
  echo
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Whew! 😌"
    return 1;
  fi

  echo "Uninstalling DN...";
  echo "";
  rm -rf ${DN_INSTALL_DIR};
  rm -f ${DN_BIN_DIR}/dn
  echo "DN has been successfully UNINSTALLED 🤔"
  echo
  echo "Sorry to see you go. If this is due to a bug or lack"
  echo "of features please let me know by opening an issue at:"
  echo
  echo "  ${DN_REPO_URL}"
  echo
}

validate_version() {
  if [ -z "$(echo "${1}" | grep -Eo '^[0-9]+(\.[0-9]+){0,2}$')" ]; then
    echo 'INVALID_VERSION';
  fi
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
    if [[ ! $1 =~ ^(node|npm|npx|yarn|yarnpkg|sh)$ ]]; then
      echo 'INVALID_COMMAND';
    fi
  }

  if [[ "$#" -le 0 || "$1" = '-h' || "$1" = '--help' ]]; then
    _help;
  else
    local node_version=$(get_active_version);
    local node_major_version=$(echo "${node_version}" | grep --color=never -Eo ^[0-9]+)
    local docker_vol="dnode_modules_${node_major_version}";
    docker volume create "${docker_vol}" > /dev/null;
    local CMD=(docker run -it --rm);
    ## TODO: figure out how to create a container once and then just keep running stuff in it
    ##       figure out if it ha any performance advantages
    CMD=(${CMD[*]} -it);
    CMD=(${CMD[*]} -w "/.dnode${PWD}");
    CMD=(${CMD[*]} -v "${PWD}:/.dnode${PWD}");
    CMD=(${CMD[*]} -v "${docker_vol}:/usr/local/lib/node_modules");
    CMD=(${CMD[*]} "node:${node_version}-alpine");
    if [ -z $(validate_command $1) ]; then
      CMD=(${CMD[*]} $@);
    else
      echoerr "Unknown command $1";
      return 1;
    fi
    ${CMD[*]};
  fi
}

validate_img_tag() {
  docker image inspect "${1}" >/dev/null 2>&1 || echo 'INVALID_IMAGE';
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

    if [ ! -z $is_help ]; then
      _help;
      return 0;
    fi

    local node_version="${1}"
    if [ ! -z $(validate_version "${node_version}") ]; then
      echoerr "Invalid version: ${node_version}";
      return 1;
    fi

    if [ ! -z $(validate_img_tag "node:${node_version}-alpine") ]; then
      echoerr "Version ${node_version} is not installed; to install, run:   dn add ${node_version}";
      return 1;
    fi

    if [ ! -z $is_global ]; then
      printf "${node_version}" > "${DN_INSTALL_DIR}/.dnode_version";
    else
      printf "${node_version}" > .dnode_version;
    fi

    dn_show;

  fi
}

dn_forget() {
  _help() { echoerr "
Usage:  dn forget

Forget local Node version setting and use the next in line version.";}

  if [ $# -gt 0 ]; then
    _help;
  else
    rm -f .dnode_version
  fi
}

dn_use_global() {
  _help() { echoerr "
Usage:  dn use-global

Use the current global Node version setting.";}

  ## TODO: Possibly make global dynamically updatabe?
  ## meaning, if global changes at some point,
  ## .dnode_version will always point to that setting
  ## This requires a change to get_active_version_local
  ## to consider a pointer to global.

  if [ $# -gt 0 ]; then
    _help;
  else
    printf '@global' > .dnode_version;
    dn_show;
  fi
}

dn_info() {
  local node_version node_version_type;
  local flag_file_path=$(get_local_version_flag_path);
  if [[ ! -f ${flag_file_path} || $(< ${flag_file_path}) = '@global' ]]; then
    node_version_type='global';
    node_version=$(get_active_version_global);
    if [ -z $node_version ]; then node_version='N/A'; fi
  else
    node_version_type='local';
    node_version=$(< ${flag_file_path});
  fi

  echoerr "
DN:  Docker Powered Node Version Manager 🐳 + ⬢

Script version:     $DN_SCRIPT_VERSION
Installed version:  $(dn_version)
Node version:       $node_version ($node_version_type)
Source:             ${DN_REPO_URL}"
}

dn_add_and_switch() {
  _help() { echoerr "
Usage:  dn [-g|--global] VERSION

Switch to version x[.y[.z]] (install if missing).
Use -g option to switch global version.";}

  if [ $1 = '-g' ]; then
    dn_add $2
    dn_switch -g $2
  else
    dn_add $1
    dn_switch $1
  fi
}

dn_ls() {
  _help() { echoerr "
Usage:  dn ls

List installed versions.";}

  case "$1" in
    -h|--help)
      _help
      ;;
    *)
      local node_version=( $(docker image list "node:*-alpine" --format={{.Tag}} \
                              | tag_to_version \
                              | sort --version-sort) )
      local active_version=$(get_active_version);
      local prefix='  ';
      for i in ${!node_version[*]} ; do
        if [ "${node_version[$i]}" != "${active_version}" ]; then
          echo "  ${node_version[$i]}"
        else
          echo "* ${node_version[$i]}"
        fi
      done
      ;;
  esac
}

get_local_version_flag_path() {

  local this_dir="$1"

  if [ -z "${this_dir}" ]; then
    this_dir="$PWD"
  fi

  if [ -f "${this_dir}/.dnode_version" ]; then
    echo "${this_dir}/.dnode_version";
  elif [ "/" != "${this_dir}" ]; then
    get_local_version_flag_path "$(dirname "${this_dir}")"
  fi
}

get_active_version_local() {
  # returns the active node version. If no local version found, returns the global configured
  local flag_file_path=$(get_local_version_flag_path);
  if [ -f "${flag_file_path}" ]; then
    local active_version_local="$(< ${flag_file_path})";
    if [ "${active_version_local}" = '@global' ]; then
      get_active_version_global;
    else
      echo "${active_version_local}";
    fi
  fi
}

get_active_version_global() {
  if [ -f "${DN_INSTALL_DIR}/.dnode_version" ]; then
    echo "$(< "${DN_INSTALL_DIR}/.dnode_version")"
  fi
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
      local active_version=$(get_active_version);
      if [ -z ${active_version} ]; then
        echo 'N/A';
      else
        local full_version=$(docker image inspect node:${active_version}-alpine \
                              | jq -r '.[].Config.Env[]' \
                              | grep NODE_VERSION \
                              | grep -Eo --color=never '[0-9]+(\.[0-9]+){0,2}');
        echo "$active_version ($full_version)"
      fi
      ;;
  esac
}

dn_inspect() {
  local active_version=$(get_active_version);
  if [ -z ${active_version} ]; then
    echoerr "Node version undefined! There may be something wrong with your installation."
    return 1;
  else
    docker run --rm node:${active_version}-alpine sh -c "echo \"
Node version:   \$NODE_VERSION
Npm version:    \$(npm -v)
Yarn version:   \$YARN_VERSION
Container OS:   \$(cat /etc/os-release | grep -- 'PRETTY_NAME=' | grep -o [^=]*$)\"";
  fi
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
    for t in $@ ; do echo "$t"; done \
      | grep --color=never -E '^[0-9]+(\.[0-9]+){0,2}-alpine$' \
      | grep --color=never -Eo '^[0-9]+(\.[0-9]+){0,2}'
  else
    while read t ; do echo "$t"; done \
      | grep --color=never -E '^[0-9]+(\.[0-9]+){0,2}-alpine$' \
      | grep --color=never -Eo '^[0-9]+(\.[0-9]+){0,2}'
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
Search available versions.

Usage:

  dn search PREFIX     Search versions by version prefix
  dn search -a|--all   Get full list of versions";}

  if [ $# -le 0 ]; then
    _help;
  else
    case "${1}" in
      -h|--help)
        _help
        ;;
      -a|--all)
        get_node_versions | grep --color=never -Eo '^[0-9]+\.[0-9]+\.[0-9]+'
        ;;
      *)
        local prefix="${1}";
        if [ ! -z $(validate_version "${prefix}") ]; then
          echoerr 'Prefix must be a valid version number of the form x[.y[.z]]';
          _help;
          return 1;
        else
          get_node_versions \
            | grep --color=never -Eo "^${prefix}.*" \
            | grep --color=never -Eo '^[0-9]+\.[0-9]+\.[0-9]+';
        fi
        ;;
    esac
  fi
}

_main() {
  _help() { echoerr "
DN:  Docker Powered Node Version Manager 🐳 + ⬢

Usage:  dn [OPTIONS] COMMAND

Options:
  -g, --global    Affect global version when switching
  -v, --version   Show installed dn version

Commands:
  x[.y[.z]]    Switch to version x.y.z (install if missing)
  add          Install one or more node version
  forget       Forget directory local setting
  info         Display detailed informatoin about dn
  inspect      Display detailed information about active node version
  install      Install dn on your system
  ls           List installed versions
  rm           Delete a version
  search       Search available versions
  show         Show active Node version
  switch       Switch to installed version
  uninstall    Uninstall dn from your system
  use-global   Use global setting in directory

Run 'dn COMMAND --help' for more information on a command."; }

  if [ $# -le 0 ]; then
    _help;
    return 0;
  else
    local is_global is_help is_version;
    while [[ $# -gt 0 && $1 == -* ]]; do
      case "$1" in
        -g|--global)    is_global=1 ;;
        -h|--help)      is_help=1 ;;
        -v|--version)   is_version=1 ;;
        *)              echoerr "Unknown option $1"; return 1 ;;
      esac
      shift
    done

    if [ ! -z $is_help ]; then
      _help;
    elif [ ! -z $is_version ]; then
      dn_version;
    else
      local args=("$@");
      local rest_args=${args[*]:1};
      case "$1" in
        +([0-9])?(\.+([0-9]))?(\.+([0-9])))
          if [ ! -z "${is_global}" ]; then
            dn_add_and_switch -g $1;
          else
            dn_add_and_switch $1;
          fi
          ;;
        add)          dn_add ${rest_args[*]} ;;
        forget)       dn_forget ;;
        inf|info)     dn_info ;;
        inspect)      dn_inspect ;;
        install)      dn_install ;;
        ls|ll|list)   dn_ls ${rest_args[*]} ;;
        rm|remove)    dn_rm ${rest_args[*]} ;;
        run)          dn_run ${rest_args[*]} ;;
        search)       dn_search ${rest_args[*]} ;;
        show)         dn_show ${rest_args[*]} ;;
        switch)       dn_switch ${rest_args[*]} ;;
        uninstall)    dn_uninstall ;;
        use-global)   dn_use_global ;;
        *)            _help ;;
      esac
    fi
  fi
}

_main $@
