## readme

to install chart in a subdirector, use:
```
helm install postgresql-testing --dry-run --debug ./postgresql
```

to setup a remote chart repository:
```
helm repo add jetstack https://charts.jetstack.io
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update
```

to install a chart from a  chart repository:
```
helm install postgres stable/postgresql
```

to fetch chart and store in local dir:
```
helm fetch stable/postgresql
```

to initialize a simple helm chart:
```
helm create postgresql
```

to test a chart
```
helm lint ./postgresql
```

to upgrade a chart
```
helm upgrade postgres ./postgresql
```

other commands
```
# get the pods IP addresses
kubectl get pods -o yaml | grep podIP
```

### files and directories

* charts: This is an optional directory that may contain sub-charts
* templates: This is the directory where Kubernetes resources are defined as templates
* Chart.yaml: This is the main file that contains the description of our chart
* values.yaml: this is the file that contains the default values for our chart
* .helmignore: This is where we can define patterns to ignore when packaging (similar in concept to .gitignore)
