### Update May-2018
You now can deploy Tomcat to Azure Web Apps and avoid this locking issue.  Please see: https://github.com/AdamPaternostro/Azure-Tomcat-WAR-Deploy.  The below article still applies for best practices.

# Azure-Tomcat-Web-App-Container
Creates a Docker container with Tomcat installed behind Apache which acts as a reverse proxy so Tomcat can be warmed up before being added to the Azure load balancer.  Solves the problems of web apps needing time to warm-up as well as locking of WAR files that can occur on Azure Window Web Apps.  This approach can be used for solving not just Tomcat, but .NET apps, Node.js, etc. so it worth understanding. Also, this does not just apply to Azure Web Apps, if you are running web servers in a VM Scale Sets, you will encounter the same issue. 


### The problem
In Azure you can run Web Sites (Web Apps) on Windows.  The architecture of Web Apps has a shared file system in which your web code is deployed.  This creates a problem when running more than one web server and you deploy a WAR files.  The servers fight over who will get a lock to unzip the WAR file and you get issues. The other issue is that some Tomcat applications take 5+ minutes to warm up.  So you do not want web traffic hitting your site before it is ready to go.  

![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/TomcatOnAzure.png)


### The solution
- Use Azure Web Apps on Linux (this will be used to deploy a custom Docker image).
- Create a Docker image: 
  - Start Tomcat on port 8080.
  - Tomcat can now unzip your WAR file since each container has its very own WAR file (no locking).    
  - Inside your Docker image:  Warm up Tomcat on port 8080 by hitting your site within the container.
  - Inside your Docker image: Start Apache on port 80 when Tomcat is ready.  Apache is acting as a reverse proxy to Tomcat.
- Azure sees port 80 is ready to go, so Azure adds this instance to the Wep App load balancer.


### The Docker Image labels
The public repository of my image has 3 labels which are described below
https://hub.docker.com/r/adampaternostro/apachetomcatazure/tags/
1. **latest**: This is the code you would use in production.  You need to test and configure this for your needs.
2. **good**: This simulates a web app that takes 3 minutes to warm up, but does not start Apache until Tomcat is ready.
3. **bad**: This simulates the problem I am trying to solve.  Tomcat not ready for action, but starts receiving traffic.


### To build the Docker image
1. Download this repository
2. Download http://mirrors.advancedhosters.com/apache/tomcat/tomcat-9/v9.0.4/bin/apache-tomcat-9.0.4.tar.gz
3. Download http://download.oracle.com/otn-pub/java/jdk/9.0.4+11/c2514751926b4512b076cc82f959763f/jdk-9.0.4_linux-x64_bin.tar.gz
4. Replace your the WAR (sample.war) with your own and update the Dockerfile
```
COPY sample.war /usr/local/apache-tomcat-9.0.4/webapps/sample.war
```
5. Change the password in the tomcat-users.xml

You could download the two above files within your Docker build process, but it made my rapid iterations go not so rapid.  Feel free to adjust.


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


## Load Testing 

### Background
- For both the "good and "bad" load tests, I waited for the first deployment to be up and running before testing.
- I tested a single web server to see how many users a single server can handle.  The result was about 100 users before getting overload.  This is important since I ran the below test I started with 1 server and one minute into the test I told Azure to run 10 servers.  It takes Azure about 5 minutes to deploy my new image, so for the first 6 minutes of the test I only have 1 server. Also, my start up script sleeps for 3 minutes (simulating Tomcat warmup) which means for up to minute 9 just 1 server is handling all the traffic.  
- I ran the load test for 10 minutes and also for 20 minutes.


### "Good" Docker image
Results: No 502 Errors!  This is what we wanted.

Data:
- 5 initial users, every 30 seconds add 5 users up to 5000 for 10 minutes
- 60 seconds after the test started, I changed the number of servers from 1 to 10.
- It should take about 4-5 minutes for the new instances
     - Minute 1:  000:05, 030:10   (scale to 10 instances at the end of minute 1)
     - Minute 2:  060:15, 090:20   (provision new servers time)
     - Minute 3:  120:25, 150:30   (provision new servers time)
     - Minute 4:  180:35, 210:40   (provision new servers time)
     - Minute 5:  240:45, 270:50   (provision new servers time)
     - Minute 6:  300:55, 330:60   (provision new servers time)
     - Minute 7:  360:65, 390:70   (tomcat warm up 1nd minute)  
     - Minute 8:  420:75, 450:80   (tomcat warm up 2nd minute)  
     - Minute 9:  480:85, 510:90   (tomcat warm up 3rd minute)
     - Minute 10: 540:95, 600:100  (traffic should now be on all 10 servers)
- I would NOT expect to get 502 errors during minutes 2 through 9, the provisioning time and the simulated Tomcat warmup time.

![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/good-performance-all.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/good-performance-view.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/good-throughput.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/good-http-errors.png)

#### 20 Minute Test
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/good-throughput-20-minutes.png)

### "Bad" Docker image
Results: 502 Errors!  This is what we wanted.  Yes, we wanted errors to show we actually have a problem when Tomcat is started, but the Java app is still warming up or unzipping the WAR file.

Data:
- 5 initial users, every 30 seconds add 5 users up to 5000 for 10 minutes
- 60 seconds after the test started, I changed the number of servers from 1 to 10.
- It should take about 4-5 minutes for the new instances
     - Minute 1:  000:05, 030:10   (scale to 10 instances at the end of minute 1)
     - Minute 2:  060:15, 090:20   (provision new servers time)
     - Minute 3:  120:25, 150:30   (provision new servers time)
     - Minute 4:  180:35, 210:40   (provision new servers time)
     - Minute 5:  240:45, 270:50   (provision new servers time)
     - Minute 6:  300:55, 330:60   (provision new servers time - I started getting 502 errors)
     - Minute 7:  360:65, 390:70   (tomcat warm up 1st minute) 
     - Minute 8:  420:75, 450:80   (tomcat warm up 2nd minute)
     - Minute 9:  480:85, 510:90   (tomcat warm up 3rd minute)
     - Minute 10: 540:95, 600:100  (eventually errors should stop occurring since we are all spun up)  
- I would EXPECT to get 502 as soon as the new servers are provisioned, around minute 6.  As soon as the container is started Apache is started, but Tomcat is still warming up.  Azure added the new servers to the load balancer since port 80 (Apache) started accepting traffic.


![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/bad-performance-all.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/bad-performance-view.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/bad-throughput.png)
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/bad-http-errors.png)

#### 20 Minute Test
![alt tag](https://raw.githubusercontent.com/AdamPaternostro/Azure-Tomcat-Web-App-Container/master/images/bad-throughput-20-minutes.png)

The reason I ran a 20 minute test is because the 10 minute test never showed the errors leveling off.  The 20 minute chart show no more errors after about minute 14.  The chart levels off, meaning no more new errors.  This proves that the servers did evenually start, but leaves me thinking it took about 13 minutes for all 10 servers to be available (something else for me to look into... why so long...).

## Notes
1. If you want to be able to SSH to your containers please see:  https://docs.microsoft.com/en-us/azure/app-service/containers/tutorial-custom-docker-image.
2. You can reduce the layer by getting rid of a lot of the RUN command and combining with the & character.  I like my code explicit when developing and then condense later, but always keep it readable.
3. You should put some code in the start-server.sh script to handle interrupts.  Right now when you run the Docker image locally it is hard to kill.  I have to run:
```
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
```
4. This project is based upon a discussion I had with a colleague who had similar issues. Please check out his Github for a Wildfly example: https://github.com/jamarsto/MyWildfly.  I wanted to do this for Tomcat since my customers use this app server and I also wanted to do the load testing of the site.
5. Tomcat has two flags: antiJARLocking and antiJARLocking.  These do not seem to solve this particular problem through and were attempting as a solution.
6. If you are using a Windows Web App and need to warm up your website (.NET, Java, etc.) see this: https://docs.microsoft.com/en-us/azure/app-service/web-sites-staged-publishing#custom-warm-up-before-swap.  If you are using Tomcat and the WAR file unzipping process is locking your application then you need to use this reverse proxy approach.  This approach really should be used for any Docker web app deployment.  I would suspect this issue will occur on-prem and other cloud vendors.
7. Other benefits of this approach: You are control of your updates with Java/Tomcat.  Your other choice is to pick a specific version in the Azure portal, be careful if you select "latest" since when Azure does updates your site could be affected.


## Summary
As you can see from the above load tests we can start Tomcat in our container, let it warmup and when ready, start Apache, which singles to Azure the server is ready for traffic.  This solves the 502 errors during auto-scale operations and solves the locking of shared files.
