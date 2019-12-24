#!/bin/bash

scp ~/.bash/.bash_core/.ssh_bashrc $1:/tmp/.bashrc_temp
ssh -t $1 "bash --rcfile /tmp/.bashrc_temp ; rm /tmp/.bashrc_temp"
