# Azure-Tomcat-Web-App-Container
Creates a Docker container with Tomcat installed behind Apache which acts as a reverse proxy so Tomcat can be warmed up before being added to the Azure load balancer.  Solves the problems of web apps needing time to warm-up as well as locking of WAR files that can occur on Azure Window Web Apps.

### Downloads
1. Download this repository
2. Download http://mirrors.advancedhosters.com/apache/tomcat/tomcat-9/v9.0.4/bin/apache-tomcat-9.0.4.tar.gz
3. Download http://download.oracle.com/otn-pub/java/jdk/9.0.4+11/c2514751926b4512b076cc82f959763f/jdk-9.0.4_linux-x64_bin.tar.gz

### To build the Docker image
Replace adampaternostro with your public repo
1. Replace your the WAR (sample.war) with your own and update the Dockerfile
```
COPY sample.war /usr/local/apache-tomcat-9.0.4/webapps/sample.war
```
2. Change the password in the tomcat-users.xml
3. Run these in your directory
```
docker build -t apachetomcatazure .
docker login
docker tag apachetomcatazure adampaternostro/apachetomcatazure:v1
docker push adampaternostro/apachetomcatazure:v1
```
You need to deploy either the good or bad image to Azure
https://hub.docker.com/r/adampaternostro/apachetomcatazure/tags/

### Deploy to Azure
Run this in the Azure portal (create a Bash prompt). Replace "Adam" with your name.
```
az group create --name AdamLinuxGroup --location "East US"
az appservice plan create --name AdamAppServicePlan --resource-group AdamLinuxGroup --sku S1 --is-linux
az webapp create --resource-group AdamLinuxGroup --plan AdamAppServicePlan --name AdamLinuxWebApp --deployment-container-image-name adampaternostro/apachetomcatazure:{good OR bad}
az webapp config appsettings set --resource-group AdamLinuxGroup --name AdamLinuxWebApp --settings WEBSITES_PORT=80
```

## Current Notes
1. I'm working on the script to test if the website is up
2. I need to implement SSH (see: https://docs.microsoft.com/en-us/azure/app-service/containers/tutorial-custom-docker-image)
3. Changing to a private Azure Container Registry
4. I need to load test this
5. I need to change the WAR file so it sleeps for a long time (basically takes a long time to start up)
6. It would be nice to reduce this image size
