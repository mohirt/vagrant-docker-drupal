#!/bin/bash
set -e

# Check if drupal exists, download and install then.
if [ ! -f /var/www/drupal/sites/default/settings.php ]; then
  # drush dl and si takes time, setting a fake settings.php prevent
  # chasing the tail since three containers based on this image
  # will be created at the same time.
  touch /var/www/drupal/sites/default/settings.php

  drush dl -y --destination=/var/www --drupal-project-rename=drupal

  cd /var/www/drupal && drush si -y \
    standard install_configure_form.update_status_module='array(FALSE,FALSE)' \
    --db-url=mysql://PROJECT_CODE@db/PROJECT_CODE \
    --account-name=admin \
    --account-pass=test \
    --account-mail="admin@mail.localdomain" \
    --site-name=PROJECT_CODE \
    --site-mail="PROJECT_CODE@mail.localdomain"

  # Some minor tweaks for default Drupal install.
  # Remove http request fail notice.
  chmod a+w /var/www/drupal/sites/default/settings.php
  echo -e "\n\$conf['drupal_http_request_fails'] = FALSE;" >> /var/www/drupal/sites/default/settings.php
  chmod a-w /var/www/drupal/sites/default/settings.php
  # Remove default poor man cron.
  drush -r /var/www/drupal vset cron_safe_threshold -y 0
  # Organize modules into subdirectories.
  mkdir -p /var/www/drupal/sites/all/modules/contrib
  mkdir -p /var/www/drupal/sites/all/modules/custom
  # Set syslog variables
  drush -r /var/www/drupal vset syslog_facility -y '176'
  drush -r /var/www/drupal vset syslog_format -y '!base_url|!timestamp|!type|!ip|!request_uri|!referer|!uid|!link|!message'
  drush -r /var/www/drupal vset syslog_identity -y 'PROJECT_CODE'
  drush -r /var/www/drupal en -y syslog
  # Download smtp module and set variables.
  drush -r /var/www/drupal vset smtp_host -y 'exim'
  drush -r /var/www/drupal vset smtp_port -y '25'
  drush -r /var/www/drupal vset smtp_allowhtml -y 1
  drush -r /var/www/drupal vset smtp_protocol -y 'standard'
  drush -r /var/www/drupal dl smtp
  drush -r /var/www/drupal en -y smtp
  # Download devel module.
  drush -r /var/www/drupal dl devel
  # Set permission for Drupal directories.
  chown -R root:root /var/www/drupal
  chown -R www-data:www-data /var/www/drupal/sites/default/files
  chown -R www-data:www-data /var/www/drupal/sites/default/private
  chmod -R o= /var/www/drupal
fi

# Nginx.
if [ "$1" = 'nginx' ]; then
  exec nginx
fi

# Cron.
if [ "$1" = 'cron' ]; then
  # Sleep before running cron for 30 mins,
  # in case it crashes the DB during DB install or import.
  sleep 1800
  exec cron -f
fi

# FPM.
if [ "$1" = 'fpm' ]; then
  if [ ! -z "$2" ] && [ "$2" = 'devel' ]; then
    exec php5-fpm -F -c /etc/php5/fpm/php.ini-devel
  else
    exec php5-fpm -F
  fi
fi

echo 'Hello! No daemon is running, are you running as a helper container?'
exec "$@"
