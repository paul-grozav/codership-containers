# wsrep-aware docker image for MySQL

## Usage

### Basic
Basic usage follows conventions for the official MySQL docker image (*aside from tags!*), so for reference look here: https://hub.docker.com/_/mysql

### Clustering
Using a dedicated bridge or overlay network is required, e.g.:
```
$ docker network create <some-network>
```

`WSREP_JOIN` enviroment variable introduced. When started without this variable specified, the container initiates a new cluster:
```
docker run -d --network <some-network> --name node1 ... <image tag>
```
To join a cluster of nodes:
```
docker run -d --network <some-network> --name node2 -e WSREP_JOIN=node1,node2,node3 ... <image tag>
```
where `node0,node1,node2` is a comma-separated list of running containers' names. It should contain at least one node from primary configuration, but does not need to list all.

If container stops (server crashes or deliberate stop) **DO NOT** restart the container! Delete stopped container and create a new one to join the remaining nodes.

When adding a node to the cluster always use exactly the same image tag as the othe cluster nodes. Never use "latest".

### Upgrading a cluster to another release (tag)

 1. Add new nodes with the new tag to the existing cluster but don't use them for client connections.
 2. Stop and remove old nodes.
 3. Now new nodes are safe to use.

