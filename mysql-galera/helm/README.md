# HELM charts for MyDQL/Galera cluster

## Common usage:
```
helm install [set values] --set storageClass=<value> <cluster name> .
```
see values.yaml for supported/required oprtions.

By default MySQL client service is open through load balancer on port 30006.

### Setting values for Docker image
On first cluster creation you will need to set some environmet variables for the image, e.g.
```
--set env.MYSQL_ROOT_PASSWORD=<value> --set env.MYSQL_USER=<value> --set env.MYSQL_PASSWORD=<value>
```
For all variables see https://hub.docker.com/_/mysql. Not all of them are supported, e.g. datadir mount point is fixed.

### Requesting kubernetes resources for pods
```
--set resorces.requests.memory=4Gi --set resources.requests.storage=16Gi --set resources.requests.cpu=4
```

## Provider specific usage

### Minikube
```
--set storageClass=minikube
```

### Amazon EKS (not fully suported yet)
```
--set storageClass=efs
```
