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
# For faster performance, don't install dev dependencies.
export COMPOSER_NO_DEV=1

#== Remove root-owned files.
echo
echo Remove root-owned files.
time sudo rm -rf lost+found

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
# If update fails, change it to install.
time composer -n update --no-dev --no-progress

#== Create the private files directory.
if [ ! -d private ]; then
  echo
  echo 'Create the private files directory.'
  time mkdir private
fi

#== Create the config sync directory.
if [ ! -d config/sync ]; then
  echo
  echo 'Create the config sync directory.'
  time mkdir -p config/sync
fi

#== Install Drupal.
echo
if [ -z "$(drush status --field=db-status)" ]; then
  echo 'Install Drupal.'
  time drush -n si
else
  echo 'Update database.'
  time drush -n updb
fi

# ==============================================================================
# APPLY HAVEN RECIPE & CONFIGURE THEME
# ==============================================================================
echo
echo '=== Setting up Haven Theme & Demo Content ==='

# Find the Haven recipe path
HAVEN_PATH=$(find web/themes web/recipes recipes web/profiles web/modules -maxdepth 3 -type d -name "haven" 2>/dev/null | head -n 1)

if [ -n "$HAVEN_PATH" ]; then
  echo "Found Haven at: $HAVEN_PATH"

  # Apply Haven base recipe if recipe.yml exists
  if [ -f "$HAVEN_PATH/recipe.yml" ]; then
    echo 'Applying Haven base recipe...'
    cd $APP_ROOT/web
    php core/scripts/drupal recipe "$APP_ROOT/$HAVEN_PATH"
    cd $APP_ROOT
  fi

  # Find and apply Demo Content recipe (sub-directory with demo/content in name)
  DEMO_RECIPE_PATH=$(find "$HAVEN_PATH" -maxdepth 2 -type d \( -iname "*demo*" -o -iname "*content*" \) 2>/dev/null | head -n 1)

  if [ -n "$DEMO_RECIPE_PATH" ] && [ -f "$DEMO_RECIPE_PATH/recipe.yml" ]; then
    echo "Found Demo Content recipe at: $DEMO_RECIPE_PATH"
    echo 'Applying Haven Demo Content recipe...'
    cd $APP_ROOT/web
    php core/scripts/drupal recipe "$APP_ROOT/$DEMO_RECIPE_PATH"
    cd $APP_ROOT
  fi
else
  echo 'Haven recipe directory not found. Applying recipe from vendor or modules...'
  # Try to find haven in vendor or other locations
  HAVEN_VENDOR=$(find vendor -maxdepth 4 -type d -name "haven" 2>/dev/null | head -n 1)
  if [ -n "$HAVEN_VENDOR" ] && [ -f "$HAVEN_VENDOR/recipe.yml" ]; then
    echo "Found Haven at: $HAVEN_VENDOR"
    cd $APP_ROOT/web
    php core/scripts/drupal recipe "$APP_ROOT/$HAVEN_VENDOR"
    cd $APP_ROOT
  fi
fi

# Install and set Haven theme as default
echo 'Installing Haven theme...'
drush -n theme:install haven_theme 2>/dev/null || echo 'Haven theme may already be installed.'

# Set Haven as the default theme
echo 'Setting Haven theme as default...'
drush -n config-set system.theme default haven_theme

# Install and set Claro as admin theme
echo 'Installing Claro admin theme...'
drush -n theme:install claro 2>/dev/null || echo 'Claro theme may already be installed.'
drush -n config-set system.theme admin claro
drush -n config-set node.settings use_admin_theme 1

echo '=== Haven Theme setup complete ==='
echo

# ==============================================================================

#== Warm up caches.
echo
echo 'Run cron.'
time drush cron
echo
echo 'Populate caches.'
time drush cache:warm &> /dev/null || :
time .devpanel/warm

#== Finish measuring script time.
INIT_DURATION=$SECONDS
INIT_HOURS=$(($INIT_DURATION / 3600))
INIT_MINUTES=$(($INIT_DURATION % 3600 / 60))
INIT_SECONDS=$(($INIT_DURATION % 60))
printf "\nTotal elapsed time: %d:%02d:%02d\n" $INIT_HOURS $INIT_MINUTES $INIT_SECONDS