What is vCluster?

vCluster is a tool that creates fully functional virtual Kubernetes clusters within a namespace of an existing (host) Kubernetes cluster. Unlike Kata Containers, 
which provides VM-isolated runtimes for individual containers, vCluster virtualizes an entire Kubernetes control plane, offering isolated clusters with lower 
overhead than separate physical clusters. It’s a great fit for multi-tenancy, testing, or development—potentially alongside your Kata/Netshoot setup.

Install vCluster CLI on Ubuntu

Download latest release from [github](https://github.com/loft-sh/vcluster/releases)
```bash
> wget https://github.com/loft-sh/vcluster/releases/download/v0.24.0-alpha.1/vcluster-linux-amd64
> chmod +x vcluster-linux-amd64
> sudo mv vcluster-linux-amd64 /usr/local/bin/vcluster
> vcluster --version
vcluster version 0.24.0-alpha.1
```

Create a Virtual Cluster
```bash
 > vcluster create my-vcluster
04:49:49 info Creating namespace vcluster-my-vcluster
04:49:49 info Create vcluster my-vcluster...
04:49:49 info execute command: helm upgrade my-vcluster /tmp/vcluster-0.24.0-alpha.1.tgz-2310332467 --create-namespace --kubeconfig /tmp/1619415846 --namespace vcluster-my-vcluster --install --repository-config='' --values /tmp/405645175
04:49:50 done Successfully created virtual cluster my-vcluster in namespace vcluster-my-vcluster
04:56:25 info Waiting for vcluster to come up...
04:56:25 info vcluster is waiting, because vcluster pod my-vcluster-0 has status: Init:0/3
04:56:35 info vcluster is waiting, because vcluster pod my-vcluster-0 has status: Init:1/3

```

Notice it's not coming up

```bash
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s                                                          │
│ Events:                                                                                                                                           │
│   Type     Reason            Age                    From               Message                                                                    │
│   ----     ------            ----                   ----               -------                                                                    │
│   Warning  FailedScheduling  2m22s (x3 over 8m52s)  default-scheduler  0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims. │
│  preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling..                                                                │               │
│   N
```

It requires PersistentVolumeClaims

```bash
> kubectl get pvc -A
NAMESPACE              NAME                 STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
vcluster-my-vcluster   data-my-vcluster-0   Pending                                                     4m34s
```

let's create one 
```bash
> sudo mkdir -p /mnt/data-my-vcluster-0
```

```bash
> cat vcluster-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-my-vcluster-0
  namespace: vcluster-my-vcluster
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data-my-vcluster-0"
```

```
k create -f vcluster-pv.yaml
persistentvolume/data-my-vcluster-0 created
```

Now the vcluster will come up

```bash
> vcluster create my-vcluster
04:49:49 info Creating namespace vcluster-my-vcluster
04:49:49 info Create vcluster my-vcluster...
04:49:49 info execute command: helm upgrade my-vcluster /tmp/vcluster-0.24.0-alpha.1.tgz-2310332467 --create-namespace --kubeconfig /tmp/1619415846 --namespace vcluster-my-vcluster --install --repository-config='' --values /tmp/405645175
04:49:50 done Successfully created virtual cluster my-vcluster in namespace vcluster-my-vcluster
04:56:25 info Waiting for vcluster to come up...
04:56:25 info vcluster is waiting, because vcluster pod my-vcluster-0 has status: Init:0/3
04:56:35 info vcluster is waiting, because vcluster pod my-vcluster-0 has status: Init:1/3
04:56:56 done vCluster is up and running
04:56:56 done Switched active kube context to vcluster_my-vcluster_vcluster-my-vcluster_mgmt07-admin@mgmt07
04:56:56 warn Since you are using port-forwarding to connect, you will need to leave this terminal open
- Use CTRL+C to return to your previous kube context
- Use `kubectl get namespaces` in another terminal to access the vcluster
Forwarding from 127.0.0.1:10917 -> 8443
Forwarding from [::1]:10917 -> 8443
```

verify the logs
```bash
   Type     Reason            Age                   From               Message                                                                     │
│   ----     ------            ----                  ----               -------                                                                     │
│   Warning  FailedScheduling  6m28s (x3 over 12m)   default-scheduler  0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims.  │
│ preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling..                                                                 │
│   Normal   Scheduled         6m23s                 default-scheduler  Successfully assigned vcluster-my-vcluster/my-vcluster-0 to eksa-cp02       │
│   Normal   Pulling           6m22s                 kubelet            Pulling image "ghcr.io/loft-sh/vcluster-pro:0.24.0-alpha.1"                 │
│   Normal   Pulled            6m16s                 kubelet            Successfully pulled image "ghcr.io/loft-sh/vcluster-pro:0.24.0-alpha.1" in  │
│ 6.491s (6.491s including waiting)                                                                                                                 │
│   Normal   Created           6m16s                 kubelet            Created container vcluster-copy                                             │
│   Normal   Started           6m16s                 kubelet            Started container vcluster-copy                                             │
│   Normal   Pulled            6m14s                 kubelet            Container image "registry.k8s.io/kube-controller-manager:v1.28.15" already  │
│ present on machine                                                                                                                                │
│   Normal   Created           6m14s                 kubelet            Created container kube-controller-manager                                   │
│   Normal   Started           6m14s                 kubelet            Started container kube-controller-manager                                   │
│   Normal   Pulled            6m10s                 kubelet            Container image "registry.k8s.io/kube-apiserver:v1.28.15" already present o │
│ n machine                                                                                                                                         │
│   Normal   Created           6m10s                 kubelet            Created container kube-apiserver                                            │
│   Normal   Started           6m10s                 kubelet            Started container kube-apiserver                                            │
│   Normal   Pulled            6m6s                  kubelet            Container image "ghcr.io/loft-sh/vcluster-pro:0.24.0-alpha.1" already prese │
│ nt on machine                                                                                                                                     │
│   Normal   Created           6m6s                  kubelet            Created container syncer                                                    │
│   Normal   Started           6m6s                  kubelet            Started container syncer 
```

```bash
 > vcluster create my-vcluster
```
1. Creates a namespace vcluster-my-vcluster in the host cluster.
2. Deploys a virtual control plane (API server, etc.) as a pod.
3. Switches your kubectl context to the virtual cluster.

Test with Netshoot 
```bash
> kubectl run netshoot --image=nicolaka/netshoot --restart=Never -- /bin/bash -c "sleep infinity"
pod/netshoot created
```

```bash
> kubectl exec -it netshoot -- /bin/bash
netshoot:~# uname -a
Linux netshoot 5.15.0-126-generic #136-Ubuntu SMP Wed Nov 6 10:38:22 UTC 2024 x86_64 Linux
```

Integrate with Kata

runtimeClass is a built-in type in Kubernetes. To apply each Kata Containers runtimeClass:
```bash
$ kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/runtimeclasses/kata-runtimeClasses.yaml
runtimeclass.node.k8s.io/kata-clh created
runtimeclass.node.k8s.io/kata-cloud-hypervisor created
runtimeclass.node.k8s.io/kata-dragonball created
runtimeclass.node.k8s.io/kata-fc created
runtimeclass.node.k8s.io/kata-qemu-coco-dev created
runtimeclass.node.k8s.io/kata-qemu-nvidia-gpu-snp created
runtimeclass.node.k8s.io/kata-qemu-nvidia-gpu-tdx created
runtimeclass.node.k8s.io/kata-qemu-nvidia-gpu created
runtimeclass.node.k8s.io/kata-qemu-runtime-rs created
runtimeclass.node.k8s.io/kata-qemu-se-runtime-rs created
runtimeclass.node.k8s.io/kata-qemu-se created
runtimeclass.node.k8s.io/kata-qemu-sev created
runtimeclass.node.k8s.io/kata-qemu-snp created
runtimeclass.node.k8s.io/kata-qemu-tdx created
runtimeclass.node.k8s.io/kata-qemu created
runtimeclass.node.k8s.io/kata-remote created
runtimeclass.node.k8s.io/kata-stratovirt created
```

To run an example with kata-clh:

> kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/examples/test-deploy-kata-clh.yaml
service "php-apache-kata-clh" deleted
deployment.apps/php-apache-kata-clh created
service/php-apache-kata-clh created

> k get pods -A
NAMESPACE     NAME                                   READY   STATUS    RESTARTS       AGE
default       kata-pod                               1/1     Running   0              40s
default       nginx-7854ff8877-sgt8w                 1/1     Running   0              7m12s
default       php-apache-kata-clh-67f67d6f89-wvtdf   1/1     Running   0              22s
kube-system   coredns-664c8d69c4-hhwkp               1/1     Running   1 (3d4h ago)   7d19h

root@kata-pod:/# uname -a
Linux kata-pod 6.12.22 #1 SMP Fri Apr 25 06:19:46 UTC 2025 x86_64 GNU/Linux
root@kata-pod:/# 

```

How to connect to virtual cluster ?

The vcluster connect command in the vCluster CLI establishes a connection between your local machine and a virtual Kubernetes cluster running inside a host cluster.
It updates your kubeconfig file to point to the virtual cluster’s API server, allowing you to use kubectl (and other tools) to manage it as if it were a standalone cluster.

```
vcluster list
       NAME     |      NAMESPACE       | STATUS  |    VERSION     | CONNECTED |   AGE    
  --------------+----------------------+---------+----------------+-----------+----------
    my-vcluster | vcluster-my-vcluster | Running | 0.24.0-alpha.1 |           | 1h7m18s  
  
 install  vcluster connect my-vcluster
05:57:25 done vCluster is up and running
05:57:25 done Switched active kube context to vcluster_my-vcluster_vcluster-my-vcluster_mgmt07-admin@mgmt07
05:57:25 warn Since you are using port-forwarding to connect, you will need to leave this terminal open
- Use CTRL+C to return to your previous kube context
- Use `kubectl get namespaces` in another terminal to access the vcluster
Forwarding from 127.0.0.1:12511 -> 8443
Forwarding from [::1]:12511 -> 8443

```

```
kubectl get nodes
NAME        STATUS   ROLES    AGE   VERSION
eksa-cp02   Ready    <none>   53m   v1.28.15

```

Stop it later with:
```
vcluster disconnect
```
