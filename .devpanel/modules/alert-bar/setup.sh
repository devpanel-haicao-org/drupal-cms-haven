#!/usr/bin/env bash

# PATH of module
export MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT_DIR="$(cd "$MODULE_DIR/../../../" && pwd)"

echo "Configuring DevPanel Alert Bar (Module)..."

# 1. Fetch Dynamic Data from DrupalForge Proxy.
CURRENT_APP_ID="${DP_APP_ID:-}"
if [ -z "$CURRENT_APP_ID" ]; then
    echo "Not Yet DP_APP_ID."
    export RAW_API_JSON=""
    export BASE_PLATFORM_URL=""
    export BUY_LINK_URL="https://www.devpanel.com/pricing/"
else
    # Get Hostname automatic.
    if [ -n "${DP_HOSTNAME:-}" ]; then
        CURRENT_ENV=$(echo "$DP_HOSTNAME" | cut -d'-' -f1)
    else
        CURRENT_ENV="dev"
    fi

    case "$CURRENT_ENV" in
        "local" | "docksal") BASE_PROXY_URL="https://drupal-forge.docksal.site:8444" ;;
        "dev") BASE_PROXY_URL="https://dev.drupalforge.org" ;;
        "stage" | "staging") BASE_PROXY_URL="https://stage.drupalforge.org" ;;
        "prod" | "production" | "www") BASE_PROXY_URL="https://www.drupalforge.org" ;;
        *) BASE_PROXY_URL="https://dev.drupalforge.org" ;;
    esac

    DRUPALFORGE_PROXY="${BASE_PROXY_URL}/api/internal/alert-app-info?app_id=${CURRENT_APP_ID}"
    
    # Get JSON data from API.
    export BASE_PLATFORM_URL="${BASE_PROXY_URL}/app/purchase/"
    export RAW_API_JSON=$(curl -s -f -X GET "$DRUPALFORGE_PROXY" \
      -H "X-DrupalForge-Auth: DF-Alert-v1-8x92nd81bs" || true)
    export BUY_LINK_URL="${BASE_PROXY_URL}/app/purchase/${CURRENT_APP_ID}"
fi

# 2. Generate data.json
php -r '
    $raw_json = getenv("RAW_API_JSON");
    $buy_link = getenv("BASE_PLATFORM_URL");
    $module_dir = getenv("MODULE_DIR");
    
    $api_data = json_decode($raw_json, true) ?:[];
    
    $submissionId = $api_data["submissionId"] ?? "submissionId";
    $templateId = $api_data["templateId"] ?? "templateId";
    $showBuyNow = isset($api_data["showBuyNow"]) ? (bool) $api_data["showBuyNow"] : false;

    $safe_data =[
        "appName" => $api_data["appName"] ?? "My Application",
        "subId" => $submissionId,
        "email" => $api_data["email"] ?? "",
        "buyLink" => $buy_link . $submissionId . "/" . $templateId,
        "showBuyNow" => $showBuyNow
    ];
    
    $json_output = json_encode($safe_data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    file_put_contents($module_dir . "/data.json", $json_output);
'

echo "Generate JSON Data successful."

# ==============================================================================
# 3. Include alert-bar.php to index.php file (DYNAMIC PATH COMPUTATION)
# ==============================================================================
# Get WEB_ROOT
CURRENT_WEB_ROOT="${WEB_ROOT:-$APP_ROOT_DIR/web}"
INDEX_FILE="$CURRENT_WEB_ROOT/index.php"

if [ -f "$INDEX_FILE" ]; then
  if ! grep -q "alert-bar.php" "$INDEX_FILE"; then
    
    # Relative path from WEB_ROOT to MODULE_DIR
    REL_PATH=$(realpath --relative-to="$CURRENT_WEB_ROOT" "$MODULE_DIR" 2>/dev/null || echo "")
    
    if [ -n "$REL_PATH" ]; then
        INCLUDE_CODE="include_once __DIR__ . '/${REL_PATH}/alert-bar.php';"
    else
        # Fallback absolute path if the system not yet realpath
        INCLUDE_CODE="include_once '${MODULE_DIR}/alert-bar.php';"
    fi

    # Include alert-bar.php to index.php
    sed -i "s|<?php|<?php\n${INCLUDE_CODE}\n|g" "$INDEX_FILE"
    echo "Included Alert Bar to index.php (Path: $INCLUDE_CODE)"
  else
    echo "Alert bar already existed."
  fi
else
  echo "Can not find index.php file in $INDEX_FILE"
fi