#!/bin/bash

function generic-update(){
	cd $1 || die 1 "Directory doesn't exist"
	
	local ISUPTODATE=$(git status | grep "Your branch is up-to-date with 'origin/master'.")
	if [ -z "$ISUPTODATE" ];
	then
		git pull || die 1 ""
	else
		echo "Your branch is up-to-date with 'origin/master'."
	fi
	local ISWORKINGTREECLEAN=$(git status | grep "nothing to commit, working tree clean")
	if [ -z "$ISUPTODATE" ];
	then
		git add .
		git commit -m 'Generic update'
		git push || die 1 ""
	else
		echo "Nothing to commit, working tree clean."
	fi
	cd -
	ascii_ok
}
