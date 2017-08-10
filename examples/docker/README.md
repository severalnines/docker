# Example Deployment on Standalone Docker#

## Manual Deployment ##

Manual deployment allows you to have better control on what you are going to deploy through ClusterControl UI. The basic steps are:
1) Run ClusterControl container
2) Run DB containers using `severalnines/centos-ssh` image with AUTO_DEPLOYMENT=0
3) Use ClusterControl UI to deploy the cluster according to the topology defined in the deployment wizard

### Example Architecture ###

The following diagram illustrates our target setup, a 4-node MySQL Replication with ProxySQL:

```
                      |
               +------------+                               +================+
               |  proxysql  |   <- - - - - deploy/manage - -| ClusterControl |
               +------------+                    |          +================+
                      |                          |
       _______________|_________________         |
      |          |           |          |        |
  +--------+ +--------+ +--------+ +--------+    |
  | master | | slave1 | | slave2 | | slave3 |  <-
  +--------+ +--------+ +--------+ +--------+
```

### Deployment Commands ###

1. Create a Docker network, 192.168.10.0/24 (db-cluster), for persistent IP addresses and hostnames:

```bash
docker network create --subnet=192.168.10.0/24 db-cluster
```

2. Run ClusterControl container with dedicated IP address 192.168.10.10, publish HTTP port 5000 and create persistent volumes to survive across upgrade/restart/reschedule:

```bash
docker run -d --name=clustercontrol \
--network db-cluster \
--ip 192.168.10.10 \
-p 5000:80 \
-p 5001:443 \
-h clustercontrol \
-v /storage/clustercontrol/.ssh:/root/.ssh \
-v /storage/clustercontrol/datadir:/var/lib/mysql \
-v /storage/clustercontrol/cmon.d:/etc/cmon.d \
-v /storage/clustercontrol/backups:/backups \
severalnines/clustercontrol
```

3. Run MySQL Replication containers. Make sure ClusterControl container starts first (master, 192.168.10.100 port 6000):

```bash
docker run -d --name master \
--network db-cluster \
--ip 192.168.10.100 \
-v /storage/master/datadir:/var/lib/mysql \
-h master \
-p 6000:3306 \
-e AUTO_DEPLOYMENT=0 \
-e CC_HOST=192.168.10.10 \
severalnines/centos-ssh
```

Then, create 3 slaves, 192.168.10.101-103 port 6001-6003:

```bash
for i in {1..3}; do
        docker run -d --name slave${i} \
        -v /storage/slave${i}/datadir:/var/lib/mysql \
        -h slave${i} \
        -p 600${i}:3306 \
        --network db-cluster \
        --ip 192.168.10.10${i} \
        -e AUTO_DEPLOYMENT=0 \
        -e CC_HOST=192.168.10.10 \
        severalnines/centos-ssh
done
```

4. Log into ClusterControl UI at `http://{docker_host}:5000/clustercontrol` or `https://{docker_host}:5001/clustercontrol` for HTTPS, register the default admin user and go to *Deploy -> MySQL Replication* to start the deployment. Take note that AUTO_DEPLOYMENT is turned off, so we can perform the installation with a better control via ClusterControl UI. Details at [centos-ssh repository](https://github.com/severalnines/docker-centos-ssh#environment-variables).

Enter the following details in the deployment wizard:

* SSH User: 'root'
* SSH Key Path: '/root/.ssh/id_rsa'
* SSH Port: 22

Fill up the remaining input fields and click Deploy.

5. Run ProxySQL container, 192.168.10.201 port 6033:

```bash
docker run -d --name proxysql1 \
-v /storage/proxysql1/datadir:/var/lib/proxysql \
-p 6033:3306 \
--network db-cluster \
--ip 192.168.10.201 \
-e AUTO_DEPLOYMENT=0 \
-e CC_HOST=192.168.10.10 \
severalnines/centos-ssh
```

6. Go to *ClusterControl -> choose the cluster -> Manage -> Load Balancers -> ProxySQL -> Deploy ProxySQL*. Specify 192.168.10.201 as the ProxySQL Address and fill up the remaining input fields.

7. You are done.


## Automatic Deployment ##

ClusterControl on Docker also supports automatic deployment, where you only need to create the containers and ClusterControl will perform the deployment automatically once the DB containers start. The basic steps are:
1) Run ClusterControl container
2) Run database containers using `centos-ssh` image. Specify the environment variables accordingly.
3) Wait until the deployment completes.

** At the moment, the supported cluster type is Galera only.

### Example Architecture ###

The following diagram illustrates our target setup, a 5-node Galera cluster:

```
         _______________________________________________
        |           |           |           |           |
        |           |           |           |           |                                +================+
  +---------+ +---------+ +---------+ +---------+ +---------+  < - - - deploy/manage - - | clustercontrol |
  | galera1 | | galera2 | | galera3 | | galera4 | | galera5 |                            +================+
  +---------+ +---------+ +---------+ +---------+ +---------+
```


### Deployment Commands ###

1) Run the ClusterControl container (this example uses standard Docker bridge network):

```bash
docker run -d --name=clustercontrol \
-p 5000:80 \
-p 5001:443 \
-h clustercontrol \
-v /storage/clustercontrol/.ssh:/root/.ssh \
-v /storage/clustercontrol/datadir:/var/lib/mysql \
-v /storage/clustercontrol/cmon.d:/etc/cmon.d \
-v /storage/clustercontrol/backups:/backups \
severalnines/clustercontrol
```

2) Run the DB containers (`CC_HOST` is the ClusterControl container's IP address):

```bash
# find the ClusterControl container's IP address
CC_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' clustercontrol)
docker run -d --name galera1 -p 6661:3306 -e CC_HOST=${CC_IP} -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
docker run -d --name galera2 -p 6662:3306 -e CC_HOST=${CC_IP} -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
docker run -d --name galera3 -p 6663:3306 -e CC_HOST=${CC_IP} -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
```

Or, you can use container linking (assume the ClusterControl container name is 'clustercontrol'):

```bash
docker run -d --name galera1 -p 6661:3306 --link clustercontrol:clustercontrol -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
docker run -d --name galera2 -p 6662:3306 --link clustercontrol:clustercontrol -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
docker run -d --name galera3 -p 6663:3306 --link clustercontrol:clustercontrol -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
```

** In Docker Swarm mode, `centos-ssh` will default to look for 'cc_clustercontrol' as the `CC_HOST`. If you create the ClusterControl container with 'cc_clustercontrol' as the service name, you can skip defining `CC_HOST`.

3) ClusterControl will automatically pick the new containers to deploy. If it finds the number of containers is equal or greater than `INITIAL_CLUSTER_SIZE`, the cluster deployment shall begin. You can verify that with:

```bash
docker logs -f clustercontrol
```

Or, open ClusterControl UI and look under *Activity (top menu) -> Jobs*.

4) To scale up, just run new containers and ClusterControl will add them into the cluster automatically:

```bash
docker run -d --name galera4 -p 6664:3306 --link clustercontrol:clustercontrol -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
docker run -d --name galera5 -p 6665:3306 --link clustercontrol:clustercontrol -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
```

5) Repeat step #3.

