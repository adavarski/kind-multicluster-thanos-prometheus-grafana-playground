# KinD: Thanos ( Highly available Prometheus setup ) Lab multi-cluster


## Requirements

- Linux OS
- [Docker](https://docs.docker.com/)
- [KinD](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [istioctl](https://istio.io/latest/docs/setup/install/istioctl/)


Run the `setup-clusters.sh` script. It creates three KinD clusters:

- One thanos cluster (`thanos`)
- Two Istio remotes (`remote1`, `remote2`)

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

kubectl config use-context kind-thanos
kubectl create ns monitoring

cd monitoring
helm install thanos bitnami/thanos -n monitoring --values values.yaml
kubectl  get secret -n monitoring thanos-minio -o yaml -o jsonpath={.data.root-password} | base64 -d

Substitute this password by KEY (secret_key: KEY)  in your values.yaml file, and upgrade the helm chart:

helm upgrade thanos bitnami/thanos -n monitoring \
  --values values.yaml
```

### Grafana
````
helm install grafana bitnami/grafana \
  --set service.type=LoadBalancer \
  --set admin.password=admin --namespace monitoring

```
Once the pod is up and running, access Grafana from the UI and add Prometheus as Data Source with the following URL:

`http://thanos-query.monitoring.svc.cluster.local:9090`

Click Save and Test and you should get a message in green saying that Data source is working.



## Clean local environment
```
$ kind delete cluster --name=thanos
Deleting cluster "thanos" ...
$ kind delete cluster --name=remote1
Deleting cluster "remote1" ...
$ kind delete cluster --name=remote2
Deleting cluster "remote2" .
```
