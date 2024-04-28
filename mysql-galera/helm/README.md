# HELM charts for MyDQL/Galera cluster

## Common usage:
```
helm install [set values] <cluster name> .
```
see values.yaml for supported/required oprtions.

### Setting values for Docker image
On `helm install` you will need to set some environmet variables for the image, e.g.
```
--set env.MYSQL_ROOT_PASSWORD=<value> --set env.MYSQL_USER=<value> --set env.MYSQL_PASSWORD=<value>
```
For all variables see https://hub.docker.com/_/mysql. Not all of them are supported, e.g. datadir mount point is fixed.

These variables will be used to initialize the database if not yet initialized. Otherwise MYSQL_USER and MYSQL_PASSWORD will be used for the readiness probe so they must be specified on all chart installs. MYSQL_ROOT_PASSWORD is used only once for database initialization.

### Requesting kubernetes resources for pods
The usual kubernetes stuff:
```
--set resorces.requests.memory=4Gi --set resources.requests.storage=16Gi --set resources.requests.cpu=4
```

### Connecting to cluster
By default MySQL client service is open through load balancer on port 30006. It can be changed by:
```
--set service,port=NNNN
```

### Graceful cluster shutdown
Graceful cluster shutdown requires scaling the cluster to one node before `helm uninstall`:
```
helm upgrade --reuse-values --set replicas=1 <cluster name> .
mysql <options> -e "shutdown;"
helm uninistall <cluster name>
```
This will leave the last pod in the stateful set (0) safe to autoatically bootstrap the cluster from.

### Force bootstrap from a particular pod
In case of a catastrophic failure (something other than graceful shutdown, cluster won't recover by itself), it can be forced to bootstrap from a particular pod. To find which pod to use the cluster can be started in "recover-only" mode:
```
helm install --set env.WSREP_RECOVER_ONLY <cluster name> .
```
Then
```
kubectl logs <pod name> | grep 'Recovered position'
```
shall print diagnostic output showing pod position in replication history. Most updated pod should be chosen as a bootstrap node.
`find_most_updated.sh` script can help to identify the right pod.

After the bootstrap pod has been identified the cluster can be bootstrapped like
```
helm install --set env.MYSQL_USER=... --set env.MYSQL_PASSWORD=... --set env.WSREP_BOOTSTRAP_FROM=<pod number, 0 to n-1> <cluster name> .
```
after that it the variable should be unset to prevent unintended cluster bootsrap:
```
helm upgrade --reuse-values --set env.WSREP_BOOTSTRAP_FROM= <cluster name> .
```
This will cause a quick round-robin set restart after which the cluster is ready to use.
