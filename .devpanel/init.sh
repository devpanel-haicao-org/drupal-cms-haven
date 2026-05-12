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
  if composer show --locked cweagans/composer-patches ^2 &> /dev/null; then
    echo 'Update patches.lock.json.'
    time composer prl
    echo
  fi
else
  echo 'Generate composer.json.'
  time source .devpanel/composer_setup.sh
  echo
fi
time composer -n update --no-progress

#== Create the private files directory.
echo
echo 'Create and set permissions for private files directory.'
if [ ! -d private ]; then
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
if [ -d assets ]; then
  time sudo chmod -R 777 assets/
fi

#== Install Drupal.
echo
if [ -z "$(drush status --field=db-status)" ]; then
  # Run the installer in a loop. Each invocation processes one install task
  # (form submission or batch step). The loop continues until install_task
  # state equals 'done', meaning ALL tasks are complete including recipe
  # application and profile uninstall.
  echo 'Install Drupal CMS with Haven template (this may take several minutes).'
  INSTALL_COUNTER=0
  while true; do
    INSTALL_COUNTER=$((INSTALL_COUNTER + 1))
    echo "  Install step $INSTALL_COUNTER..."
    .devpanel/install 2>&1 || true

    # Check if installation is complete.
    TASK=$(drush sget install_task 2>/dev/null || echo "unknown")
    if [ "$TASK" = "done" ]; then
      echo "  Installation complete after $INSTALL_COUNTER steps."
      break
    fi

    # Safety: prevent infinite loops.
    if [ $INSTALL_COUNTER -ge 200 ]; then
      echo "  Warning: Installation did not complete after $INSTALL_COUNTER steps (install_task=$TASK)."
      break
    fi
  done

  echo
  echo 'Tell Automatic Updates about patches.'
  drush -n cset --input-format=yaml package_manager.settings additional_trusted_composer_plugins '["cweagans/composer-patches"]'
  time drush ev '\Drupal::moduleHandler()->invoke("automatic_updates", "modules_installed", [[], FALSE])'

  echo
  time drush cr
else
  echo 'Update database.'
  time drush -n updb
fi

echo
echo 'Enable DevPanel Marketplace Bar.'
time drush -n en devpanel_marketplace_bar
echo

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
