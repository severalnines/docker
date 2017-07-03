#!/bin/bash

TBL='cmon.containers'
SLEEP=30

mysql_exec() {
	mysql --defaults-file=/etc/my_cmon.cnf --defaults-group-suffix=_cmon -A -Bse "$*"
}

deploy_container() {
	local cluster_name=$1
	local cluster_type=$2
	local nodes=$3
	local db_root_password=$4
	local vendor=${5:-'percona'}
	local provider_version=${6:-'5.7'}
	local os_user=${7:-'root'}

	echo ">> Deploying ${cluster_name}.. It's gonna take some time.."
	echo ">> You shall see a progress bar in a moment. You can also monitor"
	echo ">> the progress under Activity (top menu) on ClusterControl UI."
	s9s cluster --create --cluster-type=${cluster_type} --nodes="$nodes"  --vendor=${vendor} --provider-version=${provider_version} --db-admin-passwd="${db_root_password}" --os-user=${os_user} --cluster-name="$cluster_name" --wait

	[ $? -ne 0 ] && DEPLOYED=0 || DEPLOYED=1
}

set_container_status() {
	local flag=$1
	local flag_value=$2
	local cluster_name=$3
	local host=$4

	mysql_exec "UPDATE $TBL SET $flag = $flag_value WHERE ip = '$host' and cluster_name = '$cluster_name'"
}

add_container() {
	local cluster_name=$1
	local hosts=$2

	cid=$(s9s cluster --list -l | grep $cluster_name | awk {'print $1'})

	for host in $hosts; do
		s9s node --list --long | grep Failed | grep ${host}
		if [ $? -eq 0 ]; then
                	echo ">> Removing existing host ${host} from ${cluster_name}"
	                s9s cluster --remove-node --nodes=${host} --cluster-id=${cid} --wait
        	fi

		echo ">> Adding $host into $cluster_name"
		s9s cluster --add-node --nodes=$host --cluster-id=${cid} --wait
		if [ $? -eq 0 ]; then
			echo ">> $hosts added."
			set_container_status deployed 1 $cluster_name $host
			set_container_status deploying 0 $cluster_name $host
		else
			echo ">> Job failed. Will retry in the next loop."
			set_container_status deployed 0 $cluster_name $host
			set_container_status deploying 0 $cluster_name $host
		fi
	done
}

check_new_containers_to_scale() {

	scale_cluster=$(mysql_exec "SELECT cluster_name FROM $TBL GROUP BY cluster_name HAVING SUM(deployed) >= AVG(initial_size) AND SUM(deployed) > 0 AND SUM(deploying) = 0 AND AVG(deployed) < 1")
	if [ ! -z "$scale_cluster" ]; then
		echo ">> Found the following cluster(s) has node(s) to scale:"
		echo "$scale_cluster"
		echo ""

		nodelist=$(mysql_exec "SELECT distinct(ip) FROM $TBL WHERE cluster_name = '$scale_cluster' AND deployed = 0 AND deploying = 0 AND created = 1")
		trim_nodes=$(echo $nodelist | tr '\n' ' ')

                echo ">> Found a new set of containers awaiting for deployment. Sending scaling command to CMON."
                echo ">> Cluster name         : $scale_cluster"
		echo ">> Nodes to deploy      : $trim_nodes"
		echo ""
		
		add_container "$scale_cluster" "${trim_nodes}"
	fi

}

check_new_cluster_deployment() {
	new_cluster=$(mysql_exec "SELECT cluster_name FROM $TBL GROUP BY cluster_name HAVING SUM(deployed) <= AVG(initial_size) AND SUM(deployed) = 0 AND SUM(deploying) = 0")
	if [ ! -z "$new_cluster" ]; then
		echo ">> Found the following cluster(s) is yet to deploy:"
		echo "$new_cluster"
		echo ""

		for i in $new_cluster; do
			cluster_size=$(mysql_exec "SELECT initial_size FROM $TBL GROUP BY cluster_name HAVING cluster_name='$i'")
			number_nodes=$(mysql_exec "SELECT count(ip) FROM $TBL WHERE cluster_name = '$i'")

			if [ $number_nodes -ge $cluster_size ]; then
				initial_nodes=$(mysql_exec "SELECT DISTINCT(ip) FROM $TBL WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1 LIMIT $cluster_size")
				all_nodes=$(mysql_exec "SELECT DISTINCT(ip) FROM $TBL WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1")
				cluster_type=$(mysql_exec "SELECT DISTINCT(cluster_type) FROM $TBL WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1")
				db_root_password=$(mysql_exec "SELECT DISTINCT(db_root_password) FROM $TBL WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1")
				vendor=$(mysql_exec "SELECT DISTINCT(vendor) FROM $TBL WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1")
				provider_version=$(mysql_exec "SELECT DISTINCT(provider_version) FROM $TBL WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1")
				trim_initial_nodes=$(echo $initial_nodes | tr ' ' ';')
				trim_all_nodes=$(echo $all_nodes | tr '\n' ' ')

			        echo ">> Found a new set of containers awaiting for deployment. Sending deployment command to CMON."
        			echo ">> Cluster name         : $i"
			        echo ">> Cluster type         : $cluster_type"
				echo ">> Vendor               : $vendor"
				echo ">> Provider Version     : $provider_version"
			        echo ">> Nodes discovered     : $trim_all_nodes"
				echo ">> Initial cluster size : $cluster_size"
				echo ">> Nodes to deploy      : $trim_initial_nodes"
			        echo ""

				# deploy_container 1cluster_name 2cluster_type 3nodes 4db_root_password 5vendor 6provider_version 7os_user
				deploy_container "$i" "$cluster_type" "${trim_initial_nodes}" "$db_root_password" "$vendor" "$provider_version"
				
				if [ $DEPLOYED -eq 1 ]; then
					# set deployed=1 in cmon.containers
					for n in $initial_nodes; do
						set_container_status deployed 1 $i $n
					done
					echo ">> Deployment of $i has been successfully completed."
				else
				
					echo ">> Deployment of $i is failed. Please refer to ClusterControl activity logs."
				fi
			else
				echo ">> Number of containers for $i is lower than its initial size ($cluster_size)."
				echo ">> Nothing to do. Will check again on the next loop."
			fi
		done
	fi
}

while true; do
	check_new_cluster_deployment
	check_new_containers_to_scale
	sleep $SLEEP
done
