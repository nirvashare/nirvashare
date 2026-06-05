#!/bin/bash

###############################################################################
# NirvaShare Data Backup Utility
#
# Copyright (c) 2020-2026 NirvaShare.
# All Rights Reserved.
#
# Purpose:
#   Creates a backup of the NirvaShare database and configuration files.
#
# This software and associated documentation are proprietary to NirvaShare.
# Unauthorized copying, modification, distribution, or use of this software,
# via any medium, is strictly prohibited except as expressly permitted by
# NirvaShare.
###############################################################################

set -euo pipefail

BACKUP_TEMP_FOLDER=/var/nirvashare/bk-temp
BACKUP_FOLDER=/var/nirvashare/backup
CONFIG_FILE=/var/nirvashare/config.properties
DOCKER_FILE=/var/nirvashare/install-app.yml
DB_PASS_FILE=/var/nirvashare/dbpass

terminate()
{
    echo ""
    echo "Terminated"
    exit 1
}

cleanup()
{
    rm -rf "$BACKUP_TEMP_FOLDER"
}

error_handler()
{
    echo ""
    echo "ERROR: Backup failed."
    cleanup
    exit 1
}

trap error_handler ERR

user_prompt()
{
    echo ""
    echo "NirvaShare Data Backup Utility."
    echo ""

    echo "This utility will allow you to take backup of entire database and the configurations of NirvaShare."

    if [ "${NS_SILENT:-false}" != "true" ]; then
        while true; do
            read -p "Do you want to backup now? (y/n)? " yn

            case $yn in
                [Yy] ) break ;;
                [Nn] ) terminate ;;
                * ) echo "Please answer yes or no (y/n)." ;;
            esac
        done
    else
        echo "Silent mode enabled"
    fi

    echo ""
}

create_backup()
{
    rm -rf "$BACKUP_TEMP_FOLDER"
    mkdir -p "$BACKUP_TEMP_FOLDER"

    echo "Backup of database started."

    docker exec -i nirvashare_database \
        pg_dumpall -c -U nirvashare \
        > "$BACKUP_TEMP_FOLDER/db-dump.sql"

    if [ ! -s "$BACKUP_TEMP_FOLDER/db-dump.sql" ]; then
        echo "Database backup file is empty."
        exit 1
    fi

    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$BACKUP_TEMP_FOLDER/"
    fi

    if [ -f "$DB_PASS_FILE" ]; then
        cp "$DB_PASS_FILE" "$BACKUP_TEMP_FOLDER/"
    fi

    mkdir -p "$BACKUP_FOLDER"

    FILE_NAME="ns_backup_$(date +%Y-%m-%d_%H%M%S).tar.gz"

    tar -czf \
        "$BACKUP_FOLDER/$FILE_NAME" \
        -C "$BACKUP_TEMP_FOLDER" .

    if [ ! -f "$BACKUP_FOLDER/$FILE_NAME" ]; then
        echo "Backup archive was not created."
        exit 1
    fi

    echo ""
    echo "Backup Created Successfully!"
    echo ""
    echo "Location - $BACKUP_FOLDER/$FILE_NAME"
    echo ""

    export NS_BACKUP_FILE="$BACKUP_FOLDER/$FILE_NAME"
}

check_installation()
{
    if [ ! -f "$DOCKER_FILE" ]; then
        echo "$DOCKER_FILE does not exist."
        terminate
    fi

    user_prompt
}

check_installation
create_backup
cleanup
