#!/bin/bash

# This is a bash script for installing CloneDeploy server

#First check that we're running the script as root, if not exit:

if (( EUID != 0 )) ; then
    echo "This script must be run as root!"
exit 1
fi

# Install CloneDeploy:

#Update repositories list:

apt-get -y update

#Install gnupg and ca-certificates:

apt-get -y install gnupg ca-certificates

#Add an apt-key:
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF

#Add the mono repository to /etc/apt/sources.list.d:

echo "deb http://download.mono-project.com/repo/ubuntu stable-bionic main" | tee /etc/apt/sources.list.d/mono-official-stable.list

#Update the repository list:

apt-get update

#Install mono and the depencies:

apt-get -y install mono-devel libapache2-mod-mono apache2 udpcast liblz4-tool mkisofs

#Uncomment the following if you want the script to download the clonedeploy tarball from sourceforge.net.
#If the installer folder already contains the tarball there is no need to download it.
#wget "https://sourceforge.net/projects/clonedeploy/files/CloneDeploy 1.4.0/clonedeploy-1.4.0.tar.gz"

#Extract the tarball:

tar xvzf clonedeploy-1.4.0.tar.gz

#Switch to the directory extracted from the tarball:

cd clonedeploy

#Copy the clonedeploy configuration file to apache config directory:

cp clonedeploy.conf /etc/apache2/sites-available/

#Create the directory containing the Clonedeploy web-interface:

mkdir /var/www/html/clonedeploy

#Copy the web-interface and API files to the directory created earlier:

cp -r frontend /var/www/html/clonedeploy
cp -r api /var/www/html/clonedeploy

#Copy tftpboot-directory to the root directory:

cp -r tftpboot/ /

#Create symbolic links for the following directories:

ln -s ../../images /tftpboot/proxy/bios/images
ln -s ../../images /tftpboot/proxy/efi32/images
ln -s ../../images /tftpboot/proxy/efi64/images
ln -s ../../kernels /tftpboot/proxy/bios/kernels
ln -s ../../kernels /tftpboot/proxy/efi32/kernels
ln -s ../../kernels /tftpboot/proxy/efi64/kernels

#Create the "imaging" directory with the specified absolute path:

mkdir -p /cd_dp/images

#Create the "resources" directory with the specified absolute path:

mkdir /cd_dp/resources

#Create the "mono" and "registry" directories with the specified absolute paths:

mkdir /var/www/.mono
mkdir /etc/mono/registry

#Change recursive ownership of the following directories to www-data:

chown -R www-data:www-data /tftpboot /cd_dp /var/www/html/clonedeploy /var/www/.mono /etc/mono/registry

#Change /tmp-directory permissions:

chmod 1777 /tmp

#Set the maximum number of user instances to 1024:

sysctl fs.inotify.max_user_instances=1024
echo fs.inotify.max_user_instances=1024 >> /etc/sysctl.conf

#Enable the Clonedeploy web-interface:

a2ensite clonedeploy

#Restart apache2 webserver:

service apache2 restart

#Install mysql-server:

apt-get -y install mysql-server

#Query user for database username and password and set them as variables:

read -p "Enter database username: " cduser
read -s -p "Enter password for the database user: " mypass

#Create the database:

mysql << HERE
create database clonedeploy;
CREATE USER "$cduser"@"localhost" IDENTIFIED BY "$mypass";
GRANT ALL PRIVILEGES ON clonedeploy.* TO "$cduser"@"localhost";
quit
HERE
mysql clonedeploy < cd.sql -v

#This section will modify /var/www/html/clonedeploy/api/Web.config and change the following values:
#xx_marker1_xx on line 35 to your cduser database password created earlier
#On that same line change Uid=root to Uid=$cduser
#xx_marker2_xx to some random characters

sed -i "35s/root/$cduser/" /var/www/html/clonedeploy/api/Web.config

#If you want to query the user for the database
#password uncomment the following line and change 
#the variable $mypass in the sed command to $pswd:

#read -s -p "Enter a password for database:" pswd

sed -i "s/xx_marker1_xx/$mypass/" /var/www/html/clonedeploy/api/Web.config

#Create an 8-character random key, if you would like to
#give your own key comment out this line and uncomment the next one.
#NOTE! a-z and numeric only,  should be a minimum of 8.

key=< /dev/urandom tr -dc [:alnum:] | head -c8

#read -p "Enter at least 8 random characters: " key

sed -i "s/xx_marker2_xx/$key/" /var/www/html/clonedeploy/api/Web.config

#Install samba server:

apt-get -y install samba

#Create the cdsharewriters group:

addgroup cdsharewriters

#Create the "read-only" user:

useradd cd_share_ro

#Create the "read-write" user, and add it to cdsharewriters-group:

useradd cd_share_rw -G cdsharewriters

#Add user www-data to cdsharewriters group:

adduser www-data cdsharewriters

#Uncomment the following 3 lines if you would like to display
#a message before setting passwords for ro and rw users.

#echo "The following two commands will prompt you to create passwords for"
#echo "the smb share for a read only user and a read write user."
#echo "Remember these passwords, you will need them again during the Web Interface Initial Setup."

#Comment out these two lines and uncomment the following two 
#commands if you would like to set the passwords to something else than the mypass-variable.

(echo "$mypass"; echo "$mypass") | smbpasswd -a cd_share_ro

(echo "$mypass"; echo "$mypass") | smbpasswd -a cd_share_rw

#Command for setting the ro-password manually:

#smbpasswd -a cd_share_ro

#Command for setting the rw-password manually:

#smbpasswd -a cd_share_rw

#Write the cd_share configuration to smb.conf:

cat <<EOT>> /etc/samba/smb.conf
[cd_share]
path = /cd_dp
valid users = @cdsharewriters, cd_share_ro
create mask = 02775
directory mask = 02775
guest ok = no
writable = yes
browsable = yes
read list = @cdsharewriters, cd_share_ro
write list = @cdsharewriters
force create mode = 02775
force directory mode = 02775
force group = +cdsharewriters

EOT

#Change the cd_dp directory (cd_share) owner and permissions:

chown -R www-data:cdsharewriters /cd_dp
chmod -R 2775 /cd_dp

#Restart samba-server:

service smbd restart

#Install TFTP server:

apt-get -y install tftpd-hpa

#Configure tftpd-hpa:

echo "TFTP_USERNAME=\"root\"
TFTP_DIRECTORY=\"/tftpboot\"
TFTP_ADDRESS=\"0.0.0.0:69\"
TFTP_OPTIONS=\"-s -m /tftpboot/remap\"" > /etc/default/tftpd-hpa

#Restart tftpd-hpa so it loads the new configuration:

service tftpd-hpa restart

#Restart apache2 webserver:

service apache2 restart

echo "Your clonedeploy server is now installed and waiting to be configured. This can be done by browsing to $(hostname -I | tr -d ' ')/clonedeploy and logging in with the default credentials clonedeploy / password."

