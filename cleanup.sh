#!/bin/bash

source_dir=$1
target_dir=$2
FILE_OWNER_USER=$3
FILE_OWNER_GROUP=$4
COPY_HIDDEN_STUFF=$5

if [[ -z $COPY_HIDDEN_STUFF= ]]; then
    COPY_HIDDEN_STUFF="0"
fi

# delete everything from target_dir
echo "Deleting $target_dir..."
rm -rf $target_dir

# copy new files
echo "Copying new files from $source_dir to $target_dir..."
cp -r $source_dir $target_dir

# we may want to copy hidden stuff as well
if [[ -n $COPY_HIDDEN_STUFF ]]; then
    echo "Copying hidden stuff..."
    cp -r $source_dir/.[a-zA-Z0-9]* $target_dir/
    echo "Hidden stuff copied."
fi

echo "Copying complete."

# fix file permissions
echo "Changing file permissions..."
chown -Rf $FILE_OWNER_USER:$FILE_OWNER_GROUP $target_dir
chmod -Rf 777 $target_dir/sites/default
chmod -Rf 775 $target_dir/sites/all/translations
echo "Permissions have been set."



