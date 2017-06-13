#!/usr/bin/env bash
set -e

# set default value if not set
[ -z "$CMON_PASSWORD" ] && cmon_password='cmon' || cmon_password=$CMON_PASSWORD
[ -z "$MYSQL_ROOT_PASSWORD" ] && mysql_root_password='password' || mysql_root_password=$MYSQL_ROOT_PASSWORD

CMON_CONFIG=/etc/cmon.cnf
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

# check mysql status
DATADIR=/var/lib/mysql
PIDFILE=${DATADIR}/mysqld.pid

if [ "$(ls -A $DATADIR)" ]; then
	echo ">> Datadir is not empty"
	[ -f $PIDFILE ] && rm -f $PIDFILE
else
	echo ">> Datadir is empty. Initializing datadir.."
	mysql_install_db --user=mysql --datadir="$DATADIR" --rpm
	chown -R mysql:mysql "$DATADIR"
fi

echo
echo '>> Checking MySQL daemon..'
[ -z $(pidof mysqld_safe) ] && service mysql start || (killall -9 mysqld && service mysql start)

# import data
if [ ! -e $MYSQL_CMON_CNF ]; then
	# configure ClusterControl Controller
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
	echo
	echo '>> Setting up ClusterControl UI and CMONAPI..'
	## configure ClusterControl UI & CMONAPI
	sed -i "s|GENERATED_CMON_TOKEN|$CMON_TOKEN|g" $CMONAPI_BOOTSTRAP
	sed -i "s|^define('ENABLE_CC_API_TOKEN_CHECK'.*|define('ENABLE_CC_API_TOKEN_CHECK', '1');|g" $CMONAPI_BOOTSTRAP
	sed -i "s|MYSQL_PASSWORD|$cmon_password|g" $CMONAPI_DATABASE
	sed -i "s|MYSQL_PORT|3306|g" $CMONAPI_DATABASE
	sed -i "s|DBPASS|$cmon_password|g" $CCUI_BOOTSTRAP
	sed -i "s|DBPORT|3306|g" $CCUI_BOOTSTRAP
	sed -i "s|RPCTOKEN|$CMON_TOKEN|g" $CCUI_BOOTSTRAP

	echo '>> Generating SSH key..'
	## configure SSH
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
	cat ${SSH_KEY}.pub >> $PUB_KEY_DIR/cc.pub
	chown -Rf apache:apache  $PUB_KEY_DIR
	KEY_TYPE=$(awk {'print $1'} ${SSH_KEY}.pub)
	PUB_KEY=$(awk {'print $2'} ${SSH_KEY}.pub)
	echo "$IP_ADDRESS $KEY_TYPE $PUB_KEY" >> $KNOWN_HOSTS
	chmod 600 $AUTHORIZED_FILE

	mysql=( mysql -uroot -h127.0.0.1 )

	if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
		echo
		echo '>> Importing CMON data..'
		mysql -uroot -h127.0.0.1 -e 'create schema cmon; create schema dcps;' && \
			mysql -f -uroot -h127.0.0.1 cmon < /usr/share/cmon/cmon_db.sql && \
				mysql -f -uroot -h127.0.0.1 cmon < /usr/share/cmon/cmon_data.sql && \
					mysql -f -uroot -h127.0.0.1 dcps < $WWWROOT/clustercontrol/sql/dc-schema.sql

		# configure CMON user & password
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
fi

# Start the services
service cmon restart
service sshd restart
sleep 5

# Configure s9s CLI

if [ ! -e $BANNER_FILE ]; then
	echo
	echo '>> Create user "dba" for s9s cli'
	/usr/sbin/useradd dba
	echo '>> Generating key for s9s cli'
	/usr/bin/s9s user --create --generate-key --controller=”https://localhost:9501” --cmon-user=dba
	S9S_CONF=/root/.s9s/s9s.conf
	if [ -f $S9S_CONF ]; then
		echo '>> Configuring s9s.conf'
		echo 'controller_host_name = localhost' >> $S9S_CONF
		echo 'controller_port      = 9501' >> $S9S_CONF
		echo 'rpc_tls              = true' >> $S9S_CONF
	fi

	echo ">> Testing connection to ClusterControl via s9s CLI"
	/usr/bin/s9s cluster --ping
fi
echo
echo ">> Starting up the Docker deployment script"
/deploy-container.sh &

## generate a README-IMPORTANT! file to notify the generated credentials
if [ ! -e $BANNER_FILE ]; then
	echo "!! Please remember following information which generated during entrypoint !!" > $BANNER_FILE
	[ -z "$CMON_PASSWORD" ] && echo ">> Generated CMON password: $cmon_password" >> $BANNER_FILE || echo "CMON password: $cmon_password" >> $BANNER_FILE
	[ -z "$MYSQL_ROOT_PASSWORD" ] &&	echo "Generated MySQL root password: $mysql_root_password" >> $BANNER_FILE || echo "MySQL root password: $mysql_root_password" >> $BANNER_FILE
	echo "Generated ClusterControl API Token: $CMON_TOKEN" >> $BANNER_FILE
	echo "Detected IP address: $IP_ADDRESS" >> $BANNER_FILE
	echo "To access ClusterControl UI, go to http://${IP_ADDRESS}/clustercontrol" >> $BANNER_FILE
fi

echo ""
echo ">> Starting HTTP in the foreground"
/usr/sbin/httpd -D FOREGROUND
