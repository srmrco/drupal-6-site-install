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
if [[ -z $FULL_DEPLOY_TRIGGER_SUBSTRING ]]; then
    FULL_DEPLOY_TRIGGER_SUBSTRING='#deploy'
fi

# find out if we need a full deploy or only file updates
NEED_FULL_DEPLOY="1"
if [ -n $FULL_DEPLOY_ONLY_ON_COMMIT_TOKEN ] && [ "$FULL_DEPLOY_ONLY_ON_COMMIT_TOKEN" = "1" ]; then
    NEED_FULL_DEPLOY="0"
fi

if [ "$NEED_FULL_DEPLOY" = "1" ]; then
    echo "Proceed with full deployment..."
else
    echo "Configuration params are set to check if we actually need a full deployment."
    echo "We will look for a '#deploy' substring in a commit message..."
    # get the commit message from git log
    if [[ -z $GIT_COMMIT ]]; then
        echo "Unable to deterine git commit sha"
    else
        echo "Trying to find out a commit message for commit $GIT_COMMIT"
        message="$(git log --format=%B -n 1 $GIT_COMMIT)"
        if [[ "$message" == *"$FULL_DEPLOY_TRIGGER_SUBSTRING"* ]]; then
            echo "Commit message contains build trigger substring $FULL_DEPLOY_TRIGGER_SUBSTRING - need full deployment"
            NEED_FULL_DEPLOY="1"
        else
            echo "Don't need full deployment right now because git commit message does not contain trigger substring $FULL_DEPLOY_TRIGGER_SUBSTRING."
        fi
    fi
fi

# it is possible that we just need to update files and exit
if [ "$NEED_FULL_DEPLOY" = "0" ]; then
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
        echo "sites/default folder has been backed up. Ready to update files"

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

        # maybe we need to modify RewriteBase in .htaccess?
        if [ -n "${REWRITE_BASE}" ]; then
            echo "Updating RewriteBase directive in .htaccess file..."
            sed "s/# RewriteBase \/$/RewriteBase \/$REWRITE_BASE/" $target_dir/.htaccess > ~/tmp.out
            cp -f ~/tmp.out $target_dir/.htaccess
            rm ~/tmp.out
        fi

        echo "Going to $target_dir/sites/default..."
        cd $target_dir/sites/default

        echo "Now run drush updates..."
        $DRUSH -y updb

        rm -rf $temp_dir
        echo "Temp directory deleted."
        echo "Ready."

        exit 0
    else
        echo "Target directory does not exist - $target_dir, redeploy from scratch"
        NEED_FULL_DEPLOY="1"
    fi
fi

# run cleanup script
sudo $CLEANUP $source_dir $target_dir $FILE_OWNER_USER $FILE_OWNER_GROUP

# append some additional content to settings.php file
if [ -f $variables_overrides_in_settings ]; then
    echo "Append vaiables overrides to settings.php from $variables_overrides_in_settings"

    # modify default.settings.php! because it will be used by drush site-install to create the real settings.php file
    cat "$variables_overrides_in_settings" >> "$target_dir/sites/default/default.settings.php"
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
chmod -Rf 777 $target_dir/sites/default/files
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
