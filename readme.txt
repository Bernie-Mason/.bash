#
# - readme for .bash setup
#

This is the bash configuration space for the work of Bernard Mason. It contains both global (to be used across many machines) and local (to be used on specific machines) settings. These settings include aliases, scripts, configuration and environmental settings. The folder, global, contains all global settings. The folder named .bash_core contains copies of original .bashrc and .bash_profile files from their respective machines and are suffixed with their hostnames. All other non-hidden folders in the root directory are named after their host machine and contain settings for use only on their specific machines.

The aim of this setup is to keep a global set of scripts, aliases and other settings that can be modified and used across any machine that I end up working on. In this way I'll only ever be using one set of naming conventions for all such shortcut commands, whether working on a Unix-like machine or on Windows.

References
https://en.wikibooks.org/wiki/Bash_Shell_Scripting

15/06/2017 - First entry
I have just set up this configuration folder, allowing me to work with easily with the same set of settings across my Windows Machine (BAN-TOP) and my Antergos Virtual Box machine (antergoes-vb).  
Currently, I am mostly using aliases to navigate more easily (cdp, cdd), to find files (find -type f -name "etc" - ffn) and to perform git operations quickly. I am using scripts very simply to update folders (a set of git commands for example).
