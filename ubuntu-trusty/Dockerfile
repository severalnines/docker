## ClusterControl 1.2.10, Percona Server 5.6, Ubuntu Trusty 64bit
## The OS distribution running on managed nodes must be the same with controller node
## If your database nodes are running on Ubuntu/Debian, use clustercontrol-debian Dockerfile instead

FROM ubuntu:trusty
MAINTAINER Ashraf Sharif <ashraf@severalnines.com>

## list of packages to be installed by package manager
ENV PACKAGE curl mailutils netcat psmisc libaio1 dnsutils clustercontrol clustercontrol-cmonapi clustercontrol-controller percona-server-server-5.6 percona-xtrabackup openssh-server python apache2 php5-common php5-mysql php5-ldap php5-gd libapache2-mod-php5 php5-json php5-curl

# install packages
RUN apt-get update && apt-get install -y wget && \
	wget http://repo.severalnines.com/severalnines-repos.asc && \
	apt-key add severalnines-repos.asc && \
	wget http://www.severalnines.com/downloads/cmon/s9s-repo.list -P /etc/apt/sources.list.d/
RUN apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A && \
	sed -i '/repo.percona.com/d'  /etc/apt/sources.list && \
	sh -c 'echo "deb http://repo.percona.com/apt trusty main" >> /etc/apt/sources.list' && \
	sh -c 'echo "deb-src http://repo.percona.com/apt trusty main" >> /etc/apt/sources.list'
RUN apt-get update
RUN LC_ALL=en_US.utf8 DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::='--force-confnew' -y install $PACKAGE

## configure MySQL
RUN sed -i 's/^\(bind-address\s.*\)/# \1/' /etc/mysql/my.cnf

## post-installation: setting up Apache
RUN cp -f /var/www/html/cmonapi/ssl/server.crt /etc/ssl/certs/s9server.crt && \
	cp -f /var/www/html/cmonapi/ssl/server.key /etc/ssl/private/s9server.key && \
	rm -rf /var/www/html/cmonapi/ssl && \
	cp -f /var/www/html/clustercontrol/app/tools/apache2/s9s.conf /etc/apache2/sites-available/ && \
	cp -f /var/www/html/clustercontrol/app/tools/apache2/s9s-ssl.conf /etc/apache2/sites-available/ && \
	rm -f /etc/apache2/sites-enabled/000-default.conf && \
	rm -f /etc/apache2/sites-enabled/default-ssl.conf && \
	rm -f /etc/apache2/sites-enabled/001-default-ssl.conf && \
	ln -sfn /etc/apache2/sites-available/s9s.conf /etc/apache2/sites-enabled/001-s9s.conf && \
	ln -sfn /etc/apache2/sites-available/s9s-ssl.conf /etc/apache2/sites-enabled/001-s9s-ssl.conf && \
	sed -i 's|^[ \t]*SSLCertificateFile.*|SSLCertificateFile /etc/ssl/certs/s9server.crt|g' /etc/apache2/sites-available/s9s-ssl.conf && \
	sed -i 's|^[ \t]*SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/ssl/private/s9server.key|g' /etc/apache2/sites-available/s9s-ssl.conf

# prepare config files
RUN cp -f /var/www/html/clustercontrol/bootstrap.php.default /var/www/html/clustercontrol/bootstrap.php && \
	cp -f /var/www/html/cmonapi/config/bootstrap.php.default /var/www/html/cmonapi/config/bootstrap.php && \
	cp -f /var/www/html/cmonapi/config/database.php.default /var/www/html/cmonapi/config/database.php && \
	chmod -R 777 /var/www/html/clustercontrol/app/tmp && \
	chmod -R 777 /var/www/html/clustercontrol/app/upload && \
	chown -Rf www-data.www-data /var/www/html/cmonapi/ && \
	chown -Rf www-data.www-data /var/www/html/clustercontrol/

# enable modules and site
RUN a2enmod ssl && \
	a2enmod rewrite && \
	a2ensite default-ssl

ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid
ENV APACHE_RUN_DIR /var/run/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_SERVERADMIN admin@localhost
ENV APACHE_SERVERNAME localhost
ENV APACHE_SERVERALIAS docker.localhost
ENV APACHE_DOCUMENTROOT /var/www/html

VOLUME ["/var/www/html","/var/lib/mysql","/etc"]

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

## cmon 9500, netcat 9999, haproxy-stats 9600
EXPOSE 22 443 3306 80 9500 9999 9600
