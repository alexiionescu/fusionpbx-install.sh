#!/bin/sh

#move to script directory so all relative paths work
cd "$(dirname "$0")"

#includes
. ./config.sh
. ./colors.sh

# check system_branch if 5.3 or older
target_version="5.3"
lowest=$(printf '%s\n%s' "$system_branch" "$target_version" | sort -V | head -n1)
if [ "$lowest" = "$target_version" ]; then
    echo "[upgrade.php] System branch is 5.3 or older. Use old upgrade scripts..."
	older_upgrade_scripts=yes
fi
#database details
database_host=127.0.0.1
database_port=5432
database_username=fusionpbx
if [ .$database_password = .'random' ]; then
	database_password=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64 | sed 's/[=\+//]//g')
fi

#allow the script to use the new password
export PGPASSWORD=$database_password

#update the database password
sudo -u postgres psql -c "ALTER USER fusionpbx WITH PASSWORD '$database_password';"
sudo -u postgres psql -c "ALTER USER freeswitch WITH PASSWORD '$database_password';"

#install the database backup
cp backup/fusionpbx-backup /etc/cron.daily
cp backup/fusionpbx-maintenance /etc/cron.daily
chmod 755 /etc/cron.daily/fusionpbx-backup
chmod 755 /etc/cron.daily/fusionpbx-maintenance
sed -i "s/zzz/$database_password/g" /etc/cron.daily/fusionpbx-backup
sed -i "s/zzz/$database_password/g" /etc/cron.daily/fusionpbx-maintenance

#add the config.conf
mkdir -p /etc/fusionpbx
cp fusionpbx/config.conf /etc/fusionpbx
sed -i /etc/fusionpbx/config.conf -e s:"{database_host}:$database_host:"
sed -i /etc/fusionpbx/config.conf -e s:"{database_name}:$database_name:"
sed -i /etc/fusionpbx/config.conf -e s:"{database_username}:$database_username:"
sed -i /etc/fusionpbx/config.conf -e s:"{database_password}:$database_password:"

echo "[upgrade.php] Using php version $(php -v | head -n 1)"
#add the database schema
echo "[upgrade.php] Adding the database schema..."
if [ "$older_upgrade_scripts" = "yes" ]; then
cd /var/www/fusionpbx && php /var/www/fusionpbx/core/upgrade/upgrade_schema.php > /dev/null 2>&1
else
cd /var/www/fusionpbx && /usr/bin/php /var/www/fusionpbx/core/upgrade/upgrade.php --schema
fi

#get the server hostname
if [ .$domain_name = .'hostname' ]; then
	domain_name=$(hostname -f)
fi

#get the ip address
if [ .$domain_name = .'ip_address' ]; then
	domain_name=$(hostname -I | cut -d ' ' -f1)
fi

#get the domain_uuid
domain_uuid=$(/usr/bin/php /var/www/fusionpbx/resources/uuid.php);

#add the domain name
psql --host=$database_host --port=$database_port --username=$database_username -c "insert into v_domains (domain_uuid, domain_name, domain_enabled) values('$domain_uuid', '$domain_name', 'true');"


#run app defaults
echo "[upgrade.php] Running application defaults..."
if [ "$older_upgrade_scripts" = "yes" ]; then
cd /var/www/fusionpbx && php /var/www/fusionpbx/core/upgrade/upgrade_domains.php
else
cd /var/www/fusionpbx && /usr/bin/php /var/www/fusionpbx/core/upgrade/upgrade.php --defaults
fi
#add the user
user_uuid=$(/usr/bin/php /var/www/fusionpbx/resources/uuid.php);
user_salt=$(/usr/bin/php /var/www/fusionpbx/resources/uuid.php);
user_name=$system_username
if [ .$system_password = .'random' ]; then
	user_password=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64 | sed 's/[=\+//]//g')
else
	user_password=$system_password
fi
password_hash=$(php -r "echo md5('$user_salt$user_password');");
psql --host=$database_host --port=$database_port --username=$database_username -t -c "insert into v_users (user_uuid, domain_uuid, username, password, salt, user_enabled) values('$user_uuid', '$domain_uuid', '$user_name', '$password_hash', '$user_salt', 'true');"

#get the superadmin group_uuid
group_uuid=$(psql --host=$database_host --port=$database_port --username=$database_username -t -c "select group_uuid from v_groups where group_name = 'superadmin';");
group_uuid=$(echo $group_uuid | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//')

#add the user to the group
user_group_uuid=$(/usr/bin/php /var/www/fusionpbx/resources/uuid.php);
group_name=superadmin
psql --host=$database_host --port=$database_port --username=$database_username -c "insert into v_user_groups (user_group_uuid, domain_uuid, group_name, group_uuid, user_uuid) values('$user_group_uuid', '$domain_uuid', '$group_name', '$group_uuid', '$user_uuid');"

#update xml_cdr url, user and password
xml_cdr_username=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64 | sed 's/[=\+//]//g')
xml_cdr_password=$(dd if=/dev/urandom bs=1 count=20 2>/dev/null | base64 | sed 's/[=\+//]//g')
sed -i /etc/freeswitch/autoload_configs/xml_cdr.conf.xml -e s:"{v_http_protocol}:http:"
sed -i /etc/freeswitch/autoload_configs/xml_cdr.conf.xml -e s:"{domain_name}:127.0.0.1:"
sed -i /etc/freeswitch/autoload_configs/xml_cdr.conf.xml -e s:"{v_project_path}::"
sed -i /etc/freeswitch/autoload_configs/xml_cdr.conf.xml -e s:"{v_user}:$xml_cdr_username:"
sed -i /etc/freeswitch/autoload_configs/xml_cdr.conf.xml -e s:"{v_pass}:$xml_cdr_password:"


#update application defaults
echo "[upgrade.php] Updating application defaults..."
if [ "$older_upgrade_scripts" = "yes" ]; then
cd /var/www/fusionpbx && php /var/www/fusionpbx/core/upgrade/upgrade_domains.php
else
cd /var/www/fusionpbx && /usr/bin/php /var/www/fusionpbx/core/upgrade/upgrade.php --defaults
fi
#update permissions
echo "[upgrade.php] Updating permissions..."
cd /var/www/fusionpbx && /usr/bin/php /var/www/fusionpbx/core/upgrade/upgrade.php --permissions

if [ -n "$DOMAIN_NAME" ]; then
	# check if $DOMAIN_NAME does not match the first IP from hostname -I
	first_ip=$(hostname -I | awk '{print $1}')
	if [ "$DOMAIN_NAME" != "$first_ip" ]; then
		echo "[upgrade.php] DOMAIN_NAME ($DOMAIN_NAME) does not match the first IP ($first_ip)"
		psql --host=$database_host --port=$database_port --username=$database_username -c "UPDATE v_sip_profile_settings SET sip_profile_setting_value = '$DOMAIN_NAME' WHERE sip_profile_setting_name IN ('sip-ip', 'rtp-ip');"

		# 1. Update the individual profile keys (sip-ip and rtp-ip) for the IPv4 profiles
		psql --host=$database_host --port=$database_port --username=$database_username -c "UPDATE v_sip_profile_settings SET sip_profile_setting_value = '$DOMAIN_NAME' WHERE sip_profile_setting_name IN ('sip-ip', 'rtp-ip') AND sip_profile_uuid IN (SELECT sip_profile_uuid FROM v_sip_profiles WHERE sip_profile_name IN ('internal', 'external'));"
		# Force FusionPBX to provision the internal profile to your custom IP instead of the local macro
		# 2. Update the base profile bind templates if they are hardcoded
		psql --host=$database_host --port=$database_port --username=$database_username -c "UPDATE v_sip_profiles SET sip_profile_enabled = 'true' WHERE sip_profile_name IN ('internal', 'external');"
	fi
fi
#restart freeswitch
/bin/systemctl daemon-reload
/bin/systemctl restart freeswitch

#make the /var/run directory and set the ownership
mkdir -p /var/run/fusionpbx
chown -R www-data:www-data /var/run/fusionpbx

#install the services
echo "[upgrade.php] Installing services..."
cd /var/www/fusionpbx && /usr/bin/php /var/www/fusionpbx/core/upgrade/upgrade.php --services

#install crontab
apt install cron

#welcome message
echo ""
echo ""
verbose "Installation has completed."
echo ""
echo "   Use a web browser to login."
echo "      domain name: https://$domain_name"
echo "      username: $user_name"
echo "      password: $user_password"
echo "      database username: $database_username"
echo "      database password: $database_password"
echo ""
echo "   The domain name in the browser is used by default as part of the authentication."
echo "   If you need to login to a different domain then use username@domain."
echo "      username: $user_name@$domain_name";
echo ""
echo "   Official FusionPBX Training"
echo "      Fastest way to learn FusionPBX. For more information https://www.fusionpbx.com."
echo "      Available online and in person. Includes documentation and recording."
echo ""
echo "      Location:               Online"
echo "      Admin Training:         TBA"
echo "      Advanced Training:      TBA"
echo "      Continuing Education:   https://www.fusionpbx.com/training"
echo "      Timezone:               https://www.timeanddate.com/weather/usa/idaho"
echo ""
echo "   Additional information."
echo "      https://fusionpbx.com/members.php"
echo "      https://fusionpbx.com/training.php"
echo "      https://fusionpbx.com/support.php"
echo "      https://www.fusionpbx.com"
echo "      http://docs.fusionpbx.com"
echo ""



