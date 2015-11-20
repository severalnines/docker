# ClusterControl Docker Image #

## Table of Contents ##

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Image Description](#image-description)
4. [Run Container](#run-container)
5. [Optional Docker System Environment](#optional-docker-system-environment)
6. [Build Image](#build-image)
7. [Add an Existing Server/Cluster](#add-an-existing-cluster)
8. [Limitations](#limitations)
9. [Development](#development)

## Overview ##

ClusterControl is a management and automation software for database clusters. It helps deploy, monitor, manager and scale your database cluster. This Docker image comes with ClusterControl installed and configured with all of its components so you can immediately use it to manage and monitor an existing database infrastructure. 

Supported database servers/clusters:
* Galera Cluster for MySQL
* Percona XtraDB Cluster
* MariaDB Galera Cluster
* MySQL replication
* MySQL single instance
* MySQL Cluster (NDB)
* MongoDB/TokuMX sharded cluster
* MongoDB/TokuMX replica set
* PostgreSQL single instance

More details at [Severalnines](http://www.severalnines.com/clustercontrol) website.

## Requirements ##

Make sure you meet following criteria prior to the deployment:

* Make sure your database cluster is up and running before importing to ClusterControl.
* Only root user is supported at moment. No sudo user.
* SELinux/AppArmor will be turned off.

## Image Description ##

To pull ClusterControl images, simply:
```bash
$ docker pull severalnines/clustercontrol
```

The image consists of ClusterControl and all of its components:
* ClusterControl controller, cmonapi and UI installed via Severalnines package repository.
* MySQL, CMON database, cmon user grant and dcps database for ClusterControl UI.
* Apache, file and directory permission for ClusterControl UI with SSL installed.
* An auto-generated SSH key for ClusterControl usage.

## Run Container ##

To run a ClusterControl container, the simplest command would be:
```bash
$ docker run -d severalnines/clustercontrol
```

However, we would recommend users to assign a container name and map the host's port with exposed HTTP or HTTPS port on container:
```bash
$ docker run -d --name clustercontrol -p 5000:80 severalnines/clustercontrol
```

Verify with:
```bash
$ docker logs clustercontrol
$ docker ps # ensure the container is started and running
```

After a moment, you should able to access the ClusterControl Web UI at http://[host's IP address]:[host's port]/clustercontrol, for example:
**http://192.168.10.100:5000/clustercontrol**

To access the ClusterControl's console:
```bash
$ docker exec -it clustercontrol /bin/bash
```

## Optional Docker System Environment ##

* `CMON_PASSWORD`: MySQL password for user 'cmon'. Default to 'cmon'.
* `MYSQL_ROOT_PASSWORD`: MySQL root password for the ClusterControl container. Default to 'password'.

Use -e flag to specify the environment variable, for example:
```bash
$ docker run -d --name clustercontrol -e CMON_PASSWORD=MyCM0nP4ss -e MYSQL_ROOT_PASSWORD=MyR00tP4ss severalnines/clustercontrol
```

* -p : Map the exposed port from host to the container. By default following ports are exposed on the container:
	* 22 - SSH
	* 80 - HTTP
	* 443 - HTTPS
	* 3306 - MySQL
	* 9500 - cmon
	* 9600 - HAproxy stats (if HAproxy is installed in this container)
	* 9999 - netcat (backup streaming)

Use -p flag to map ports between host and container, for example to map HTTP and HTTPS of ClusterControl UI, simply run the container with:
```bash
$ docker run -d --name clustercontrol -p 5000:80 -p 5443:443 severalnines/clustercontrol
```

## Build Image ##

To build Docker image, download the Docker related files available at [our Github repository](https://github.com/severalnines/docker):
```bash
$ git clone https://github.com/severalnines/docker
$ cd docker
$ docker build -t severalnines/clustercontrol .
```

Verify with:
```bash
$ docker images
```

## Adding an Existing Cluster ##

1) Ensure your database cluster is up and running. Supported database cluster is listed under [Overview](#overview) section.

2) Copy the auto-generated SSH key on ClusterControl to the target database containers/nodes. For example, if your database containers' IP address is 172.17.0.11,172.17.0.12,172.17.0.13 run following command on ClusterControl node:
```bash
$ ssh-copy-id 172.17.0.11
$ ssh-copy-id 172.17.0.12
$ ssh-copy-id 172.17.0.13
```

3) Access the ClusterControl UI and click on *Add Existing Server/Cluster* button. Enter required details and click *Add Cluster*. 


## Limitations ##

* The image are tested and built using Docker version 1.5.0-dev, build fc0329b and Docker version 1.6.0, build bdbc177 on CentOS 7.1.

* Deploying a new external DB node/cluster (out of Docker's network) is not working since the DB node will see different IP address compare to what CMON sees internally.

* The image only supports bootstrapping MySQL servers with IP address where it expects skip-name-resolve is enabled on all MySQL nodes. However, for MongoDB, you can specify hostname instead.

* [ClusterControl known issues and limitations](http://severalnines.com/docs/troubleshooting.html#known-issues-and-limitations).

## Development ##

Please report bugs, improvements or suggestions via our support channel: [https://support.severalnines.com](https://support.severalnines.com) 

If you have any questions, you are welcome to get in touch via our [contact us](http://www.severalnines.com/contact-us) page or email us at info@severalnines.com.
