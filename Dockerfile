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
# You want this near the end of the Dockerfile so we do not have to rebuild the other layers
COPY sample.war /usr/local/apache-tomcat-9.0.4/webapps/sample.war


########################################
# Entry point of container (startup script that starts tomcat, checks site, then starts apache)
########################################
ENTRYPOINT ["/usr/local/custom-app/start-server.sh"]