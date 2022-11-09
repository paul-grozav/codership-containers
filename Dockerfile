FROM rockylinux:8-minimal

LABEL org.opencontainers.image.authors="info@galeracluster.com"

ARG MYSQL_VERSION=8.0.28-26.10
ARG OS_VERSION=el8

ADD *.repo /etc/yum.repos.d

RUN rpm --import http://releases.galeracluster.com/GPG-KEY-galeracluster.com; \
  microdnf -y install epel-release; \
  microdnf -y install galera-4 mysql-wsrep-server-${MYSQL_VERSION}.${OS_VERSION}

# Cleanup & create
RUN rpm -e --nodeps mysql-wsrep-client mysql-wsrep-client-plugins; \
  microdnf clean all; \
  rm -rf /var/cache/dnf /var/cache/yum /usr/lib/.build-id; \
  rm -rf /var/cache/dnf /var/cache/yum /var/lib/mysql; \
  mkdir -p /var/lib/mysql /var/log/mysql; \
  chown mysql:mysql /var/lib/mysql /var/log/mysql

# Config files
ADD entrypoint.sh /
ADD codership.cnf /etc/my.cnf.d/
RUN echo '!includedir /etc/my.cnf.d/' >> /etc/my.cnf;

USER mysql
VOLUME [/var/lib/mysql /var/log/mysql]
# ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 3306/tcp 33060/tcp 4567/tcp 4568/tcp
CMD ["mysqld"]
