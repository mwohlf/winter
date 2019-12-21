
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
