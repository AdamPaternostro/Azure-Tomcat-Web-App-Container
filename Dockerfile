FROM ubuntu

# Run as admin
USER root

########################################
# Update Ubuntu, install Curl and install Apache
########################################
RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get install -y curl 
RUN apt-get install -y apache2

# Make a known working directory for downloads
RUN mkdir /usr/local/downloadtemp

########################################
# Install Java
########################################
COPY jdk-9.0.4_linux-x64_bin.tar.gz /usr/local/downloadtemp/jdk-9.0.4.tar.gz
RUN tar xvzf /usr/local/downloadtemp/jdk-9.0.4.tar.gz -C /usr/local
RUN rm /usr/local/downloadtemp/jdk-9.0.4.tar.gz

# Set Java environment variablees
ENV JAVA_HOME /usr/local/jdk-9.0.4
ENV PATH ${PATH}:${JAVA_HOME}/bin

########################################
# Install and Configure Tomcat 
########################################
COPY apache-tomcat-9.0.4.tar.gz /usr/local/downloadtemp/apache-tomcat-9.0.4.tar.gz
RUN tar xvzf /usr/local/downloadtemp/apache-tomcat-9.0.4.tar.gz -C /usr/local
RUN rm /usr/local/downloadtemp/apache-tomcat-9.0.4.tar.gz

# Set Tomcat variables
ENV CATALINA_HOME=/usr/local/apache-tomcat-9.0.4
ADD tomcat-users.xml /usr/local/apache-tomcat-9.0.4/conf/

########################################
# Configure Apache
########################################
# Apache: Environment Variables
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data

RUN mkdir /usr/local/apache
RUN mkdir /usr/local/apache/pid
ENV APACHE_PID_FILE /usr/local/apache/pid/pid$SUFFIX.pid

RUN mkdir /usr/local/apache/run
ENV APACHE_RUN_DIR /var/run

RUN mkdir /usr/local/apache/lock
ENV APACHE_LOCK_DIR /var/lock

RUN mkdir /usr/local/apache/log
ENV APACHE_LOG_DIR /usr/local/apache/log

# Apache: Reverse Proxy
RUN a2enmod proxy
RUN a2enmod proxy_http
RUN a2enmod proxy_ajp
RUN a2enmod rewrite
RUN a2enmod deflate
RUN a2enmod headers
RUN a2enmod proxy_balancer
RUN a2enmod proxy_connect
RUN a2enmod proxy_html
RUN a2dissite 000-default
COPY proxy-host.conf /etc/apache2/sites-available/proxy-host.conf
RUN a2ensite proxy-host

# Apache: Expose port
EXPOSE 80

########################################
# Copy start up script and Deploy your custom application (WAR file)
########################################
RUN mkdir /usr/local/custom-app
COPY start-server.sh /usr/local/custom-app/start-server.sh 
RUN chmod +x /usr/local/custom-app/start-server.sh 

# Deploy custom application http://localhost:8080/sample which gets reversed proxyed to http://localhost/sample
COPY sample.war /usr/local/apache-tomcat-9.0.4/webapps/sample.war


########################################
# Entry point of container (startup script that starts tomcat, checks site, then starts apache)
########################################
ENTRYPOINT ["/usr/local/custom-app/start-server.sh"]


########################################
# Notes
########################################
# Build this file:                       docker build -t apachetomcatazure .
# Start container (locally):             docker run -p 80:80 apachetomcatazure

# To upload:                             docker login
# Tag:                                   docker tag apachetomcatazure adampaternostro/apachetomcatazure:v1
# Push:                                  docker push adampaternostro/apachetomcatazure:v1
# Start container (prod):                docker run -p 80:80 adampaternostro/apachetomcatazure:v1

# Deploy to Azure
# az group create --name AdamLinuxGroup --location "East US"
# az appservice plan create --name AdamAppServicePlan --resource-group AdamLinuxGroup --sku S1 --is-linux
# az webapp create --resource-group AdamLinuxGroup --plan AdamAppServicePlan --name AdamLinuxWebApp --deployment-container-image-name adampaternostro/apachetomcatazure:v1
# az webapp config appsettings set --resource-group AdamLinuxGroup --name AdamLinuxWebApp --settings WEBSITES_PORT=80
#


# To debug the container (commment out the ENTRYPOINT and run any of the below)
# Start container (debug):               docker run -it apachetomcatazure 
# Run Tomcat in foreground:              docker run -p 8080:8080 apachetomcatazure ./usr/local/apache-tomcat-9.0.4/bin/catalina.sh run
# Run Apahe in forground:                docker run -p 80:80 apachetomcatazure ./usr/sbin/apache2ctl -D FOREGROUND
# Start Tomcat (manually):               /usr/local/apache-tomcat-9.0.4/bin/startup.sh start
# Start Apache (background):             /usr/sbin/apache2 -k start
# Start Apache (foreground):             /usr/sbin/apache2 -k start -DFOREGROUND

# Docker Clean-up
# Stop all running containers:           docker stop $(docker ps -aq)
# Remove all containers:                 docker rm $(docker ps -aq)
# Delete all images:                     docker rmi $(docker images -q)

# NOTES:
# You could install curl and download each item.  This takes time and slows down your Docker debug process.
# To use curl replace the COPY command with below download commands
# RUN curl -o -O /usr/local/downloadtemp/apache-tomcat-9.0.4.tar.gz http://mirrors.advancedhosters.com/apache/tomcat/tomcat-9/v9.0.4/bin/apache-tomcat-9.0.4.tar.gz
# RUN curl -o -O /usr/local/downloadtemp/jdk-9.0.4.tar.gz http://download.oracle.com/otn-pub/java/jdk/9.0.4+11/c2514751926b4512b076cc82f959763f/jdk-9.0.4_linux-x64_bin.tar.gz

# Unzip / rezip WAR
# jar -xvf sample.war
# jar -cvf slowapp.war slowapp

# Want to use another distribution of Linux
# Create an Azure VM (e.g. CentOS).  Run the commands 1 by 1 in the VM and see if they work (adjust as necessary, use yum instead of apt-get)
# Check the paths of everything
# Once the get the VM working, update this Dockerfile with your steps

# Also, slimming down this container would be a good thing.
# I tried Alpine, but ran into just lots of small issues with Java and such (will try again)