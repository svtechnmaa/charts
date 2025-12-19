## Altinity Clickhouse Helm Chart 

##### Installation

```bash
git clone .../charts.git
cd ./charts/kubernetes/clickhouse
vi values.yaml # Modify values to suit your needs
helm dep build
helm install clickhouse . \
        --namespace clickhouse \
        --create-namespace
```

##### Uninstallation

```bash
helm un clickhouse -n clickhouse
kubectl delete ns clickhouse # this will be hang, remove finalizer from chi
kubectl edit chi clickhouse -n clickhouse
```