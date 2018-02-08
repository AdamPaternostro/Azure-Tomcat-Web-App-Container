#!/bin/bash

# Start Apache (background)
/usr/sbin/apache2 -k start

# This is to test a BAD startup (meaning Tomcat not ready for traffic)
# Emulate a long start up time of a Java App
# Since Apache is started we should get added to the load balancer in Azure
# Tomcat will not start for 5 minutes, so we should get failures
sleep 5m

# Start Tomcat
/usr/local/apache-tomcat-9.0.4/bin/catalina.sh run