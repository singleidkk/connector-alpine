#!/bin/bash

function remove_opt_banyan {
  rm -rf /opt/banyan
}

# Remove /opt/banyan dir when this script exits
trap remove_opt_banyan EXIT

sudo rc-service connector stop

sudo rc-update del connector

sudo rm -f /etc/init.d/connector