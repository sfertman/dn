#!/bin/bash
set -e

test_fn () {



}

source dn.sh 2> /dev/null
[ ! -z $(validate_version 12.3.) ] || { echo "expected \"\""; exit 1; }

echo last result $?


# validate_version_test() { #tests in functions do not get automatically invoked; gotta be in root script
#   echo "validating 12         $(validate_version 12)"
#   echo "validating 12.        $(validate_version 12.)"
#   echo "validating 12.3       $(validate_version 12.3)"
#   echo "validating 12.3.      $(validate_version 12.3.)"
#   echo "validating 12.3.4     $(validate_version 12.3.4)"
#   echo "validating 12.3.4.5   $(validate_version 12.3.4.5)"
#   echo "validating \"\"         $(validate_version "")"
#   echo "validating abc        $(validate_version abc)"
#   echo "validating a b c      $(validate_version a b c)"
# }

# [[ ]]

# validate_version_test



# tag_to_version_test() {
#   echo 1

# }
