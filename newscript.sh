#!/bin/bash

##Install needed Packages
yum -y install dialog
yum -y install pstack
yum -y install mcelog
yum -y install sysstat
yum -y install java

##Create Data and Catalog Directories
## Modified by JVA -- mkdir /data
mkdir /vertica


##Get Vertica RPM
mkdir /tmp/software
wget -O /tmp/software/vertica-8.1.0-2.x86_64.RHEL6.rpm https://s3.amazonaws.com/verticatestdrive/PredictiveMaint/vertica-8.1.0-2.x86_64.RHEL6.rpm
wget -O /tmp/software/vertica-console-8.1.0-0.x86_64.RHEL6.rpm https://s3.amazonaws.com/verticatestdrive/PredictiveMaint/vertica-console-8.1.0-0.x86_64.RHEL6.rpm

##Install Vertica RPM
rpm -Uvh /tmp/software/vertica-8.1.0-2.x86_64.RHEL6.rpm
rpm -Uvh /tmp/software/vertica-console-8.1.0-0.x86_64.RHEL6.rpm

##Determine disks
raid=""
size=$(blockdev --getsize64 /dev/sda)
if [ $(blockdev --getsize64 /dev/sda) -eq 137438953472 ] ; then raid="/dev/sda" ; fi
size=$(blockdev --getsize64 /dev/sdb)
if [ $(blockdev --getsize64 /dev/sdb) -eq 137438953472 ] ; then raid="/dev/sdb" ; fi
size=$(blockdev --getsize64 /dev/sdc)
if [ $(blockdev --getsize64 /dev/sdc) -eq 137438953472 ] ; then raid="/dev/sdc" ; fi

##Format Disk
mkfs -t ext4 -F $raid

##Add UUID of data disk to FSTAB
if [ $raid = "/dev/sda" ] ; then DevCon=`blkid /dev/sdc|sed 's_/dev/sda: UUID="__' | sed 's_" TYPE="ext4"__'` ; fi
if [ $raid = "/dev/sdb" ] ; then DevCon=`blkid /dev/sdb|sed 's_/dev/sdb: UUID="__' | sed 's_" TYPE="ext4"__'` ; fi
if [ $raid = "/dev/sdc" ] ; then DevCon=`blkid /dev/sdc|sed 's_/dev/sdc: UUID="__' | sed 's_" TYPE="ext4"__'` ; fi

## Modified by JVA -- echo "UUID=${DevCon} /data ext4 defaults,nofail,nobarrier 0 2" >> /etc/fstab
echo "UUID=${DevCon} /vertica ext4 defaults,nofail,nobarrier 0 2" >> /etc/fstab

mount -all

##Create Swapfile
install -o root -g root -m 0600 /dev/null /swapfile
dd if=/dev/zero of=/swapfile bs=1k count=2048k
mkswap /swapfile
swapon /swapfile
echo "/swapfile       swap    swap    auto      0       0" >> /etc/fstab

##Set Vertica Requirements
echo '/sbin/blockdev --setra 2048 /dev/sda' >> /etc/rc.local
echo '/sbin/blockdev --setra 2048 /dev/sdc' >> /etc/rc.local

/sbin/blockdev --setra 2048 /dev/sda
/sbin/blockdev --setra 2048 /dev/sdc

echo 'if test -f /sys/kernel/mm/transparent_hugepage/enabled; then' >> /etc/rc.local
echo '   echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.local
echo 'fi' >> /etc/rc.local
echo always > /sys/kernel/mm/transparent_hugepage/enabled


echo deadline > /sys/block/sda/queue/scheduler
echo deadline > /sys/block/sdc/queue/scheduler

## Enable rc.local execution at boot
chmod +x /etc/rc.d/rc.local

sed -i '/SELINUX=enforcing/c\SELINUX=disable' /etc/selinux/config
setenforce 0

chkconfig iptables off

systemctl stop iptables
systemctl disable iptables
systemctl start ntpd
systemctl enable ntpd

##Setup User
groupadd verticadba
usermod -g verticadba $1
chown $1:verticadba /home/$1
chmod 755 /home/$1
## Modified by JVA -- chown $1:verticadba /data
chown $1:verticadba /vertica
echo 'export TZ="America/New_York"' >> /etc/profile

## ********************Move the Predictive Maintenance Stuff before the database creation ### 
## Install the necessary Packages
echo "Starting Step-01 -- YumInstall" >> /home/dbadmin/stepfile.out
yum install -y mdadm
yum install -y gdb
yum install -y mcelog
yum install -y sysstat
yum install -y python-pip
## yum install -y tz
yum update -y tzdata
yum install -y httpd
yum install -y unixODBC
pip install  --upgrade pip
yum install -y php-odbc
yum install -y dialog
yum install -y php-gd php-pear php-mysql
yum group install -y 'Development Tools'
yum install -y libxml2-devel
yum install -y  php-xml
yum install -y java
yum install -y php
yum install -y php-odbc
yum install -y dos2unix 
echo "Complete Step-01 -- YumInstall" >> /home/dbadmin/stepfile.out

## Update the Profile file with this information
echo "Starting Step-02 -- UpdateProfile" >> /home/dbadmin/stepfile.out
sudo echo "export TZ=America/New_York" >> /etc/profile
source /etc/profile
echo "Complete Step-02 -- UpdateProfile" >> /home/dbadmin/stepfile.out

## Create folders for storing Vertica files
echo "Starting Step-03 -- Create folder" >> /home/dbadmin/stepfile.out
## Commented by JVA -- mkdir /vertica
mkdir /vertica/data
mkdir /vertica/data/controlfiles
mkdir /vertica/data/datafiles
mkdir /vertica/data/iotdata
## - Added this steps for Azure
## Commented by JVA -- mkdir /data/iotdata
## Commented by JVA -- ln -s /data/iotdata /vertica/data/iotdata 
## - Added this steps for Azure
## "Not Required for Azure" mkdir /vertica/data/datafiles
## "Not Required for Azure" mkdir /vertica/data/controlfiles
mkdir /tmp/tdpmfiles
echo "Complete Step-03 -- Create folder" >> /home/dbadmin/stepfile.out

## Change Permission on the Vertica folder
echo "Starting Step-04 -- Change owner of the folder" >> /home/dbadmin/stepfile.out
chown -R dbadmin /vertica
chgrp -R verticadba /vertica
## Commneted by JVA -- chown -R dbadmin /vertica
## Commneted by JVA -- chgrp -R verticadba /vertica
## Commneted by JVA -- chown -R dbadmin /data/iotdata
## Commneted by JVA -- chgrp -R verticadba /data/iotdata
echo "Complete Step-04 -- Change owner of the folder" >> /home/dbadmin/stepfile.out

## Get the files
echo "Starting Step-05 -- Download files" >> /home/dbadmin/stepfile.out
wget -O /tmp/tdpmfiles/predictivemaint_addfiles.tar.gz https://s3.amazonaws.com/verticatestdrive/PredictiveMaint/predictivemaint_addfiles.tar.gz
wget -O /tmp/tdpmfiles/predictivemaint_application.tar.gz https://s3.amazonaws.com/verticatestdrive/PredictiveMaint/predictivemaint_application.tar.gz
wget -O /tmp/tdpmfiles/predictivemaint_db.tar.gz https://s3.amazonaws.com/verticatestdrive/PredictiveMaint/predictivemaint_db.tar.gz
## Not required for Azure wget -O /tmp/tdpmfiles/Changedbadminpasswd_resticted.sh https://s3.amazonaws.com/verticatestdrive/Changedbadminpasswd_resticted.sh
## Not Required for Azure wget -O /tmp/tdpmfiles/auth.txt https://s3.amazonaws.com/verticatestdrive/auth.txt 
echo "Complete Step-05 -- Download files" >> /home/dbadmin/stepfile.out

## gunzip the files
echo "Starting Step-06 -- Unziping files" >> /home/dbadmin/stepfile.out
gunzip /tmp/tdpmfiles/predictivemaint_addfiles.tar.gz
gunzip /tmp/tdpmfiles/predictivemaint_application.tar.gz
gunzip /tmp/tdpmfiles/predictivemaint_db.tar.gz
echo "Complete Step-06 -- Unziping files" >> /home/dbadmin/stepfile.out

## Create the folders under dbadmin
echo "Starting Step-07 -- Create folder in DBAdmin" >> /home/dbadmin/stepfile.out
sudo -n -H -u dbadmin mkdir /home/dbadmin/TestDrive 
sudo -n -H -u dbadmin mkdir /home/dbadmin/TestDrive/PredictiveMaint
echo "Complete Step-07 -- Create folder in DBAdmin" >> /home/dbadmin/stepfile.out

## Add Authfile just for testing purpose
echo "Starting Step-08 -- SSHloginwithTestDriveID" >> /home/dbadmin/stepfile.out
## Not required for Azure cat /tmp/tdpmfiles/auth.txt >> /home/dbadmin/.ssh/authorized_keys
echo "complete Step-08 -- SSHloginwithTestDriveID" >> /home/dbadmin/stepfile.out

## Untar the files
echo "Starting Step-09 -- Untar the files into respective folder" >> /home/dbadmin/stepfile.out
tar -xvf /tmp/tdpmfiles/predictivemaint_db.tar --directory=/home/dbadmin/TestDrive/PredictiveMaint/
tar -xvf /tmp/tdpmfiles/predictivemaint_addfiles.tar --directory=/tmp/tdpmfiles/
tar -xvf /tmp/tdpmfiles/predictivemaint_application.tar --directory=/tmp/tdpmfiles/
mv /tmp/tdpmfiles/httpsphp/* /var/www/html/
echo "Complete Step-09 -- Untar the files into respective folder" >> /home/dbadmin/stepfile.out

## Move the system files
echo "Starting Step-10 -- Move the misc files to right folders" >> /home/dbadmin/stepfile.out
mv /tmp/tdpmfiles/*.ini /etc/.
mv /tmp/tdpmfiles/httpd.conf /etc/httpd/conf/
cat /tmp/tdpmfiles/sudoers.txt >> /etc/sudoers
echo "Complete Step-10 -- Move the misc files to right folders" >> /home/dbadmin/stepfile.out


## Complete the Application
echo "Starting Step-11 -- Compile the Application" >> /home/dbadmin/stepfile.out
sudo gcc -o /var/www/html/execfiles/fasttrack4 /var/www/html/execfiles/fasttrack4.c -lm
echo "Complete Step-11 -- Compile the Application" >> /home/dbadmin/stepfile.out

## Start the Webservices
echo "Starting Step-12 -- Start the WebServices" >> /home/dbadmin/stepfile.out
sudo /bin/systemctl start httpd.service
echo "Complete Step-12 -- Start the WebServices" >> /home/dbadmin/stepfile.out

## Change the TestDrive Password
echo "Starting Step-13 -- ChangetheTestDrive Password" >> /home/dbadmin/stepfile.out
echo "Param 1" $1 " - Param2 " $2 >> /home/dbadmin/stepfile.out
cat /tmp/tdpmfiles/Changedbadminpasswd_resticted.sh | dos2unix  >> /tmp/tdpmfiles/Chg.txt
mv /tmp/tdpmfiles/Chg.txt  /tmp/tdpmfiles/Changedbadminpasswd_resticted.sh
chmod +x /tmp/tdpmfiles/Changedbadminpasswd_resticted.sh 
/tmp/tdpmfiles/Changedbadminpasswd_resticted.sh $2
echo "Param 1" $1 " - Param2 " $2 >> /home/dbadmin/stepfile.out
echo "Complete Step-13 -- ChangetheTestDrive Password" >> /home/dbadmin/stepfile.out

##Install Vertica
/opt/vertica/sbin/install_vertica --accept-eula --license CE --point-to-point --dba-user $1 --dba-user-password-disabled --hosts localhost --failure-threshold NONE

## Restricted Environment Setup
echo "Starting Step-14 -- Restricted Environment Setup" >> /home/dbadmin/stepfile.out
cp /bin/bash /bin/rbash 
useradd -s /bin/rbash tdpmuser
mkdir /home/tdpmuser/programs
wget -O /tmp/tdpmfiles/bashprofile.txt https://s3.amazonaws.com/verticatestdrive/PredictiveMaint/bashprofile.txt
wget -O /tmp/tdpmfiles/Changetdpmuserpasswd.sh https://s3.amazonaws.com/verticatestdrive/PredictiveMaint/Changetdpmuserpasswd.sh
cat /tmp/tdpmfiles/bashprofile.txt | dos2unix | sudo tee /home/tdpmuser/.bash_profile
ln -s /bin/date /home/tdpmuser/programs/
ln -s /bin/ls /home/tdpmuser/programs/
ln -s /usr/bin/scp /home/tdpmuser/programs/
ln -s /usr/bin/cd /home/tdpmuser/programs/
ln -s /usr/bin/view /home/tdpmuser/programs/
ln -s /usr/bin/cat /home/tdpmuser/programs/	
ln -s /usr/bin/touch /home/tdpmuser/programs/
ln -s /usr/bin/gunzip /home/tdpmuser/programs/
ln -s /usr/bin/tar /home/tdpmuser/programs/	
ln -s /opt/vertica/bin/vsql /home/tdpmuser/programs/
ln -s /usr/bin/vi /home/tdpmuser/programs/
ln -s /usr/bin/sed /home/tdpmuser/programs/
ln -s /usr/bin/awk /home/tdpmuser/programs/
ln -s /usr/bin/cut /home/tdpmuser/programs/
ln -s /usr/bin/unzip /home/tdpmuser/programs/ 
cp -R /home/dbadmin/TestDrive /home/tdpmuser/. 
chown -R tdpmuser /home/tdpmuser/Testdrive
chattr +i /home/tdpmuser/.bash_profile
#usermod -s /sbin/nologin dbadmin
echo "Starting Step-14 -- Restricted Environment Setup" >> /home/dbadmin/stepfile.out

## Restricted Environment Setup Password Change
echo "Starting Step-15 -- ChangetheTestDrive tdpmuser Password" >> /home/dbadmin/stepfile.out
echo "Param 1" $1 " - Param2 " $2 >> /home/dbadmin/stepfile.out
cat /tmp/tdpmfiles/Changetdpmuserpasswd.sh | dos2unix  >> /tmp/tdpmfiles/Chgtdpm.txt
mv /tmp/tdpmfiles/Chgtdpm.txt  /tmp/tdpmfiles/Changetdpmuserpasswd.sh
chmod +x /tmp/tdpmfiles/Changetdpmuserpasswd.sh 
/tmp/tdpmfiles/Changetdpmuserpasswd.sh $2
echo "Param 1" $1 " - Param2 " $2 >> /home/dbadmin/stepfile.out
echo "Complete Step-15 -- ChangetheTestDrive tdpmuser Password" >> /home/dbadmin/stepfile.out		  

## Final Cleanup
echo "Starting Step-14 -- Cleaning Up the files" >> /home/dbadmin/stepfile.out
rm -rf /tmp/tdpmfiles 
echo "Complete Step-14 -- Cleaning Up the files" >> /home/dbadmin/stepfile.out

## ********************END -- Move the Predictive Maintenance Stuff before the database creation ### 


##Setup MC User
groupadd 500 -g 1002
useradd uidbadmin -g 1002 -d /home/dbadmin


##Create DB
## Modified by JVA -- sudo -n -H -u $1 /opt/vertica/bin/admintools  -t create_db -s localhost -d testdrive -c /data/controlfiles -D /data/datafiles
sudo -n -H -u $1 /opt/vertica/bin/admintools  -t create_db -s localhost -d testdrive -c /vertica/data/controlfiles -D /vertica/data/datafiles

##Install MC
echo StartMC_Install_PredictiveMaint-`date` >> /home/dbadmin/stepfile.out
mkdir /tmp/mcfile
wget -O /tmp/mcfile/MCInstall.tar.gz https://s3.amazonaws.com/verticatestdrive/PredictiveMaint/MCInstall.tar.gz
gunzip /tmp/mcfile/MCInstall.tar.gz
tar -xvf /tmp/mcfile/MCInstall.tar --directory=/tmp/mcfile
chmod +x /tmp/mcfile/MCAttachedDB.sh
sudo -n -H -u dbadmin /tmp/mcfile/MCAttachedDB.sh  >> /home/dbadmin/mcinstall.out
rm -rf /tmp/mcfile
rm -rf /tmp/software
echo CompleteMC_Install_PredictiveMaint-`date` >> /home/dbadmin/stepfile.out


echo 'sudo -n -H -u dbadmin /opt/vertica/bin/admintools --tool start_db --database=testdrive' >> /etc/rc.local
echo 'sudo /bin/systemctl start httpd.service' >> /etc/rc.local

shutdown -r +1 &


