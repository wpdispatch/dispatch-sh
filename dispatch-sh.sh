#!/bin/bash
#
# dispatch-sh shell script
# @author Ionik Labs
# @url www.ioniklabs.com
# @version 1.0.0
#
# credits
# https://wpdistillery.org

DISPATCH_YML=dispatch-sh.yml
DISPATCH_SH=dispatch-sh.sh

WP_CLI_TGMPA_PLUGIN_COMMAND=wp-cli-tgmpa-plugin-command.php

func_dispatch_sh() {
  func_credits
  # yaml
  func_load_yaml
  # setup
  func_setup
  # databse
  func_database
  # wordpress
  func_wordpress
  # settings
  func_settings
  # theme
  func_theme
  # cleanup
  func_cleanup
  # tgmpa
  func_tgmpa
  # plugin
  func_plugin
  # finished
  func_finished
}

func_credits() {
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
  echo "                 --- dispatch-sh ---                 "
  echo "                    version 0.0.1                    "
  echo "                     MIT License                     "
  echo "                                                     "
  echo "====================================================="
  echo "                                                     "
}

func_divider() {
  echo "                                                     "
  echo "====================================================="
  echo " ${1}"
  echo "====================================================="
  echo "                                                     "
}

func_load_yaml() {
  func_divider 'load yaml'
  if [ -f $DISPATCH_YML ]; then
    echo "[success]: found local ${DISPATCH_YML}"
    eval $(func_parse_yaml $DISPATCH_YML "CONF_")
    echo "[success]: parsed ${DISPATCH_YML} for site ${CONF_wpsettings_title}"
  else
    echo "[error]: could not find ${DISPATCH_YML}"
    exit
  fi
}

func_setup() {
  func_divider 'setup'
  if [ ! -d "$CONF_wpfolder" ]; then
    mkdir $CONF_wpfolder
    echo "[success]: creating wp folder ${CONF_wpfolder}"
  else
    echo "[info]: ${CONF_wpfolder} already exists"
  fi
  cd $CONF_wpfolder
}

func_database() {
  func_divider 'database'
  if $CONF_setup_db ; then
    db_check="mysql -u$CONF_db_user -p$CONF_db_pass -h$CONF_db_host -e 'SHOW DATABASES' | grep -Fo $CONF_db_name"
    if [ "$db_check" == "$CONF_db_name" ]; then
      echo "[error]: Database $CONF_db_name@$CONF_db_host already exists."
      exit
    else
      query="CREATE DATABASE $CONF_db_name;
             GRANT ALL PRIVILEGES ON $CONF_db_name.* TO $CONF_db_user@$CONF_db_host IDENTIFIED BY '$CONF_db_pass';"
      mysql -u$CONF_db_user -p$CONF_db_pass -h$CONF_db_host -e "$query"
      if [ $? != "0" ]; then
        echo "[error]: Could not create database $CONF_db_name@$CONF_db_host."
        exit
      else
        echo "[success]: Created database $CONF_db_name@$CONF_db_host."
      fi
    fi
  else
    echo "[info]: skipping database"
  fi
}

func_wordpress() {
  func_divider 'wordpress'
  if $CONF_setup_db ; then
    echo "[info]: downloading wordpress"
    wp core download --locale=$CONF_wplocale --version=$CONF_wpversion
    echo "[info]: creating wp-config.php"
    wp config create --dbhost=$CONF_db_host --dbname=$CONF_db_name --dbuser=$CONF_db_user --dbpass=$CONF_db_pass --dbprefix=$CONF_db_prefix --locale=$CONF_wplocale
    echo "[info]: installing wordpress"
    wp core install --url=$CONF_wpsettings_url --title="$CONF_wpsettings_title" --admin_user=$CONF_admin_user --admin_password=$CONF_admin_password --admin_email=$CONF_admin_email --skip-email
    wp user update 1 --first_name=$CONF_admin_first_name --last_name=$CONF_admin_last_name
  else
    echo "[info]: skipping wordpress"
  fi
}

func_settings() {
  func_divider 'settings'
  if $CONF_setup_settings ; then
    echo "[info]: timezone"
    wp option update timezone $CONF_timezone
    wp option update timezone_string $CONF_timezone
    echo "[info]: permalink structure"
    wp rewrite structure "$CONF_wpsettings_permalink_structure"
    wp rewrite flush --hard
    echo "[info]: description"
    wp option update blogdescription "$CONF_wpsettings_description"
    echo "[info]: image sizes"
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
      echo "[info]: front page"
      # create and set frontpage
      wp post create --post_type=page --post_title="$CONF_wpsettings_frontpage_name" --post_content='Front Page created by WPDistillery' --post_status=publish
      wp option update page_on_front $(wp post list --post_type=page --post_status=publish --posts_per_page=1 --pagename="$CONF_wpsettings_frontpage_name" --field=ID --format=ids)
      wp option update show_on_front 'page'
    fi
  else
    echo "[info]: skipping settings"
  fi
}

func_theme() {
  func_divider 'theme'
  if $CONF_setup_theme ; then
    echo "[info]: downloading theme ${CONF_theme_name}"
    wp theme install $CONF_theme_url
    echo "[info]: downloading theme ${CONF_theme_name}"
    if [ ! -z "$CONF_theme_rename" ]; then
      echo "[info]: renaming $CONF_theme_name to $CONF_theme_rename"
      mv wp-content/themes/$CONF_theme_name wp-content/themes/$CONF_theme_rename
      wp theme activate $CONF_theme_rename
    else
      wp theme activate $CONF_theme_name
    fi
  else
    echo "[info]: skipping theme"
  fi
}

func_cleanup() {
  func_divider 'cleanup'
  if $CONF_setup_cleanup ; then
    if $CONF_setup_cleanup_comment ; then
      echo "[info]: removing default comment"
      wp comment delete 1 --force
    fi
    if $CONF_setup_cleanup_posts ; then
      echo "[info]: removing default posts"
      wp post delete 1 2 --force
    fi
    if $CONF_setup_cleanup_files ; then
      echo "[info]: removing files"
      if [ -f readme.html ];    then rm readme.html;    fi
      if [ -f license.txt ];    then rm license.txt;    fi
    fi
    if $CONF_setup_cleanup_themes ; then
      echo "[info]: removing default themes"
      wp theme delete twentyfifteen
      wp theme delete twentysixteen
      wp theme delete twentyseventeen
    fi
    if $CONF_setup_cleanup_plugins ; then
      echo "[info]: removing default plugins"
      wp plugin delete akismet
      wp plugin delete hello
    fi
  else
    echo "[info]: skipping cleanup"
  fi
}

func_tgmpa() {
  func_divider 'TGMPA (TGM Plugin Activation)'
  if $CONF_setup_tgmpa ; then
    curl -v --fail --output $WP_CLI_TGMPA_PLUGIN_COMMAND https://raw.githubusercontent.com/itspriddle/wp-cli-tgmpa-plugin/master/command.php
    wp --require=$WP_CLI_TGMPA_PLUGIN_COMMAND tgmpa-plugin install --all-required --activate
  else
    echo "[info]: skipping tgmpa"
  fi
}

func_plugins() {
  func_divider 'plugins'
  if $CONF_setup_plugins ; then
    for entry in "${CONF_plugins_active[@]}"
    do
      wp plugin install $entry --activate
    done

    for entry in "${CONF_plugins_inactive[@]}"
    do
      wp plugin install $entry
    done
  else
    echo "[info]: skipping plugins"
  fi
}

func_finished() {
  func_divider 'finished'
  echo "[info]: dispatch-sh has finished"
  printf "would you like to remove ${DISPATCH_YML}? [y/n]: "
  read -e run
  if [ "$run" == y ]; then
      rm $DISPATCH_YML
  fi
  printf "would you like to remove ${WP_CLI_TGMPA_PLUGIN_COMMAND}? [y/n]: "
  read -e run
  if [ "$run" == y ]; then
      rm $WP_CLI_TGMPA_PLUGIN_COMMAND
  fi
  echo "you will need to remove ${DISPATCH_SH} manually"
}

func_parse_yaml() {
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

# START
printf "would you like to run dispatch-sh? [y/n]: "
read -e run
if [ "$run" == y ]; then
    func_dispatch_sh
else
    exit
fi