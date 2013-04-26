#!/bin/bash
#
# Drupal deployment script to be called from Jenkins
#

source_dir=$1
target_dir=$2
config_file=$3
variables_file=$4
variables_overrides_in_settings=$5

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

# append some additional content to settings.php file
if [ -f $variables_overrides_in_settings ]; then
    echo "Append vaiables overrides to settings.php from $variables_overrides_in_settings"
    echo $variables_overrides_in_settings >> $target_dir/sites/default/settings.php
fi

# drop all tables in the database
echo "Dropping tables from $DB_NAME..."
$DRUSH sql-drop $DB_URL --yes

# run installation
echo "Starting Drupal installation using drush site-install..."
cd $target_dir
$DRUSH site-install $PROFILE --yes --site-name="$SITE_NAME" --site-mail="$SITE_MAIL" --db-url="$DB_URL" --account-mail="$ACCOUNT_MAIL" --account-name="$ACCOUNT_NAME" --account-pass="$ACCOUNT_PASS"

# update translations
if [[ -n $L10N_UPDATE ]]; then
    # set proper permissions on translations dir
    var="l10n_update_download_store"
    $DRUSH vget $var --root="$target_dir" &> /dev/null
    if [[ "$?" -eq 0 ]]; then
        set `$DRUSH vget $var --root="$target_dir"`
        l10n_update_dir=`echo "$2" | sed 's/"//g'`
	# this is not needed anymore - persmissions are set by cleanup script because it executes under sudo
        #echo "Changing file permissions for $l10n_update_dir..."
        #chmod -Rf 775 $target_dir/$l10n_update_dir 
    fi
    echo "Updating translations..."
    $DRUSH l10n-update --root="$target_dir"
fi

# fix file permissions
echo "Changing file permissions..."
chown -Rf $FILE_OWNER_USER:$FILE_OWNER_GROUP $target_dir
chmod -Rf 777 $target_dir/sites/default
echo "Permissions have been set."

# try parse variables file
if [ -f $variables_file ]; then
    echo "Using variables file $variables_file"

    cat $variables_file |
        while read line
        do
	    chr=${line:0:1}
   	    case $chr in
                "#") # Currently we ignore commented lines
                     ;;
                 * )
	             $DRUSH --root=$target_dir vset $line
                     ;;
            esac
        done

else
    echo "No variables file specified. But that's OK..."
fi

# maybe we need to modify RewriteBase in .htaccess?
if [ -n "${REWRITE_BASE}" ]; then
    echo "Updating RewriteBase directive in .htaccess file..."
    sed "s/# RewriteBase \/$/RewriteBase \/$REWRITE_BASE/" $target_dir/.htaccess > ~/tmp.out
    cp -f ~/tmp.out $target_dir/.htaccess
    rm ~/tmp.out
fi


echo "Installation ends."

echo "Exit"
exit 0
