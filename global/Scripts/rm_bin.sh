#!/bin/bash
function rmbin() {
   echo "removing 'obj' directories";
   find . -type d -name obj | xargs -I{} rm -rf "{}";
   echo "removing 'bin' directories";
   find . -type d -name bin | xargs -I{} rm -rf "{}";
   echo "done.";
}