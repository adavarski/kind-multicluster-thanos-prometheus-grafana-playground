# KinD: Thanos ( Highly available Prometheus setup ) Lab multi-cluster


## Requirements

- Linux OS
- [Docker](https://docs.docker.com/)
- [KinD](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)


Run the `setup-clusters.sh` script. It creates three KinD clusters:

- One thanos cluster (`thanos`)
- Two remotes (`remote1`, `remote2`)

`kubectl` contexts are named respectively:

- `kind-thanos`
- `kind-remote1`
- `kind-remote2`


Example Output:

```

[+] Creating KinD clusters
   ⠿ [remote2] Cluster created
   ⠿ [remote1] Cluster created
   ⠿ [thanos] Cluster created
[+] Adding routes to other clusters
   ⠿ [thanos] Route to 10.20.0.0/24 added
   ⠿ [thanos] Route to 10.30.0.0/24 added
   ⠿ [remote1] Route to 10.10.0.0/24 added
   ⠿ [remote1] Route to 10.30.0.0/24 added
   ⠿ [remote2] Route to 10.10.0.0/24 added
   ⠿ [remote2] Route to 10.20.0.0/24 added
[+] Deploying MetalLB inside primary
   ⠿ [thanos] MetalLB deployed
[+] Deploying MetalLB inside clusters
   ⠿ [thanos] MetalLB deployed
   ⠿ [remote1] MetalLB deployed
   ⠿ [remote2] MetalLB deployed
```

We will deploy one Prometheus Operator for each workload cluster. In each workload cluster we will change the externalLabel of the cluster, so for workload remote1 we can use data-producer-1 and for workload remote2 we can use data-producer-2

```
$ kubectl config get-contexts 
CURRENT   NAME            CLUSTER         AUTHINFO        NAMESPACE
          kind-thanos   kind-thanos   kind-thanos   
          kind-remote1    kind-remote1    kind-remote1    
*         kind-remote2    kind-remote2    kind-remote2  


helm repo add bitnami https://charts.bitnami.com/bitnami

kubectl config use-context kind-remote1

helm install prometheus-operator \
  --set prometheus.thanos.create=true \
  --set operator.service.type=ClusterIP \
  --set prometheus.service.type=ClusterIP \
  --set alertmanager.service.type=ClusterIP \
  --set prometheus.thanos.service.type=LoadBalancer \
  --set prometheus.externalLabels.cluster="data-producer-1" \
  bitnami/kube-prometheus

kubectl config use-context kind-remote2

helm install prometheus-operator \
  --set prometheus.thanos.create=true \
  --set operator.service.type=ClusterIP \
  --set prometheus.service.type=ClusterIP \
  --set alertmanager.service.type=ClusterIP \
  --set prometheus.thanos.service.type=LoadBalancer \
  --set prometheus.externalLabels.cluster="data-producer-2" \
  bitnami/kube-prometheus


cd monitoring

$ kubectl config use-context kind-remote1
$ kubectl get svc --all-namespaces|grep thanos
default          prometheus-operator-kube-p-prometheus-thanos         LoadBalancer   10.255.20.171   172.19.255.30   10901:30621/TCP                102m
$ kubectl config use-context kind-remote2
$ kubectl get svc --all-namespaces|grep thanos
default          prometheus-operator-kube-p-prometheus-thanos         LoadBalancer   10.255.30.185   172.19.255.50   10901:30493/TCP                100m

Edit values.yaml (SIDECAR-SERVICE-IP-ADDRESS-1:10901 & SIDECAR-SERVICE-IP-ADDRESS-2:10901 -> 172.19.255.30:10901 & 172.19.255.50:10901)

kubectl config use-context kind-thanos
kubectl create ns monitoring


helm install thanos bitnami/thanos -n monitoring --values values.yaml
kubectl  get secret -n monitoring thanos-minio -o yaml -o jsonpath={.data.root-password} | base64 -d

Substitute this password by KEY in your values.yaml file, and upgrade the helm chart:

helm upgrade thanos bitnami/thanos -n monitoring \
  --values values.yaml

Example Output:
Release "thanos" has been upgraded. Happy Helming!
NAME: thanos
LAST DEPLOYED: Mon Jul 24 18:25:00 2023
NAMESPACE: monitoring
STATUS: deployed
REVISION: 3
TEST SUITE: None
NOTES:
CHART NAME: thanos
CHART VERSION: 12.8.6
APP VERSION: 0.31.0** Please be patient while the chart is being deployed **

Thanos chart was deployed enabling the following components:
- Thanos Query
- Thanos Bucket Web
- Thanos Compactor
- Thanos Ruler
- Thanos Store Gateway

Thanos Query can be accessed through following DNS name from within your cluster:

    thanos-query.monitoring.svc.cluster.local (port 9090)

To access Thanos Query from outside the cluster execute the following commands:

1. Get the Thanos Query URL by running these commands:

    export SERVICE_PORT=$(kubectl get --namespace monitoring -o jsonpath="{.spec.ports[0].port}" services thanos-query)
    kubectl port-forward --namespace monitoring svc/thanos-query ${SERVICE_PORT}:${SERVICE_PORT} &
    echo "http://127.0.0.1:${SERVICE_PORT}"

2. Open a browser and access Thanos Query using the obtained URL.

$ kubectl get po -n monitoring
NAME                                     READY   STATUS    RESTARTS   AGE
thanos-bucketweb-d8c4ff845-hqlqc         1/1     Running   0          2m4s
thanos-compactor-65cc47bd56-t9fpt        1/1     Running   0          2m3s
thanos-minio-57c56b9854-8gc5s            1/1     Running   0          2m3s
thanos-query-7d5c88c67b-22r4j            1/1     Running   0          3m3s
thanos-query-frontend-7d4d455875-lpxpk   1/1     Running   0          3m3s
thanos-ruler-0                           1/1     Running   0          2m
thanos-storegateway-0                    1/1     Running   0          42s


```
Screenshot: Thanos Query (Stores):

<img src="pictures/Thanos-Query-UI-Stores.png?raw=true" width="1300">


## Architecture:

Architecture diagram for implementation of Thanos with prometheus:

<img src="pictures/thanos-architecture.png?raw=true" width="1000">

Diagram for the purpose of understanding the whole concept and applying it in local environment and testing it:

<img src="pictures/thanos-diagram.webp?raw=true" width="500">


Thanos logical operations:

<img src="pictures/Thanos_logical_view.svg.png?raw=true" width="500">

Thanos deployment in Production is illustrated by the following diagram:

<img src="pictures/Thanos_deployment_view.svg.png?raw=true" width="500">



### Grafana
```
helm install grafana bitnami/grafana \
  --set service.type=LoadBalancer \
  --set admin.password=admin --namespace monitoring

```
Once the pod is up and running, access Grafana from the UI and add Prometheus as Data Source with the following URL:

`http://thanos-query.monitoring.svc.cluster.local:9090`

Click Save and Test and you should get a message in green saying that Data source is working.

### Test the system

At this point, we can start deploying applications into your "data producer" clusters and collating the metrics in Thanos and Grafana. For demonstration purposes, this guide will deploy a MariaDB replication cluster using Bitnami's MariaDB Helm chart in each "data producer" cluster and display the metrics generated by each MariaDB service in Grafana.

Deploy MariaDB in each cluster with one master and one slave using the production configuration with the commands below. Replace the MARIADB-ADMIN-PASSWORD and MARIADB-REPL-PASSWORD placeholders with the database administrator account and replication account password respectively. You can also optionally create a MariaDB user account for application use by specifying values for the USER-PASSWORD, USER-NAME and DB-NAME placeholders.

```
kubectl config use-context kind-remote1 & kind-remote2

helm install mariadb \
  --set rootUser.password=MARIADB-ADMIN-PASSWORD \
  --set replication.password=MARIADB-REPL-PASSWORD \
  --set db.user=USER-NAME \
  --set db.password=USER-PASSWORD \
  --set db.name=DB-NAME \
  --set slave.replicas=1 \
  --set metrics.enabled=true \
  --set metrics.serviceMonitor.enabled=true \
  bitnami/mariadb
```

Note the metrics.enabled parameter, which enables the Prometheus exporter for MySQL server metrics, and the metrics.serviceMonitor.enabled parameter, which creates a Prometheus Operator ServiceMonitor.

Once deployment in each cluster is complete, note the instructions to connect to each database service.

Browse to the [MySQL Overview dashboard in the Percona GitHub repository](https://github.com/percona/grafana-dashboards/blob/pmm-1.x/dashboards/MySQL_Overview.json) and copy the JSON model.
Log in to Grafana. From the Grafana dashboard, click the "Import -> Dashboard" menu item. On the "Import" page, paste the JSON model into the "Or paste JSON" field. Click "Load" to load the data and then "Import" to import the dashboard. 
Connect to the MariaDB service in the first "data producer" cluster and perform some actions, such as creating a database, adding records to a table and executing a query. Perform similar actions in the second "data producer" cluster. You should see your activity in each cluster reflected in the MySQL Overview chart in Grafana, as shown below. We can view metrics from individual master and slave nodes in each cluster by selecting a different host in the "Host" drop down of the dashboard, as shown below:

<img src="pictures/thanos-test-mysql.png?raw=true" width="900">

You can now continue adding more applications to your clusters. So long as you enable Prometheus metrics and a Prometheus Operator ServiceMonitor for each deployment, Thanos will continuously receive and aggregate the metrics and you can inspect them using Grafana.

## Clean local environment
```
$ kind delete cluster --name=thanos
Deleting cluster "thanos" ...
$ kind delete cluster --name=remote1
Deleting cluster "remote1" ...
$ kind delete cluster --name=remote2
Deleting cluster "remote2" .
```

## Thanos screenshots: 

<img src="pictures/Thanos-Query-UI-Stores.png?raw=true" width="1300">

<img src="pictures/Grafana-explore-NO-thanos-metrics.png?raw=true" width="1300">

<img src="pictures/Thanos-Query-missing-thanos-metrics.png?raw=true" width="1300">

<img src="pictures/Thanos-prometeteus-metrics-problem.png?raw=true" width="1300">

<img src="pictures/Thanos-Query-Prometheus-Rules.png?raw=true" width="1300">

Links: 

- https://thanos.io/tip/components/query.md/
- https://thanos.io/tip/operating/compactor-backlog.md/

Diagram shows what Querier does for each Prometheus query request:

<img src="pictures/querier.svg?raw=true" width="500">

### Ref: 
- https://docs.bitnami.com/tutorials/create-multi-cluster-monitoring-dashboard-thanos-grafana-prometheus/
- https://thesaadahmed.medium.com/thanos-monitoring-with-prometheus-and-grafana-843ed231c8a6
- https://medium.com/nerd-for-tech/deep-dive-into-thanos-part-i-f72ecba39f76 && https://medium.com/nerd-for-tech/deep-dive-into-thanos-part-ii-8f48b8bba132
- https://docs.bitnami.com/tutorials/create-multi-cluster-monitoring-dashboard-thanos-grafana-prometheus/
- Credits: https://github.com/edubonifs/multicluster-canary
  


