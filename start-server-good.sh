#!/bin/bash

# Start Tomcat
/usr/local/apache-tomcat-9.0.4/bin/startup.sh start

# Test with curl that our site is up and is running (all warmed up)
echo "Site test"
while true;
do
    result=`curl http://localhost/sample -k -s -f -o /dev/null && echo "UP" || echo "DOWN"`
    if [ "$result" = "UP" ]
    then
        break
    else
        echo "Site not up"
        sleep 1
    fi
done
echo "Site ready"


# Start Apache (foreground so the process does not end)
/usr/sbin/apache2 -k start -DFOREGROUND
