#!/bin/bash


FILE=$(</opt/minecraftCasalino/backups/lastFile.dat)

rclone copy /opt/minecraftCasalino/backups/$FILE mega:backupCasalino

rclone delete --mega-hard-delete  mega:backupCasalino --min-age 8d -v
