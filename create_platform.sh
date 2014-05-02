#!/bin/bash
#
# Aegir platform creation script to be called from Jenkins
#

source_dir=$1
target_dir=$2

DRUSH=/usr/share/drush/drush
PLATFORM_DEPLOY_TRIGGER='#platform'

# check our input arguments
if [[ -z $source_dir ]] || [[ -z $target_dir ]]; then
    echo "Error: missing source or target dir arguments. Exit."
    exit 1
fi

echo "Looking for a '$PLATFORM_DEPLOY_TRIGGER' substring in a commit message..."
# get the commit message from git log
if [[ -z $GIT_COMMIT ]]; then
    echo "Unable to deterine git commit sha"
else
    echo "Trying to find out a commit message for commit $GIT_COMMIT"
    message="$(git log --format=%B -n 1 $GIT_COMMIT)"
    if [[ "$message" == *"$PLATFORM_DEPLOY_TRIGGER"* ]]; then
        echo "Commit message contains platform creation trigger substring $PLATFORM_DEPLOY_TRIGGER - need platform creation"
    else
        echo "No need to create a new platform because git commit message does not contain trigger substring $PLATFORM_DEPLOY_TRIGGER."
        exit 0
    fi
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
$DRUSH @hostmaster hosting-import "@$platform_alias"
$DRUSH @hostmaster hosting-dispatch

echo "Complete."
exit 0