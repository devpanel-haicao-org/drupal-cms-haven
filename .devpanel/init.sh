#!/usr/bin/env bash
if [ -n "${DEBUG_SCRIPT:-}" ]; then
  set -x
fi
set -eu -o pipefail
cd $APP_ROOT

LOG_FILE="logs/init-$(date +%F-%T).log"
exec > >(tee $LOG_FILE) 2>&1

TIMEFORMAT=%lR
# For faster performance, don't audit dependencies automatically.
export COMPOSER_NO_AUDIT=1

#== Remove root-owned files.
echo
echo Remove root-owned files.
time sudo rm -rf lost+found

#== Set permissions for application root.
echo
echo 'Set permissions for application root.'
time sudo chmod 777 $APP_ROOT

#== Composer install.
echo
if [ -f composer.json ]; then
  echo 'Composer update.'
else
  echo 'Generate composer.json.'
  time source .devpanel/composer_setup.sh
  echo
fi
time composer -n update --no-progress

#== Create the private files directory.
if [ ! -d private ]; then
  echo
  echo 'Create the private files directory.'
  time mkdir -p private
fi
time sudo chmod -R 777 private

#== Create the config sync directory.
if [ ! -d config/sync ]; then
  echo
  echo 'Create the config sync directory.'
  time mkdir -p config/sync
fi

#== Generate hash salt.
if [ ! -f .devpanel/salt.txt ]; then
  echo
  echo 'Generate hash salt.'
  time openssl rand -hex 32 > .devpanel/salt.txt
fi

#== Set permissions for Drupal installation.
echo
echo 'Set permissions for Drupal installation.'
if [ ! -d web/sites/default/files ]; then
  time mkdir -p web/sites/default/files
fi
time sudo chmod -R 777 web/sites/default/files/
if [ ! -f web/sites/default/settings.php ] && [ -f web/sites/default/default.settings.php ]; then
  time cp web/sites/default/default.settings.php web/sites/default/settings.php
fi
if [ -f web/sites/default/settings.php ]; then
  time sudo chmod 666 web/sites/default/settings.php
fi

#== Install Drupal.
echo
if [ -z "$(drush status --field=db-status)" ]; then
  # Step 1: Install Drupal with minimal profile (fast, non-interactive).
  echo 'Install Drupal (minimal profile).'
  time drush -n si minimal --site-name='Drupal CMS Haven'

  # Step 2: Apply the haven recipe (installs theme + demo content + dependencies).
  echo
  echo 'Apply Haven recipe (theme + demo content).'
  HAVEN_PATH=$(find vendor -type f -name "recipe.yml" -path "*/haven/*" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || echo "")
  if [ -n "$HAVEN_PATH" ]; then
    echo "Found haven recipe at: $HAVEN_PATH"
    time php web/core/scripts/drupal recipe "$HAVEN_PATH"
  else
    echo "Warning: haven recipe not found in vendor directory."
  fi

  echo
  time drush cr
else
  echo 'Update database.'
  time drush -n updb
fi

# ==============================================================================
# SET UP MARKETPLACE BAR
# ==============================================================================
echo
echo 'Enable DevPanel Marketplace Bar.'
time drush -n en devpanel_marketplace_bar
echo
# ==============================================================================

#== Warm up caches.
echo
echo 'Run cron.'
time drush cron
echo
echo 'Populate caches.'
time drush cache:warm &> /dev/null || :

#== Finish measuring script time.
INIT_DURATION=$SECONDS
INIT_HOURS=$(($INIT_DURATION / 3600))
INIT_MINUTES=$(($INIT_DURATION % 3600 / 60))
INIT_SECONDS=$(($INIT_DURATION % 60))
printf "\nTotal elapsed time: %d:%02d:%02d\n" $INIT_HOURS $INIT_MINUTES $INIT_SECONDS
