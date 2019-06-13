#! /bin/bash

paramfile=$1
source $paramfile

# ------------------------ Initial creation and setup of all VMs --------------------- #

#NB! This script produces A LOT of Error messages due to how we reboot and configure the VMs. It works as intended, so just let it run it's course.
#It finnishes by sleeping for 1 minute as to not let the script continue while the VMs are rebooting. 
./vm_setup.sh


# ------------------------ Get IPs for all the projects VMs --------------------- #

#As per May 9th 2019 there is no way to properly export an array in the bash-environment.
#Thus we have to create the arrays containing database and webserver IPs here.

echo "Getting IPs from OpenStack..."
openstack server list -c Name -c Networks -f value | sed 's/BSc_dats_network=//g' > ips.txt #Gets the ips of all the VMs on OpenStack
cat ips.txt

export loadbalancerIP=$(cat ips.txt | sed 's/BSc_dats_network=//g' | grep lb | cut -d ' ' -f2)
export maxscaleIP=$(cat ips.txt | sed 's/BSc_dats_network=//g' | grep dbproxy | cut -d ' ' -f2)

for (( i=0; i < $webservers; i++ ))
do
	let webserver=$i+1
	webIPs[$i]=$(cat ips.txt | sed 's/BSc_dats_network=//g' | grep web-$webserver | cut -d ' ' -f2)
done

for (( i=0; i < $databases; i++ ))
do
	let database=$i+1
	databaseIPs[$i]=$(cat ips.txt | sed 's/BSc_dats_network=//g' | grep db-$database | cut -d ' ' -f2)
done

# ------------------------ Setup --------------------- #

./lb_setup.sh ${webIPs[@]}
./web_setup.sh ${webIPs[@]}
./hadb_setup.sh ${databaseIPs[@]}
