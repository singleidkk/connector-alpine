#!/bin/bash
set -euo pipefail

# Usage: ./test-connection.sh [OPTIONS]
#
# This script checks TCP connections to a specified domain and port.
#
# Options:
#   -d, --domain            Domain to test connections to (default: net.banyanops.com)
#   -t, --tcp-port          TCP port to test (default: 443)
#
# Example:
#   ./test-connection.sh --domain "net.banyanops.com" --tcp-port 443
#

# Defaults
domain="net.banyanops.com"
tcp_port=443
OS_TYPE=$(uname)

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d|--domain) domain="$2"; shift ;;
        -t|--tcp-port) tcp_port="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Function to log messages to the console
log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp - $message"
}

# Test TCP connection Function
test_tcp_connection() {
    local domain="$1"
    local port="$2"

    local success_message="TCP connection to $domain on port $port succeeded."
    local failure_message="TCP connection to $domain on port $port failed."

    if [ "$OS_TYPE" == "Darwin" ]; then
        # macOS: use nc command which is available by default on mac
        if nc -zv -w 3 "$domain" "$port" 2>&1 | grep -q succeeded; then
            log_message "$success_message"
        else
            log_message "$failure_message"
            exit 1
        fi
    else
        # Linux: use /dev/ttcp which is special file to test tcp connections, available from bash4.0 onwards
        if {
            timeout 2 bash -c "echo > /dev/tcp/$domain/$port" >/dev/null 2>&1
        }; then
            log_message "$success_message"
        else
            log_message "$failure_message"
            exit 1
        fi
    fi
}

test_tcp_connection "$domain" "$tcp_port"

completion_message="Check completed."
log_message "$completion_message"
