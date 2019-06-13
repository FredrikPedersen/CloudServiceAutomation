#! /bin/bash

webIPs=("$@") #Get an array with the IPs for all webservers VMs

function setup_loadbalancer() {

	webservers=$1
	OS_USERNAME=$2
	shift
	shift
	webIPs=("$@")
		
	echo "Updating package database..."
	sudo apt-get update 2>/dev/null #Updates the package database
	echo "Installing HaProxy..."
	sudo apt-get install haproxy -y 2>/dev/null #Installs HaProxy
	echo "Enabling HaProxy..."
	sudo bash -c "echo ENABLED=1 >> /etc/default/haproxy" #Append ENABLED=1 to the end of the haproxy file
	echo "Starting Haproxy..."
	sudo service haproxy start 2>/dev/null #Start HaProxy

	echo "Configuring HaProxy config file..."
	sudo bash -c "printf '\nfrontend myfrontend\n\tbind *:80\n\tmode http\n\tdefault_backend mybackend\n' >> /etc/haproxy/haproxy.cfg"
	sudo bash -c "printf '\nbackend mybackend\n\tmode http\n\tbalance roundrobin\n\toption httpchk HEAD / HTTP/1.1' >> /etc/haproxy/haproxy.cfg"
	sudo bash -c "echo '\r\nHost:\ localhost' >> /etc/haproxy/haproxy.cfg"
	
	for (( i=1; i < $webservers + 1; i++ ))
	do
		sudo bash -c "printf '\tserver web$i ${webIPs[$i]}:80 check weight 10\n' >> /etc/haproxy/haproxy.cfg"
    done
    
	sudo bash -c "printf '\t#Monitoring part\n\tstats enable\n\tstats refresh 30s\n\tstats uri /stats\n\tstats realm Haproxy\ Statistics\n\tstats auth $OS_USERNAME:admin\n' >> /etc/haproxy/haproxy.cfg"
	
	echo "Restarting HaProxy..."
	sudo service haproxy restart
}


 ssh -i ~/.ssh/$OS_USERNAME-key -oStrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@dats.vlab.cs.hioa.no" ubuntu@$loadbalancerIP "$(typeset -f setup_loadbalancer); setup_loadbalancer $webservers $OS_USERNAME ${webIPs[@]}"
