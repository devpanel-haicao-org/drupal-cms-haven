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

# =================================================================
# 1. THÊM MỚI: Cấp quyền cho thư mục gốc (Chạy ngay từ đầu)
# Giúp Web Server và Composer có quyền tạo file/thư mục thoải mái
# =================================================================
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

# =================================================================
# 2. THAY ĐỔI: Create & chmod the private files directory.
# Gom lệnh mkdir và chmod của bạn vào chung một khối logic
# =================================================================
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

# =================================================================
# 3. THÊM MỚI: Chuẩn bị quyền files và settings.php TRƯỚC KHI cài đặt
# =================================================================
echo
echo 'Set permissions for Drupal installation (files, settings, assets).'

# A. Đảm bảo thư mục files tồn tại rồi mới chmod 777
if [ ! -d web/sites/default/files ]; then
  time mkdir -p web/sites/default/files
fi
time sudo chmod -R 777 web/sites/default/files/

# B. Đảm bảo settings.php tồn tại (copy từ file default) rồi mới chmod 666
if [ ! -f web/sites/default/settings.php ] && [ -f web/sites/default/default.settings.php ]; then
  time cp web/sites/default/default.settings.php web/sites/default/settings.php
fi
if [ -f web/sites/default/settings.php ]; then
  time sudo chmod 666 web/sites/default/settings.php
fi

# C. (Bonus) Cấp quyền cho thư mục assets của Drupal CMS Starshot để tránh lỗi cũ
if [ -d assets ]; then
  time sudo chmod -R 777 assets/
fi
# =================================================================

#== Install Drupal.
echo
if [ -z "$(drush status --field=db-status)" ]; then
  echo 'Install Drupal base system.'
  time drush -n si minimal

  # Get the contrib recipes path using the custom drush command.
  CONTRIB_RECIPES_PATH=$(drush crp)
  echo "Contrib recipes path: $CONTRIB_RECIPES_PATH"

  echo
  echo 'Apply Drupal CMS Starter recipe.'
  if [ -d "$CONTRIB_RECIPES_PATH/drupal_cms_starter" ]; then
    time php web/core/scripts/drupal recipe "$CONTRIB_RECIPES_PATH/drupal_cms_starter"
  else
    echo "Warning: drupal_cms_starter recipe not found at $CONTRIB_RECIPES_PATH/drupal_cms_starter"
  fi

  echo
  echo 'Apply Haven recipe (theme + demo content).'
  if [ -d "$CONTRIB_RECIPES_PATH/haven" ]; then
    time php web/core/scripts/drupal recipe "$CONTRIB_RECIPES_PATH/haven"
  else
    echo "Warning: haven recipe not found at $CONTRIB_RECIPES_PATH/haven"
  fi

  drush -n cset system.site name 'Drupal CMS Haven'

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
