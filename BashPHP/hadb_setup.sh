#! /bin/bash

databaseIPs=("$@") #Get an array with the IPs for all database VMs

amntDB=$databases

#This is not properly parameterized, but hardcoded for three databases. Couldn't find a proper solution.
db1name=db-1
db2name=db-2
db3name=db-3

maxscaleIP="maxscale"
maxscale=$(cat ips.txt | sed 's/BSc_dats_network=//g' | grep dbproxy | cut -d ' ' -f2)


function db_installer(){
echo "Installing softwate properties"
sudo apt-get install software-properties-common &>/dev/null
echo "Getting key"
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8 &>/dev/null
echo "Adding repo"
sudo add-apt-repository 'deb [arch=amd64,arm64,i386,ppc64el] http://mirror.homelab.no/mariadb/repo/10.2/ubuntu xenial main' &>/dev/null
echo "Installing mariaDB"
sudo apt update &>/dev/null
sudo debconf-set-selections <<< 'mariadb-server-10.2 mysql-server/root_password password PASS'
sudo debconf-set-selections <<< 'mariadb-server-10.2 mysql-server/root_password_again password PASS'
sudo apt-get install -y mariadb-server &>/dev/null
}

function setup_db() {

db1IP=$1
db2IP=$2
db3IP=$3
maxscale=$4

T1="CREATE DATABASE student_grades;"
T2="CREATE TABLE students(studentid int NOT NULL AUTO_INCREMENT, name varchar(55) NOT NULL DEFAULT '', PRIMARY KEY (studentid));"
T3="CREATE TABLE grades (studentid int NOT NULL, subject varchar(55) NOT NULL DEFAULT '', grade char(1) NOT NULL, FOREIGN KEY (studentid) REFERENCES students(studentid) ON DELETE CASCADE);"
T4="INSERT INTO students (studentid, name) VALUES (1, 'S1'), (2, 'S2'),(3, 'S3'), (4, 'S4'), (5,'S5');"
T5="INSERT INTO grades (studentid, subject, grade) VALUES (1,'DATS2410','D'), (2,'DATS2410','A'), (3,'DATS2410','B'), (4,'DATS2410','C'), (5,'DATS2410','F'), (2,'DATS1600','B');"
T6="SET PASSWORD FOR 'root'@'localhost'=PASSWORD('PASS'); CREATE USER 'dats05'@'$%' IDENTIFIED BY '$OS_PASSWORD';"
T7="grant select on mysql.* to 'maxscaleuser'@'$4' IDENTIFIED BY 'maxscalepass'; grant replication slave on *.* to 'maxscaleuser'@'$4'; grant replication client on *.* to 'maxscaleuser'@'$4'; grant show databases on *.* to 'maxscaleuser'@'$4';"
T8="GRANT ALL PRIVILEGES ON student_grades.* TO 'dats05'@'%';"
T9="flush privileges;"

echo "Creating databases"
mysql -uroot -pPASS -e "${T1}"
echo "Creating table of grades"
mysql -uroot -pPASS -D student_grades -e "${T2}"
echo "Creating table of students"
mysql -uroot -pPASS -D student_grades -e "${T3}"
echo "Inserting to students table"
mysql -uroot -pPASS -D student_grades -e "${T4}"
echo "Inserting to grades table"
mysql -uroot -pPASS -D student_grades -e "${T5}"
echo "Setting password for root and create user"
mysql -uroot -pPASS -D student_grades -e "${T6}"
echo "Granting maxscale replication"
mysql -uroot -pPASS -D student_grades -e "${T7}"
echo "Granting priviliges on all webservers"
mysql -uroot -pPASS -D student_grades -e "${T8}"
echo "Flushing privileges"
mysql -uroot -pPASS -D student_grades -e "${T9}"
echo "Done setting up databases"
}


function setup_Galera_config(){
maxscaleIP=$1
db1name=$2
db2name=$3
db3name=$4

echo "Editing my.cnf"

sudo bash -c "sudo sed -i '47s/.*/bind-address            = $1/' /etc/mysql/my.cnf"
sudo bash -c "sudo sed -i '158s/.*/binlog_format=ROW/' /etc/mysql/my.cnf"
sudo bash -c "sudo sed -i '159s/.*/default-storage-engine=innodb/' /etc/mysql/my.cnf"
sudo bash -c "sudo sed -i '160s/.*/innodb_autoinc_lock_mode=2/' /etc/mysql/my.cnf"
sudo bash -c "sudo sed -i '161s/.*/bind-address=0.0.0.0/' /etc/mysql/my.cnf"
sudo bash -c "sudo sed -i '162s/.*/# Galera Provider Configuration/' /etc/mysql/my.cnf"
sudo bash -c "sudo sed -i '163s/.*/wsrep_on=ON/' /etc/mysql/my.cnf"
sudo bash -c "sudo sed -i '164s/.*/wsrep_provider=\/usr\/lib\/galera\/libgalera_smm.so/' /etc/mysql/my.cnf"
sudo bash -c "sudo sed -i '165s/.*/# Galera Cluster Configuration/' /etc/mysql/my.cnf"
sudo bash -c "sudo sed -i '166s/.*/wsrep_cluster_address=gcomm:\/\/$2,$3,$4/' /etc/mysql/my.cnf" #HUSK Å PARAMETRISERE
sudo bash -c "sudo sed -i '167s/.*/# Galera Synchronization Configuration/' /etc/mysql/my.cnf"
sudo bash -c "sudo sed -i '168s/.*/wsrep_sst_method=rsync/' /etc/mysql/my.cnf"
sudo bash -c "sudo sed '169,172d' /etc/mysql/my.cnf"

sudo bash -c "sudo service mysql stop"
}

function setup_cluster(){
echo "Starting cluster"
sudo bash -c "sudo galera_new_cluster"
echo "Cluster started successfully"
}

function start_other(){
pw=$1
sudo bash -c "sudo sed -i '5s/.*/$1/' /etc/mysql/debian.cnf"
sudo bash -c "sudo sed -i '10s/.*/$1/' /etc/mysql/debian.cnf"

sudo bash -c "sudo service mysql start"
}

for (( i = 1; i < $amntDB + 1; i++ ))
do
	echo "SETTING UP DB $OS_USERNAME-db-$i"
	ssh -i ~/.ssh/$OS_USERNAME-key -oStrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@${databaseIPs[$i-1]} "$(typeset -f db_installer); db_installer"
	echo "DONE SETTING UP DB $OS_USERNAME-db-$i"
done


ssh -i ~/.ssh/$OS_USERNAME-key -o StrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@$db1IP "$(typeset -f setup_db); setup_db $db1IP $db2IP $db3IP $maxscale"

for (( i = 1; i < $amntDB + 1; i++ ))
do
    echo "Editing galera config of $OS_USERNAME-db-$i, and stopping mysql"
    ssh -i ~/.ssh/$OS_USERNAME-key -oStrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@${databaseIPs[$i-1]} "$(typeset -f setup_Galera_config); setup_Galera_config $maxscaleIP $db1name $db2name $db3name"
	echo "DONE SETTING UP galeraconfig for $OS_USERNAME-db-$i"
done

ssh -i ~/.ssh/$OS_USERNAME-key -o StrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@${databaseIPs[0]} "sudo cat /etc/mysql/debian.cnf | grep -E '(password)+.' | sort -u"

ssh -i ~/.ssh/$OS_USERNAME-key -o StrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@${databaseIPs[0]} "$(typeset -f setup_cluster); setup_cluster"
for (( i = 2; i < $amntDB + 1; i++ ))
do
	echo "Adding PW for debian and starting sql on db $i"
	ssh -i ~/.ssh/$OS_USERNAME-key -oStrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@${databaseIPs[$i-1]} "$(typeset -f start_other); start_other $pw"
	echo "DONE STARTING SQL on db $i"
done

#----------------------MAXSCALE SETUP----------------------------

#Variables
amtThreads=$(openstack server list -c Name -c Networks -f value | sed 's/BSc_dats_network=//g' | grep db | wc -l)
echo "$amtThreads"
# Getting list of databases
dbT=($(openstack server list -c Name -c Networks -f value | sed 's/BSc_dats_network=//g' | grep db- | awk '{print $1}' | sed 's/dats05-//g'))
# Making list with names of databases
for l in ${!dbT[@]};
do
db=${dbT[l]}
dbs1="$db, $dbs1"
done
mIp=$(openstack server list -c Name -c Networks -f value | sed 's/BSc_dats_network=//g' | grep dbproxy | awk '{print $2}')
echo "$mIP"
# Formating list with names of databases
dbs2=${dbs1::-2}
#END of Variables

function setup_maxscale() {
sudo wget https://downloads.mariadb.com/MaxScale/2.2.2/ubuntu/dists/xenial/main/binary-amd64/maxscale-2.2.2-1.ubuntu.xenial.x86_64.deb
sudo dpkg -i maxscale-2.2.2-1.ubuntu.xenial.x86_64.deb
sudo apt-get -f install -qq
sudo apt-get install mariadb-client
}

ssh -i ~/.ssh/$OS_USERNAME-key -o StrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@$mIp "$(typeset -f setup_maxscale); setup_maxscale"

# config
touch maxscale.cnf
chmod 777 maxscale.cnf

# Creating maxscale config file from template
bash -c "echo '# MaxScale documentation:
# https://mariadb.com/kb/en/mariadb-enterprise/mariadb-maxscale-22/

# Global parameters
#
# Complete list of configuration options:
# https://mariadb.com/kb/en/mariadb-enterprise/mariadb-maxscale-22-mariadb-maxscale-configuration-usage-scenarios/
' >> maxscale.cnf"

# Configuring thread
bash -c "echo '[maxscale]
threads=$amtThreads
' >> maxscale.cnf"

bash -c "echo '# Server definitions
#
# Set the address of the server to the network
# address of a MariaDB server.
#
' >> maxscale.cnf"

# Configuring servers
weight=2

for ((i=${#dbT[@]}-1; i>=0; i--));
do

bash -c "echo '[${dbT[i]}]
type=server
address=${dbT[i]}
port=3306
protocol=MariaDBBackend
serv-weight=$weight
' >> maxscale.cnf"

if [ $i -gt 1 ]
then
    weight=1
fi

done

#konfigurer monitor
bash -c "echo '# Monitor for the servers
#
# This will keep MaxScale aware of the state of the servers.
# MariaDB Monitor documentation:
# https://mariadb.com/kb/en/mariadb-enterprise/mariadb-maxscale-22-mariadb-monitor/
' >> maxscale.cnf"

bash -c "echo '[Galera-Monitor]
type=monitor
module=galeramon
servers=$dbs2
user=maxscaleuser
passwd=maxscalepass
monitor_interval=10000
disable_master_failback=1
' >> maxscale.cnf"

#konfigurer services
bash -c "echo '# Service definitions
#
# Service Definition for a read-only service and
# a read/write splitting service.
#

# ReadConnRoute documentation:
# https://mariadb.com/kb/en/mariadb-enterprise/mariadb-maxscale-22-readconnroute/
' >> maxscale.cnf"

bash -c "echo '# ReadWriteSplit documentation:
# https://mariadb.com/kb/en/mariadb-enterprise/mariadb-maxscale-22-readwritesplit/
' >> maxscale.cnf"

bash -c "echo '[Read-Write-Service]
type=service
router=readwritesplit
servers=$dbs2
user=maxscaleuser
passwd=maxscalepass
max_slave_connections=1
router_options=slave_selection_criteria=LEAST_GLOBAL_CONNECTIONS,master_failure_mode=error_on_write
weightby=serv_weight
enable_root_user=true
' >> maxscale.cnf"

bash -c "echo '# This service enables the use of the MaxAdmin interface
# MaxScale administration guide:
# https://mariadb.com/kb/en/mariadb-enterprise/mariadb-maxscale-22-maxadmin-admin-interface/
' >> maxscale.cnf"

bash -c "echo '[MaxAdmin-Service]
type=service
router=cli
' >> maxscale.cnf"

#konfigurer listeners
bash -c "echo '# Listener definitions for the services
#
# These listeners represent the ports the
# services will listen on.
#
' >> maxscale.cnf"

bash -c "echo '[Read-Write-Listener]
type=listener
service=Read-Write Service
protocol=MySQLClient
port=3306
' >> maxscale.cnf"

bash -c "echo '[MaxAdmin-Listener]
type=listener
service=MaxAdmin Service
protocol=maxscaled
socket=default
' >> maxscale.cnf"
# Config generation over

# send conf

echo "til dats"
scp maxscale.cnf $OS_USERNAME@$DATS_HOST:/home/$OS_USERNAME
echo "til hjem max"
ssh $OS_USERNAME@$DATS_HOST "scp -i ~/$OS_USERNAME-key -o StrictHostKeyChecking=no ~/maxscale.cnf $VMusername@'$mIp':maxscale.cnf"
echo "slet fra dats"
ssh $OS_USERNAME@$DATS_HOST "rm ~/maxscale.cnf"
echo "i max fra hjem til etc"
ssh -i ~/.ssh/$OS_USERNAME-key -o StrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@$mIp "sudo cp maxscale.cnf /etc/maxscale.cnf"
echo "i max slett fra hjem"
ssh -i ~/.ssh/$OS_USERNAME-key -o StrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@$mIp "sudo rm ~/maxscale.cnf"
echo "restart service"
ssh -i ~/.ssh/$OS_USERNAME-key -o StrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@$mIp "sudo service maxscale restart"
#Delete config from local machine
rm maxscale.cnf
