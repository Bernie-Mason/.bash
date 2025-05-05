#!/bin/bash
# Playground for testing the script


string="Grid_3.0.97.0"
if [[ $string =~ Grid_([0-9]+\.[0-9]+)\.([0-9]+)\.[0-9]+ ]]; then
    echo "Full match: ${BASH_REMATCH[0]}"  # Output: Grid_3.0.97.0
    echo "Major.Minor: ${BASH_REMATCH[1]}"  # Output: 3.0
    echo "Patch: ${BASH_REMATCH[2]}"  # Output: 97
fi

function outParametertest(){
    currentDir=$(pwd)
    eval "$1=$currentDir"
}

currentDir=""
outParametertest currentDir
echo "Current directory: $currentDir"