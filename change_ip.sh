#!/bin/bash
# change_ip.sh
# Run this script if ClusterControl and DB containers' IP addresses have changed after restart
# Ensure the DB containers are started/bootstrapped before running this script
# Maintainer: Ashraf Sharif <ashraf@severalnines.com>

readme=/root/README_IMPORTANT
oldip=$(grep "Detected IP address:" $readme | awk {'print $4'})
newip=$(hostname -i | tr -d ' ')
mysql_password=$(grep "MySQL root password" $readme | awk {'print $5'})

[ "$oldip" == "$newip" ] && echo "IP address didn't change. Aborting.." && exit 1

echo "Old IP: $oldip"
echo "New IP: $newip"
echo ""

ans=

while [ -z $ans ];
do
  read -p "Enter IP address of new Galera nodes (separate by comma): " ans
done

dbnodes=$(echo $ans | tr ',' ' ')
echo "New DB nodes: $dbnodes"

echo "Stopping CMON"
service cmon stop

echo "Updating mysql.user table"
mysql_command () {
  mysqlbin=$(command -v mysql)
  $mysqlbin -uroot -p$mysql_password -h127.0.0.1 -e "$*"
}
mysql_command "update mysql.user set host='$newip' where host='$oldip'"
mysql_command "flush privileges"

echo "Updating CMON configuration"
cmon_cfg=/etc/cmon.d/cmon_1.cnf
if [ -e $cmon_cfg ]; then
  sed -i "s|$oldip|$newip|g" $cmon_cfg
  sed -i "s|mysql_server_addresses=.*|mysql_server_addresses=$ans|g" $cmon_cfg
fi
[ -e /etc/cmon.cnf ]  && sed -i "s|$oldip|$newip|g" /etc/cmon.cnf
mysql_command 'truncate cmon.hosts'
mysql_command 'truncate cmon.server_node'
mysql_command 'truncate cmon.mysql_server'

ssh_opts="-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no -oNumberOfPasswordPrompts=0 -oConnectTimeout=10"
for h in $dbnodes
do
  echo "Updating CMON grant on $h"
  ssh $ssh_opts root@$h "mysql -uroot -proot123 -e \"update mysql.user set host='$newip' where host='$oldip'; flush privileges\""
done

echo "Starting CMON"
service cmon start

echo "Updating README_IMPORTANT file"
sed -i "s|$oldip|$newip|g" $readme
