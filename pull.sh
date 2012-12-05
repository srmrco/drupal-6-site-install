#!/bin/bash

#
# Git repository update shortcut script
#

target_dir=$1
remote_name=$2
branch_name=$3

echo "Updating repository in $target_dir ..."
cd $target_dir

echo "About to do git pull $remote_name $branch_name..."
git pull $remote_name $branch_name

echo "Update complete"
echo "Exit"
exit 0


