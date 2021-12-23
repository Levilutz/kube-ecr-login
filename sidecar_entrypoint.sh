#!/bin/sh

set -e

echo "Starting proxy in background"
kubectl proxy --port 8080 &

echo "Starting kill listener"
nc -l -p 54345 -e "/empty.sh"

echo "Killing the proxy"
pid=`ps aux | grep "kubectl proxy" | grep -v grep | awk '{ print $1 }'`
kill $pid

echo "Exiting"
exit 0
