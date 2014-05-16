#!/bin/bash
#
# Aegir platform creation script to be called from Jenkins
#

source_dir=$1
target_dir=$2

DRUSH=/usr/share/drush/drush.php

# check our input arguments
if [[ -z $source_dir ]] || [[ -z $target_dir ]]; then
    echo "Error: missing source or target dir arguments. Exit."
    exit 1
fi

timestamp=$(date +%F_%H_%M_%S)
platform_alias=platform_$timestamp
new_platform_path=$target_dir/$platform_alias

echo "Copying new platform to $new_platform_path..."
sudo cp -r $source_dir $new_platform_path

echo "Setting permission to aegir:aegir for $new_platform_path..."
sudo chown -R aegir:aegir $new_platform_path

echo "Setting up a new platform in Aegir..."
$DRUSH --root="$new_platform_path" provision-save "@$platform_alias" --context_type='platform'

echo 'Sleeping for 5 seconds...'
sleep 10s

$DRUSH @hostmaster hosting-import "@$platform_alias"
echo 'Sleeping for 5 more seconds...'
sleep 10s

echo 'Dispatching frontend update so that platform will become visible in Aegir...'
$DRUSH @hostmaster hosting-dispatch

echo "Complete."
exit 0