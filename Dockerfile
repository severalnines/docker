## ClusterControl 1.9.5-5827, Percona Server 5.6, CentOS 7 64bit, PHP 7.3 (Remi)

FROM centos:7
MAINTAINER Ashraf Sharif <ashraf@severalnines.com>

## list of packages to be installed by package manager
ENV PACKAGES curl mailx cronie nc bind-utils clustercontrol clustercontrol2 clustercontrol-controller clustercontrol-notifications clustercontrol-ssh clustercontrol-cloud clustercontrol-clud Percona-Server-server-56 openssh-clients openssh-server httpd php php-mysql php-ldap php-gd php-curl mod_ssl s9s-tools sudo python-setuptools sysvinit-tools iproute socat python-pip

# install packages
RUN yum clean all
RUN yum -y install wget epel-release && \
        rpm --import http://repo.severalnines.com/severalnines-repos.asc && \
        wget http://severalnines.com/downloads/cmon/s9s-repo.repo -P /etc/yum.repos.d/ && \
        wget http://repo.severalnines.com/s9s-tools/CentOS_7/s9s-tools.repo -P /etc/yum.repos.d/ && \
        yum -y install http://rpms.famillecollet.com/enterprise/remi-release-7.rpm && \
        sed -i s/enabled=0/enabled=1/g /etc/yum.repos.d/remi-php73.repo && \
        yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm && \
        yum -y install ${PACKAGES} && \
        pip install supervisor && \
	yum -y --disablerepo=epel upgrade nss ca-certificates openssl && \
        yum clean all

# install Prometheus suite
ENV STAGING_DIR /root/packages
RUN mkdir -p ${STAGING_DIR} && \
        wget http://libslack.org/daemon/download/daemon-0.6.4-1.x86_64.rpm -P ${STAGING_DIR} && \
        wget https://github.com/prometheus/prometheus/releases/download/v2.29.2/prometheus-2.29.2.linux-amd64.tar.gz -P ${STAGING_DIR} && \
        wget https://github.com/prometheus/node_exporter/releases/download/v1.0.1/node_exporter-1.0.1.linux-amd64.tar.gz -P ${STAGING_DIR} && \
        wget https://github.com/kedazo/process_exporter/releases/download/0.10.10/process_exporter-0.10.10.linux-amd64.tar.gz -P ${STAGING_DIR} && \
        cd ${STAGING_DIR} && \
        tar -xzf prometheus-*.linux-amd64.tar.gz && \
        cp prometheus*/prometheus /usr/local/bin/ && \
        cp prometheus*/promtool /usr/local/bin/ && \
        tar -xzf node_exporter*.tar.gz && \
        cp node_exporter*/node_exporter /usr/local/bin/ && \
        tar -xzf process_exporter*.tar.gz && \
        cp process_exporter*/process_exporter /usr/local/bin/ && \
        yum -y localinstall daemon* && \
        useradd --no-create-home --shell /bin/false prometheus && \
        mkdir -p /etc/prometheus && \
        mkdir /var/lib/prometheus && \
        chown prometheus:prometheus /usr/local/bin/prometheus && \
        chown prometheus:prometheus /usr/local/bin/promtool && \
        chown prometheus:prometheus /etc/prometheus && \
        chown prometheus:prometheus /var/lib/prometheus && \
        chown prometheus:prometheus /usr/local/bin/process_exporter && \
        rm -Rf ${STAGING_DIR}

## add configuration files
ADD conf/my.cnf /etc/my.cnf
ADD conf/supervisord.conf /etc/supervisord.conf
ADD conf/s9s.conf /etc/httpd/conf.d/s9s.conf
ADD conf/ssl.conf /etc/httpd/conf.d/ssl.conf
ADD conf/cc-frontend.conf /etc/httpd/conf.d/cc-frontend.conf
ADD conf/cc-proxy.conf /etc/httpd/conf.d/cc-proxy.conf

## post-installation: setting up Apache
RUN mv /var/www/html/clustercontrol/ssl/server.crt /etc/pki/tls/certs/s9server.crt && \
        mv /var/www/html/clustercontrol/ssl/server.key /etc/pki/tls/private/s9server.key && \
        sed -i 's|AllowOverride None|AllowOverride All|g' /etc/httpd/conf/httpd.conf && \
        cp -f /var/www/html/clustercontrol/bootstrap.php.default /var/www/html/clustercontrol/bootstrap.php && \
        chmod -R 777 /var/www/html/clustercontrol/app/tmp && \
        chmod -R 777 /var/www/html/clustercontrol/app/upload && \
        chown -Rf apache:apache /var/www/html/clustercontrol/ && \
        mkdir /root/backups

VOLUME ["/etc/cmon.d","/var/lib/mysql","/root/.ssh","/var/lib/cmon"]

COPY change_ip.sh /root/change_ip.sh
COPY entrypoint.sh /entrypoint.sh
COPY deploy-container.sh /deploy-container.sh
ENTRYPOINT ["/entrypoint.sh"]

## cmon 9500, cmon-tls 9501, cmon-events 9510, cmon-ssh 9511, netcat 9999
EXPOSE 80 443 9500 9501 9510 9511 9999 19501 9443
HEALTHCHECK CMD curl -sSf http://localhost/clustercontrol/ > /dev/null || exit 1
