#!/bin/bash

#
# Git repository update shortcut script
#

target_dir=$1
remote_name=$2
branch_name=$3

echo "Updating repository in $target_dir ..."
cd $target_dir

echo "Fetching from $remote_name/$branch_name..."
git fetch
git reset --hard $remote_name/$branch_name

echo "Making files folder writable by server..."
chown -R jenkins:www-data $target_dir/www/sites/default/files
chmod -R g+w $target_dir/www/sites/default/files

echo "Update complete"
echo "Exit"
exit 0


