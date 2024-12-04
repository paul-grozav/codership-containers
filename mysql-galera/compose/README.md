# What is it?
Sample docker compose file to launch 3-node cluster using MySQL-Galera docker
image

# Usage
Create `.env` file containing required parameters, e.g.:
```
NODE_IMAGE='codership/mysql-galera-test:8.0.40'
RUN_AS=1000:100

MYSQL_USER='test'
MYSQL_PASSWORD='testpass'
```
For all supported parameters see `../image/entrypoint.sh`

Run:
```
$ docker compose up
```
