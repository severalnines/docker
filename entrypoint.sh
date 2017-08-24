#!/usr/bin/env bash
set -e

# set default value if not set
[ -z "$CMON_PASSWORD" ] && cmon_password='cmon' || cmon_password=$CMON_PASSWORD
[ -z "$MYSQL_ROOT_PASSWORD" ] && mysql_root_password='password' || mysql_root_password=$MYSQL_ROOT_PASSWORD

CMON_CONFIG=/etc/cmon.d/cmon.cnf
SSH_KEY=/root/.ssh/id_rsa
MOUNT_SSH_KEY=/mnt/key/id_rsa
WWWROOT=/var/www/html
PUB_KEY_DIR=$WWWROOT/keys
CMONAPI_BOOTSTRAP=$WWWROOT/cmonapi/config/bootstrap.php
CMONAPI_DATABASE=$WWWROOT/cmonapi/config/database.php
CCUI_BOOTSTRAP=$WWWROOT/clustercontrol/bootstrap.php
BANNER_FILE='/root/README_IMPORTANT'
MYSQL_CMON_CNF=/etc/my_cmon.cnf
IP_ADDRESS=$(ip a | grep eth0 | grep inet | awk {'print $2'} | cut -d '/' -f 1 | head -1)
[ -z $IP_ADDRESS ] && IP_ADDRESS=$(hostname -i | awk {'print $1'} | tr -d ' ')
DATADIR=/var/lib/mysql
PIDFILE=${DATADIR}/mysqld.pid

ping_stats() {
        [[ $(command -v cmon) ]] && VERSION=$(cmon --version | awk '/version/ {print $3}')
        UUID=$(basename "$(head /proc/1/cgroup)" | sed "s/docker-\(.*\).scope/\\1/")
        OS=$(cat /proc/version)
        OS=$(python -c "import sys,urllib; print urllib.quote('${OS}')")
        MEM=$(free -m | awk '/Mem:/ { print "T:" $2, "F:" $4}')
        MEM=$(python -c "import sys,urllib; print urllib.quote('${MEM}')")
        LAST_MSG=$(python -c "import sys,urllib; print urllib.quote('${LAST_MSG}')")
        CONTAINER=docker
        wget -T 10 -qO- --post-data="version=${VERSION:=NA}&uuid=${UUID}&os=${OS}&mem=${MEM}&rc=${INSTALLATION_STATUS}&msg=${LAST_MSG}&container=${CONTAINER}" https://severalnines.com/service/diag.php &>/dev/null
}


## Check whether initializing MySQL data directory is necessary.
## /var/lib/mysql on new volume is usually empty.

echo
if [ "$(ls -A $DATADIR)" ]; then
	echo ">> Datadir is not empty.."
	[ -f $PIDFILE ] && rm -f $PIDFILE
else
	echo ">> Datadir is empty. Initializing datadir.."
	mysql_install_db --user=mysql --datadir="$DATADIR" --rpm
	chown -R mysql:mysql "$DATADIR"
fi

echo
echo '>> Starting MySQL daemon..'
[ -f $PIDFILE ] && rm -f $PIDFILE

start_mysqld() {
	/usr/bin/mysqld_safe --plugin-dir=/usr/lib64/mysql/plugin --socket=mysql.sock &
}

stop_mysqld() {
	echo
	echo '>> Stopping MySQL daemon so Supervisord can take over'
	killall -15 mysqld_safe mysqld
	sleep 3
}

if [ -z $(pidof mysqld) ]; then
	start_mysqld
else
	killall -9 mysqld
	start_mysqld
fi
sleep 3

echo
if [ ! -z $(pidof mysqld) ]; then
	echo '>> MySQL started. Looking for existing cmon/dcps data..'
	echo
	if [ "$(ls -A $DATADIR/cmon 2>/dev/null)" ]; then
		echo '>> Found existing cmon/dcps database'
		echo '>> Setting INITIALIZED=1'
		INITIALIZED=1
	else
		echo '>> It looks like this is a new instance..'
		echo '>> Setting INITIALIZED=0'
		INITIALIZED=0
	fi
else
        echo '>> MySQL failed to start. Aborting..'
        exit 1
fi

create_mysql_cmon_cnf() {
	## Create /etc/cmon.d/my_cmon.cnf
	if [ -f $CMON_CONFIG ]; then
		rm -f /etc/cmon.cnf
	elif [ -f /etc/cmon.cnf ]; then
		mv /etc/cmon.cnf $CMON_CONFIG
	fi
	cmon_pwd=$(grep mysql_password $CMON_CONFIG | sed 's|^mysql_password=||g')
	cat > "$MYSQL_CMON_CNF" << EOF
[mysql_cmon]
user=cmon
password=$cmon_pwd
EOF
}

generate_ssh_key() {
	## Generate SSH keys
        echo
        echo ">> Generating SSH key for root at $SSH_KEY.."
	AUTHORIZED_FILE=/root/.ssh/authorized_keys
	KNOWN_HOSTS=/root/.ssh/known_hosts
	if [ -f $MOUNT_SSH_KEY ]; then
		cp $MOUNT_SSH_KEY $SSH_KEY
		cp ${MOUNT_SSH_KEY}.pub ${SSH_KEY}.pub
	else
		ssh-keygen -t rsa -N "" -f $SSH_KEY
	fi
	cat ${SSH_KEY}.pub >> $AUTHORIZED_FILE
	[ -d $PUB_KEY_DIR ] || mkdir -p $PUB_KEY_DIR
	cat ${SSH_KEY}.pub > $PUB_KEY_DIR/cc.pub
	chown -Rf apache:apache  $PUB_KEY_DIR
	KEY_TYPE=$(awk {'print $1'} ${SSH_KEY}.pub)
	PUB_KEY=$(awk {'print $2'} ${SSH_KEY}.pub)
	echo "$IP_ADDRESS $KEY_TYPE $PUB_KEY" >> $KNOWN_HOSTS
	chmod 600 $AUTHORIZED_FILE
}

if [ $INITIALIZED -eq 1 ]; then
	[ ! -f $MYSQL_CMON_CNF ] && create_mysql_cmon_cnf
	cmon_token=$(mysql --defaults-file=$MYSQL_CMON_CNF --defaults-group-suffix=_cmon -A -Bse "SELECT token FROM dcps.apis" 2> /dev/null)
	echo

	if [ ! -z $cmon_token ]; then
		CMON_EXISTING_TOKEN=$cmon_token
		echo ">> Existing token: $CMON_EXISTING_TOKEN"

		echo
		echo '>> Updating API token..'
		sed -i "s|^rpc_key=.*|rpc_key=$CMON_EXISTING_TOKEN|g" $CMON_CONFIG
	        sed -i "s|^define('RPC_TOKEN'.*|define('RPC_TOKEN', '$CMON_EXISTING_TOKEN');|g" $CCUI_BOOTSTRAP
	        sed -i "s|^define('CMON_TOKEN'.*|define('CMON_TOKEN', '$CMON_EXISTING_TOKEN');|g" $CMONAPI_BOOTSTRAP

		echo
		echo '>> Retrieving existing cmon credentials..'
		cmon_pass=$(grep mysql_password $CMON_CONFIG | sed 's|^mysql_password=||g')
		cmon_port=$(grep mysql_port $CMON_CONFIG | sed 's|^mysql_port=||g')

		[ -z $cmon_pass ] && CMON_EXISTING_PASS=$cmon_password || CMON_EXISTING_PASS=$cmon_pass
		[ -z $cmon_port ] && CMON_EXISTING_PORT=3306 || CMON_EXISTING_PORT=$cmon_port

		echo
		echo '>> Updating database credentials..'
		sed -i "s|^define('DB_PASS'.*|define('DB_PASS', '$(echo ${CMON_EXISTING_PASS} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')');|g" $CCUI_BOOTSTRAP
		sed -i "s|^define('DB_PORT'.*|define('DB_PORT', '$CMON_EXISTING_PORT');|g" $CCUI_BOOTSTRAP
		sed -i "s|^define('DB_PASS'.*|define('DB_PASS', '$(echo ${CMON_EXISTING_PASS} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')');|g" $CMONAPI_DATABASE
		sed -i "s|^define('DB_PORT'.*|define('DB_PORT', '$CMON_EXISTING_PORT');|g" $CMONAPI_DATABASE

		echo
		echo '>> Setting up public key directory..'
		if [ -f $SSH_KEY ]; then
	                [ -d $PUB_KEY_DIR ] || mkdir -p $PUB_KEY_DIR
        	        cat ${SSH_KEY}.pub > $PUB_KEY_DIR/cc.pub
			chown -Rf apache:apache  $PUB_KEY_DIR
		else
			generate_ssh_key
		fi

		echo
		echo '>> Bootstrapping completed.'
	else
		echo 'Unable to retrieve existing token.'
	fi
else
	## Start ClusterControl initialization

	[ ! -f $SSH_KEY ] && generate_ssh_key

	## Configure CMON service

	CMON_TOKEN=$(python -c 'import uuid; print uuid.uuid4()' | sha1sum | cut -f1 -d' ')
	echo
	echo ">> Setting up minimal $CMON_CONFIG.."
	cat /dev/null > $CMON_CONFIG
	cat > "$CMON_CONFIG" << EOF
mysql_port=3306
mysql_hostname=127.0.0.1
mysql_password=$cmon_password
hostname=$IP_ADDRESS
rpc_key=$CMON_TOKEN
EOF
	## Configure ClusterControl UI & CMONAPI

	echo
	echo '>> Setting up ClusterControl UI and CMONAPI..'
	sed -i "s|GENERATED_CMON_TOKEN|$CMON_TOKEN|g" $CMONAPI_BOOTSTRAP
	sed -i "s|^define('ENABLE_CC_API_TOKEN_CHECK'.*|define('ENABLE_CC_API_TOKEN_CHECK', '1');|g" $CMONAPI_BOOTSTRAP
        sed -i "s|^define('DB_PASS'.*|define('DB_PASS', '$(echo ${cmon_password} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')');|g" $CMONAPI_DATABASE
	sed -i "s|MYSQL_PORT|3306|g" $CMONAPI_DATABASE
	sed -i "s|^define('DB_PASS'.*|define('DB_PASS', '$(echo ${cmon_password} | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')');|g" $CCUI_BOOTSTRAP
	sed -i "s|DBPORT|3306|g" $CCUI_BOOTSTRAP
	sed -i "s|RPCTOKEN|$CMON_TOKEN|g" $CCUI_BOOTSTRAP

	mysql=( mysql -uroot -h127.0.0.1 )

	if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then

		## Create schemas and import
		echo
		echo '>> Importing CMON data..'
		mysql -uroot -h127.0.0.1 -e 'create schema cmon; create schema dcps;' && \
			mysql -f -uroot -h127.0.0.1 cmon < /usr/share/cmon/cmon_db.sql && \
				mysql -f -uroot -h127.0.0.1 cmon < /usr/share/cmon/cmon_data.sql && \
					mysql -f -uroot -h127.0.0.1 dcps < $WWWROOT/clustercontrol/sql/dc-schema.sql

		## Configure CMON user & password
		echo
		echo '>> Configuring CMON user and MySQL root password..'
		TMPFILE=/tmp/configure_cmon.sql
		cat > "$TMPFILE" << EOF
UPDATE mysql.user SET Password=PASSWORD('$mysql_root_password') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE DB='test' OR DB='test\\_%';
GRANT ALL PRIVILEGES ON *.* TO 'cmon'@'localhost' IDENTIFIED BY '$cmon_password' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'cmon'@'127.0.0.1' IDENTIFIED BY '$cmon_password' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'cmon'@'$IP_ADDRESS' IDENTIFIED BY '$cmon_password' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'cmon'@'%' IDENTIFIED BY '$cmon_password' WITH GRANT OPTION;
REPLACE INTO dcps.apis(id, company_id, user_id, url, token) VALUES (1, 1, 1, 'https://127.0.0.1/cmonapi', '$CMON_TOKEN');
CREATE TABLE cmon.containers (id INT PRIMARY KEY AUTO_INCREMENT, did INT, hostname VARCHAR(255), ip VARCHAR(128), cluster_type VARCHAR(128), cluster_name VARCHAR(255), vendor VARCHAR(128), provider_version VARCHAR(16), db_root_password VARCHAR(255), initial_size INT, deploying TINYINT NOT NULL DEFAULT 0, deployed TINYINT NOT NULL DEFAULT 0, created TINYINT NOT NULL DEFAULT 0);
FLUSH PRIVILEGES;
EOF

		mysql -uroot -h127.0.0.1 < $TMPFILE; rm -f $TMPFILE

		echo
		echo '>> Configuring CMON MySQL defaults file..'
		cat > "$MYSQL_CMON_CNF" << EOF
[mysql_cmon]
user=cmon
password=$cmon_password
EOF

	fi

	[ -f $CMON_CONFIG ] && rm -f /etc/cmon.cnf

	ping_stats

	echo "!! Please remember following information which generated during entrypoint !!" > $BANNER_FILE
	[ -z "$CMON_PASSWORD" ] && echo ">> Generated CMON password: $cmon_password" >> $BANNER_FILE || echo "CMON password: $cmon_password" >> $BANNER_FILE
	[ -z "$MYSQL_ROOT_PASSWORD" ] &&	echo "Generated MySQL root password: $mysql_root_password" >> $BANNER_FILE || echo "MySQL root password: $mysql_root_password" >> $BANNER_FILE
	echo "Generated ClusterControl API Token: $CMON_TOKEN" >> $BANNER_FILE
	echo "Detected IP address: $IP_ADDRESS" >> $BANNER_FILE
	echo "To access ClusterControl UI, go to http://${IP_ADDRESS}/clustercontrol" >> $BANNER_FILE
fi

if ! $(grep -q dba /etc/passwd); then
	## Setting up ssh daemon
	echo
	echo '>> Preparing SSH daemon'
	[ -d /var/run/sshd ] ||  mkdir /var/run/sshd
	[ -f /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
	[ -f /etc/ssh/ssh_host_dsa_key ] || ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N ''

	## Configure s9s CLI

	echo
	echo '>> Starting CMON to grant s9s cli user..'
	/usr/sbin/cmon --rpc-port=9500 --events-client=http://127.0.0.1:9510
	sleep 5

	echo '>> Creating user "dba" for s9s cli'
	/usr/sbin/useradd dba

	echo '>> Generating key for s9s cli'
	[ -d /var/lib/cmon ] || mkdir -p /var/lib/cmon
	/usr/bin/s9s user --create --generate-key --controller=https://localhost:9501 --cmon-user=dba

	S9S_CONF=/root/.s9s/s9s.conf
	if [ -f $S9S_CONF ]; then
		echo '>> Configuring s9s.conf'
		echo 'controller_host_name = localhost' >> $S9S_CONF
		echo 'controller_port      = 9501' >> $S9S_CONF
		echo 'rpc_tls              = true' >> $S9S_CONF
	fi

	echo
	kill -15 $(pidof cmon)
	while ($pidof cmon); do
		echo '>> Stopping CMON..'
		sleep 1
	done
	echo '>> CMON stopped'

	if ! $(grep -q CONTAINER $CCUI_BOOTSTRAP); then
		echo "define('CONTAINER', 'docker');" >> $CCUI_BOOTSTRAP
	fi
fi

stop_mysqld
echo '>> Sleeping 15s for the stopping processes to clean up..'
sleep 15

echo ""
echo ">> Starting Supervisord and all related services:"
echo ">> sshd, httpd, cmon, cmon-events, cmon-ssh, cc-auto-deployment"
/usr/bin/supervisord -c /etc/supervisord.conf
