#!/bin/bash
echo "Site test"
while true;
do
    # NEED TO TEST for 200???
    result=$(curl -Is http://localhost/largewar | head -n 1)
    if [ "$result" == "" ]
    then
        echo "Site not up"
        sleep 1
    else
        break
    fi
done
echo "Site ready"
