# ClusterControl Docker Image #

## Table of Contents ##

1. [Supported Tags](#supported-tags)
2. [Overview](#overview)
3. [Image Description](#image-description)
4. [Run Container](#run-container)
5. [Environment Variables](#environment-variables)
6. [Service Management](#service-management)
7. [Examples](#examples)
8. [Development](#development)

## Supported Tags ##
* [1.7.6, latest (master/Dockerfile)](https://github.com/severalnines/docker/blob/master/Dockerfile)
* [1.7.5 (1.7.5/Dockerfile)](https://github.com/severalnines/docker/blob/1.7.5/Dockerfile)
* [1.7.4 (1.7.4/Dockerfile)](https://github.com/severalnines/docker/blob/1.7.4/Dockerfile)
* [1.7.3 (1.7.3/Dockerfile)](https://github.com/severalnines/docker/blog/1.7.3/Dockerfile)
* [1.7.2 (1.7.2/Dockerfile)](https://github.com/severalnines/docker/blob/1.7.2/Dockerfile)
* [1.7.1 (1.7.1/Dockerfile)](https://github.com/severalnines/docker/blob/1.7.1/Dockerfile)
* [1.7.0 (1.7.0/Dockerfile)](https://github.com/severalnines/docker/blob/1.7.0/Dockerfile)
* [1.6.2 (1.6.2/Dockerfile)](https://github.com/severalnines/docker/blob/1.6.2/Dockerfile)
* [1.6.1 (1.6.1/Dockerfile)](https://github.com/severalnines/docker/blob/1.6.1/Dockerfile)
* [1.6.0 (1.6.0/Dockerfile)](https://github.com/severalnines/docker/blob/1.6.0/Dockerfile)


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

The image is based on CentOS 7 with Apache 2.4, which consists of ClusterControl packages and prerequisite components:
* ClusterControl controller, UI, cloud, notification and web-ssh packages installed via Severalnines repository.
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
-v /storage/clustercontrol/sshkey:/root/.ssh \
-v /storage/clustercontrol/cmonlib:/var/lib/cmon \
-v /storage/clustercontrol/backups:/root/backups \
severalnines/clustercontrol
```

The recommended persistent volumes are:
* `/etc/cmon.d` - ClusterControl configuration files.
* `/var/lib/mysql` - MySQL datadir to host `cmon` and `dcps` database.
* `/root/.ssh` - SSH private and public keys.
* `/var/lib/cmon` - ClusterControl internal files.
* `/root/backups` - Default backup directory only if ClusterControl is the backup destination

After a moment, you should able to access the ClusterControl Web UI at `{host's IP address}:{host's port}`, for example:
* HTTP: **http://192.168.10.100:5000/clustercontrol**
* HTTPS: **https://192.168.10.100:5001/clustercontrol**

We have built a complement image called `centos-ssh` to simplify database deployment with ClusterControl. It supports automatic deployment (Galera Cluster) or it can also be used as a base image for database containers (all cluster types are supported). Details at [here](https://github.com/severalnines/docker-centos-ssh).

## Environment Variables ## 

* `CMON_PASSWORD={string}`
	- MySQL password for user 'cmon'. Default to 'cmon'. Use `docker secret` is recommended.
	- Example: `CMON_PASSWORD=cmonP4s5`

* `MYSQL_ROOT_PASSWORD={string}`
	- MySQL root password for the ClusterControl container. Default to 'password'. Use `docker secret` is recommended.
	- Example: `MYSQL_ROOT_PASSWORD=MyPassW0rd`


## Service Management ##

Starting from version 1.4.2, ClusterControl requires a number of processes to be running:
* sshd - SSH daemon. The main communication channel.
* mysqld - MySQL backend runs on Percona Server 5.6.
* httpd - Web server running on Apache 2.4.
* cmon - ClusterControl backend daemon. The brain of ClusterControl. It depends on `mysqld` and `sshd`.
* cmon-ssh - ClusterControl web-based SSH daemon, which depends on `cmon` and `httpd`.
* cmon-events - ClusterControl notifications daemon, which depends on `cmon` and `httpd`.
* cmon-cloud - ClusterControl cloud integration daemon, which depends on `cmon` and `httpd`.
* cc-auto-deployment - ClusterControl automatic deployment script, running as a background process, which depends on `cmon`.

These processes are being controlled by Supervisord, a process control system. To manage a process, one would use `supervisorctl` client as shown in the following example:

```bash
[root@physical-host]$ docker exec -it clustercontrol /bin/bash
[root@clustercontrol /]# supervisorctl
cc-auto-deployment               RUNNING   pid 570, uptime 2 days, 19:11:54
cmon                             RUNNING   pid 573, uptime 2 days, 19:11:54
cmon-events                      RUNNING   pid 576, uptime 2 days, 19:11:54
cmon-ssh                         RUNNING   pid 575, uptime 2 days, 19:11:54
httpd                            RUNNING   pid 571, uptime 2 days, 19:11:54
mysqld                           RUNNING   pid 577, uptime 2 days, 19:11:54
sshd                             RUNNING   pid 572, uptime 2 days, 19:11:54
supervisor> restart cmon
cmon: stopped
cmon: started
supervisor> status cmon
cmon                             RUNNING   pid 2838, uptime 0:11:12
supervisor>
```

In some cases, you might need to restart the related service after a manual upgrade or configuration tweaking. Details on the start commands can be found inside `conf/supervisord.conf`.

## Examples ##

* [Standalone Docker](https://github.com/severalnines/docker/tree/master/examples/docker)
* [Kubernetes](https://github.com/severalnines/docker/tree/master/examples/kubernetes)

## Development ##

Please report bugs, improvements or suggestions via our support channel: [https://support.severalnines.com](https://support.severalnines.com) 

If you have any questions, you are welcome to get in touch via our [contact us](http://www.severalnines.com/contact-us) page or email us at info@severalnines.com.
