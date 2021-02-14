# cdinstaller
A bash script for installing Clone Deploy remote install server on Ubuntu server 18.04, posted here mainly for demonstrating my experience in bash programming to potential employers.
Most of the installation commands are readily available in the project wiki, I just compiled them all to one single installation scipt for ease of use and added some functionality.
The script will download depencies, such as mono, samba, tftpd-hpa and apache and install them for you, and can download and extract the server files if needed, you just need to enable it before running the script.
The script will also ask for necessary usernames and passwords, and modify configuration files accordingly.
Instructions for everything are commented in the script itself so go through everything before running and modify if needed.
