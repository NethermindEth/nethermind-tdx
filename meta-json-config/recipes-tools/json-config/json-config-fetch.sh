#!/bin/sh
### BEGIN INIT INFO
# Provides:          json-config-fetch
# Required-Start:    $network
# Required-Stop:     
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Fetch configuration JSON file
# Description:       Fetch configuration JSON file and set up environment variables
### END INIT INFO

set -e

# Source the configuration file
source /etc/json-config.conf

case "$1" in
  start)
    echo "Fetching configuration..."
    if curl -H Metadata:true "${CONFIG_URL}" | base64 --decode > /etc/json_config.json; then
      echo "Configuration fetched successfully."
      # Parse the config and write to a file
      /usr/bin/json_config_parse.sh /etc/json_config.json "${ALLOWED_KEYS}" > /etc/json-config
      # Make the file readable only by root
      chmod 600 /etc/json-config
      # Source the file to set variables for this session
      source /etc/json-config
    else
      echo "Failed to fetch configuration."
    fi
    ;;
  stop)
    echo "Nothing to stop."
    ;;
  restart|reload)
    $0 stop
    $0 start
    ;;
  status)
    if [ -f /etc/json_config.json ]; then
      echo "Configuration file exists."
    else
      echo "Configuration file does not exist."
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac

exit 0