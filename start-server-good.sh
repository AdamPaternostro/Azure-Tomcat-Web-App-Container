#!/bin/bash

# Start Tomcat
/usr/local/apache-tomcat-9.0.4/bin/startup.sh start

# Pretent Tomcat is warming up
sleep 3m

# Start Apache (foreground so the process does not end)
/usr/sbin/apache2 -k start -DFOREGROUND
