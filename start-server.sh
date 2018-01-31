#!/bin/bash

# Start Tomcat
/usr/local/apache-tomcat-9.0.4/bin/startup.sh start

# Test with curl that our site is up and is running (all warmed up)


# Start Apache (foreground so the process does not end)
/usr/sbin/apache2 -k start -DFOREGROUND
