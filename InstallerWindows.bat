@echo off 
echo After the installation is done, the window will close itself, DO NOT close it yourself or else this would break the launcher, please don't forget to make a backup folder of your Bleach Rebirth of Souls folder, in case things go wrong (this will also allow you to use the repair function in the launcher)
pause

winget uninstall Python.Python.3.14
winget install --id Python.Python.3.11 -e --accept-source-agreements --accept-package-agreements
winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements

py -0

if exist BROS-Patch (
	rmdir /s /q BROS-Patch
)
git clone https://github.com/Nilsix/BROS-Patch.git


