#!/bin/bash

set -e

# CONFIG
DISPATCH_YML=dispatch-sh.yml
REMOTE_DISPATCH_YML=https://raw.githubusercontent.com/wpdispatch/dispatch-sh/master/dispatch-sh.example.yml

# COLOR
ERROR="\033[0;31m"
SUCCESS="\033[0;32m"
INFO="\033[0;34m"
WARNING="\033[0;33m"
DEFAULT='\033[0m'

# HELPER
function catch_continue() {
  read -p "$(echo -e "${WARNING}do you want to continue? [y/n] ${DEFAULT}")" -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "\n${ERROR}>> exiting  ${DEFAULT}\n"
    exit 1
  else
    printf "\n${SUCCESS}>> continuing  ${DEFAULT}\n"
  fi
}
trap 'catch_continue' ERR

# YAML PARSER FUNCTION
function parse_yaml() {
    local prefix=$2
    local s
    local w
    local fs
    s='[[:space:]]*'
    w='[a-zA-Z0-9_]*'
    fs="$(echo @|tr @ '\034')"
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$1" |
    awk -F"$fs" '{
    indent = length($1)/2;
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, $3);
        }
    }' | sed 's/_=/+=/g'
}

echo "====================================================="
echo "  WORDPRESS                                          "
echo "  |||||  || ||||| |||||  |||||| ||||||  |||| ||  ||  "
echo "  ||  || || ||    ||  || ||  ||   ||   ||    ||  ||  "
echo "  ||  || || ||||| |||||  ||||||   ||   ||    ||||||  "
echo "  ||  || ||    || ||     ||  ||   ||   ||    ||  ||  "
echo "  |||||  || ||||| ||     ||  ||   ||    |||| ||  ||  "
echo "                               by www.ioniklabs.com  "
echo "====================================================="
echo "                                                     "
echo "                 --- WP-Dispatch ---                 "
echo "                    version 0.0.1                    "
echo "                     MIT License                     "
echo "                                                     "
echo "====================================================="
echo "                                                     "

echo "                                                     "
echo "====================================================="
echo "                       CONFIG                        "
echo "====================================================="
echo "                                                     "

# GET CONFIG
if [ -f $DISPATCH_YML ]; then
  printf "\n${DEFAULT}>> found local ${DISPATCH_YML} template ${DEFAULT}\n"
else
  printf "\n${DEFAULT}>> downloading default ${DISPATCH_YML} template ${DEFAULT}\n"
  curl --fail --silent --output $DISPATCH_YML $REMOTE_DISPATCH_YML
fi

printf "\n${SUCCESS}>> open ${DISPATCH_YML} and configure your new project then continue! ${DEFAULT}\n"

catch_continue

# READ CONFIG
eval $(parse_yaml $DISPATCH_YML "CONF_")
printf "\n${DEFAULT}>> parsing ${DISPATCH_YML} ${DEFAULT}\n"

# CHECK WP FOLDER
if [ ! -d "$CONF_wpfolder" ]; then
  mkdir $CONF_wpfolder
  printf "${INFO}>> creating WP Folder ${CONF_wpfolder}...${DEFAULT}\n"
fi

cd $CONF_wpfolder

if $CONF_setup_db ; then

  echo "                                                     "
  echo "====================================================="
  echo "                      DATABASE                       "
  echo "====================================================="
  echo "                                                     "

  db_check="mysql -u$CONF_db_user -p$CONF_db_pass -h$CONF_db_host -e 'SHOW DATABASES' | grep -Fo $CONF_db_name"
  if [ "$db_check" == "$CONF_db_name" ]; then
    #Database Exists
    printf "${ERROR}>> Database $CONF_db_name@$CONF_db_host already exists. ${DEFAULT}\n"
    exit
  else
    #Create Database and User
    #Create Database and User
    query="CREATE DATABASE $CONF_db_name;
           GRANT ALL PRIVILEGES ON $CONF_db_name.* TO $CONF_db_user@$CONF_db_host IDENTIFIED BY '$CONF_db_pass';"
    mysql -u$CONF_db_user -p$CONF_db_pass -h$CONF_db_host -e "$query"
    if [ $? != "0" ]; then
      printf "${ERROR}>> Could not create database $CONF_db_name@$CONF_db_host. ${DEFAULT}\n"
      exit
    else
      printf "${SUCCESS}>> Created database $CONF_db_name@$CONF_db_host. ${DEFAULT}\n"
    fi
  fi
fi

# INSTALL WORDPRESS
if $CONF_setup_wp ; then

  echo "                                                     "
  echo "====================================================="
  echo "                      WORDPRESS                      "
  echo "====================================================="
  echo "
                                                       "
  printf "${DEFAULT}>> downloading WordPress...${DEFAULT}\n"
  wp core download --locale=$CONF_wplocale --version=$CONF_wpversion
  printf "${DEFAULT}>> creating wp-config...${DEFAULT}\n"
  wp config create --dbhost=$CONF_db_host --dbname=$CONF_db_name --dbuser=$CONF_db_user --dbpass=$CONF_db_pass --dbprefix=$CONF_db_prefix --locale=$CONF_wplocale
  printf "${DEFAULT}>> installing wordpress...${DEFAULT}\n"
  wp core install --url=$CONF_wpsettings_url --title="$CONF_wpsettings_title" --admin_user=$CONF_admin_user --admin_password=$CONF_admin_password --admin_email=$CONF_admin_email --skip-email
  wp user update 1 --first_name=$CONF_admin_first_name --last_name=$CONF_admin_last_name
else
  printf "${INFO}>>> skipping WordPress installation...${DEFAULT}\n"
fi

if $CONF_setup_settings ; then

  echo "                                                     "
  echo "====================================================="
  echo "                      SETTINGS                       "
  echo "====================================================="
  echo "                                                     "

  printf "${INFO}>> configure settings...${DEFAULT}\n"
  printf "timezone:\n"
  wp option update timezone $CONF_timezone
  wp option update timezone_string $CONF_timezone
  printf "permalink structure:\n"
  wp rewrite structure "$CONF_wpsettings_permalink_structure"
  wp rewrite flush --hard
  printf "description:\n"
  wp option update blogdescription "$CONF_wpsettings_description"
  printf "image sizes:\n"
  wp option update thumbnail_size_w $CONF_wpsettings_thumbnail_width
  wp option update thumbnail_size_h $CONF_wpsettings_thumbnail_height
  wp option update medium_size_w $CONF_wpsettings_medium_width
  wp option update medium_size_h $CONF_wpsettings_medium_height
  wp option update large_size_w $CONF_wpsettings_large_width
  wp option update large_size_h $CONF_wpsettings_large_height
  if ! $CONF_wpsettings_convert_smilies ; then
    wp option update convert_smilies 0
  fi
  if $CONF_wpsettings_page_on_front ; then
    printf "front page:\n"
    # create and set frontpage
    wp post create --post_type=page --post_title="$CONF_wpsettings_frontpage_name" --post_content='Front Page created by WPDistillery' --post_status=publish
    wp option update page_on_front $(wp post list --post_type=page --post_status=publish --posts_per_page=1 --pagename="$CONF_wpsettings_frontpage_name" --field=ID --format=ids)
    wp option update show_on_front 'page'
  fi
else
  printf "${INFO}>>> skipping settings...${DEFAULT}\n"
fi

# INSTALL THEME
if $CONF_setup_theme ; then

  echo "                                                     "
  echo "====================================================="
  echo "                       THEME                         "
  echo "====================================================="
  echo "                                                     "

  printf "${WARNING}[=== INSTALL $CONF_theme_name ===]${DEFAULT}\n"
  printf "${INFO}>> downloading $CONF_theme_name...${DEFAULT}\n"
  wp theme install $CONF_theme_url
  printf "${INFO}>> installing/activating $CONF_theme_name...${DEFAULT}\n"
  if [ ! -z "$CONF_theme_rename" ]; then
    # rename theme
    printf "${INFO}>> renaming $CONF_theme_name to $CONF_theme_rename...${DEFAULT}\n"
    mv wp-content/themes/$CONF_theme_name wp-content/themes/$CONF_theme_rename
    wp theme activate $CONF_theme_rename
  else
    wp theme activate $CONF_theme_name
  fi
else
  printf "${INFO}>>> skipping theme installation...${DEFAULT}\n"
fi

# CLEANUP
if $CONF_setup_cleanup ; then

  echo "                                                     "
  echo "====================================================="
  echo "                      CLEANUP                        "
  echo "====================================================="
  echo "                                                     "

  printf "${WARNING}[=== CLEANUP ===]${DEFAULT}\n"
  if $CONF_setup_cleanup_comment ; then
    printf "${INFO}>> removing default comment...${DEFAULT}\n"
    wp comment delete 1 --force
  fi
  if $CONF_setup_cleanup_posts ; then
    printf "${INFO}>> removing default posts...${DEFAULT}\n"
    wp post delete 1 2 --force
  fi
  if $CONF_setup_cleanup_files ; then
    printf "${INFO}>> removing WP readme/license files...${DEFAULT}\n"
    # delete default files
    if [ -f readme.html ];    then rm readme.html;    fi
    if [ -f license.txt ];    then rm license.txt;    fi
    # delete german files
    if [ -f liesmich.html ];  then rm liesmich.html;  fi
  fi
  if $CONF_setup_cleanup_themes ; then
    printf "${INFO}>> removing default themes...${DEFAULT}\n"
    wp theme delete twentyfifteen
    wp theme delete twentysixteen
    wp theme delete twentyseventeen
  fi
else
  printf "${INFO}>>> skipping Cleanup...${DEFAULT}\n"
fi

# PLUGINS
if $CONF_setup_plugins ; then

  echo "                                                     "
  echo "====================================================="
  echo "                      PLUGINS                        "
  echo "====================================================="
  echo "                                                     "

  printf "${WARNING}[=== PLUGINS ===]${DEFAULT}\n"
  printf "${INFO}>> removing WP default plugins${DEFAULT}\n"
  wp plugin delete akismet
  wp plugin delete hello
  printf "${INFO}>> adding active plugins${DEFAULT}\n"
  for entry in "${CONF_plugins_active[@]}"
  do
  	wp plugin install $entry --activate
  done

  printf "${INFO}>> adding inactive plugins${DEFAULT}\n"
  for entry in "${CONF_plugins_inactive[@]}"
  do
    wp plugin install $entry
  done
else
  printf "${INFO}>>> skipping Plugin installation...${DEFAULT}\n"
fi

# MISC
printf "${INFO}>> checking wp cli version ${DEFAULT}\n"
wp cli check-update

printf "${WARNING}>> finished installation ${DEFAULT}\n"
printf "${ERROR}>> if the installation was successful you can remove ${DISPATCH_YML} ${DEFAULT}\n"
