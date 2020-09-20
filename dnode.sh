#!/bin/sh

declare -a CMD=(docker run -it --rm); ## add --rm here after I know that it actually works
CMD=(${CMD[*]} -it);
CMD=(${CMD[*]} -w "/.dnode${PWD}");
CMD=(${CMD[*]} -v "${PWD}:/.dnode${PWD}");
## TODO: mount external node_modules
CMD=(${CMD[*]} "node:12-alpine" $@); ## TODO: paramerize version!
echo "running:
  ${CMD[*]}"
# FIXME: ^ cleanup

${CMD[*]}

