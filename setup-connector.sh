#!/usr/bin/env bash

# Installs Banyan Satellite Connector as a systemd service.

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

# Prepare to install dependencies
function install_deps_prepare {
  # try to locate yum, fall back to apt-get
  if [[ $(command -v yum) ]]; then
    sudo yum clean metadata
    check_error "sudo yum clean metadata"
  else
    sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update
    check_error "sudo apt-get update"
  fi
}

# Install dependencies, exit on any error
function install_deps {
  local deps=("${@}")

  # try to locate yum, fall back to apt-get
  if [[ $(command -v yum) ]]; then
    sudo yum -y -q install "${deps[@]}"
    check_error "sudo yum install ${deps[*]}"
  else
    sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 -y install "${deps[@]}"
    check_error "sudo apt-get install ${deps[*]}"
  fi
}

# Install dependencies, do NOT exit on error
function install_deps_without_exit {
  local deps=("${@}")

  if [[ $(command -v yum) ]]; then
    sudo yum -y -q install "${deps[@]}"
  else
    sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 -y install "${deps[@]}"
  fi
}

# Uninstall, do NOT exit on error
function uninstall_deps_without_exit {
  local deps=("${@}")

  if [[ $(command -v yum) ]]; then
    sudo yum -y -q remove "${deps[@]}"
  else
    sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 -y remove "${deps[@]}"
  fi
}

function check_error {
	local err=$?
	if [[ ${err} -ne 0 ]]; then
		echo "$1 Error: ${err}"
		exit 1
	fi
}

function yaml_value {
	awk "/$1/"'{n=split($0,a,":"); if (n<=2) {print a[n]} else {joined=a[2]; for (i=3; i<=n; i++) {joined = joined ":" a[i]}; print joined}}' ${config_file}| sed -e 's/"//g' | sed -e "s/'//g"
}

# validate config values
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

sudo userdel -rf banyan-example-user 2> /dev/null
sudo useradd -m -s /usr/bin/rbash banyan-example-user 2> /dev/null
check_error "sudo useradd -m -s  /usr/bin/rbash banyan-example-user"

# install dependencies
if [[ ${INSTALL_DEPS} == "true" ]]; then
	install_deps_prepare
	install_deps iptables

	# remove unbound which was needed by connector v1.2.0
	uninstall_deps_without_exit unbound

	install_deps_without_exit wireguard
fi

sudo systemctl stop connector

# Copy executable
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
sudo install -m 0700 -C -t /opt/banyan ${DIRBIN}/connector

# Install configuration
sudo install -m 0600 -C -t /opt/banyan "${config_file}"
rm "${config_file}"

sudo install -m 0644 "${DIRETC}/connector.service.tpl" /lib/systemd/system/connector.service
check_error "install -m 0644 ${DIRETC}/connector.service.tpl /lib/systemd/system/connector.service"
sudo systemctl enable connector
sudo systemctl daemon-reload

sudo systemctl stop connector
sudo systemctl start connector
sudo systemctl status connector
