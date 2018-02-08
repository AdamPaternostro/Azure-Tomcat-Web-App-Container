#!/bin/bash

# Start Apache (background)
/usr/sbin/apache2 -k start

# Pretent Tomcat is warming up
sleep 3m

# Start Tomcat
/usr/local/apache-tomcat-9.0.4/bin/catalina.sh run