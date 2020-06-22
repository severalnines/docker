## ClusterControl 1.7.6-3996, Percona Server 5.7, CentOS 7 64bit

FROM centos:7
MAINTAINER Ashraf Sharif <ashraf@severalnines.com>

## list of packages to be installed by package manager
ENV PACKAGE curl mailx cronie nc bind-utils clustercontrol clustercontrol-controller clustercontrol-notifications clustercontrol-ssh clustercontrol-cloud clustercontrol-clud Percona-Server-server-56 openssh-clients openssh-server httpd php php-mysql php-ldap php-gd php-curl mod_ssl s9s-tools sudo python-setuptools sysvinit-tools iproute socat

# install packages
RUN yum clean all
RUN yum -y install wget && \
        rpm --import http://repo.severalnines.com/severalnines-repos.asc && \
        wget http://severalnines.com/downloads/cmon/s9s-repo.repo -P /etc/yum.repos.d/ && \
        wget http://repo.severalnines.com/s9s-tools/CentOS_7/s9s-tools.repo -P /etc/yum.repos.d/ && \
	yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm && \
        yum -y install $PACKAGE && \
        easy_install supervisor && \
        yum clean all

## add configuration files
ADD conf/my.cnf /etc/my.cnf
ADD conf/supervisord.conf /etc/supervisord.conf
ADD conf/s9s.conf /etc/httpd/conf.d/s9s.conf
ADD conf/ssl.conf /etc/httpd/conf.d/ssl.conf

## post-installation: setting up Apache
RUN cp -f /var/www/html/clustercontrol/ssl/server.crt /etc/pki/tls/certs/s9server.crt && \
        cp -f /var/www/html/clustercontrol/ssl/server.key /etc/pki/tls/private/s9server.key && \
        sed -i 's|AllowOverride None|AllowOverride All|g' /etc/httpd/conf/httpd.conf && \
        cp -f /var/www/html/clustercontrol/bootstrap.php.default /var/www/html/clustercontrol/bootstrap.php && \
        chmod -R 777 /var/www/html/clustercontrol/app/tmp && \
        chmod -R 777 /var/www/html/clustercontrol/app/upload && \
        chown -Rf apache.apache /var/www/html/clustercontrol/ && \
	mkdir /root/backups

VOLUME ["/etc/cmon.d","/var/lib/mysql","/root/.ssh"]

COPY change_ip.sh /root/change_ip.sh
COPY entrypoint.sh /entrypoint.sh
COPY deploy-container.sh /deploy-container.sh
ENTRYPOINT ["/entrypoint.sh"]

## cmon 9500, cmon-tls 9501, cmon-events 9510, cmon-ssh 9511, netcat 9999
EXPOSE 80 443 9500 9501 9510 9511 9999
HEALTHCHECK CMD curl -sSf http://localhost/clustercontrol/ > /dev/null || exit 1
