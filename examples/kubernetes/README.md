# Example Deployment on Kubernetes #

We have covered this in the following blog post:
* [MySQL on Docker: Running Galera Cluster with ClusterControl on Kubernetes](https://severalnines.com/blog/mysql-docker-running-galera-cluster-clustercontrol-kubernetes)

Description on the definition files:

**ClusterControl**

* cc-pv-pvc.yml - Create PersistentVolume and PersistentVolumeClaim for ClusterControl
* cc-rs.yml - Deploy ClusterControl in ReplicaSet mode

**Galera Cluster**

* cc-galera-pv-pvc.yml - Create PersistentVolume and PersistentVolumeClaim for Galera nodes
* cc-galera-rs.yml - Deploy a 3-node Galera Cluster in ReplicaSet mode
* cc-galera-ss.yml - Deploy a 3-node Galera Cluster in StatefulSet mode

**HAProxy (load balancer)**

* cc-haproxy-rs.yml - Deploy 2 HAproxy pods in ReplicaSet mode
