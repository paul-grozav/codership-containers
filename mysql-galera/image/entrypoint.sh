#!/usr/bin/env bash
#
# ENV variables:
# MYSQL_USER
# MYSQL_PASSWORD
# MYSQL_DATABASE
# MYSQL_ALLOW_EMPTY_PASSWORD
# MYSQL_INITDB_TZINFO
# MYSQL_INITDB_SKIP_TZINFO
# MYSQL_ROOT_HOST
# MYSQL_ROOT_PASSWORD
# PRODUCT
# WSREP_JOIN - a list of node addresses to join in a cluster
#
set -euo pipefail
#
[[ ${IMAGEDEBUG:-0} -eq 1 ]] && set -x
#
PRODUCT="mysql-wsrep"
INITDBDIR="/codership-initdb.d"
# Allowed values are <user-defined password>, RANDOM, EMPTY
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-RANDOM}
[[ ${MYSQL_ALLOW_EMPTY_PASSWORD:-0} -eq 1 ]] && MYSQL_ROOT_PASSWORD="EMPTY"
#
MYSQL_INITDB_TZINFO=${MYSQL_INITDB_TZINFO:-1}
#
MYSQL_DB=mysql
MYSQL_SYSUSER=mysql
#
MYSQL_CLIENT=mysql
MYSQL_SERVER=mysqld
MYSQL_INSTALL_DB=mysql_install_db
MYSQL_TZINFOTOSQL=mysql_tzinfo_to_sql
#
# if command starts with an option, prepend mysqld
if [[ "${1:0:1}" = '-' ]] || [[ -z "${1:0:1}" ]]; then
  set -- ${MYSQL_SERVER} "${@}"
fi
#
timestamp() {
  date +%Y%m%d\ %H:%M:%S.%N | cut -b -21
}
#
message() {
  echo "$(timestamp) [Init message]: ${@}"
}
#
error() {
  echo >&2 "$(timestamp) [Init ERROR]: ${@}"
}
#
warning() {
  echo >&2 "$(timestamp)[Init WARNING]: ${@}"
}
#
# Dump some useful info into the container log to simplify debugging
# in case of error
debug_exit() {
  rcode=${1}
  if [[ $rcode -ne 0 ]]; then
    echo "Error detected. Some diagnostic info below:"
    echo "id:"
    id
    echo
    echo "ls -l ${DATADIR}:"
    ls -l ${DATADIR} || :
    echo
    echo "tail -n1024 ${LOG_ERROR}"
    tail -n1024 ${LOG_ERROR} || :
    echo
    echo "journalctl -xe --no-pager"
    journalctl -xe --no-pager
  fi
  exit $rcode
}
#
# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"
  if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
    mysql_error "Both $var and $fileVar are set (but are exclusive)"
  fi
  local val="$def"
  if [ "${!var:-}" ]; then
    val="${!var}"
  elif [ "${!fileVar:-}" ]; then
    val="$(< "${!fileVar}")"
  fi
  export "$var"="$val"
  unset "$fileVar"
}
#
validate_cfg() {
  local CMD="${@} --verbose --help --log-bin-index=$(mktemp -u)"
  local OUT=$(${CMD} 2>&1 1>/dev/null || echo $?)
  if [ -n "${OUT}" ]; then
    error "Config validation error, please check your configuration!"
    error "Command failed: ${CMD}"
    error "Error output: ${OUT}"
    exit 1
  fi
}
#
get_cfg_value() {
  local conf="${1}"; shift
  "${@}" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | grep "^$conf " | awk '{ print $2 }'
}
#
start_server() {
  message "Starting '$@'"
  # sleep a bit in case we just crashed and are restarting
  # to allow the remaining nodes to form a new PC in peace
  sleep 3
  # start the process and in case of error dump significant
  # part of error log to stderr for quicker debugging
	if [ "$(id -u)" = "0" ]; then
		message "Switching to dedicated user 'mysql'"
		exec gosu mysql "$@" 2>&1 || debug_exit $?
  else
    exec "$@" 2>&1 || debug_exit $?
	fi
}
#
message "Preparing ${PRODUCT}..."
#
message "Searching for custom MYSQL_CMD configs in ${INITDBDIR}..."
CFGS=$(find "${INITDBDIR}" -name '*.cnf')
if [[ -n "${CFGS}" ]]; then
  cp -vf "${CFGS}" /etc/mysql/conf.d/
fi
#
message "Validating configuration..."
validate_cfg "${@}"
DATADIR="$(get_cfg_value 'datadir' "$@")"
DATADIR=${DATADIR%/} # strip the trailing '/' if any
# Make sure error log is stored on persistent volume
LOG_ERROR="${DATADIR}/mysqld.err"
set -- "$@" "--log-error=${LOG_ERROR}"
INIT_MARKER="${DATADIR}/grastate.dat"
#
#################################################
# If database is initialized - recover position #
#################################################
if [[ -f ${INIT_MARKER} ]]; then
  message "Recovering data directory..."
  find /usr -name 'wsrep_recover' && \
  WSREP_POSITION_OPTION=$(wsrep_recover) && \
  set -- "$@" "${WSREP_POSITION_OPTION}"
fi
#################################################
# If WSREP_JOIN is not set but we run in a      #
# Kubernetes pod then assume StatefulSet and    #
# construct WSREP_JOIN ourselves                #
#################################################
if [[ -z ${WSREP_JOIN:=} && -n ${KUBERNETES_SERVICE_HOST:=} ]]; then
  IFS='.'; my_fqdn=($(hostname -f)); unset IFS
  my_name=${my_fqdn[0]}
  my_ordinal=${my_name##*-}
  state_file="${DATADIR}/grastate.dat"

  safe_to_bootstrap=
  if [[ -n "${WSREP_BOOTSTRAP_FROM:=}" ]]; then
    # force bootstrap from a given node
    [[ ${WSREP_BOOTSTRAP_FROM} -eq ${my_ordinal} ]] \
      && safe_to_bootstrap=1 || safe_to_bootstrap=0
    # rewrite state file if present
    [[ -r ${state_file} ]] && \
      sed -i "s/safe_to_bootstrap: [0-9]/safe_to_bootstrap: $safe_to_bootstrap/" \
      ${state_file}
  fi

  [[ -z "${safe_to_bootstrap}" ]] && \
    safe_to_bootstrap=$(grep -s 'safe_to_bootstrap' ${state_file} | cut -d ' ' -f 2) || :
  # if there is no state file and my ordinal is 0 then it is the first start
  # of the first node
  [[ -z "${safe_to_bootstrap}" && ${my_ordinal} -eq 0 ]] && safe_to_bootstrap=1

  if [[ ${safe_to_bootstrap} -ne 1 ]]; then
    # must join others, construct WSREP_JOIN
    base_name=${my_name%-*}
    subdomain=${my_fqdn[1]}
    # there should be at least max(3, my_ordinal + 1) replicas
    # (numbered from 0, 3 is the minimum usable cluster size)
    [[ "${my_ordinal}" -le 2 ]] && max_ordinal=2 || max_ordinal=$((${my_ordinal} - 1))
    for i in $(seq 0 ${max_ordinal}); do
      if [[ $i -ne ${my_ordinal} ]]; then
        node_name="${base_name}-${i}.${subdomain}"
        [[ -z ${WSREP_JOIN} ]] && WSREP_JOIN="${node_name}" || WSREP_JOIN+=",${node_name}"
      fi
    done
  fi
  message "Running in Kubernetes: WSREP_JOIN=${WSREP_JOIN}, MEM_REQUEST=${MEM_REQUEST}, MEM_LIMIT=${MEM_LIMIT}"
#  export WSREP_JOIN="${WSREP_JOIN}"
fi
# set up readiness probe
if [[ -n ${KUBERNETES_SERVICE_HOST:=} ]]; then
  readiness_probe="${DATADIR}/k8s_readiness_probe"
  cat << EOF > "${readiness_probe}"
if [[ -n "\${MYSQL_PASSWORD}" ]]; then
  SYNCED=4
  export MYSQL_PWD="\${MYSQL_PASSWORD}"
  [[ \$(mysql -h\$HOSTNAME -u\$MYSQL_USER --disable-column-names -Be "SHOW STATUS LIKE 'wsrep_local_state'" | cut -f2) -eq \$SYNCED ]]
fi
EOF
  chmod 700 "${readiness_probe}"
fi
################################################# 
# If we are joining a cluster then skip         #
# initialization and start right away - we'll   #
# be getting state transfer anyways             #
#################################################
if [[ -n ${WSREP_JOIN} || -f ${INIT_MARKER} ]]; then
  if [[ -n ${WSREP_JOIN} ]]; then
    set -- "$@" "--wsrep-cluster-address=gcomm://${WSREP_JOIN}"
  else
    set -- "$@" "--wsrep-new-cluster"
  fi
  start_server "$@"
  exit ${?}
fi
################################################
# Need to initialize the database before start #
################################################
file_env 'MYSQL_ROOT_PASSWORD'
if [[ -z "${MYSQL_ROOT_PASSWORD}" && -z "${MYSQL_ALLOW_EMPTY_PASSWORD:=}" && -z "${MYSQL_RANDOM_ROOT_PASSWORD:=}" ]]; then
  echo >&2 'error: database is uninitialized and password option is not specified '
  echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
  exit 1
fi
#
if [[ ! -d "${DATADIR}/${MYSQL_DB}" ]]; then
  rm -rf $DATADIR/* && mkdir -p "$DATADIR"

  message "Initializing data directory..."
  "$@" --initialize-insecure --tls-version='' || debug_exit $?
  message 'Data directory initialized'
fi
#
SOCKET="$(get_cfg_value 'socket' "$@")"
"$@" --skip-networking --socket="${SOCKET}" --wsrep-provider="none" &
PID="${!}"

MYSQL_CMD=( ${MYSQL_CLIENT} --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" )
STARTED=0
while ps -uh --pid ${PID} > /dev/null; do
  if echo "SELECT @@wsrep_on;" | "${MYSQL_CMD[@]}" >/dev/null; then
    STARTED=1
    break
  fi
  message "${PRODUCT} initialization startup in progress..."
  sleep 1
done
if [[ "${STARTED}" -eq 0 ]]; then
  error "${PRODUCT} failed to start!"
  debug_exit 1
fi
#
if [[ "${MYSQL_INITDB_TZINFO}" -eq 1 ]]; then
  message "Loading TZINFO..."
  # sed is for https://bugs.mysql.com/bug.php?id=20545
  ${MYSQL_TZINFOTOSQL} /usr/share/zoneinfo \
  | sed 's/Local time zone must be set--see zic manual page/FCTY/' \
  | "${MYSQL_CMD[@]}" ${MYSQL_DB}
fi
#
file_env 'MYSQL_DATABASE'
if [[ -n "${MYSQL_DATABASE}" ]]; then
  message "Creating database ${MYSQL_DATABASE}"
  echo "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`" | "${MYSQL_CMD[@]}"
fi
#
file_env 'MYSQL_USER'
file_env 'MYSQL_PASSWORD'
if [[ -n "${MYSQL_USER}" ]] && [[ -n "${MYSQL_PASSWORD}" ]]; then
  message "Creating user ${MYSQL_USER} with password set"
  echo "CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';" | "${MYSQL_CMD[@]}"
  if [[ -n "${MYSQL_DATABASE}" ]]; then
    message "Giving all privileges on ${MYSQL_DATABASE} to ${MYSQL_USER}..."
    echo "GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';" | "${MYSQL_CMD[@]}"
  fi
  echo 'FLUSH PRIVILEGES ;' | "${MYSQL_CMD[@]}"
else
  message "Skipping MYSQL user creation, both MYSQL_USER and MYSQL_PASSWORD must be set"
fi
#
for _file in "${INITDBDIR}"/*; do
  case "${_file}" in
    *.sh)
      message "Running shell script ${_file}"
      . "${_file}"
      ;;
    *.sql)
      message "Running SQL file ${_file}"
      "${MYSQL_CMD[@]}" < "${_file}"
      echo
      ;;
    *.sql.gz)
      message "Running compressed SQL file ${_file}"
      zcat "${_file}" | "${MYSQL_CMD[@]}"
      echo
      ;;
    *)
      message "Ignoring ${_file}"
      ;;
  esac
done
#
if [[ "${MYSQL_ROOT_PASSWORD}" = RANDOM || ! -z "${MYSQL_RANDOM_ROOT_PASSWORD:=}" ]]; then
  export MYSQL_ROOT_PASSWORD="$(openssl rand -base64 24)"
  echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
else
  if [[ "${MYSQL_ROOT_PASSWORD}" = EMPTY || ! -z "${MYSQL_ALLOW_EMPTY_PASSWORD:=}" ]]; then
    warning "=-> Warning! Warning! Warning!"
    warning "EMPTY password is specified for image, your container is insecure!!!"
  fi
fi
#
# Disable binlog for the setup session
ROOT_SETUP="SET @@SESSION.SQL_LOG_BIN=0; "
# Reading password from docker filesystem (bind-mounted directory or file added during build)
file_env 'MYSQL_ROOT_HOST' '%'
if [ ! -z "${MYSQL_ROOT_HOST}" -a "${MYSQL_ROOT_HOST}" != 'localhost' ]; then
  # no, we don't care if read finds a terminating character in this heredoc
  # https://unix.stackexchange.com/questions/265149/why-is-set-o-errexit-breaking-this-read-heredoc-expression/265151#265151
  read -r -d '' ROOT_SETUP <<- EOSQL || true
    ${ROOT_SETUP}
    CREATE USER 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; 
    GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION; 
EOSQL
  if [ ! -z "${MYSQL_ONETIME_PASSWORD:=}" ]; then
#  echo "ALTER USER 'root'@'%' PASSWORD EXPIRE;" | "${MYSQL_CMD[@]}"
    read -r -d '' ROOT_SETUP <<- EOSQL || true
    ${ROOT_SETUP}
    ALTER USER 'root'@'${MYSQL_ROOT_HOST}' PASSWORD EXPIRE; 
EOSQL
  fi
fi
if [[ "${MYSQL_ROOT_PASSWORD}" != EMPTY ]]; then
  message "ROOT password has been specified for image, updating account..."
#  echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" | "${MYSQL_CMD[@]}"
  read -r -d '' ROOT_SETUP <<- EOSQL || true
    ${ROOT_SETUP}
    GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION; 
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; 
EOSQL
fi
read -r -d '' ROOT_SETUP <<- EOSQL || true
  ${ROOT_SETUP}
  FLUSH PRIVILEGES;
EOSQL
#
echo "${ROOT_SETUP}" | ${MYSQL_CMD[@]}
#
if ! kill -s TERM "${PID}" || ! wait "${PID}"; then
  error "${PRODUCT} init process failed!"
  debug_exit 1
fi
#
# Finally
message "${PRODUCT} is starting!"
#
start_server "$@"
debug_exit $?
