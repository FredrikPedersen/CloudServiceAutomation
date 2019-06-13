# CloudServicesAutomation
Bash-scripts used for automating the setup of a cloud service in DATA2410 - Networking and Cloud Computing Spring 2019

This was our first big project using bash scripting, where as we had only created very simple scripts earlier.
Note that we had approximately two weeks to do this, and had to learn a lot during that time. The scripts are in no way optimized
properly, nor very coherent in their coding style (we were three students working on this), but they function (mostly) as intended.

The assignment given were:
```
In this work, you will setup a cloud-based application architecture using LEMP stack in OpenStack
(ALTO). It has a load balancer, three web servers, a database proxy and three database servers.

Follow the naming conventions for the virtual
machines (VMs) as shown in the figure, where
your two-digit group number should be used
in place of XX. Load balancer should be of
m1.1GB flavor and all other VMs should be of
m1.512MB4GB flavor. Use the following OS
and software in the setup.

OS: Ubuntu 16.04
• Web server: Nginx
• Load balancer: HAProxy
• Database server: MariaDB v10.2
• Server-side programming: PHP v7.x
• Database proxy: MariaDB MaxScale 2.2

The whole work is divided into different tasks listed below, which include implementing in ALTO
cloud and providing details as asked in the submitted report. The report should provide properly
labelled or captioned diagrams, configuration details and screenshots as asked in these tasks.

1. VM setup: This task consists of creating a ssh key (datsXX-key) and a security group (datsXXsecurity),
creating VMs with desired flavors, doing minimal required common configurations in
VMs such as naming of hosts, and setup locale to Norwegian. From the security point of view,
only the required outside access (such as ssh, web, etc.) to the VMs must be given. This means
the required ports only should be opened in the security group.

2. HAProxy setup: Setup HAProxy for the load balancer and monitoring. Load balancer should use
round robin algorithm with equal weights. HAProxy monitoring page should be configured such
that it can be accessed from the url, dats.vlab.cs.hioa.no:80XX/stats. Use your ALTO credentials
for the authentication purpose.

3. Web server setup: Setup all the web servers using Nginx with the support for dynamic web
development with PHP and MariaDB and give a proper ownership and permission to the web
root folder for the ‘ubuntu’ user. Setup a simple web deployment mechanism, where datsXX-web-1 is 
considered as the primary web server and whenever an updated web application is deployed to this 
server, the application is synchronized (pushed) to the other web servers automatically in every 3 
minutes (using rsync and crontab).

4. HA database setup: Setup a cluster-based high availability database with Galera cluster of three
MariaDB database servers (nodes) and a MaxScale database proxy. Create a database named
‘student_grades‘ with two tables as in the lecture slide and add some test data. Create a
students-grades.php page that lists the grades of the students on the web,
dats.vlab.cs.hioa.no:80XX/students-grades.php. For those who do not know much PHP, the
example PHP code given in the lecture slide can be used. This web page should also show the
host name or IP of the web server serving the page, at the bottom. Use the same user name and
password as your ALTO to access the database from the PHP code

5. Automation with scripts: Automate all the setup tasks above (1 to 4) using bash shell scripts,
and name the script files as: vm_setup.sh, lb_setup.sh, web_setup.sh, hadb_setup.sh
respectively. Create one more script file, cloud_setup_all.sh which runs all the scripts and do all
the tasks automatically by running this script. Only bash, python and OpenStack API commands
are allowed in the scripts. All the shell scripts should be fully parameterized to avoid any hard coding
of parameter values inside the scripts so that it can be used in any other projects just by modifying the 
relevant parameters in a parameter file and/or passing command-line parameters, but without modifying
the script. Use a single parameter file, datsXX-params.sh to have most of the common
parameters for all the scripts. Describe each script file briefly in the report about its usage and
what it does. Script files should be well documented with appropriate comments. 
```
