# SETUP PROCESS

## If on Windows, update your windows path to include the following: 
- %USERPROFILE%\.bash\global\Scripts
- %USERPROFILE%\.bash\global\WorkPlace
- %USERPROFILE%\.bash\global\Scripts\Powershell
- %USERPROFILE%\.bash\global\Scripts\git
- %USERPROFILE%\.bash\global\Vendor

## Create bash configuration files. 
	1. In .bash/.bash_core create .bashrc, .bash_profile and .gitconfig configuration files as desired. You can run generate-bash-core-files to generate blank files with the correct naming
	2. Copy/write config into these files as desired
	3. Run propagate-bash-config to copy these files into your user folder
	4. When making changes to configuration you can make changes to files in use and run backup-bash-config when you're done OR make changes to the files in .bash_core and run propagate-bash-config to propagate your changes out of the working directory.


## Other new computer setup
- Install Chocolatey. In elevated powershell run:
	```powershell
	Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
	```

* Install Haskell. In elevated terminal run:
	choco install haskell-dev

* Install Sublime Text 3. 
	* Run alias "cd-sublime" 