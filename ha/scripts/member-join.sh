#!/usr/bin/env bash

echo "Member join script triggered" >> /var/log/serf.log

BACKEND_REGISTERED=false

# We iterate over stdin
while read -a values; do
  # We extract the hostname, the ip, the role of each line and the tags
  HOSTNAME=${values[0]}
  HOSTIP=${values[1]}
  HOSTROLE=${values[2]}
  HOSTTAGS=${values[3]}

  # We only register the backend nodes
  if [[ "$HOSTROLE" == "backend" ]]; then
    echo "Member join event received from: $HOSTNAME with role $HOSTROLE" >> /var/log/serf.log

    # We simply register the backend IP and hostname in a file in /nodes
    # with the hostname for the file name
    echo "$HOSTNAME $HOSTIP" > /nodes/$HOSTNAME

    # We have at least one new node registered
    BACKEND_REGISTERED=true
  fi
done

# We only update the HAProxy configuration if we have at least one new  backend node
if [[ "$BACKEND_REGISTERED" = true ]]; then
  # To build the collection of nodes
  HOSTS=""

  # We iterate over each backend node registered
  for hostfile in $(ls /nodes); do
    # We convert the content of the backend node file to a JSON format: { "host": "<hostname>", "ip": "<ip address>" }
    CURRENT_HOST=`cat /nodes/$hostfile | awk '{ print "{\"host\":\"" $1 "\",\"ip\":\"" $2 "\"}" }'`

    # We concatenate each host
    HOSTS="$HOSTS$CURRENT_HOST,"
  done

  # We process the template with handlebars. The sed command will simply remove the
  # trailing comma from the hosts list.
  handlebars --addresses "[$(echo $HOSTS | sed s/,$//)]" < /config/haproxy.cfg.hb > /usr/local/etc/haproxy/haproxy.cfg

  # TODO: [CFG] Add the command to restart HAProxy
  s6-svc -h /var/run/s6/services/ha
fi
