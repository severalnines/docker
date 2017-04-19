## ClusterControl 1.4.1 (nightly), Percona Server 5.6, CentOS 6.6 64bit

FROM centos:6
MAINTAINER Ashraf Sharif <ashraf@severalnines.com>

## list of packages to be installed by package manager
ENV PACKAGE curl mailx cronie nc bind-utils clustercontrol clustercontrol-cmonapi clustercontrol-controller clustercontrol-nodejs Percona-Server-server-56 percona-xtrabackup-22 openssh-clients openssh-server httpd php php-mysql php-ldap php-gd php-curl mod_ssl s9s-tools sudo

# install packages
RUN yum clean all
RUN yum -y install wget && \
	rpm --import http://repo.severalnines.com/severalnines-repos.asc && \
	wget http://severalnines.com/downloads/cmon/s9s-repo.repo -P /etc/yum.repos.d/ && \
	wget http://download.opensuse.org/repositories/home:kedazo/CentOS_6/home:kedazo.repo -P /etc/yum.repos.d/ && \
	yum -y install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm && \
	yum -y install $PACKAGE && \
	yum clean all

## configure MySQL
ADD my.cnf /etc/my.cnf

## post-installation: setting up Apache
RUN cp -f /var/www/html/cmonapi/ssl/server.crt /etc/pki/tls/certs/s9server.crt && \
	cp -f /var/www/html/cmonapi/ssl/server.key /etc/pki/tls/private/s9server.key && \
	rm -rf /var/www/html/cmonapi/ssl && \
	sed -i 's|AllowOverride None|AllowOverride All|g' /etc/httpd/conf/httpd.conf && \
	sed -i 's|AllowOverride None|AllowOverride All|g' /etc/httpd/conf.d/ssl.conf && \
	sed -i 's|^SSLCertificateFile.*|SSLCertificateFile /etc/pki/tls/certs/s9server.crt|g' /etc/httpd/conf.d/ssl.conf && \
	sed -i 's|^SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/pki/tls/private/s9server.key|g' /etc/httpd/conf.d/ssl.conf && \
	cp -f /var/www/html/clustercontrol/bootstrap.php.default /var/www/html/clustercontrol/bootstrap.php && \
	cp -f /var/www/html/cmonapi/config/bootstrap.php.default /var/www/html/cmonapi/config/bootstrap.php && \
	cp -f /var/www/html/cmonapi/config/database.php.default /var/www/html/cmonapi/config/database.php && \
	chmod -R 777 /var/www/html/clustercontrol/app/tmp && \
	chmod -R 777 /var/www/html/clustercontrol/app/upload && \
	chown -Rf apache.apache /var/www/html/cmonapi/ && \
	chown -Rf apache.apache /var/www/html/clustercontrol/

VOLUME ["/var/www/html","/var/lib/mysql"]

COPY change_ip.sh /root/change_ip.sh
COPY docker-entrypoint.sh /entrypoint.sh
COPY deploy-container.sh /deploy-container.sh
ENTRYPOINT ["/entrypoint.sh"]

## cmon 9500, netcat 9999
EXPOSE 22 443 3306 80 9500 9501 9999
HEALTHCHECK CMD curl -sSf http://localhost/clustercontrol/ > /dev/null || exit 1
