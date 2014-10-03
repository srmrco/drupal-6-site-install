#!/bin/bash
#
# Drupal deployment script to be called from Jenkins
#

source_dir=$1
target_dir=$2
config_file=$3

DRUSH=/usr/share/drush5/drush
CLEANUP=/usr/local/share/deploy/cleanup.sh

# check our input arguments
if [[ -z $source_dir ]] || [[ -z $target_dir ]]; then
    echo "Error: missing source or target dir arguments. Exit."
    exit 1
fi


# include config file if it exists
if [ -f $config_file ]; then
    echo "Using configuration from $config_file"
    . $config_file
else
    echo "Error: configuration file file not found. Exit."
    exit 1
fi


# optional config parameters
if [[ -z $FILE_OWNER_USER ]]; then
    FILE_OWNER_USER="www-data"
fi
if [[ -z $FILE_OWNER_GROUP ]]; then
    FILE_OWNER_GROUP="www-data"
fi

if [ -d "$target_dir" ]; then

    # temp folder that will hold sites/default folder
    timestamp=$(date +%F-%H-%M-%S)
    temp_dir=/tmp/deploy/$timestamp

    if [ -d $temp_dir ]; then
        rm -rf $temp_dir
    fi
    mkdir -p $(dirname "$temp_dir/default")
    echo "Created a temp dir: $temp_dir"

    # copy sites/default folder to temp location
    cp -Rf $target_dir/sites/default $temp_dir/default
    echo "sites/default folder has been copeid to $temp_dir. Ready to update files"

    # run cleanup script
    sudo $CLEANUP $source_dir $target_dir $FILE_OWNER_USER $FILE_OWNER_GROUP

    echo "Restoring sites/default..."
    # restore sites/default folder
    cp -Rf $temp_dir/default $target_dir/sites/
    echo "Restored."

    # fix file permissions
    echo "Changing file permissions..."
    chown -Rf $FILE_OWNER_USER:$FILE_OWNER_GROUP $target_dir
    chmod -Rf 777 $target_dir/sites/default/files
    echo "Permissions have been set."

    echo "Going to $target_dir/sites/default..."
    cd $target_dir/sites/default

    echo "Now run drush updates..."
    $DRUSH -y updb

    echo "Clean caches..."
    $DRUSH cc all

    # to invalidate APC caches
    sudo /etc/init.d/apache2 graceful

    rm -rf $temp_dir
    echo "Temp directory deleted."
    echo "Ready."

    exit 0
fi


echo "Error: no target dir specified. Exit."

exit 1
