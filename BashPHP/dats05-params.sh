#! /bin/bash

# ------------------------ Variables for Running OpenStack Project --------------------- #

#These are slightly modified versions of the variables from the OpenStack RC File V3.
#These are project specific, and needs to be completly changed if used in a different project.
#NB! These variables must be generated through OpenStack if they are to be used for another project. They are left here for showcasing purposes only.

export OS_AUTH_URL=https://cloud.cs.hioa.no:5000/v3
export OS_PROJECT_ID=cbbabde40fc043dca077ecbec6187df7
export OS_PROJECT_NAME="dats05_project"
export OS_USER_DOMAIN_NAME="Default"
if [ -z "$OS_USER_DOMAIN_NAME" ]; then unset OS_USER_DOMAIN_NAME; fi
unset OS_TENANT_ID
unset OS_TENANT_NAME
export OS_USERNAME= #HOST USERNAME HERE
export OS_PASSWORD= #PASSWORD HERE
export OS_REGION_NAME="RegionOne"
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3

# ------------------------ Other Variables --------------------- #

export webservers=3 #Number of webservers
export databases=3 #Number of databases
export dbproxys=1 #Number of database proxys
export loadbalancers=1 #Number of loadbalancers

export studentgrades=$(<studentgrades.php) #Variable containing the php-code for showing the student grades table
export indexPHP=$(<index.php) #Variable containing the php-code for the php-index 
export VMusername=ubuntu # The username we are going to be working from in all VMs
export projectLocale=nb_NO.UTF-8 #The current locale

export DEBIAN_FRONTEND=noninteractive #Variable for installing MariaDB
export DATS_HOST=dats.vlab.cs.hioa.no





