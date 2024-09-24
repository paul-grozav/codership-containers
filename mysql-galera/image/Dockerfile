ARG RH_VERSION=
FROM redhat/ubi${RH_VERSION}-minimal

LABEL org.opencontainers.image.authors="info@galeracluster.com"

ARG RH_VERSION=
ARG MYSQL_RPM_VERSION=
ARG GALERA_RPM_VERSION=4
ARG GOSU_VERSION=1.16
ARG DEBUG_UTILS="less iputils bind-utils"
ARG RSYNC_SST_DEPS="rsync lsof which"

# Create mysql user.group with predefined IDs
# (later may be useful for mounting volumes)
ENV USER='mysql'
ENV UID='1000'
ENV DNF=microdnf

ADD *.repo /etc/yum.repos.d

RUN set -eu; \
  sed -i s/MYSQL_RPM_VERSION/mysql-wsrep-${MYSQL_RPM_VERSION}/ /etc/yum.repos.d/Codership.repo; \
  sed -i s/GALERA_RPM_VERSION/galera-${GALERA_RPM_VERSION}/ /etc/yum.repos.d/Codership.repo; \
  ${DNF} -y install shadow-utils; \
  groupadd -g ${UID} ${USER}; \
  useradd -M -s '/sbin/nologin' -g ${USER} -u ${UID} ${USER}; \
  rpm --import https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-${RH_VERSION}; \
  rpm --import http://releases.galeracluster.com/GPG-KEY-galeracluster.com; \
  ${DNF} install -y \
  tzdata \
  hostname \
  findutils \
  galera-${GALERA_RPM_VERSION} \
  mysql-wsrep-server-${MYSQL_RPM_VERSION}.el${RH_VERSION} \
  ${RSYNC_SST_DEPS} \
  ${DEBUG_UTILS} \
  ; \
  ${DNF} clean all; \
  rm -rf /var/cache/dnf /var/cache/yum /usr/lib/.build-id; \
  rm -rf /var/cache/dnf /var/cache/yum /var/lib/mysql;

RUN set -eu; \
  mkdir -p /var/lib/mysql; \
  chown mysql:mysql /var/lib/mysql; \
  touch /var/lib/mysql/mysqld.err; \
  chown mysql:mysql /var/lib/mysql/mysqld.err; \
  chmod 600 /var/lib/mysql/mysqld.err

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
