#!/usr/bin/env bash
# Provision Bedrock Project

set -eo pipefail

echo " * Roots Bedrock template provisioner ${VVV_SITE_NAME} - downloads and installs a copy of WP stable for testing, building client sites, etc"

# fetch the first host as the primary domain. If none is available, generate a default using the site name
DB_NAME=$(get_config_value 'db_name' "${VVV_SITE_NAME}")
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*]/}
DB_PREFIX=$(get_config_value 'db_prefix' 'wp_')
DOMAIN=$(get_primary_host "${VVV_SITE_NAME}".test)
BEDROCK_DIR=$(get_config_value 'bedrock_dir' 'htdocs')
BEDROCK_DIR_PATH="${VVV_PATH_TO_SITE}/${BEDROCK_DIR}"
PUBLIC_DIR="${BEDROCK_DIR}/web"
PUBLIC_DIR_PATH="${BEDROCK_DIR_PATH}/web"
BEDROCK_VERSION=$(get_config_value 'bedrock_version' '*')

# Make a database, if we don't already have one
setup_database() {
  echo -e " * Creating database '${DB_NAME}' (if it's not already there)"
  mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`"
  echo -e " * Granting the wp user privileges to the '${DB_NAME}' database"
  mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO wp@localhost IDENTIFIED BY 'wp';"
  echo -e " * DB operations done."
}

setup_nginx_folders() {
  echo " * Setting up the log subfolder for Nginx logs"
  noroot mkdir -p "${VVV_PATH_TO_SITE}/log"
  noroot touch "${VVV_PATH_TO_SITE}/log/nginx-error.log"
  noroot touch "${VVV_PATH_TO_SITE}/log/nginx-access.log"
}

copy_nginx_configs() {
  echo " * Copying the sites Nginx config template"
  if [ -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx-custom.conf" ]; then
    echo " * A vvv-nginx-custom.conf file was found"
    noroot cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx-custom.conf" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
  else
    echo " * Using the default vvv-nginx-default.conf, to customize, create a vvv-nginx-custom.conf"
    noroot cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx-default.conf" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
  fi

  echo " * Applying public dir setting to Nginx config"
  noroot sed -i "s#{vvv_public_dir}#/${PUBLIC_DIR}#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"

  LIVE_URL=$(get_config_value 'live_url' '')
  if [ ! -z "$LIVE_URL" ]; then
    echo " * Adding support for Live URL redirects to NGINX of the website's media"
    # replace potential protocols, and remove trailing slashes
    LIVE_URL=$(echo "${LIVE_URL}" | sed 's|https://||' | sed 's|http://||'  | sed 's:/*$::')

    redirect_config=$((cat <<END_HEREDOC
if (!-e \$request_filename) {
  rewrite ^/[_0-9a-zA-Z-]+(/app/uploads/.*) \$1;
}
if (!-e \$request_filename) {
  rewrite ^/app/uploads/(.*)\$ \$scheme://${LIVE_URL}/app/uploads/\$1 redirect;
}
END_HEREDOC
    ) |
    # pipe and escape new lines of the HEREDOC for usage in sed
    sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n\\1/g'
    )
    noroot sed -i -e "s|\(.*\){{LIVE_URL}}|\1${redirect_config}|" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
  else
    noroot sed -i "s#{{LIVE_URL}}##" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
  fi
}

setup_env_file() {
  echo " * Setting up .env"
  noroot sed -i "s#database_name#${DB_NAME}#" "${BEDROCK_DIR_PATH}/.env"
  noroot sed -i "s#database_user#wp#" "${BEDROCK_DIR_PATH}/.env"
  noroot sed -i "s#database_password#wp#" "${BEDROCK_DIR_PATH}/.env"
  noroot sed -i "s#http://example.com#https://${DOMAIN}#" "${BEDROCK_DIR_PATH}/.env"
  noroot sed -i "s#\# DB_PREFIX='wp_'#DB_PREFIX='${DB_PREFIX}'#" "${BEDROCK_DIR_PATH}/.env"
}

restore_db_backup() {
  echo " * Found a database backup at ${1}. Restoring the site"
  noroot wp db import "${1}"
  echo " * Installed database backup"
}

install_wp() {
  echo " * Installing WordPress"
  ADMIN_USER=$(get_config_value 'admin_user' "admin")
  ADMIN_PASSWORD=$(get_config_value 'admin_password' "password")
  ADMIN_EMAIL=$(get_config_value 'admin_email' "admin@local.test")
  echo " * Installing using wp core install --url=\"${DOMAIN}\" --title=\"${SITE_TITLE}\" --admin_name=\"${ADMIN_USER}\" --admin_email=\"${ADMIN_EMAIL}\" --admin_password=\"${ADMIN_PASSWORD}\""
  noroot wp core install --url="${DOMAIN}" --title="${SITE_TITLE}" --admin_name="${ADMIN_USER}" --admin_email="${ADMIN_EMAIL}" --admin_password="${ADMIN_PASSWORD}"
  echo " * WordPress was installed, with the username '${ADMIN_USER}', and the password '${ADMIN_PASSWORD}' at '${ADMIN_EMAIL}'"
}

setup_cli() {
  rm -f "${VVV_PATH_TO_SITE}/wp-cli.yml"
  echo "# auto-generated file" > "${VVV_PATH_TO_SITE}/wp-cli.yml"
  echo "path: \"${PUBLIC_DIR}/wp\"" >> "${VVV_PATH_TO_SITE}/wp-cli.yml"
  echo "@vvv:" >> "${VVV_PATH_TO_SITE}/wp-cli.yml"
  echo "  ssh: vagrant" >> "${VVV_PATH_TO_SITE}/wp-cli.yml"
  echo "  path: ${PUBLIC_DIR_PATH}/wp" >> "${VVV_PATH_TO_SITE}/wp-cli.yml"
  echo "@${VVV_SITE_NAME}:" >> "${VVV_PATH_TO_SITE}/wp-cli.yml"
  echo "  ssh: vagrant" >> "${VVV_PATH_TO_SITE}/wp-cli.yml"
  echo "  path: ${PUBLIC_DIR_PATH}/wp" >> "${VVV_PATH_TO_SITE}/wp-cli.yml"
}

cd "${VVV_PATH_TO_SITE}"

setup_cli
setup_database
setup_nginx_folders

if [ ! -d "${BEDROCK_DIR}" ]; then
  echo "Installing Roots Bedrock stack"
  composer create-project "roots/bedrock":"${BEDROCK_VERSION}" "${BEDROCK_DIR}"
fi

setup_env_file

if ! $(noroot wp core is-installed ); then
  echo " * Bedrock is present but WordPress isn't installed to the database, checking for SQL dumps in web/app/database.sql or the main backup folder."
  if [ -f "${PUBLIC_DIR_PATH}/app/database.sql" ]; then
    restore_db_backup "${PUBLIC_DIR_PATH}/app/database.sql"
  elif [ -f "/srv/database/backups/${VVV_SITE_NAME}.sql" ]; then
    restore_db_backup "/srv/database/backups/${VVV_SITE_NAME}.sql"
  else
    install_wp
  fi
fi

copy_nginx_configs

SAGE=$(get_config_value 'sage' '')
if [ ! -z "$SAGE" ]; then
  if [ ! -d "${BEDROCK_DIR}/vendor/roots/acorn" ]; then
    cd "${BEDROCK_DIR}"
    echo " * Installing Roots Acorn - Required by Sage"
    composer require roots/acorn
    cd -
  fi

  if [ "$SAGE" = "True" ] || [ "$SAGE" = true ]; then
    THEME_NAME="core-theme"
  else
    THEME_NAME="${SAGE}"
  fi

  THEME_PATH="${PUBLIC_DIR}/app/themes/${THEME_NAME}"

  if [ ! -d "${THEME_PATH}" ]; then
    echo " * Installing Sage with theme name set to \"${THEME_NAME}\""

    cd "${PUBLIC_DIR}/app/themes/"

    composer create-project roots/sage ${THEME_NAME}
    cd -
  fi

  noroot sed -i "s#http://example.test#https://${DOMAIN}#" "${THEME_PATH}/bud.config.mjs"

  if [ ! -d "${THEME_PATH}/node_modules" ]; then
    cd "${THEME_PATH}"

    echo " * Installing Sage dependencies"
    yarn

    echo " * Compile the theme assets"
    yarn build

    cd -
  fi

  noroot wp theme activate ${THEME_NAME}
fi

echo " * Site Template provisioner script completed for ${VVV_SITE_NAME}"
