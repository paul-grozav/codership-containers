#!/usr/bin/env bash
#
# ENV variables:
# MYSQL_USER
# MYSQL_ROOT_PASSWORD
# MYSQL_DATABASE
# MYSQL_ALLOW_EMPTY_PASSWORD
# MYSQL_INITDB_TZINFO
# MYSQL_INITDB_SKIP_TZINFO
# MYSQL_ROOT_HOST
# PRODUCT
#
set -ex
#
[[ ${IMAGEDEBUG:-0} -eq 1 ]] && set -x
#
PRODUCT="mysql-wsrep"
INITDBDIR="/codership-initdb.d"
INIT_MARKER="/var/lib/mysql/codership-init.completed"
# Allowed values are <user-defined password>, RANDOM, EMPTY
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-RANDOM}
[[ ${MYSQL_ALLOW_EMPTY_PASSWORD:-0} -eq 1 ]] && MYSQL_ROOT_PASSWORD=EMPTY
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
if [[ "${1:0:1}" = '-' ]] || [[ -z "${1:0:1}" ]]; then
  set -- ${MYSQL_SERVER} "${@}"
fi
#
function message {
  echo "[Init message]: ${@}"
}
#
function error {
  echo >&2 "[Init ERROR]: ${@}"
}
function warning {
  echo >&2 "[Init WARNING]: ${@}"
}
#
function validate_cfg {
  local RES=0
  local CMD="exec gosu ${MYSQL_SYSUSER} ${@} --verbose --help --log-bin-index=$(mktemp -u)"
  local OUT=$(${CMD}) || RES=${?}
  if [ ${RES} -ne 0 ]; then
    error "Config validation error, please check your configuration!"
    error "Command failed: ${CMD}"
    error "Error output: ${OUT}"
    exit 1
  fi
}
#
function get_cfg_value {
  local conf="${1}"; shift
  "${@}" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | grep "^$conf " | awk '{ print $2 }'
}
#
function start_server {
  exec gosu ${MYSQL_SYSUSER} "$@" 2>&1 | tee -a /var/log/codership-error.log
}
#########
if [[ -f ${INIT_MARKER} ]]; then
  start_server "$@"
  exit ${?}
fi
#########
#
message "Preparing ${PRODUCT}..."
#
DATADIR="$(get_cfg_value 'datadir' "$@")"
#
if [[ ! -d "${DATADIR}/${MYSQL_DB}" ]]; then
  message "Initializing database..."
  ${MYSQL_INSTALL_DB} --auth-root-socket-user=${MYSQL_SYSUSER} --datadir="${DATADIR}" --rpm "${@:2}"
  message 'Database initialized'
fi
#
chown -R ${MYSQL_SYSUSER}:${MYSQL_SYSUSER} "${DATADIR}"
#
message "Searching for custom MYSQL configs in ${INITDBDIR}..."
CFGS=$(find "${INITDBDIR}" -name '*.cnf')
if [[ -n "${CFGS}" ]]; then
  cp -vf "${CFGS}" /etc/my.cnf.d/
fi
#
message "Validating configuration..."
validate_cfg "${@}"
SOCKET="$(get_cfg_value 'socket' "$@")"
gosu ${MYSQL_SYSUSER} "$@" --skip-networking --socket="${SOCKET}" &
PID="${!}"
MYSQL=( ${MYSQL_CLIENT} --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" )

for second in {30..0}; do
  [[ ${second} -eq 0 ]] && error 'MYSQL Enterprise Server failed to start!' &&  exit 1
  if echo 'SELECT 1' | "${MYSQL[@]}" &> /dev/null; then
    break
  fi
  message "Bringing up ${PRODUCT}..."
  sleep 1
done
#
if [[ "${MYSQL_INITDB_TZINFO}" -eq 1 ]]; then
  message "Loading TZINFO..."
  ${MYSQL_TZINFOTOSQL} /usr/share/zoneinfo | "${MYSQL[@]}" ${MYSQL_DB}
fi
#
if [[ "${MYSQL_ROOT_PASSWORD}" = RANDOM ]]; then
  MYSQL_ROOT_PASSWORD="'"
  while [[ "${MYSQL_ROOT_PASSWORD}" = *"'"* ]] || [[ "${MYSQL_ROOT_PASSWORD}" = *"\\"* ]]; do
    export MYSQL_ROOT_PASSWORD="$(pwgen -scny -r \'\"\\\/\; 32 1)"
  done
  message "=-> GENERATED ROOT PASSWORD: ${MYSQL_ROOT_PASSWORD}"
fi
#
if [[ "${MYSQL_ROOT_PASSWORD}" = EMPTY ]]; then
  warning "=-> Warning! Warning! Warning!"
  warning "EMPTY password is specified for image, your container is insecure!!!"
fi
#
if [[ -n "${MYSQL_DATABASE}" ]]; then
  message "Trying to create database ${MYSQL_DATABASE}"
  echo "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`" | "${MYSQL[@]}"
fi
#
if [[ -n "${MYSQL_USER}" ]] && [[ -n "${MYSQL_ROOT_PASSWORD}" ]]; then
  message "Trying to create user ${MYSQL_USER} with password set"
  echo "CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" | "${MYSQL[@]}"
  if [[ -n "${MYSQL_DATABASE}" ]]; then
    message "Trying to set all privileges on ${MYSQL_DATABASE} to ${MYSQL_USER}..."
    echo "GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';" | "${MYSQL[@]}"
  fi
else
  message "Skipping MYSQL user creation, both MYSQL_USER and MYSQL_ROOT_PASSWORD must be set"
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
      "${MYSQL[@]}" < "${_file}"
      echo
      ;;
    *.sql.gz)
      message "Running compressed SQL file ${_file}"
      zcat "${_file}" | "${MYSQL[@]}"
      echo
      ;;
    *)
      message "Ignoring ${_file}"
      ;;
  esac
done
#
# Reading password from docker filesystem (bind-mounted directory or file added during build)
[[ -z "${MYSQL_ROOT_HOST}" ]] && MYSQL_ROOT_HOST='%'
[[ -f "${MYSQL_ROOT_PASSWORD}" ]] && MYSQL_ROOT_PASSWORD=$(cat "${MYSQL_ROOT_PASSWORD}")
if [[ "${MYSQL_ROOT_PASSWORD}" != EMPTY ]]; then
  message "ROOT password has been specified for image, trying to update account..."
  echo "CREATE USER IF NOT EXISTS 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" | "${MYSQL[@]}"
  echo "GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION;" | "${MYSQL[@]}"
  echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;" | "${MYSQL[@]}"
fi
#
###
if ! kill -s TERM "${PID}" || ! wait "${PID}"; then
  error "${PRODUCT} init process failed!"
  exit 1
fi
#
# Finally
message "${PRODUCT} is ready for start!"
touch ${INIT_MARKER}
#
start_server "$@"










