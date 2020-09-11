#!/bin/sh


## useful resource: https://hackernoon.com/inspecting-docker-images-without-pulling-them-4de53d34a604
# "inspecting docker image without pulling"

DN_SCRIPT_VERSION=0.1.0
DN_INSTALLED_VERSION=$(cat ~/.dn/.version)

dn_version() {
  echoerr "
Script version:     $DN_SCRIPT_VERSION
Installed version:  $DN_INSTALLED_VERSION"
}

echoerr() { echo "$@" 1>&2; }
ERRNIMPL() { echoerr "ERROR: Not implemented"; }

dn_help() {
  echoerr "
Usage:

  dn [OPTIONS] VERSION
    Switch to specified version (install if missing.)

  dn COMMAND ...
    Manage versions using available commands below.

Options:

  -g, --global   Affect global version when switching
  -v, --version  Show installer dn version

Commands:
  add      Install one or more versions
  ls       List installed versions
  rm       Delete a version
  search   Search available versions
  show     Display information about current version
  switch   Switch to installed version
  version  Show the dn version information

Run 'dn COMMAND --help' for more information on a command.";
}

dn_add_help() {
  echoerr "
Usage:  dn add VERSIONS...

Install one or more node versions.";
}

dn_ls_help() {
  echoerr "
Usage:  dn ls

List installed versions.";
}

dn_rm_help() {
  echoerr "
Usage:  dn rm V1 V2 ...

Uninstall one or more node versions from your system.";
}

dn_search_help() {
  echoerr "
Usage:  dn search VERSION

Search available versions. Will display any matching versions starting with major.
For example: 'dn search 12' will display all versions matching '12.x.y'
             'dn search 11.4' will display all versions matching '11.4.x'.";
}

dn_show_help() {
  echoerr "
Usage:  dn show

Display information about currently active node version.";
}

dn_switch_help() {
  echoerr "
Usage:  dn switch [OPTIONS] VERSION

Switch to specified installed VERSION. Will fail if VERSION is not installed.

Options:

  -g, --global  Affect global version when switching";
}


install() {
  # Installs dn on your system
  ERRNIMPL;
}

uninstall() {
  # Uninstalls dn from your system
  ERRNIMPL;
}

is_version() {
  # echoes input if semver version x.y.z and nothing otherwize
  echo 1
  ERRNIMPL;
}

is_installed_version() {
  # echoes input if version installed and nothing otherwize
  ERRNIMPL;
}

dn_add() {
  if [[ $# -le 0 ]] ; then
    dn_add_help
  else
    case "$1" in
      -h|--help)
        dn_add_help
        ;;
      *)
        for v in $@ ; do
        # TODO(performance): check if image exists locally before tryoing to pull
          docker pull library/node:$v-alpine;
        done
        ;;
    esac
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
    --header "Autorization: Bearer $token" \
    "https://registry-1.docker.io/$repo/tags/list" \
    | jq -r '.tags[]'
}

tag_to_version() {
  # Converts tags to versions (keeps alpine only)
  # Example: tag_to_version 12-alpine 12.1.3-alpine 14.0.4-alpine

  # local tag=$1
  # grep -E '^[0-9]+\.?[0-9]*\.?[0-9]*-alpine$' \
  #   | grep -Eo '^[0-9]+\.?[0-9]*\.?[0-9]*[^-]*' <<<$tag ## or something

  for t in $@ ; do
    grep -E '^[0-9]+\.?[0-9]*\.?[0-9]*-alpine$' | grep -Eo '^[0-9]+\.?[0-9]*\.?[0-9]*[^-]*' <<< "$t" ## or something
  done
}

get_node_versions() {
  get_tags library/node | tag_to_version | sort --version-sort
}

get_versions_old() {
  local image=$1
  local token=$2
  curl\
    --silent \
    --header "Autorization: Bearer $token" \
    "https://registry-1.docker.io/$image/tags/list" \
    | jq -r '.tags[]' \
    | grep -E '^[0-9]+\.?[0-9]*\.?[0-9]*-alpine$' \
    | grep -Eo '^[0-9]+\.?[0-9]*\.?[0-9]*[^-]*' \
    | sort --version-sort
}


get_dir() {
  dirname $PWD
}


get_active_version() {
  # returns the active node version. If no local version found, returns the global configured
  # while [ ! -f .dnode_version ]
  echo "spam";
}

ARGS=(${@})
REST_ARGS=${ARGS[*]:1}

case "$1" in
  -h|--help)
    dn_help
    ;;
  -v|--version)
    echo $DN_INSTALLED_VERSION
    ;;
  -semver_regex) ## figure out how to do this
    add_and_switch ${ARGS[@]}
    ;;
  add)
    dn_add ${REST_ARGS[*]}
    ;;
  ls)
    dn_ls ${REST_ARGS[@]}
    ;;
  rm)
    dn_rm ${REST_ARGS[@]}
    ;;
  search)
    dn_search ${REST_ARGS[@]}
    ;;
  show)
    dn_switch ${REST_ARGS[@]}
    ;;
  switch)
    dn_switch ${REST_ARGS[@]}
    ;;
  version)
    dn_version
    ;;
  *)
    dn_help
    ;;
esac


# # straightforward example of command-line parameter handling:
# while [ $# -gt 0 ]; do    # Until you run out of parameters . . .
#   case "$1" in
#     -g|--global)
#       DN_IS_GLOBAL=1
#       ;;

#     --help)
#       DN_IS_HELP=1
#       ;;
#   esac
#   shift       # Check next set of parameters.
# done

# get_cmd
# ## place holder for getting the command from cli input

# help() {
#   local cmd=$1
#   cat help/$1.txt
# }


# if [ $DN_IS_HELP ]; then
#   help $DN_CMD
#   ## find a way to exit the script here without throwing errors (hint: exit is not the wayh because it will close the terminal)
# fi


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
