#!/bin/bash

sudo useradd dbadmin
sudo echo -e "dbadmin ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers

##Install needed Packages
yum -y install dialog
#yum -y install pstack
yum -y install mcelog
yum -y install sysstat

##Create Data and Catalog Directories
mkdir /data

##Get Vertica RPM
wget https://s3.amazonaws.com/verticatestdrive/vertica-8.0.0-3.x86_64.RHEL6.rpm

mv vertica-8.0.0-3.x86_64.RHEL6.rpm /root/vertica-8.0.0-3.x86_64.RHEL6.rpm

##Install Vertica RPM
rpm -Uvh /root/vertica-8.0.0-3.x86_64.RHEL6.rpm

##Determine disks
raid="/dev/sdb"
#size=$(blockdev --getsize64 /dev/sda)
#if [ $(blockdev --getsize64 /dev/sda) -eq 137438953472 ] ; then raid="/dev/sda" ; fi
#size=$(blockdev --getsize64 /dev/sdb)
#if [ $(blockdev --getsize64 /dev/sdb) -eq 137438953472 ] ; then raid="/dev/sdb" ; fi
#size=$(blockdev --getsize64 /dev/sdc)
#if [ $(blockdev --getsize64 /dev/sdc) -eq 137438953472 ] ; then raid="/dev/sdc" ; fi


##Format Disk
mkfs -t ext4 -F $raid

##Add UUID of data disk to FSTAB
#if [ $raid = "/dev/sda" ] ; then DevCon=`blkid /dev/sdc|sed 's_/dev/sda: UUID="__' | sed 's_" TYPE="ext4"__'` ; fi
#if [ $raid = "/dev/sdb" ] ; then 
DevCon=`blkid /dev/sdb|sed 's_/dev/sdb: UUID="__' | sed 's_" TYPE="ext4"__'` 
#; fi
#if [ $raid = "/dev/sdc" ] ; then DevCon=`blkid /dev/sdc|sed 's_/dev/sdc: UUID="__' | sed 's_" TYPE="ext4"__'` ; fi

echo "UUID=${DevCon} /data ext4 defaults,nofail,nobarrier 0 2" >> /etc/fstab

mount -all

sleep 5

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
echo never > /sys/kernel/mm/transparent_hugepage/enabled

echo deadline > /sys/block/sda/queue/scheduler
echo deadline > /sys/block/sdc/queue/scheduler

##Setup User
groupadd verticadba
usermod -g verticadba dbadmin
chown dbadmin:verticadba /home/dbadmin
chmod 755 /home/dbadmin
chown dbadmin:verticadba /data
echo 'export TZ="America/New_York"' >> /etc/profile

sleep 5

##Install Vertica
/opt/vertica/sbin/install_vertica --accept-eula --license CE --point-to-point --dba-user dbadmin --dba-user-password-disabled --hosts localhost --failure-threshold NONE


##Steps for Test Drive
yum install -y dos2unix
mkdir /data/datafiles
chown dbadmin:verticadba /data/datafiles
mkdir /data/controlfiles
chown dbadmin:verticadba /data/controlfiles
mkdir /tmp/java

echo 1step_DownloadStart >> /home/dbadmin/stepfile
wget -O /tmp/java/dos2unix-6.0.3-4.el7.x86_64.rpm https://s3.amazonaws.com/verticatestdrive/dos2unix-6.0.3-4.el7.x86_64.rpm
wget -O /home/dbadmin/clickstreamAB.tar.gz https://s3.amazonaws.com/verticatestdrive/clickstreamAB.tar.gz
wget -O /home/dbadmin/ML_Function_Schema_Data.tar.gz https://s3.amazonaws.com/verticatestdrive/ML_Function_Schema_Data.tar.gz
wget -O /home/dbadmin/auth.txt https://s3.amazonaws.com/verticatestdrive/auth.txt
wget -O /tmp/java/jdk-8u121-linux-x64.rpm  https://s3.amazonaws.com/verticatestdrive/jdk-8u121-linux-x64.rpm
wget -O /tmp/java/apache-tomcat-8.0.41.tar.gz https://s3.amazonaws.com/verticatestdrive/apache-tomcat-8.0.41.tar.gz
wget -O /tmp/java/editprofile.txt https://s3.amazonaws.com/verticatestdrive/editprofile.txt
#wget -O /tmp/java/Changedbadminpasswd.sh https://s3.amazonaws.com/verticatestdrive/Changedbadminpasswd.sh
wget -O /tmp/java/Changedbadminpasswd.sh https://raw.githubusercontent.com/pradeepts/testRepo/master/Changedbadminpasswd.sh
# wget -O /tmp/java/TestJava.zip https://s3.amazonaws.com/verticatestdrive/TestJava.zip
wget -O /tmp/java/ACME_ABTesting_Dashboard.zip https://s3.amazonaws.com/verticatestdrive/ACME_ABTesting_Dashboard.zip
wget -O /tmp/java/lgx120201.lic https://s3.amazonaws.com/verticatestdrive/lgx120201.lic

echo 2ndstep_DownloadEnd_GunzipStart >> /home/dbadmin/stepfile
gunzip /home/dbadmin/clickstreamAB.tar.gz
gunzip /tmp/java/apache-tomcat-8.0.41.tar.gz
gunzip /home/dbadmin/ML_Function_Schema_Data.tar.gz

echo 3rdstep_GzipEnd_RunRPM >> /home/dbadmin/stepfile      	
rpm -Uvh /tmp/java/jdk-8u121-linux-x64.rpm
# rpm -Uvh /tmp/java/dos2unix-6.0.3-4.el7.x86_64.rpm		  
tar -xvf /tmp/java/apache-tomcat-8.0.41.tar --directory=/opt 
# unzip /tmp/java/TestJava.zip -d /opt/apache-tomcat-8.0.41/webapps/ 	
unzip /tmp/java/ACME_ABTesting_Dashboard.zip -d /opt/apache-tomcat-8.0.41/webapps/ 	
mv /opt/apache-tomcat-8.0.41/webapps/ACME_ABTesting_Dashboard/lgx120201.lic /opt/apache-tomcat-8.0.41/webapps/ACME_ABTesting_Dashboard/lgx120201.lic.old 
# mv /opt/apache-tomcat-8.0.41/webapps/TestJava/lgx120201.lic /opt/apache-tomcat-8.0.41/webapps/TestJava/lgx120201.lic.old
# cp /tmp/java/lgx120201.lic /opt/apache-tomcat-8.0.41/webapps/TestJava/lgx120201.lic
cp /tmp/java/lgx120201.lic /opt/apache-tomcat-8.0.41/webapps/ACME_ABTesting_Dashboard/lgx120201.lic
cat /tmp/java/editprofile.txt | dos2unix  >>/etc/profile
cat /tmp/java/Changedbadminpasswd.sh | dos2unix  >> /tmp/java/Chg.txt
mv /tmp/java/Chg.txt  /tmp/java/Changedbadminpasswd.sh
source /etc/profile

echo 4thstep_InstallVerticaDB >> /home/dbadmin/stepfile 	
sudo -n -H -u dbadmin /opt/vertica/bin/admintools  -t create_db -s localhost -d testdrive -c /data/controlfiles -D /data/datafiles  
sudo -n -H -u dbadmin mkdir /home/dbadmin/TestDrive 		  
sudo -n -H -u dbadmin mkdir /home/dbadmin/TestDrive/ABTesting 		  
sudo -n -H -u dbadmin mkdir /home/dbadmin/TestDrive/MLFunctions

echo 5thstep_Misc >> /home/dbadmin/stepfile 	
cat /home/dbadmin/auth.txt >> /home/dbadmin/.ssh/authorized_keys 	
tar -xvf /home/dbadmin/clickstreamAB.tar  --directory=/home/dbadmin/TestDrive/ABTesting/ 	
tar -xvf /home/dbadmin/ML_Function_Schema_Data.tar --directory=/home/dbadmin/TestDrive/MLFunctions/	
hostname testdrive.localdomain
echo 'testdrive.localdomain' > /etc/hostname
sed 's/1   localhost /1   testdrive.localdomain localhost /' < /etc/hosts > /tmp/java/hosts
cp /etc/hosts /etc/hosts.sav
mv /tmp/java/hosts /etc/hosts
/opt/apache-tomcat-8.0.41/bin/startup.sh
echo End_of_Steps >> /home/dbadmin/stepfile 

echo set_password >> /home/dbadmin/stepfile
chmod +x /tmp/java/Changedbadminpasswd.sh >>/home/dbadmin/stepfile
/tmp/java/Changedbadminpasswd.sh >>/home/dbadmin/stepfile
echo set_password_completed >> /home/dbadmin/stepfile
rm -rf /tmp/java
rm -f /home/dbadmin/clickstreamAB.tar
rm -f /home/dbadmin/ML_Function_Schema_Data.tar
rm -f /home/dbadmin/auth.txt
echo Clean_up_files >> /home/dbadmin/stepfile 
chkconfig --level 12345 verticad  on
sed -i 's/ChallengeResponseAuthentication .*no$/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config

sleep 5

#Firewall add to the vm
#sudo yum update -y
sudo systemctl start firewalld
sudo firewall-cmd --zone=public --add-port=443/tcp --permanent
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --zone=public --add-port=5433/tcp --permanent
sudo firewall-cmd --reload

service sshd restart
ystemctl stop firewalld
systemctl disable firewalld


