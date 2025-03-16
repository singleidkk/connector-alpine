#!/sbin/openrc-run
# /etc/init.d/connector
# Banyan Satellite Connector OpenRC init script

description="Banyan Satellite Connector"
command="/opt/banyan/connector"
command_stop="/opt/banyan/connector stop-net"
command_background=true
pidfile="/run/connector.pid"
directory="/opt/banyan"
nice=10

depend() {
    need net
}

start_pre() {
    # Set file descriptor limit equivalent to LimitNOFILE=65536
    ulimit -n 65536
    # Set environment variables
    export BANYAN_DIR="/var/log/banyan"
    export com_banyanops_app="banyan-platform"
    export com_banyanops_servicename="connector"
    export com_banyanops_servicetype="visibility"
}

stop_post() {
    # Add any necessary post-stop processing here
    :
}
