#!/usr/bin/env bash

# Installs Banyan Satellite Connector as an OpenRC service on Alpine Linux.

DIR=$( cd "$( dirname "$0" )" && pwd )

DIRBIN=${DIR}/x/bin
DIRETC=${DIR}/x/etc
DIRWWW=${DIR}/x/www
DIRSSH=${DIR}/x/ssh

config_file=${DIR}/connector-config.yaml
log_home=/var/log/banyan

# Install dependencies by default
INSTALL_DEPS=${INSTALL_DEPS:-true}

if [[ $# -ne 0 ]]; then
  echo "Usage: $0"
  exit 1
fi

if [[ ! -f ${config_file} ]]; then
  echo "Error: Missing config file ${config_file}"
  exit 1
fi

# Prepare to install dependencies using apk
function install_deps_prepare {
  sudo apk update || { echo "Error: apk update failed"; exit 1; }
}

# Install dependencies, exit on any error
function install_deps {
  local deps=("${@}")
  sudo apk add --no-cache "${deps[@]}" || { echo "Error: Failed to install ${deps[*]}"; exit 1; }
}

# Install dependencies, do NOT exit on error
function install_deps_without_exit {
  local deps=("${@}")
  sudo apk add --no-cache "${deps[@]}"
}

# Uninstall dependencies, do NOT exit on error
function uninstall_deps_without_exit {
  local deps=("${@}")
  sudo apk del "${deps[@]}"
}

function check_error {
  local err=$?
  if [[ ${err} -ne 0 ]]; then
    echo "$1 Error: ${err}"
    exit 1
  fi
}

function yaml_value {
  awk "/$1/"'{n=split($0,a,":"); if (n<=2) {print a[n]} else {joined=a[2]; for (i=3; i<=n; i++) {joined = joined ":" a[i]}; print joined}}' ${config_file} | sed -e 's/"//g' | sed -e "s/'//g"
}

# Validate config values
api_key_secret=$(yaml_value api_key_secret)
if [[ -z ${api_key_secret} ]]; then
  echo "Error: api key secret not defined in ${config_file}"
  exit 1
fi

sudo install -d -m 0755 /opt/banyan
check_error "install -d -m 0755 /opt/banyan"

sudo install -d -m 0755 ${log_home}
check_error "install -d -m 0755 ${log_home}"

echo "Logs will be stored in ${log_home}/connector.log"

# Remove existing user if any, then add user for the connector.
sudo deluser --remove-home banyan-example-user 2> /dev/null
sudo adduser -D -s /bin/ash banyan-example-user 2> /dev/null
check_error "sudo adduser -D -s /bin/ash banyan-example-user"

# Install dependencies if enabled
if [[ ${INSTALL_DEPS} == "true" ]]; then
  install_deps_prepare
  install_deps iptables

  # Remove unbound which was needed by connector v1.2.0
  uninstall_deps_without_exit unbound

  # In Alpine, the WireGuard tools are usually provided as the wireguard-tools package
  install_deps_without_exit wireguard-tools
fi

# Stop any running connector service (ignore error if not running)
sudo rc-service connector stop 2>/dev/null

# Copy appropriate executable based on architecture
ARCH=$(uname -m)
case "${ARCH}" in
  arm64|aarch64)
    cp ${DIRBIN}/connector:arm64 ${DIRBIN}/connector
    ;;
  arm*)
    cp ${DIRBIN}/connector:arm ${DIRBIN}/connector
    ;;
  *)
    cp ${DIRBIN}/connector:amd64 ${DIRBIN}/connector
    ;;
esac

# Install executable
sudo install -m 0700 -t /opt/banyan ${DIRBIN}/connector

# Install configuration file and remove original
sudo install -m 0600 -t /opt/banyan "${config_file}"
rm "${config_file}"

# Install OpenRC service script
# The connector.openrc.tpl is the template file for the OpenRC service script, edit as needed.
sudo install -m 0755 "${DIRETC}/connector.openrc.tpl" /etc/init.d/connector
check_error "install -m 0755 ${DIRETC}/connector.openrc.tpl /etc/init.d/connector"

# Add service to default runlevel
sudo rc-update add connector default

# Restart connector service
sudo rc-service connector stop 2>/dev/null
sudo rc-service connector start
sudo rc-service connector status
