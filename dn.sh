#!/bin/sh

## useful resource: https://hackernoon.com/inspecting-docker-images-without-pulling-them-4de53d34a604
# "inspecting docker image without pulling"

get_token() {
  local image=$1

  curl \
    --silent \
    "https://auth.docker.io/token?scope=repository:$image:pull&service=registry.docker.io" \
    | jq -r '.token'
}

get_tags() {
  local repo=$1
}

tag_to_version() {
  local tag=$1
  grep -E '^[0-9]+\.?[0-9]*\.?[0-9]*-alpine$' \
    | grep -Eo '^[0-9]+\.?[0-9]*\.?[0-9]*[^-]*' <<<$tag ## or something
}

get_versions() {
  local image=$1
  local token=$2
  # curl\
  #   --silent \
  #   --header "Autorization: Bearer $token" \
  #   "https://registry-1.docker.io/$image/tags/list"
  #   | jq -r '.tags[]'
  #   | grep -E '^[0-9]+\.?[0-9]*\.?[0-9]*-alpine$' \
  #   | grep -Eo '^[0-9]+\.?[0-9]*\.?[0-9]*[^-]*' \
  #   | sort --version-sort
  curl\
    --silent \
    --header "Autorization: Bearer $token" \
    "https://registry-1.docker.io/$image/tags/list"
    | jq -r '.tags[]'
    | tag_to_version \
    | sort --version-sort

}





# straightforward example of command-line parameter handling:
while [ $# -gt 0 ]; do    # Until you run out of parameters . . .
  case "$1" in
    -g|--global)
      DN_IS_GLOBAL=1
      ;;

    --help)
      DN_IS_HELP=1
      ;;
  esac
  shift       # Check next set of parameters.
done

get_cmd
## place holder for getting the command from cli input

help() {
  local cmd=$1
  cat help/$1.txt
}


if [ $DN_IS_HELP ]; then
  help $DN_CMD
  ## find a way to exit the script here without throwing errors (hint: exit is not the wayh because it will close the terminal)
fi


## this is how I want my cli to look like

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