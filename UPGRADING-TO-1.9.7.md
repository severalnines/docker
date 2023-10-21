# Upgrading to 1.9.7 Docker Image #

## Table of Contents ##

1. [Changes and Improvements](#changes-and-improvements)
2. [Upgrade Instructions](#upgrade-instructions)
3. [Rollback](#rollback)

## Changes and Improvements ##

Since ClusterControl 1.9.7 is a major release, we have rebuild the ClusterControl Docker image for 1.9.7 with the following major changes if compared to the older versions:

| Aspect  | <=1.9.6 | >=1.9.7 |
|---------|----------|--------|
| Base image | CentOS 7  | RockyLinux 9  |
| OS EOL     | June 30th, 2024  | May 31st, 2032 |
| Database server  | Percona Server 5.6  | MariaDB 10.5  |
| PHP version  | 7.3 (Apache DSO)  | 7.4 (FPM)  |
| Default  GUI | ClusterControl GUI v1 | ClusterControl GUI v2 |

Note that starting from ClusterControl 1.9.7, ClusterControl GUI v2 is the default frontend graphical user interface (GUI) for ClusterControl. ClusterControl GUI v1 has reached the end of the development cycle and is considered a feature-freeze product, despite it is still accessible on port 9443. All new developments will be happening on ClusterControl GUI v2. 

Other notable changes are:

* We have deprecated `deploy-container.sh` and `auto-deployment` script.
* Supervisord is updated to the latest version with proper a priority setting.
* The entrypoint script will attempt to perform the database upgrade (mariadb-upgrade) if it finds `auto.cnf` (created by older version of MySQL 5.6).

## Upgrade Instructions ##

The new image uses MariaDB as cmon database. Therefore, we need to perform a clean shutdown of MySQL before performing the database upgrade procedure. The database upgrade process will be performed automatically by the `entrypoint.sh` script when starting up the new container.

1) Retrieve the `docker run` command of the current ClusterControl container. Assuming the container name is `clustercontrol`:

```bash
docker inspect \
  --format "$(curl -s https://gist.githubusercontent.com/efrecon/8ce9c75d518b6eb863f667442d7bc679/raw/run.tpl)" \
  clustercontrol
```

Save the command's output to a text file, just in case we need it later for rollback.

2) Attach to the ClusterControl container:

```bash 
docker exec -it /bin/bash clustercontrol
```

3) Retrieve the ClusterControl controller version, just in case we need it later for rollback:

```bash 
cmon -v
```

4) Connect to the MySQL service inside the container (the `cmon` password is `CMON_PASSWORD` environment variable if defined):

```bash
mysql -ucmon -p
```

5) Inside the mysql terminal, run the following commands to flag a clean MySQL shutdown:

```sql
SET GLOBAL innodb_fast_shutdown=0;
SET GLOBAL innodb_max_dirty_pages_pct=0; 
SET GLOBAL innodb_change_buffering='none';
```

6) Observe the following 2 variables and make sure the value is 0 (indicating MySQL does not have any dirty pages left to flush):

```sql

mysql> show global status like '%dirty%';
+--------------------------------+-------+
| Variable_name                  | Value |
+--------------------------------+-------+
| Innodb_buffer_pool_pages_dirty | 0     |
| Innodb_buffer_pool_bytes_dirty | 0     |
+--------------------------------+-------+
```

7) Stop the ClusterControl services using supervisord:

```bash
supervisorctl stop cmon cmon-ssh cmon-cloud cmon-events
```

8) Now we are safe to stop the MySQL service using supervisord:

```bash
supervisorctl stop mysqld
```

9) Exit from the container to return to the host's terminal:

```bash
exit
```

10) Stop the ClusterControl container:

```bash
docker stop clustercontrol
```

11) Back up all Docker volumes related to ClusterControl (in case we need to rollback). In this case, our volumes are located under the `/storage/clustercontrol` directory:

```bash
cp -pRf /storage/clustercontrol /storage/clustercontrol_196
```

12) Remove the old container:

```bash
docker rm -f clustercontrol
```

13) Pull the latest image (tag: `severalnines/clustercontrol:latest`), or specific image (tag: `severalnines/clustercontrol:1.9.7`). In this case, we are going to use `latest`:

```bash
docker pull severalnines/clustercontrol:latest
```

14) Create a new container for the new image:

```bash
docker run -d --name clustercontrol \
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
-v /storage/clustercontrol/backups:/root/backups \
-v /storage/clustercontrol/prom-data:/var/lib/prometheus \
-v /storage/clustercontrol/prom-conf:/etc/prometheus \
severalnines/clustercontrol:latest
```

** Note that in 1.9.7 Docker image, it is no longer necessary to set the `DOCKER_HOST_ADDRESS` environment variable.

15) During the start up process, you may observe the container's log and you shall see there is an attempt to upgrade the database to MariaDB 10.5, as shown below:
```
$ docker logs -f clustercontrol

...
...
>> Starting MySQL daemon..
231019 16:04:27 mysqld_safe Logging to '/var/lib/mysql/error.log'.
231019 16:04:27 mysqld_safe Starting mariadbd daemon with databases from /var/lib/mysql
>> Found /var/lib/mysql/auto.cnf. Attempting to perform mariadb-upgrade..
MariaDB upgrade detected
Phase 1/7: Checking and upgrading mysql database
Processing databases
mysql
mysql.columns_priv                                 OK
mysql.db                                           OK
mysql.event                                        OK
mysql.func                                         OK
mysql.help_category                                OK
mysql.help_keyword                                 OK
mysql.help_relation                                OK
mysql.help_topic                                   OK
mysql.innodb_index_stats                           OK
mysql.innodb_table_stats                           OK
mysql.ndb_binlog_index                             OK
mysql.plugin                                       OK
mysql.proc                                         OK
mysql.procs_priv                                   OK
mysql.proxies_priv                                 OK
mysql.servers                                      OK
mysql.slave_master_info                            OK
mysql.slave_relay_log_info                         OK
mysql.slave_worker_info                            OK
mysql.tables_priv                                  OK
mysql.time_zone                                    OK
mysql.time_zone_leap_second                        OK
mysql.time_zone_name                               OK
mysql.time_zone_transition                         OK
mysql.time_zone_transition_type                    OK
mysql.user                                         OK
Upgrading from a version before MariaDB-10.1
Phase 2/7: Installing used storage engines
Checking for tables with unknown storage engine
Phase 3/7: Fixing views from mysql
Phase 4/7: Running 'mysql_fix_privilege_tables'
Phase 5/7: Fixing table and database names
Phase 6/7: Checking and upgrading tables
Processing databases
cmon
cmon.audit_log                                     OK
cmon.backup                                        OK
cmon.backup_log                                    OK
cmon.backup_records                                OK
cmon.backup_schedule                               OK
cmon.cdt_folders                                   OK
cmon.certificate_data                              OK
cmon.cluster                                       OK
cmon.cluster_databases                             OK
cmon.cluster_events                                OK
cmon.cluster_log                                   OK
cmon.cluster_state                                 OK
cmon.cmon_configuration                            OK
cmon.cmon_cron                                     OK
cmon.cmon_error_reports                            OK
cmon.cmon_host_log                                 OK
cmon.cmon_job                                      OK
cmon.cmon_job_message                              OK
cmon.cmon_job_tags                                 OK
cmon.cmon_log_class                                OK
cmon.cmon_log_entries                              OK
cmon.cmon_schema_hugin                             OK
cmon.cmon_stats                                    OK
cmon.cmon_stats_daily                              OK
cmon.cmon_stats_monthly                            OK
cmon.cmon_stats_weekly                             OK
cmon.cmon_stats_yearly                             OK
cmon.cmondb_version                                OK
cmon.component_defaults                            OK
cmon.component_meta                                OK
cmon.containers                                    OK
cmon.db_growth2                                    OK
cmon.diskdata                                      OK
cmon.email_notification                            OK
cmon.ext_proc                                      OK
cmon.galera_status                                 OK
cmon.groups                                        OK
cmon.haproxy_server                                OK
cmon.hosts                                         OK
cmon.keepalived                                    OK
cmon.license                                       OK
cmon.local_repository                              OK
cmon.mailserver                                    OK
cmon.memcache_statistics                           OK
cmon.message_filters                               OK
cmon.message_recipients                            OK
cmon.mongodb_running_queries                       OK
cmon.mongodb_server                                OK
cmon.mysql_advisor                                 OK
cmon.mysql_backup                                  OK
cmon.mysql_duplindex_advisor                       OK
cmon.mysql_explains                                OK
cmon.mysql_memory_usage                            OK
cmon.mysql_processlist                             OK
cmon.mysql_query_histogram                         OK
cmon.mysql_selindex_advisor                        OK
cmon.mysql_server                                  OK
cmon.mysql_slow_queries                            OK
cmon.mysql_table_advisor                           OK
cmon.node_events                                   OK
cmon.node_state                                    OK
cmon.opreports                                     OK
cmon.opreports_schedule                            OK
cmon.outgoing_digest_messages                      OK
cmon.outgoing_messages                             OK
cmon.package_info                                  OK
cmon.password_reset                                OK
cmon.processes                                     OK
cmon.restore                                       OK
cmon.restore_log                                   OK
cmon.scripts                                       OK
cmon.scripts_audit_log                             OK
cmon.scripts_results                               OK
cmon.scripts_schedule                              OK
cmon.server_node                                   OK
cmon.simple_alarm                                  OK
cmon.spreadsheets                                  OK
cmon.table_growth2                                 OK
cmon.tags                                          OK
cmon.tx_deadlock_log                               OK
cmon.users                                         OK
dcps
dcps.acls                                          OK
dcps.apis                                          OK
dcps.aws_credentials                               OK
dcps.backups                                       OK
dcps.cake_sessions                                 OK
dcps.cluster_aws_keys                              OK
dcps.cluster_keys                                  OK
dcps.clusters                                      OK
dcps.companies                                     OK
dcps.containers                                    OK
dcps.custom_advisors                               OK
dcps.deployments                                   OK
dcps.glacier_jobs                                  OK
dcps.integrations                                  OK
dcps.jobs                                          OK
dcps.ldap_group_roles                              OK
dcps.ldap_settings                                 OK
dcps.onpremise_credentials                         OK
dcps.onpremise_deployments                         OK
dcps.openstack_credentials                         OK
dcps.role_acls                                     OK
dcps.roles                                         OK
dcps.settings                                      OK
dcps.settings_items                                OK
dcps.user_roles                                    OK
dcps.users                                         OK
information_schema
performance_schema
Phase 7/7: Running 'FLUSH PRIVILEGES'
OK
>> Command mariadb-upgrade succeeded.

...
...
```

After a moment, you should be able to access the following ClusterControl web GUIs (assuming the Docker host IP address is 192.168.11.111):
* ClusterControl GUI v2 HTTP: **http://192.168.11.111:5000/**
* ClusterControl GUI v2 HTTPS: **https://192.168.11.111:5001/** (recommended)
* ClusterControl GUI v1 HTTPS: **https://192.168.11.111:9443/clustercontrol** 

The upgrade process is now complete.

The container start up will fail if it encounters error during the database upgrade process. In this case, you can either rollback (see [Rollback](#rollback)) to the previous version or report the issue to us, by submitting a support ticket to https://support.severalnines.com.

## Rollback ##

If the upgrade process fails somewhere, you may roll back to the previous version by following the steps mentioned below. Basically, what you need is to remove the container and re-create it again with the same volumes (that we have copied over earlier during the upgrade) as the previous version.

1) Remove any existing container that using the same container name as clustercontrol (skip this if you want to use other container name):

```bash
docker rm -f clustercontrol
```

2) Rename the current volumes' directory to something else and copy the previously backed up directory back to its location:

```bash
mv /storage/clustercontrol /storage/clustercontrol_197_broken
cp -pRf /storage/clustercontrol_196 /storage/clustercontrol
```

3) Run the `docker run` command as retrieved from step 1 in the [**Upgrade Instructions**](#upgrade-instructions) section. Note if you are using `latest` tag, you can no longer use it because `latest` is now pointing to `1.9.7` tag (where we pulled the latest image during upgrade on step 13). You should define an explicit tag like for example, if the previous version is 1.9.6 (from step 3), use `severalnines/clustercontrol:1.9.6` instead, as shown below:

```bash
docker run -d --name clustercontrol \
--network db-cluster \
--ip 192.168.10.10 \
-h clustercontrol \
-p 5000:80 \
-p 9443:9443 \
-p 5001:443 \
-e DOCKER_HOST_ADDRESS="192.168.111.11" \
-v /storage/clustercontrol/cmon.d:/etc/cmon.d \
-v /storage/clustercontrol/datadir:/var/lib/mysql \
-v /storage/clustercontrol/sshkey:/root/.ssh \
-v /storage/clustercontrol/cmonlib:/var/lib/cmon \
-v /storage/clustercontrol/backups:/root/backups \
severalnines/clustercontrol:1.9.6
```

** Note that in 1.9.1 until 1.9.6 Docker image, the `DOCKER_HOST_ADDRESS` environment variable is mandatory. This is no longer the case in 1.9.7 image.

4) Verify the ClusterControl is running:

```bash
docker logs -f clustercontrol
docker ps
```

The rollback process is complete.