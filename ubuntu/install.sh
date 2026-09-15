#!/bin/sh

#move to script directory so all relative paths work
cd "$(dirname "$0")"

#set the ip address
if [ -z "$DOMAIN_NAME" ]; then
	server_address=$(hostname -I)
	# offer prompt for user confirmation before proceeding, or change the server address if needed
	# server_address can contain multiple IP addresses separated by spaces, we will use the first one by default
	echo -e "Detected server IP address(s): $server_address. \nWe will use the first one ${server_address%% *} by default."
	read -p "Is this correct? (Y/n) " confirm
	if [ "$confirm" != "Y" ] && [ "$confirm" != "y" ] && [ -n "$confirm" ]; then
		read -p "Enter the correct server IP address: " server_address
	fi
	echo "Using server IP address/domain: ${server_address%% *}"
	export DOMAIN_NAME=${server_address%% *}
else
	server_address=$DOMAIN_NAME
fi


#includes
. ./resources/config.sh
. ./resources/colors.sh
. ./resources/environment.sh

echo "\033[0;32mStarting installation with DOMAIN_NAME: $domain_name\033[0m"
echo "\033[0;32mStarting installation with SERVER_ADDRESS: $server_address\033[0m"
echo "\033[0;32mStarting installation with SYSTEM_PASSWORD: $system_password\033[0m"
echo "\033[0;32mStarting installation with DATABASE_PASSWORD: $database_password\033[0m"
read -p "Is this correct? (Y/n) " confirm
if [ "$confirm" != "Y" ] && [ "$confirm" != "y" ] && [ -n "$confirm" ]; then
	echo "Installation aborted by user."
	exit 1
fi

# removes the cd img from the /etc/apt/sources.list file (not needed after base install)
sed -i '/cdrom:/d' /etc/apt/sources.list

#Update to the latest packages
verbose "Update installed packages."
apt-get update && apt-get upgrade -y

#Add dependencies
apt-get install -y wget
apt-get install -y lsb-release
apt-get install -y systemd
apt-get install -y systemd-sysv
apt-get install -y ca-certificates
apt-get install -y dialog
apt-get install -y nano
apt-get install -y nginx
apt-get install -y build-essential
apt-get install -y unzip

#SNMP
apt-get install -y snmpd
echo "rocommunity public" > /etc/snmp/snmpd.conf
service snmpd restart

# Failsafe: Automatically force full execution permissions across the script footprint
chmod +x *.sh resources/*.sh resources/*/*.sh 2>/dev/null

#IPTables
resources/iptables.sh

#sngrep
resources/sngrep.sh

#FusionPBX
resources/fusionpbx.sh

#PHP
resources/php.sh

#NGINX web server
resources/nginx.sh

#Postgres
resources/postgresql.sh

#Optional Applications
resources/applications.sh

#FreeSWITCH
resources/switch.sh

#Fail2ban
resources/fail2ban.sh

#add the database schema, user and groups
resources/finish.sh
