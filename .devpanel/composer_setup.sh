#!/usr/bin/env bash

set -eu -o pipefail
cd $APP_ROOT

# Create required composer.json and composer.lock files.
composer create-project --no-install ${PROJECT:=drupal/cms}
cp -r "${PROJECT#*/}"/* ./
rm -rf "${PROJECT#*/}" AGENTS.md patches.lock.json

# Programmatically fix Composer 2.2 allow-plugins to avoid errors.
composer config --no-plugins allow-plugins.cweagans/composer-patches true
# Scaffold settings.php.
composer config -jm extra.drupal-scaffold.file-mapping '{
    "[web-root]/sites/default/settings.php": {
        "path": "web/core/assets/scaffold/files/default.settings.php",
        "overwrite": false
    }
}'
composer config scripts.post-drupal-scaffold-cmd \
    'cd web/sites/default && test -z "$(grep '\''include \$devpanel_settings;'\'' settings.php)" && patch -Np1 -r /dev/null < $APP_ROOT/.devpanel/drupal-settings.patch || :'

# Add Drush.
composer require -n --no-update drush/drush

# Add DevPanel Marketplace Bar module and Haven theme.
composer config repositories.devpanel_marketplace_bar vcs "git@github.com:devpanel-haicao/devpanel_marketplace_bar.git"
composer require -n --no-update \
    devpanel/devpanel_marketplace_bar:dev-main \
    drupal/haven
