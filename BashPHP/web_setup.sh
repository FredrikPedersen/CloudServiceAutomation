#! /bin/bash

#This script asumes that you want your first webserver VM to be your primary webserver.
#This script does not handle configuration of webservers which has already been configured to any extent. Expect bugs if the webserver is not a clean build.

webIPs=("$@") #Get an array with the IPs for all webservers VMs

function send_SSH_key() {
	web1IP=$1
	OS_USERNAME=$2

	#COPY PRIVATE SSH-KEY TO WEBSERVER-1. This is to allow Rsync to function as intended. 
	#Redirects error-messages to file and gives appropriate messages to user if the file already exists (which it shouldn't)
	echo "Sending private key to Webserver 1..."
	scp -i ~/$OS_USERNAME-key -oStrictHostKeyChecking=no ~/$OS_USERNAME-key $VMusername@$web1IP:~/.ssh 2> err.txt
	if [ -f err.txt ]
	then
        	error=$(cat err.txt | grep Permission | cut -d ' ' -f4)

        	if [ "$error" == "denied" ]
        	then
                	echo "File already exists"
        	fi
	else
        	echo "Key sent successfully!"
	fi

	rm err.txt
}

function setup_webservers() {

	studentgrades=$1
	indexPHP=$2
	shift
	shift
	currentIP=$1
	

	#NGINX/PHP INSTALL AND SETUP FOR ALL WEBSERVERS
	echo "Updating the package database..."
	sudo apt-get update &>/dev/null #Updates the package database
	echo "Installing Nginx..."
	sudo apt-get install nginx -y &>/dev/null #Installs nginx
	echo "Installing PHP..."
	sudo apt-get install php-fpm -y &>/dev/null #Installs php
	echo "Adding user Ubuntu to www-data..."
	sudo adduser ubuntu www-data &>/dev/null #Adds the user ubuntu to the www-data group
	echo "Setting the group ownership of the www-folder and all it's contents to www-data..."
	sudo chown -R www-data:www-data /var/www &>/dev/null #Sets the ownership of the www-folder to the www-data group recursively
	echo "Setting the rights to 774 for the www-folder and all it's contents..."
	sudo chmod -R 774 /var/www &>/dev/null #Sets the rights to the www-folder to rwx for the current user and the group
	echo "Installing MySQL..."
	sudo apt-get install php-mysql -y &>/dev/null #Installs MySQL
	echo "Installing RSync..."
	sudo apt-get install rsync &>/dev/null #Installs rsync
	
	
	configuredIndexLine="   index index.php index.html index.htm index.nginx-debian.html;" #Variable for storing what the configured Index-line should look like
	configuredServerLine="  server_name $currentIP;" #Variable for storing what the configured servername-line should look like 

	echo "Configuring the Nginx default config file..."
	sudo sed -i "39s/.*/$configuredIndexLine/" /etc/nginx/sites-available/default #Configures the Index-line
	sudo sed -i "41s/.*/$configuredServerLine/" /etc/nginx/sites-available/default #Configures the Servername-line
	sudo sed -i '55d' /etc/nginx/sites-available/default #Deletes line 55

	for (( i=51; i < 59; i++ ))
	do
        sudo sed -i $i's'/#// /etc/nginx/sites-available/default #Removes the # on lines 51 - 59 AFTER the removal of the original line 55
	done

	for (( i=61; i < 65; i++ ))
	do
		sudo sed -i $i's'/#// /etc/nginx/sites-available/default #Removes the # on lines 61 - 64 AFTER the removal of the original line 55
	done

	echo "Restarting Nginx..."
	sudo service nginx restart &>/dev/null #Restarts nginx

	echo "Configruing PHP security..."
	sudo sed -i 760s/.*/cgi.fix_pathinfo=0/ /etc/php/7.0/fpm/php.ini #Configures php security
	echo "Restarting the PHP-engine..."
	sudo systemctl restart php7.0-fpm &>/dev/null #Restarts php

	echo "Creating /var/www/html/index.php..."
	sudo touch /var/www/html/index.php #Creating the php.index-file
	echo "Setting the group ownership for /var/www/html/index.php to www-data..."
	sudo chown www-data:www-data /var/www/html/index.php #Setting group ownership for php.index
	echo "Setting rights for /var/www/html/index.php to 774..."
    sudo chmod 774 /var/www/html/index.php #Sets the rights to the index.php-file to rwx for the current user and the group www-data
	echo "Adding simple functionality to /var/www/html/index.php..."
	sudo  bash -c "echo '$indexPHP' >/var/www/html/index.php" #Adding content to php.index

	
	echo "Creating /var/www/html/students-grades.php"
	sudo touch /var/www/html/students-grades.php
	echo "Setting the group ownership for /var/www/html/students-grades.php to www-data..."
	sudo chown www-data:www-data /var/www/html/students-grades.php #Setting group ownership for students-grade.php
	echo "Setting rights for /var/www/html/students-grades.php to 774..."
    sudo chmod 774 /var/www/html/students-grades.php #Sets the rights to the students-grade.php-file to rwx for the current user and the group www-data
	echo "Adding content to students-grades.php..."
	sudo bash -c "echo '$studentgrades' > /var/www/html/students-grades.php"
}

function configure_rsync() {

	webIP=$1

	#CONFIGURE RSYNC ON WEBSERVER-1 TO PUSH TO THE OTHER WEBSERVERS
	(crontab -l 2>/dev/null; echo '*/3 * * * * rsync -rtu --delete --rsh= "ssh -p 22 /var/www/html $VMusername@$webIP:/var/www/" >/dev/null 2>&1') | crontab -
}

#SEND THE PRIVATE KEY TO THE PRIMARY WEBSERVER FROM DATSMASTER.
ssh $OS_USERNAME@$DATS_HOST "$(typeset -f send_SSH_key); send_SSH_key ${webIPs[0]} $OS_USERNAME"

#CONFIGURE ALL WEBSERVERS
for (( i = 0; i < $webservers; i++ )) 
do 
	let webNumber=$i+1 
	echo "SETTING UP WEBSERVER dats05-web-$webNumber"
	ssh -i ~/.ssh/$OS_USERNAME-key -oStrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@${webIPs[$i]} "$(typeset -f setup_webservers); setup_webservers '$studentgrades' '$indexPHP' ${webIPs[$i]}"
	echo "DONE SETTING UP WEBSERVER dats05-web-$webNumber"
done 

#CONFIGURE RSYNC TO PUSH FROM THE PRIMARY WEBSERVER TO THE BACKUPS
echo "Configuring crontab on Webserver-1..."
for (( i = 1; i < $webservers; i++ ))
do
	ssh -i ~/.ssh/$OS_USERNAME-key -oStrictHostKeyChecking=no -o ProxyCommand="ssh -q -W %h:%p  $OS_USERNAME@$DATS_HOST" $VMusername@${webIPs[0]} "$(typeset -f configure_rsync); configure_rsync ${webIPs[$i]}"
done
echo "Done configuring crontab"