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

### Deploy to Azure
Run this in the Azure portal (create a Bash prompt). Replace "Adam" with your name.
You need to deploy either the good or bad image to Azure.  
There are 3 images:
1. latest -> this is what you would do in production
2. good -> this tests to ensure that the web node is not added to the Azure load balancer until Apache starts
3. bad -> this simulates the problem I am trying to solve.  Tomcat not ready for action, but added to the load balancer.
https://hub.docker.com/r/adampaternostro/apachetomcatazure/tags/
```
az group create --name AdamLinuxGroup --location "East US"
az appservice plan create --name AdamAppServicePlan --resource-group AdamLinuxGroup --sku S1 --is-linux
az webapp create --resource-group AdamLinuxGroup --plan AdamAppServicePlan --name AdamLinuxWebApp --deployment-container-image-name adampaternostro/apachetomcatazure:{good OR bad}
az webapp config appsettings set --resource-group AdamLinuxGroup --name AdamLinuxWebApp --settings WEBSITES_PORT=80
```

## Notes
1. I need to implement SSH (see: https://docs.microsoft.com/en-us/azure/app-service/containers/tutorial-custom-docker-image)
2. Changing to a private Azure Container Registry
3. It would be nice to reduce this image size (you can reduce the layer by getting rid of a lot of the RUN command and combining with the & character.  I like my code explicit when developing and then condense what makes sense and keeps it readable.

This project is based upon a discussion I had with a colleague who had similar issues. He deserves credit and hit github can be found here: https://github.com/jamarsto/MyWildfly.  I wanted to do this for Tomcat since my customers use this app server and I also wanted to do the load testing of the site.

## If you are using IIS
If you are using a Windows Web App and need to warm up your website (.NET, Java, etc.) see this: https://docs.microsoft.com/en-us/azure/app-service/web-sites-staged-publishing#custom-warm-up-before-swap

If you are using Tomcat and the WAR file unzipping process is locking your application then you need to use this reverse proxy approach.  This approach really shoudl be used for any Docker web app deployment.
