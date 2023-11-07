FROM rockylinux:8-minimal

LABEL org.opencontainers.image.authors="info@galeracluster.com"

ARG MYSQL_RPM_VERSION=
ARG OS_VERSION=el8
ARG GOSU_VERSION=1.16
ARG DEBUG_UTILS="less iputils bind-utils telnet"
ARG RSYNC_SST_DEPS="rsync lsof which"

# Create mysql user.group with predefined IDs
# (later may be useful for mounting volumes)
ENV USER='mysql'
ENV UID='1000'

ADD *.repo /etc/yum.repos.d

RUN set -eu; \
  microdnf -y install shadow-utils; \
  groupadd -g ${UID} ${USER}; \
  useradd -M -s '/sbin/nologin' -g ${USER} -u ${UID} ${USER}; \
  rpm --import http://releases.galeracluster.com/GPG-KEY-galeracluster.com; \
  microdnf -y install \
  hostname \
  findutils \
  tzdata \
  galera-4 \
  mysql-wsrep-server-${MYSQL_RPM_VERSION}.${OS_VERSION} \
  ${RSYNC_SST_DEPS} \
  ${DEBUG_UTILS} \
  ; \
  microdnf clean all; \
  rm -rf /var/cache/dnf /var/cache/yum /usr/lib/.build-id; \
  rm -rf /var/cache/dnf /var/cache/yum /var/lib/mysql

RUN set -eu; \
  mkdir -p /var/lib/mysql; \
  touch /var/log/mysqld.log; \
  chown mysql:mysql /var/lib/mysql /var/log/mysqld.log

## add gosu for easy step-down from root
RUN gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" \
    && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64.asc" \
    && gpg --verify /usr/local/bin/gosu.asc \
    && rm /usr/local/bin/gosu.asc \
    && rm -fr /root/.gnupg/ \
    && chmod +x /usr/local/bin/gosu

# Config files
RUN mkdir /codership-initdb.d
ADD 00-codership.cnf /etc/mysql/conf.d/
ADD 99-codership.cnf /etc/mysql/conf.d/
RUN echo '!includedir /etc/mysql/conf.d/' >> /etc/my.cnf;

USER ${USER}
VOLUME [ "/var/lib/mysql" ]
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 3306/tcp 33060/tcp

ADD entrypoint.sh /
CMD ["mysqld"]
