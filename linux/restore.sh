#!/bin/bash

###############################################################################
# NirvaShare Data Restore Utility
#
# Copyright (c) 2020-2026 NirvaShare.
# All Rights Reserved.
#
# Purpose:
#   Restores the NirvaShare database and configuration files from a backup.
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
DOCKER_FILE_FTPS=/var/nirvashare/install-ftps.yml
DB_PASS_FILE=/var/nirvashare/dbpass

RESTORE_STARTED=false

terminate()
{
    echo ""
    echo "Terminated"
    exit 1
}

error_handler()
{
    echo ""
    echo "ERROR: Restore failed."

    if [ "$RESTORE_STARTED" = true ]; then
        echo "Attempting to restart NirvaShare services..."
        restart_nirvashare || true
    fi

    cleanup || true
    exit 1
}

trap error_handler ERR

user_prompt()
{
    echo ""
    echo "NirvaShare Data Restore Utility."
    echo ""

    echo "This utility will allow you to restore entire database and the configurations from a backup file of NirvaShare."
    echo "Please note that existing data will be deleted and new data will be restored from the backup file."

    if [ "${NS_SILENT:-false}" != "true" ]; then
        while true; do
            read -p "Do you want to restore now? (y/n)? " yn

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

prompt_filename()
{
    if [ -z "${BACKUP_FILE:-}" ]; then

        user_prompt

        while true; do

            read -p "Enter the backup file name with full path: " BACKUP_FILE
            echo

            if [[ -z "$BACKUP_FILE" ]]; then
                continue
            elif [[ "$BACKUP_FILE" != *.tar.gz ]]; then
                echo "Expected file extension should be tar.gz"
            elif [ ! -f "$BACKUP_FILE" ]; then
                echo "File not found - $BACKUP_FILE"
            else
                break
            fi

        done
    fi
}

restart_nirvashare()
{
    echo ""
    echo "Restarting Services"
    echo ""

    export COMPOSE_IGNORE_ORPHANS=true

    docker-compose -f "$DOCKER_FILE" restart

    if [ -f "$DOCKER_FILE_FTPS" ]; then
        docker-compose -f "$DOCKER_FILE_FTPS" restart
    fi
}

stop_nirvashare()
{
    echo ""
    echo "Stopping NirvaShare Services"
    echo ""

    export COMPOSE_IGNORE_ORPHANS=true

    docker-compose -f "$DOCKER_FILE" stop admin userapp search

    if [ -f "$DOCKER_FILE_FTPS" ]; then
        docker-compose -f "$DOCKER_FILE_FTPS" stop
    fi
}

restore_backup()
{
    RESTORE_STARTED=true

    rm -rf "$BACKUP_TEMP_FOLDER"
    mkdir -p "$BACKUP_TEMP_FOLDER"

    echo "Extracting backup..."

    tar -xzf "$BACKUP_FILE" -C "$BACKUP_TEMP_FOLDER"

    if [ ! -f "$BACKUP_TEMP_FOLDER/db-dump.sql" ]; then
        echo "Invalid backup. db-dump.sql not found."
        exit 1
    fi

    stop_nirvashare

    echo ""
    echo "Restoring database..."

    docker exec -i nirvashare_database \
        psql -U nirvashare \
        < "$BACKUP_TEMP_FOLDER/db-dump.sql" \
        > ns_db_restore.log 2>&1

    if [ -f "$BACKUP_TEMP_FOLDER/config.properties" ]; then
        echo "Restoring config.properties"
        cp "$BACKUP_TEMP_FOLDER/config.properties" "$CONFIG_FILE"
    fi

    if [ -f "$BACKUP_TEMP_FOLDER/dbpass" ]; then
        echo "Restoring dbpass"
        cp "$BACKUP_TEMP_FOLDER/dbpass" "$DB_PASS_FILE"
    fi
}

check_installation()
{
    if [ ! -f "$DOCKER_FILE" ]; then
        echo "$DOCKER_FILE does not exist."
        terminate
    fi

    prompt_filename
}

cleanup()
{
    rm -rf "$BACKUP_TEMP_FOLDER"
}

final_message()
{
    echo ""
    echo "Restore Completed Successfully!"
    echo ""
    echo "NOTE - Please wait a couple of minutes for the services to come up."
    echo ""
}

check_installation
restore_backup
restart_nirvashare
cleanup
final_message
