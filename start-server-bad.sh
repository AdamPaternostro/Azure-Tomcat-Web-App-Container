#!/bin/bash

# Start Apache (background)
/usr/sbin/apache2 -k start

# Pretend Tomcat is warming up
# Apache is started (port 80) so Azure thinks we are ready for web traffic
sleep 3m

# Start Tomcat
/usr/local/apache-tomcat-9.0.4/bin/catalina.sh run