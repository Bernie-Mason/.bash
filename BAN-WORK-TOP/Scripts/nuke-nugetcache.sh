#!/bin/bash

say() {
	echo "$@" 1>&2 #redirect stdout to stderr
}

PACKAGE_CACHE='/c/users/Bernie/.nuget/packages/'
rm -rf PACKAGE_CACHE || echo "Could not remove cache"