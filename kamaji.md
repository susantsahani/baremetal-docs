What is Kamaji?
Kamaji is an open-source Kubernetes operator that simplifies managing multiple Kubernetes control planes at scale. 
Unlike vCluster, which virtualizes a cluster within a namespace, Kamaji deploys tenant control planes as pods in a management cluster, 
paired with worker nodes you provide. It’s a CNCF-compliant solution, leveraging kubeadm for cluster creation, 
and contrasts with your Kata/Firecracker setup by running control planes as pods rather than VM-isolated containers.

Install Kamaji

Add Clastix Helm Repository:
```
helm repo add clastix https://clastix.github.io/charts
helm repo update
```

Install Kamaji Operator:
```
helm upgrade --install kamaji clastix/kamaji --namespace kamaji-system --create-namespace
```

Verify Installation:

```
kubectl get pods -n kamaji-system
```

```
  kubectl patch pvc data-etcd-0 -n kamaji-system --type='json' -p='[{"op": "add", "path": "/spec/storageClassName", "value": "manual"}]'
```


```
cat kamaji-etcd0-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-etcd-0
  namespace: kamaji-system
spec:
  capacity:
    storage: 10Gi  # Adjust storage as needed
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual  # Make sure this matches the PVC's storageClassName
  hostPath:
    path: "/mnt/data/kamaji/etcd0"


```

create tenant  
cat kamaji_v1alpha1_tenantcontrolplane.yaml

```
apiVersion: kamaji.clastix.io/v1alpha1
kind: TenantControlPlane
metadata:
  name: k8s-130
  labels:
    tenant.clastix.io: k8s-130
spec:
  controlPlane:
    deployment:
      replicas: 2
    service:
      serviceType: LoadBalancer
  kubernetes:
    version: "v1.30.0"
    kubelet:
      cgroupfs: systemd
  networkProfile:
    port: 6443
  addons:
    coreDNS: {}
    kubeProxy: {}
    konnectivity:
      server:
        port: 8132
```

```
kubectl get tenantcontrolplane -n kamaji-system

```

```
kubectl get tenantcontrolplane -n kamaji-system -o wide
NAME      VERSION   STATUS   CONTROL-PLANE ENDPOINT   KUBECONFIG                 DATASTORE   AGE
tenant1   v1.27.3   Ready    10.101.116.104:6443      tenant1-admin-kubeconfig   default     39m
```

```
kubectl get secret tenant1-admin-kubeconfig -n kamaji-system -o json | jq -r '.data["admin.conf"]' | base64 --decode > tenant1.kubeconfig
```

```
kubeadm token create --print-join-command --ttl 0
```

cilium Load balancer L2 Announcement with ARP

`--set kubeProxyReplacement=true \--set l2announcements.enabled=true \`

```
	   helm upgrade --install cilium cilium/cilium --version 1.17.1 \
	   --namespace kube-system \
	   --set operator.replicas=1 \
	   --set debug.enabled=true \
	   --set socketLB.hostNamespaceOnly=true \
	   --set devices='{eno12399np0}' \
	   --set kubeProxyReplacement=true \
	   --set l2announcements.enabled=true \
	   --set ipam.mode=ku
