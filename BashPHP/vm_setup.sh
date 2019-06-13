#! /bin/bash


#NB! This script produces A LOT of Error messages due to how we reboot and configure the VMs. It works as intended, so just let it run it's course.

# ---Variables---
    # -Key name
    keyName=$OS_USERNAME-key
    #keyNamePem=dats05-key-test5.pem
    # -Security group name
    securityGroupName=$OS_USERNAME-security
    # -Vm names
    web=$OS_USERNAME-web
    lb=$OS_USERNAME-lb
    db=$OS_USERNAME-db
	dbproxy=$OS_USERNAME-dbproxy
    # -Number of vm's that will be created
    webN=$webservers
    lbN=$loadbalancers
    dbN=$databases
	dbproxyN=$dbproxys
    # -Dats master login name and hostname
    DMUser=$OS_USERNAME
    DMHost=dats.vlab.cs.hioa.no
    # -Proxy command variable used in configuration
    sshproxycmd="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $DMUser@$DMHost -W %h:%p"
    # -Username on vm's
    username=$VMusername
    # -Locale variable used in configuration
    mylocale=$projectLocale
# ---End of variables---

# Note that the Create Key Pair, Create Security Group and Create VM parts are unecessary for this hand-in, as all of this already exists in our OpenStack project.
# The code is left in here for easy automation of future projects.

# --Create key pair
#openstack keypair create $keyName > ./$keyNamePem
# -Modify key permissions
#chmod 400 ./$keyNamePem
# -Send key to datsmaster and modify permissions
#scp $keyNamePem $DMUser@$DMHost:/home/$DMUser
#ssh $DMUser@$DMHost "chmod 400 $keyNamePem"

# --Creation of security group
# -Create security group
#openstack security group create $securityGroupName
# -Add rules
# Open port 80 for http connections
#openstack security group rule create --protocol tcp --dst-port 80 --remote-group $securityGroupName $securityGroupName
# Add icmp rule to make pinging possible
#openstack security group rule create --protocol icmp --remote-group $securityGroupName $securityGroupName
# Open port 22 for ssh connections
#openstack security group rule create --protocol TCP --dst-port 22 --remote-group $securityGroupName $securityGroupName
# Open port 1001 for haproxy monitoring services
#openstack security group rule create --protocol TCP --dst-port 1001 --remote-group $securityGroupName $securityGroupName
# Open port for GaleraCluster replication traffic
#openstack security group rule create --protocol TCP --dst-port 4567 --remote-group $securityGroupName $securityGroupName
# Open port for Incremental State Transfer (IST)
#openstack security group rule create --protocol TCP --dst-port 4568 --remote-group $securityGroupName $securityGroupName
# Open port for all other State Snapshot Transfer (SST)
#openstack security group rule create --protocol TCP --dst-port 4444 --remote-group $securityGroupName $securityGroupName
# Open port 3306 for MySQL client connections
#openstack security group rule create --protocol TCP --dst-port 3306 --remote-group $securityGroupName $securityGroupName

# --Creating vm's
#declare -A vms=( ["$web"]="$webN" ["$lb"]="$lbN" ["$db"]="$dbN" ["$dbproxy"]="$dbproxyN" )
#
#fail=true #Assign a boolean to check if successful creation of  VM's
#for name in "${!vms[@]}"
#do
#    echo "$name hehe ${vms[$name]}"
#
#   while [ "$fail" = true ] #Repeat until while VM's not created
#   do
#       openstack server create --image 'Ubuntu16.04' --flavor m1.512MB4GB --security-group $securityGroupName --key-name $keyName --nic net-id=BSc_dats_network --min 1 --max ${vms[$name]} --wait $name &>/dev/null #Spawn two VM's with name dats-vm and -number, we also suppress all output
#       var=$(openstack server list -c Name --status ERROR -f value) #Assign command output to variable
#   if [ -z "$var" ] #if no VM's with error execute this block
#   then
#       fail=false #Set fail to false to exit the while loop
#       echo "Oppretting vellyket"
#       break
#   fi
#   echo "Failed creation"
#   openstack server delete --wait ${var} #If error in var delete VM's with error and start while loop again
#   done #while done
#   fail=true
#done #for while
# --Configuring locale and host names
#sleep 1m

function configure() {
    # arguments
    ipentry=$1
    #sIpentry=$2
    mylocale=$2
    # add IPs in /etc/hosts
    sudo sed -i "1 i\\${ipentry}" /etc/hosts
	# configure locale
    sudo locale-gen nb_NO.UTF-8
    sudo bash -c 'echo "
    LANGUAGE=$mylocale
    LC_ALL=$mylocale
    " >> /etc/default/locale'
    sudo update-locale
    sudo reboot # This causes 255 error, but it isnt a problem since the setup is done
}

# This is a bug fix, our load balancer gets hostname dats05-m1 after rebuilding (it's the name we first gave) so we need to change it to the current given name dats05-lb
function lbfix() {
	OS_USERNAME=$1
	sudo bash -c "sudo sed -i '1s/.*/$OS_USERNAME-lb/' /etc/hostname"
}

openstack server list -c Name -c Networks -f value | sed 's/BSc_dats_network=//g' > ./host.txt
file="./host.txt"
while IFS='' read -r line || [[ -n "$line" ]]; do
    name=$(echo "$line" | awk '{print $1}' )
    sName=$(echo "$line" | awk '{print $1}' | sed 's/dats05-//g')
    ip=$(echo "$line" | awk '{print $2}')
    if [ $sName = "dbproxy" ]; then
    sName="maxscale"
    fi
    if [ $name = "dats05-lb" ]; then
    ssh -i ~/.ssh/$keyName -o StrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  dats05@dats.vlab.cs.hioa.no" $VMusername@$ip "$(typeset -f lbfix); lbfix $OS_USERNAME"
    fi
    iplist="$ip $iplist"
    ipentry="$ip $name $sName\\n$ipentry"
done < "$file"

echo "$iplist"
rm ./host.txt

#configure VMs in parallel by calling the configure() function
echo "Configuring VMs ..."
parallel-ssh -i -H "$iplist" -l "$username" -x "-i ~/.ssh/'$keyName' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand='$sshproxycmd'" -t 1800 "$(declare -f); configure '$ipentry' '$mylocale'"
sleep 1m
echo "Done!"