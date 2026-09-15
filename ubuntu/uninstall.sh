#!/bin/bash

# 1. Stop and terminate all active service processes
sudo systemctl stop freeswitch nginx php* fail2ban 2>/dev/null
sudo killall -9 freeswitch nginx php 2>/dev/null

for arg in "$@"; do
    if [ "$arg" = "delete_db" ]; then
        echo "PostgreSQL cleanup will be performed."
        delete_db="yes"
    fi
done

# if any command line argument is "delete_db", handle PostgreSQL cleanup separately
if [ "$delete_db" = "yes" ]; then
    sudo systemctl stop postgresql* 2>/dev/null
    sudo killall -9 postgres 2>/dev/null
    # 2. DROP DATABASE FILES SAFELY (Replaces the raw rm -rf commands)
    # This loops through any active database clusters and cleans them up via native system APIs
    if command -v pg_lsclusters >/dev/null 2>&1; then
        pg_lsclusters --no-header | awk '{print $1" "$2}' | while read -r version cluster; do
            sudo pg_dropcluster "$version" "$cluster" --stop 2>/dev/null
        done
    fi
    # Re-generate an empty, active main instance right away
    sudo pg_createcluster 16 main --start 2>/dev/null
    sudo apt-get purge -y postgresql* 2>/dev/null
fi

# 3. Safe Package Purge 
sudo apt-get purge -y freeswitch* php* fail2ban* lua-sql-* libspandsp* 2>/dev/null
sudo apt-get autoremove -y && sudo apt-get clean

# 4. Clean up custom website profiles (Leaves core /etc/nginx/ folders safe)
sudo rm -rf /etc/nginx/sites-enabled/* /etc/nginx/sites-available/*

# 5. Blow away application files (Bypassing core system folders and your sources)
sudo rm -rf /etc/freeswitch /etc/fusionpbx /var/www/fusionpbx
sudo rm -rf /usr/share/freeswitch /usr/local/freeswitch /var/lib/freeswitch /var/log/freeswitch

# 6. Force remove bad system-wide SpanDSP files hijacking the compiler
sudo rm -f /usr/local/include/spandsp.h /usr/include/spandsp.h
sudo rm -rf /usr/local/include/spandsp/ /usr/include/spandsp/
sudo rm -f /usr/local/lib/libspandsp* /usr/lib/libspandsp*
sudo ldconfig

if [ "$delete_db" = "yes" ]; then
    # 7. Restore the postgres system user identity container cleanly
    if ! id -u postgres >/dev/null 2>&1; then
        sudo groupadd -r postgres 2>/dev/null || true
        sudo useradd -r -g postgres -d /var/lib/postgresql -s /bin/bash -c "PostgreSQL administrator" postgres 2>/dev/null || true
    fi

    # Re-establish clean permission matrices on structural runtimes
    sudo mkdir -p /var/lib/postgresql /var/run/postgresql
    sudo chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql
    sudo chmod 2775 /var/run/postgresql
fi

# Delete all build directories except your core custom installer folder
sudo find /usr/src/ -maxdepth 1 ! -name "fusionpbx-install.sh" ! -name "" ! -name "src" -exec rm -rf {} + 2>/dev/null