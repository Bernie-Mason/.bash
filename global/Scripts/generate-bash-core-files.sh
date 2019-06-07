#!/bin/bash

FILE_BASHRC="~/.bash/.bash_core/.bashrc.${HOSTNAME}"
FILE_BASH_PROFILE="~/.bash/.bash_core/.bash_profile.${HOSTNAME}"
FILE_GIT_CONFIG="~/.bash/.bash_core/.gitconfig.${HOSTNAME}"

if [ ! -f "$FILE_BASHRC" ]{
	touch "$FILE_BASHRC"
}

if [ ! -f "$FILE_GIT_CONFIG" ]{
	touch "$FILE_GIT_CONFIG";
}

if [ ! -f "$FILE_BASH_PROFILE" ]{
	touch "$FILE_BASH_PROFILE";
}