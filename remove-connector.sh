#!/bin/bash

function remove_opt_banyan {
  rm -rf /opt/banyan
}

# Remove /opt/banyan dir when this script exits
trap remove_opt_banyan EXIT

systemctl stop connector
systemctl disable connector
rm -f /lib/systemd/system/connector.service
systemctl daemon-reload
