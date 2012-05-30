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
    echo "Missing source or target dir arguments. Exit."
    exit 1
fi


# include config file if it exists
if [ -f $config_file ]; then
    echo "Using configuration from $config_file"
    . $config_file
else
    echo "Error: configuration file file not found"
    exit 1
fi

# check that config file contains all required parameters
if [[ -z $DB_NAME ]]; then
    echo "Config file does not contain database name parameter. Exit."
    exit 1
fi
if [[ -z $DB_ADMIN_NAME ]]; then
    echo "Config file does not user name which should be used to connect to the database. Exit."
    exit 1
fi

# optional config parameters
if [[ -z $PROFILE ]]; then
    PROFILE="default"
fi
if [[ -z $LOCALE ]]; then
    LOCALE="en"
fi
if [[ -z $SITE_NAME ]]; then
    SITE_NAME="My Site"
fi
if [[ -z $SITE_MAIL ]]; then
    SITE_MAIL="site@example.com"
fi
if [[ -z $ACCOUNT_NAME ]]; then
    ACCOUNT_NAME="admin"
fi
if [[ -z $ACCOUNT_PASS ]]; then
    ACCOUNT_PASS="123"
fi
if [[ -z $ACCOUNT_MAIL ]]; then
    ACCOUNT_MAIL="admin@example.com"
fi
if [[ -z $FILE_OWNER_USER ]]; then
    FILE_OWNER_USER="www-data"
fi
if [[ -z $FILE_OWNER_GROUP ]]; then
    FILE_OWNER_GROUP="www-data"
fi


# run cleanup script
sudo $CLEANUP $source_dir $target_dir $FILE_OWNER_USER $FILE_OWNER_GROUP

# drop all tables in the database
echo "Dropping tables from $DB_NAME..."
$DRUSH sql-drop $DB_URL --yes

# run installation
echo "Starting Drupal installation using drush site-install..."
cd $target_dir
$DRUSH site-install $PROFILE --yes --site-name="$SITE_NAME" --site-mail="$SITE_MAIL" --db-url="$DB_URL" --account-mail="$ACCOUNT_MAIL" --account-name="$ACCOUNT_NAME" --account-pass="$ACCOUNT_PASS"

# update translations
if [[ -z $L10N_UPDATE ]]; then
    echo "Updating translations..."
    $DRUSH l10n-update --root="$target_dir"
fi

# workaround http://drupal.org/node/1297438#comment-5374060
# reinstalling with locale
# $DRUSH site-install $PROFILE  --yes --locale=$LOCALE --site-name="$SITE_NAME" --site-mail=$SITE_MAIL --db-url=$DB_URL --account-mail=$ACCOUNT_MAIL --account-name=$ACCOUNT_NAME --account-pass=$ACCOUNT_PASS

# fix file permissions
echo "Changing file permissions..."
chown -Rf $FILE_OWNER_USER:$FILE_OWNER_GROUP $target_dir
chmod -Rf 777 $target_dir/sites/default
echo "Permissions have been set."

echo "Installation ends."

echo "Exit"
exit 0
