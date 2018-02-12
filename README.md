# Azure-Tomcat-Web-App-Container
Creates a Docker container with Tomcat installed behind Apache which acts as a reverse proxy so Tomcat can be warmed up before being added to the Azure load balancer.  Solves the problems of web apps needing time to warm-up as well as locking of WAR files that can occur on Azure Window Web Apps.  This apporach can be used for solving not just Tomcat, but .NET apps, Node.js, etc. so it worth understanding.


### The problem
In Azure you can run Web Sites (Web Apps) on Windows.  The architecture of Web Apps has a shared file system in which your web code is deployed.  This creates a problem when running more than one web server and you deploy a WAR files.  The servers fight over who will get a lock to unzip the WAR file and you get issues. The other issue is that some Tomcat applications take 5+ minutes to warm up.  So you do not want web traffic hitting your site before it is ready to go.  

![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/TomcatOnAzure.png)


### The solution
- Use Azure Web Apps on Linux (this will deploy your custom image)
- Create a a Docker image: 
  - Start Tomcat on port 8080.
  - Tomcat can now unzip your WAR file since each container has its very own WAR file (no locking) .   
  - Inside your Docker image:  Warm up Tomcat on port 8080 by hitting your site within the container
  - Inside your Docker image: Start Apache on port 80 when Tomcat is ready.  Apache is acting as a reverse proxy to Tomcat (some people do not like Tomcat exposed directly anyway for security reasons).
- Azure sees port 80 is ready to go, so Azure adds this instance to the Wep App load balancer. 


### Image Labels
I created 1 Docker image and Labeled it 3 different ways
https://hub.docker.com/r/adampaternostro/apachetomcatazure/tags/
1. latest: This is the code you would use in production.  You need to test and configure this for your needs.
2. good: This simulates a web app that takes 3 minutes to start, but I do not start Apache until after the 3 minutes.  This means we shoud not get any 502 errors.
3. bad: This simulates the problem I am trying to solve.  Tomcat not ready for action, but added to the load balancer.



### To build the Docker image
1. Download this repository
2. Download http://mirrors.advancedhosters.com/apache/tomcat/tomcat-9/v9.0.4/bin/apache-tomcat-9.0.4.tar.gz
3. Download http://download.oracle.com/otn-pub/java/jdk/9.0.4+11/c2514751926b4512b076cc82f959763f/jdk-9.0.4_linux-x64_bin.tar.gz
4. Replace your the WAR (sample.war) with your own and update the Dockerfile
```
COPY sample.war /usr/local/apache-tomcat-9.0.4/webapps/sample.war
```
5. Change the password in the tomcat-users.xml


### To build the good and bad images
1. To build the "good" image replace the "start-server.sh" contents with "start-server-good.sh".  Follow the same steps below, but label this image "good".
2. To build the "bad" image replace the "start-server.sh" contents with "start-server-bad.sh".  Follow the same steps below, but label this image "bad".


### To use Docker Hub with Azure
Run this on your machine (same directory as your downloaded this repo)
```
docker build -t apachetomcatazure .
docker login
docker tag apachetomcatazure adampaternostro/apachetomcatazure:latest
docker push adampaternostro/apachetomcatazure:latest
```
Run this in an Azure Portal Bash prompt.  Replace "Adam" with your name.
```
az group create --name AdamLinuxGroup --location "East US"
az appservice plan create --name AdamAppServicePlan --resource-group AdamLinuxGroup --sku S1 --is-linux
az webapp create --resource-group AdamLinuxGroup --plan AdamAppServicePlan --name AdamLinuxWebApp --deployment-container-image-name adampaternostro/apachetomcatazure:latest
az webapp config appsettings set --resource-group AdamLinuxGroup --name AdamLinuxWebApp --settings WEBSITES_PORT=80
```


### To use Azure Container Registry
Run this in an Azure Portal Bash prompt.  Replace "Adam" with your name.
```
az group create --name AdamLinux --location "East US"
az acr create --name adamlinuxreg --resource-group AdamLinux --sku Basic --admin-enabled true
az acr credential show --name adamlinuxreg
```
Copy the Password that is displayed!
Run this on your machine (same directory as your downloaded this repo)
```
docker login adamlinuxreg.azurecr.io --username adamlinuxreg
docker tag adampaternostro/apachetomcatazure:latest adamlinuxreg.azurecr.io/apachetomcatazure:latest 
docker push adamlinuxreg.azurecr.io/apachetomcatazure:latest 
az acr repository list -n adamlinuxreg
```
Run this in an Azure Bash Prompt
```
az group create --name AdamLinuxGroup --location "East US"
az appservice plan create --name AdamAppServicePlan --resource-group AdamLinuxGroup --sku S1 --is-linux
az webapp create --resource-group AdamLinuxGroup --plan AdamAppServicePlan --name AdamLinuxWebApp --deployment-container-image-name adamlinuxreg.azurecr.io/apachetomcatazure:latest
az webapp config container set --name AdamLinuxWebApp --resource-group AdamLinuxGroup --docker-custom-image-name adamlinuxreg.azurecr.io/apachetomcatazure:latest --docker-registry-server-url https://adamlinuxreg.azurecr.io --docker-registry-server-user adamlinuxreg --docker-registry-server-password <<<<PASSWORD FROM ABOVE>>>>
az webapp config appsettings set --resource-group AdamLinuxGroup --name AdamLinuxWebApp --settings WEBSITES_PORT=80
```


## Notes
1. I need to implement SSH (see: https://docs.microsoft.com/en-us/azure/app-service/containers/tutorial-custom-docker-image)
2. It would be nice to reduce this image size (you can reduce the layer by getting rid of a lot of the RUN command and combining with the & character.  I like my code explicit when developing and then condense what makes sense and keeps it readable.
3. You should put some code in the start-server.sh script to handle interrupts.  Right now when you run the Docker image locally it is hard to kill.  I have to run:
```
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
```

This project is based upon a discussion I had with a colleague who had similar issues. He deserves credit and hit github can be found here: https://github.com/jamarsto/MyWildfly.  I wanted to do this for Tomcat since my customers use this app server and I also wanted to do the load testing of the site.


## If you are using IIS
If you are using a Windows Web App and need to warm up your website (.NET, Java, etc.) see this: https://docs.microsoft.com/en-us/azure/app-service/web-sites-staged-publishing#custom-warm-up-before-swap

If you are using Tomcat and the WAR file unzipping process is locking your application then you need to use this reverse proxy approach.  This approach really should be used for any Docker web app deployment.  I would suspect this issue will occur on-prem and other cloud vendors.


## Load Testing ("Good Docker image")
Results: No 502 Errors!  This is what we wanted.

For both the "good and "bad" load tests, I waited until the server was up before running the tests.
I tested the site with up to 800 users with 10 instances running, so we should not overload the site with the below test.
This also means each server can handle about 80 users at the same time.  
In the below test we have up to 40 users on just 1 server.  I did not want to get errors just because I put too much load on just the single server before the other servers were ready.

Good Test (3 minutes simulated delay for Tomcat to warmup)
- 5 users start, every 30 seconds add 5 users up to 5000 for 10 
- 60 seconds after the test started, I changed the number of servers from 1 to 10 (autoscale takes too long 5 to 6 minutes)
- It should take about 4 minutes for the new instances
   - We do not want any 502 errors during this time
   - We will have 40 users at 4 minutes which is fine for 1 server to handle 
     - Minute 1:  000:05, 030:10,  (scale to 10 instances at the end of minute 1)
     - Minute 2:  060:15, 090:20,  (tomcat warm up 1st minute)
     - Minute 3:  120:25, 150:30,  (tomcat warm up 2nd minute) 
     - Minute 4:  180:35, 210:40,  (tomcat warm up 3rd minute)
     - Minute 5:  240:45, 270:50,  (traffic should now be on all 10 servers)
     - Minute 6:  300:55, 330:60, 
     - Minute 7:  360:65, 390:70, 
     - Minute 8:  420:75, 450:80, 
     - Minute 9:  480:85, 510:90,
     - Minute 10: 540:95, 600:100
     
- I would NOT expect to get 502 errors during the scaling process (minutes 2, 3 and 4)

![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/good-performance-all.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/good-performance-view.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/good-throughput.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/good-http-errors.png)

#### 20 Minute Test
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/good-throughput-20-minutes.png)

## Load Testing ("Bad Docker image")
Results: 502 Errors!  This is what we wanted.  Yes, we wanted errors to show we actually have a problem when Tomcat is started, but the Java app is still warming up or unzipping the WAR file.

Good Test (3 minutes simulated delay for Tomcat to warmup)
- 5 users start, every 30 seconds add 5 users up to 5000 for 10 
- 60 seconds after the test started, I changed the number of servers from 1 to 10 (autoscale takes too long 5 to 6 minutes)
- It should take about 4 minutes for the new instances
   - We do not want any 502 errors during this time
   - We will have 40 users at 4 minutes which is fine for 1 server to handle 
     - Minute 1:  000:05, 030:10,  (scale to 10 instances at the end of minute 1)
     - Minute 2:  060:15, 090:20,  (traffic should now be on all 10 servers) 
                                   (tomcat warm up 1st minute)
     - Minute 3:  120:25, 150:30,  (tomcat warm up 2nd minute) 
                                   (I would expect to start getting 502 errors sometime from this point forward)
     - Minute 4:  180:35, 210:40,  (tomcat warm up 3rd minute)
     - Minute 5:  240:45, 270:50,  
     - Minute 6:  300:55, 330:60,  (I started getting 502 errors... so it took a few minutes to spin up the containers)
     - Minute 7:  360:65, 390:70, 
     - Minute 8:  420:75, 450:80, 
     - Minute 9:  480:85, 510:90,
     - Minute 10: 540:95, 600:100
     
- I would expect to get 502 errors around sometime after minute 3.  The 502 errors started around minute 6 which means it took about 5 minutes to deploy the new containers.  When deploying the website the first time it does take about 5 minutes for the site to be available.  So, this seems reasonible.


![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/bad-performance-all.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/bad-performance-view.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/bad-throughput.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/bad-http-errors.png)

#### 20 Minute Test
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/bad-throughput-20-minutes.png)

The reason I ran a 20 minute test is because the 10 minute test never showed the errors leveling off.  The 20 minute chart show no more errors after about minute 14 (the chart becomes level, meaning we are not longer getting additional errors).  This seems to prove the issue with Tomcat accepting traffic before being ready.
