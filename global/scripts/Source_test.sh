#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  TARGET="$(readlink "$SOURCE")"
  if [[ $TARGET == /* ]]; then
    echo "SOURCE '$SOURCE' is an absolute symlink to '$TARGET'"
    SOURCE="$TARGET"
  else
    DIR="$( dirname "$SOURCE" )"
    echo "SOURCE '$SOURCE' is a relative symlink to '$TARGET' (relative to '$DIR')"
    SOURCE="$DIR/$TARGET" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  fi
done
echo "SOURCE is '$SOURCE'"
RDIR="$( dirname "$SOURCE" )"
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
if [ "$DIR" != "$RDIR" ]; then
  echo "DIR '$RDIR' resolves to '$DIR'"
fi
echo "DIR is '$DIR'"


##
echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

script_relative_path1=`dirname $0`
script_relative_path2=`dirname "$BASH_SOURCE"`

script_path1=$(dirname $(readlink -f $0))
script_path2=`dirname $(realpath $0)`
script_path3=$(dirname "$(readlink -f "$BASH_SOURCE")")
script_path4=`pwd`

echo "Script-Dir-Relative : $script_relative_path1"
echo "Script-Dir-Relative : $script_relative_path1"

echo "Script Path 1: $script_path1"
echo "Script Path 2: $script_path2"
echo "Script Path 3: $script_path3"
echo "Script Path 4: $script_path4"