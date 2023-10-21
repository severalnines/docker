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
9. [Disclaimer](#disclaimer)

## Supported Tags ##
* [1.9.7, latest (master/Dockerfile)](https://github.com/severalnines/docker/blob/master/Dockerfile)
* [1.9.6 (1.9.5/Dockerfile)](https://github.com/severalnines/docker/blob/1.9.6/Dockerfile)
* [1.9.5 (1.9.5/Dockerfile)](https://github.com/severalnines/docker/blob/1.9.5/Dockerfile)

## Overview ##

ClusterControl is a management and automation software for database clusters. It helps deploy, monitor, manage and scale your database cluster. This Docker image comes with ClusterControl installed and configured with all of its components so you can immediately use it to deploy new set of database servers/clusters or manage existing database servers/clusters.

Supported database servers/clusters:
* Percona XtraDB Cluster
* MariaDB Galera Cluster
* MySQL/MariaDB (standalone & replication)
* MySQL Cluster (NDB)
* MongoDB (replica set & sharded cluster)
* PostgreSQL (standalone & streaming replication)
* TimescaleDB (standalone & streaming replication)
* Redis (replication with Sentinel)
* SQL Server 2019 for Linux (standalone & Availability Group)
* Elasticsearch

More details at [Severalnines](http://www.severalnines.com/clustercontrol) website.

## Image Description ##

To pull ClusterControl images, simply:
```bash
$ docker pull severalnines/clustercontrol
```

The image is based on RockyLinux 9 with Apache 2.4, which consists of ClusterControl packages and prerequisite components:
* ClusterControl controller, GUI v1 (port 9443), GUI v2, cloud, notification and web-ssh packages installed via Severalnines repository.
* MariaDB, CMON database, cmon user grant and dcps database for ClusterControl UI.
* Apache, file and directory permission for ClusterControl GUI with SSL installed.
* SSH key for ClusterControl usage.
* ClusterControl CLI (s9s)

## Run Container ##

To run a ClusterControl container, the simplest command would be:
```bash
$ docker run -d severalnines/clustercontrol
```

However, for production use, users are advised to run with sticky IP address/hostname and persistent volumes to survive across restarts, upgrades and rescheduling, as shown below:

---
**ATTENTION**

If you are upgrading from ClusterControl 1.9.6 (or older) to 1.9.7 (Sept 2023), please see [UPGRADING-TO-1.9.7.md](https://github.com/severalnines/docker/blob/master/UPGRADING-TO-1.9.7.md). There are additional steps to stop and recreate the container in order to perform a proper upgrade.

---

```bash
# Create a Docker network for persistent hostname & ip address
$ docker network create --subnet=192.168.10.0/24 db-cluster

# Start the container
$ docker run -d --name clustercontrol \
--network db-cluster \
--ip 192.168.10.10 \
-h clustercontrol \
-p 5000:80 \
-p 5001:443 \
-p 9443:9443 \
-p 9999:9999 \
-v /storage/clustercontrol/cmon.d:/etc/cmon.d \
-v /storage/clustercontrol/datadir:/var/lib/mysql \
-v /storage/clustercontrol/sshkey:/root/.ssh \
-v /storage/clustercontrol/cmonlib:/var/lib/cmon \
-v /storage/clustercontrol/backups:/root/backups \
-v /storage/clustercontrol/prom-data:/var/lib/prometheus \
-v /storage/clustercontrol/prom-conf:/etc/prometheus \
severalnines/clustercontrol
```

The suggested port mappings are:
* 5000 -> 80 - ClusterControl GUI v2 HTTP
* 5001 -> 443 - ClusterControl GUI v2 HTTPS
* 9443 -> 9443 - ClusterControl GUI v1 HTTPS
* 9999 -> 9999 - Backup streaming port, only if ClusterControl is the database backup destination

The recommended persistent volumes are:
* `/etc/cmon.d` - ClusterControl configuration files.
* `/var/lib/mysql` - MySQL datadir to host `cmon` and `dcps` database.
* `/root/.ssh` - SSH private and public keys.
* `/var/lib/cmon` - ClusterControl internal files.
* `/root/backups` - Default backup directory only if ClusterControl is the database backup destination.
* `/var/lib/prometheus` - Prometheus data directory.
* `/etc/prometheus` - Prometheus configuration directory.

---
**ATTENTION**

Starting from ClusterControl 1.9.7 (Sep 2023), the enviroment variable `DOCKER_HOST_ADDRESS` is no longer necessary. It was only intended for version 1.9.1 until 1.9.6.

---

After a moment, you should be able to access the following ClusterControl web GUIs (assuming the Docker host IP address is 192.168.11.111):
* ClusterControl GUI v2 HTTP: **http://192.168.11.111:5000/**
* ClusterControl GUI v2 HTTPS: **https://192.168.11.111:5001/** (recommended)
* ClusterControl GUI v1 HTTPS: **https://192.168.11.111:9443/clustercontrol** 

Note that starting from ClusterControl 1.9.7, ClusterControl GUI v2 is the default frontend graphical user interface (GUI) for ClusterControl. ClusterControl GUI v1 has reached the end of the development cycle and is considered a feature-freeze product. All new developments will be happening on ClusterControl GUI v2.

## Environment Variables ##

* `CMON_PASSWORD={string}`
	- MySQL password for user 'cmon'. Default to 'cmon'. Use `docker secret` is recommended.
	- Example: `CMON_PASSWORD=cmonP4s5`

* `MYSQL_ROOT_PASSWORD={string}`
	- MySQL root password for the ClusterControl container. Default to 'password'. Use `docker secret` is recommended.
	- Example: `MYSQL_ROOT_PASSWORD=MyPassW0rd`

* `CMON_STOP_TIMEOUT={integer}`
	- How long to wait (in seconds) for CMON to gracefully stop (SIGTERM) during container bootstrapping process. Default is 30.
	- If the timeout is exceeded, CMON will be stopped using SIGKILL.
	- Example: `CMON_STOP_TIMEOUT=30`

## Service Management ##

ClusterControl requires a number of processes to be running:
* mariadbd - ClusterControl database runs on MariaDB 10.5.
* httpd - Web server running on Apache 2.4.
* php-fpm - PHP 7.4 FastCGI process manager for ClusterControl GUI v1.
* cmon - ClusterControl backend daemon. The brain of ClusterControl which depends on `mariadbd`.
* cmon-ssh - ClusterControl web-based SSH daemon, which depends on `cmon` and `httpd`.
* cmon-events - ClusterControl notifications daemon, which depends on `cmon` and `httpd`.
* cmon-cloud - ClusterControl cloud integration daemon, which depends on `cmon` and `httpd`.

These processes are being controlled by Supervisord, a process control system. To manage a process, one would use `supervisorctl` client as shown in the following example:

```bash
[root@docker-host]$ docker exec -it clustercontrol /bin/bash
$ supervisorctl
cmon                             RUNNING   pid 504, uptime 0:11:37
cmon-cloud                       RUNNING   pid 505, uptime 0:11:37
cmon-events                      RUNNING   pid 506, uptime 0:11:37
cmon-ssh                         RUNNING   pid 507, uptime 0:11:37
httpd                            RUNNING   pid 509, uptime 0:11:37
mariadbd                         RUNNING   pid 503, uptime 0:11:37
php-fpm                          RUNNING   pid 508, uptime 0:11:37
supervisor> restart cmon
cmon: stopped
cmon: started
supervisor> status cmon
cmon                             RUNNING   pid 504, uptime 0:00:21
supervisor>
```

In some cases, you might need to restart the corresponding services after a manual upgrade or configuration tuning. Details on the start commands can be found inside `conf/supervisord.conf`.

## Examples ##

* [Standalone Docker](https://github.com/severalnines/docker/tree/master/examples/docker)
* [Kubernetes](https://github.com/severalnines/docker/tree/master/examples/kubernetes)

## Development ##

Please report bugs, improvements or suggestions via our support channel: [https://support.severalnines.com](https://support.severalnines.com)

If you have any questions, you are welcome to get in touch via our [contact us](http://www.severalnines.com/contact-us) page or email us at info@severalnines.com.

## Disclaimer ##

Although Severalnines offers ClusterCluster as a Docker image, it is not intended for production usage. ClusterControl product direction is never intended to run on a container environment due to its internal logic and system design. We are maintaining the Docker image on a best-effort basis, and it is not part of the product development projection and pipeline.

Note that starting from ClusterControl 1.9.7, ClusterControl GUI v2 is the default frontend graphical user interface (GUI) for ClusterControl. ClusterControl GUI v1 has reached the end of the development cycle and is considered a feature-freeze product. All new developments will be happening on ClusterControl GUI v2.
