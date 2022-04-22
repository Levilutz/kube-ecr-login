#!/usr/bin/env sh

set -e

echo "Searching for service"
for i in `seq 1 60`
do
    tmp=0
    lsof -i:8080 || tmp=$?
    if [ $tmp -eq 0 ]
    then
        echo "Service published on :8080"
        exit 0
    else
        echo "No service found yet, $i seconds elapsed"
    fi
    sleep 1
done

echo "Failed to find service in 60 seconds"
exit 1
