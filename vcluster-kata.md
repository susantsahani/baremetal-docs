What is vCluster?

vCluster is a tool that creates fully functional virtual Kubernetes clusters within a namespace of an existing (host) Kubernetes cluster. Unlike Kata Containers, 
which provides VM-isolated runtimes for individual containers, vCluster virtualizes an entire Kubernetes control plane, offering isolated clusters with lower 
overhead than separate physical clusters. It’s a great fit for multi-tenancy, testing, or development—potentially alongside your Kata/Netshoot setup.

Install vCluster CLI on Ubuntu

Download latest release from [github](https://github.com/loft-sh/vcluster/releases)
```
> wget https://github.com/loft-sh/vcluster/releases/download/v0.24.0-alpha.1/vcluster-linux-amd64
> chmod +x vcluster-linux-amd64
> sudo mv vcluster-linux-amd64 /usr/local/bin/vcluster
> vcluster --version
vcluster version 0.24.0-alpha.1
```

Create a Virtual Cluster
```
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

```
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s                                                          │
│ Events:                                                                                                                                           │
│   Type     Reason            Age                    From               Message                                                                    │
│   ----     ------            ----                   ----               -------                                                                    │
│   Warning  FailedScheduling  2m22s (x3 over 8m52s)  default-scheduler  0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims. │
│  preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling..                                                                │               │
│   N
```

It requires PersistentVolumeClaims

```
> kubectl get pvc -A
NAMESPACE              NAME                 STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
vcluster-my-vcluster   data-my-vcluster-0   Pending                                                     4m34s
```

let's create one 
```
> sudo mkdir -p /mnt/data-my-vcluster-0
```

```
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

```
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
```
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

```
 > vcluster create my-vcluster
```
1. Creates a namespace vcluster-my-vcluster in the host cluster.
2. Deploys a virtual control plane (API server, etc.) as a pod.
3. Switches your kubectl context to the virtual cluster.

Test with Netshoot 
```
> kubectl run netshoot --image=nicolaka/netshoot --restart=Never -- /bin/bash -c "sleep infinity"
pod/netshoot created
```

```
> kubectl exec -it netshoot -- /bin/bash
netshoot:~# uname -a
Linux netshoot 5.15.0-126-generic #136-Ubuntu SMP Wed Nov 6 10:38:22 UTC 2024 x86_64 Linux
```


