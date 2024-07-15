FROM rockylinux:9

## image description
LABEL maintainer="Severalnines AB"
LABEL contact="support@severalnines.com"
LABEL github-repo="https://github.com/severalnines/docker"
LABEL description="ClusterControl container image"
LABEL release="2.1.0"
LABEL version="2.1.0-9571"
LABEL release-date="July 9th, 2024"

# install packages
RUN dnf clean all
RUN dnf -y install wget epel-release && \
  dnf -y install http://rpms.famillecollet.com/enterprise/remi-release-9.rpm && \
  rpm --import http://repo.severalnines.com/severalnines-repos.asc && \
  wget --no-check-certificate https://severalnines.com/downloads/cmon/s9s-repo.repo -P /etc/yum.repos.d/ && \
  wget --no-check-certificate https://repo.severalnines.com/s9s-tools/RHEL_9/s9s-tools.repo -P /etc/yum.repos.d/ && \
  dnf -y module switch-to php:remi-7.4 && \
  dnf -y install clustercontrol-controller clustercontrol clustercontrol2 clustercontrol-ssh clustercontrol-notifications clustercontrol-cloud clustercontrol-clud s9s-tools \
  httpd php php-mysql php-ldap php-gd php-curl mod_ssl openssh-clients openldap-clients mariadb-server mariadb \
  supervisor sudo socat iproute s-nail cronie nc bind-utils dmidecode python procps-ng && \
  yum clean all

# install Prometheus suite
ENV STAGING_DIR /root/packages
RUN mkdir -p ${STAGING_DIR} && \
  wget http://libslack.org/daemon/download/daemon-0.6.4-1.x86_64.rpm -P ${STAGING_DIR} && \
  wget https://github.com/prometheus/prometheus/releases/download/v2.47.1/prometheus-2.47.1.linux-amd64.tar.gz -P ${STAGING_DIR} && \
  wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz -P ${STAGING_DIR} && \
  wget https://github.com/severalnines/process_exporter/releases/download/0.10.10/process_exporter-0.10.10.linux-amd64.tar.gz -P ${STAGING_DIR} && \
  cd ${STAGING_DIR} && \
  tar -xzf prometheus-*.linux-amd64.tar.gz && \
  cp prometheus*/prometheus /usr/local/bin/ && \
  cp prometheus*/promtool /usr/local/bin/ && \
  tar -xzf node_exporter*.tar.gz && \
  cp node_exporter*/node_exporter /usr/local/bin/ && \
  tar -xzf process_exporter*.tar.gz && \
  cp process_exporter*/process_exporter /usr/local/bin/ && \
  dnf -y localinstall daemon*.rpm && \
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
  mkdir -p /run/php-fpm && \
  mkdir /root/backups

## persistent volumes
VOLUME ["/etc/cmon.d","/var/lib/mysql","/etc/cmon/templates","/root/.ssh","/var/lib/cmon"]

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 80 443 9500 9501 9510 9511 9999 9443
HEALTHCHECK CMD curl -sSf http://localhost/ > /dev/null || exit 1

