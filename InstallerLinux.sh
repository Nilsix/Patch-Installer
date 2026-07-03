#!/bin/bash
echo "After the installation is done, the window will close itself, DO NOT close it yourself or else this would break the launcher, please don't forget to make a backup folder of your Bleach Rebirth of Souls folder"
read -p "Press Enter to continue..."

sudo apt-get update
sudo apt-get install -y python3.11 python3-pip git

pip3 install pygame

if [ -d "BROS-Patch" ]; then
    rm -rf BROS-Patch
fi

git clone https://github.com/Nilsix/BROS-Patch.git