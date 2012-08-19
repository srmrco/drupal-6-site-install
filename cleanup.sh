#!/bin/bash

source_dir=$1
target_dir=$2
FILE_OWNER_USER=$3
FILE_OWNER_GROUP=$4


# delete everything from target_dir
echo "Deleting $target_dir..."
rm -rf $target_dir

# copy new files
echo "Copying new files from $source_dir to $target_dir..."
cp -r $source_dir $target_dir
echo "Copying complete."

# fix file permissions
echo "Changing file permissions..."
chown -Rf $FILE_OWNER_USER:$FILE_OWNER_GROUP $target_dir
chmod -Rf 777 $target_dir/sites/default
chmod -RF 775 $target_dir/sites/all/translations
echo "Permissions have been set."



