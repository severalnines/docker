# ClusterControl Docker Image #

## Table of Contents ##

1. [Supported Tags](#supported-tags)
2. [Overview](#overview)
3. [Image Description](#image-description)
4. [Run Container](#run-container)
5. [Environment Variables](#environment-variables)
6. [Examples](#examples)
7. [Development](#development)

## Supported Tags ##

* [1.4.3, devel (1.4.3/Dockerfile)](https://github.com/severalnines/docker/blob/1.4.3/Dockerfile)
* [1.4.2, latest (1.4.2/Dockerfile)](https://github.com/severalnines/docker/blob/1.4.2/Dockerfile)
* [1.4.1 (1.4.1/Dockerfile)](https://github.com/severalnines/docker/blob/1.4.1/Dockerfile)


## Overview ##

ClusterControl is a management and automation software for database clusters. It helps deploy, monitor, manage and scale your database cluster. This Docker image comes with ClusterControl installed and configured with all of its components so you can immediately use it to deploy new set of database servers/clusters or manage existing database servers/clusters. 

Supported database servers/clusters:
* Galera Cluster for MySQL
* Percona XtraDB Cluster
* MariaDB Galera Cluster
* MySQL Replication
* MySQL single instance
* MySQL Cluster (NDB)
* MongoDB sharded cluster
* MongoDB replica set
* PostgreSQL (single instance/streaming replication)

More details at [Severalnines](http://www.severalnines.com/clustercontrol) website.

## Image Description ##

To pull ClusterControl images, simply:
```bash
$ docker pull severalnines/clustercontrol
```

The image is based on CentOS 7 which consists of ClusterControl components and requirements:
* ClusterControl controller, cmonapi, UI, notification and web-ssh packages installed via Severalnines repository.
* MySQL, CMON database, cmon user grant and dcps database for ClusterControl UI.
* Apache, file and directory permission for ClusterControl UI with SSL installed.
* SSH key for ClusterControl usage.

## Run Container ##

To run a ClusterControl container, the simplest command would be:
```bash
$ docker run -d severalnines/clustercontrol
```

However, for production use, users are advised to run with sticky IP address/hostname and persistent volumes to survive across restarts, upgrades and rescheduling, as shown below:

```bash
# Create a Docker network
$ docker network create --subnet=192.168.10.0/24 db-cluster

# Start the container
$ docker run -d --name clustercontrol \
--network db-cluster \
--ip 192.168.10.10 \
-h clustercontrol \
-p 5000:80 \
-p 5001:443 \
-v /storage/clustercontrol/cmon.d:/etc/cmon.d \
-v /storage/clustercontrol/datadir:/var/lib/mysql \
-v /storage/clustercontrol/.ssh:/root/.ssh \
-v /storage/clustercontrol/backups:/backups \
severalnines/clustercontrol
```

The recommended persistent volumes are:
	- /etc/cmon.d - ClusterControl configuration files.
	- /var/lib/mysql - MySQL datadir to host `cmon` and `dcps` database.
	- /root/.ssh - SSH private and public keys.
	- /backups - Backup repository only if the backup destination is ClusterControl

After a moment, you should able to access the ClusterControl Web UI at `{host's IP address}:{host's port}`, for example:
* HTTP: **http://192.168.10.100:5000/clustercontrol**
* HTTPS: **https://192.168.10.100:5001/clustercontrol**

We have built a complement image called `centos-ssh` to simplify database deployment with ClusterControl. It supports automatic deployment (Galera Cluster) or it can also be used as a base image for database containers (all cluster types are supported).

## Environment Variables ## 

* `CMON_PASSWORD={string}`
	- MySQL password for user 'cmon'. Default to 'cmon'. Use `docker secret` is recommended.
	- Example: `CMON_PASSWORD=cmonP4s5`

* `MYSQL_ROOT_PASSWORD={string}`
	- MySQL root password for the ClusterControl container. Default to 'password'. Use `docker secret` is recommended.
	- Example: `MYSQL_ROOT_PASSWORD=MyPassW0rd`


## Examples ##

* [Standalone Docker](https://github.com/severalnines/docker/tree/master/examples/docker)
* [Kubernetes](https://github.com/severalnines/docker/tree/master/examples/kubernetes)

## Development ##

Please report bugs, improvements or suggestions via our support channel: [https://support.severalnines.com](https://support.severalnines.com) 

If you have any questions, you are welcome to get in touch via our [contact us](http://www.severalnines.com/contact-us) page or email us at info@severalnines.com.
