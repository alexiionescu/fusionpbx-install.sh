#!/bin/sh
# 1. Stop the core services
sudo systemctl stop freeswitch

# 2. Clear out FusionPBX file cache fully
sudo rm -fr /var/cache/fusionpbx/*

# 3. Purge Sofia's internal memory database states
sudo rm -f /var/log/freeswitch/db/*
sudo rm -f /var/lib/freeswitch/db/*

# 4. Start the engine back up
sudo systemctl start freeswitch