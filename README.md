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
* [1.9.2, latest (master/Dockerfile)](https://github.com/severalnines/docker/blob/master/Dockerfile)
* [1.9.1 (1.9.1/Dockerfile)](https://github.com/severalnines/docker/blob/1.9.1/Dockerfile)
* [1.9.0 (1.9.0/Dockerfile)](https://github.com/severalnines/docker/blob/1.9.0/Dockerfile)
* [1.8.2 (1.8.2/Dockerfile)](https://github.com/severalnines/docker/blob/1.8.2/Dockerfile)
* [1.8.1 (1.8.1/Dockerfile)](https://github.com/severalnines/docker/blob/1.8.1/Dockerfile)
* [1.8.0 (1.8.0/Dockerfile)](https://github.com/severalnines/docker/blob/1.8.0/Dockerfile)

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
* Redis (replication & Sentinel) - via ClusterControl GUI v2
* SQL Server for Linux (standalone) - via ClusterControl GUI v2

More details at [Severalnines](http://www.severalnines.com/clustercontrol) website.

## Image Description ##

To pull ClusterControl images, simply:
```bash
$ docker pull severalnines/clustercontrol
```

The image is based on CentOS 7 with Apache 2.4, which consists of ClusterControl packages and prerequisite components:
* ClusterControl controller, GUI v1, GUI v2, cloud, notification and web-ssh packages installed via Severalnines repository.
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
-p 9443:9443 \
-p 19501:19501 \
-e DOCKER_HOST_ADDRESS=192.168.11.111 \
-v /storage/clustercontrol/cmon.d:/etc/cmon.d \
-v /storage/clustercontrol/datadir:/var/lib/mysql \
-v /storage/clustercontrol/sshkey:/root/.ssh \
-v /storage/clustercontrol/cmonlib:/var/lib/cmon \
-v /storage/clustercontrol/backups:/root/backups \
severalnines/clustercontrol
```

---
**ATTENTION**

Starting from ClusterControl 1.9.1 (Dec 2021), `DOCKER_HOST_ADDRESS` is mandatory for ClusterControl GUI v2 to run correctly. If the container is running on Docker bridge network, additional ports 9443 and 19501 must be published.

---

The recommended persistent volumes are:
* `/etc/cmon.d` - ClusterControl configuration files.
* `/var/lib/mysql` - MySQL datadir to host `cmon` and `dcps` database.
* `/root/.ssh` - SSH private and public keys.
* `/var/lib/cmon` - ClusterControl internal files.
* `/root/backups` - Default backup directory only if ClusterControl is the backup destination

Alternatively, if you would like to enable agent-based monitoring via Prometheus, you have to make the following paths persistent as well:
* `/var/lib/prometheus` - Prometheus data directory.
* `/etc/prometheus` - Prometheus configuration directory.

Therefore, the run command for agent-based monitoring via Prometheus would be:

```bash
$ docker run -d --name clustercontrol \
--network db-cluster \
--ip 192.168.10.10 \
-h clustercontrol \
-p 5000:80 \
-p 5001:443 \
-p 9443:9443 \
-p 19501:19501 \
-e DOCKER_HOST_ADDRESS=192.168.11.111 \
-v /storage/clustercontrol/cmon.d:/etc/cmon.d \
-v /storage/clustercontrol/datadir:/var/lib/mysql \
-v /storage/clustercontrol/sshkey:/root/.ssh \
-v /storage/clustercontrol/cmonlib:/var/lib/cmon \
-v /storage/clustercontrol/backups:/root/backups \
-v /storage/clustercontrol/prom-data:/var/lib/prometheus \
-v /storage/clustercontrol/prom-conf:/etc/prometheus \
severalnines/clustercontrol
```

---
**ATTENTION**

Starting from ClusterControl 1.9.1 (Dec 2021), `DOCKER_HOST_ADDRESS` is mandatory for ClusterControl GUI v2 to run correctly. If the container is running on Docker bridge network, additional ports 9443 and 19501 must be published.

---

After a moment, you should be able to access the following ClusterControl Web UIs:
* ClusterControl GUI v1 HTTP: **http://192.168.11.111:5000/clustercontrol**
* ClusterControl GUI v1 HTTPS: **https://192.168.11.111:5001/clustercontrol**
* ClusterControl GUI v2 HTTPS: **https://192.168.11.111:9443/**

## Environment Variables ##

* `DOCKER_HOST_ADDRESS={IP address or hostname}`
        - This value should be the same as the Docker host primary IP address, or hostname/FQDN that resolves to the Docker host's primary IP address.
	- Starting from ClusterControl 1.9.1, this environment variable is mandatory. If the container is running on Docker bridge network, additional ports 9443 and 19501 must be published.
        - Example: `DOCKER_HOST_ADDRESS=192.168.11.111`

* `CMON_PASSWORD={string}`
	- MySQL password for user 'cmon'. Default to 'cmon'. Use `docker secret` is recommended.
	- Example: `CMON_PASSWORD=cmonP4s5`

* `MYSQL_ROOT_PASSWORD={string}`
	- MySQL root password for the ClusterControl container. Default to 'password'. Use `docker secret` is recommended.
	- Example: `MYSQL_ROOT_PASSWORD=MyPassW0rd`

* `CMON_STOP_TIMEOUT={integer}`
	- How long to wait (in seconds) for CMON to gracefully stop (SIGTERM) during container bootstrapping process. Default is 10.
	- If the timeout is exceeded, CMON will be stopped using SIGKILL.
	- Example: `CMON_STOP_TIMEOUT=15`

## Service Management ##

ClusterControl requires a number of processes to be running:
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

In some cases, you might need to restart the related service after a manual upgrade or configuration tuning. Details on the start commands can be found inside `conf/supervisord.conf`.

## Examples ##

* [Standalone Docker](https://github.com/severalnines/docker/tree/master/examples/docker)
* [Kubernetes](https://github.com/severalnines/docker/tree/master/examples/kubernetes)

## Development ##

Please report bugs, improvements or suggestions via our support channel: [https://support.severalnines.com](https://support.severalnines.com)

If you have any questions, you are welcome to get in touch via our [contact us](http://www.severalnines.com/contact-us) page or email us at info@severalnines.com.

## Disclaimer ##

Although Severalnines offers ClusterCluster as a Docker image, it is not intended for production usage. ClusterControl product direction is never intended to run on a container environment due to its internal logic and system design. We are maintaining the Docker image on a best-effort basis, and it is not part of the product development projection and pipeline.
