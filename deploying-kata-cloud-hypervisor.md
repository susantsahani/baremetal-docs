### How to deploy Kata on a running Kubernetes cluster

kata-deploy provides a Dockerfile, which contains all of the binaries and artifacts required to run Kata Containers, 
as well as reference DaemonSets, which can be utilized to install Kata Containers on a running Kubernetes cluster.

```bash
> kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-rbac/base/kata-rbac.yaml
> kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-deploy/base/kata-deploy.yaml
```

#### Ensure Kata has been installed
```
> kubectl -n kube-system wait --timeout=10m --for=condition=Ready -l name=kata-deploy pod
```


#### Run a sample workload

Workloads specify the runtime they'd like to utilize by setting the appropriate runtimeClass object within the Pod specification. The runtimeClass examples provided define a node selector to match node label katacontainers.io/kata-runtime:"true", which will ensure the workload is only scheduled on a node that has Kata Containers installed

runtimeClass is a built-in type in Kubernetes. To apply each Kata Containers runtimeClass:
```
$ kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/runtimeclasses/kata-runtimeClasses.yaml
```
The following YAML snippet shows how to specify a workload should use Kata with Dragonball:
```
spec:
  template:
    spec:
      runtimeClassName: kata-dragonball
```
The following YAML snippet shows how to specify a workload should use Kata with Cloud Hypervisor:
```
spec:
  template:
    spec:
      runtimeClassName: kata-clh
```

The following YAML snippet shows how to specify a workload should use Kata with StratoVirt:
```
spec:
  template:
    spec:
      runtimeClassName: kata-stratovirt
```
The following YAML snippet shows how to specify a workload should use Kata with QEMU:

```
spec:
  template:
    spec:
      runtimeClassName: kata-qemu
```

To run an example with kata-dragonball:
```
> kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/examples/test-deploy-kata-dragonball.yaml
```
To run an example with kata-clh:
```
> kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/examples/test-deploy-kata-clh.yaml
service "php-apache-kata-clh" deleted
deployment.apps/php-apache-kata-clh created
service/php-apache-kata-clh created

```

```
> k describe pod php-apache-kata-clh
Name:                php-apache-kata-clh-67f67d6f89-ccbq5
Namespace:           default
Priority:            0
Runtime Class Name:  kata-clh
Service Account:     default
Node:                eksa-cp02/10.20.22.216
Start Time:          Tue, 11 Mar 2025 06:33:14 +0000
Labels:              pod-template-hash=67f67d6f89
                     run=php-apache-kata-clh
Annotations:         <none>
Status:              Running
IP:                  192.168.0.235
IPs:
  IP:           192.168.0.235
Controlled By:  ReplicaSet/php-apache-kata-clh-67f67d6f89
Containers:
  php-apache:
    Container ID:   containerd://40747ccf1618aa80677b22e48f9bb3e6102320de7d7aa8639816ce587aae3053
    Image:          registry.k8s.io/hpa-example
    Image ID:       registry.k8s.io/hpa-example@sha256:581697a37f0e136db86d6b30392f0db40ce99c8248a7044c770012f4e8491544
    Port:           80/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Tue, 11 Mar 2025 06:33:16 +0000
    Ready:          True
    Restart Count:  0
    Requests:
      cpu:        200m
    Environment:  <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-th8r2 (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True 
  Initialized                 True 
  Ready                       True 
  ContainersReady             True 
  PodScheduled                True 
Volumes:
  kube-api-access-th8r2:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   Burstable
Node-Selectors:              katacontainers.io/kata-runtime=true
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  56s   default-scheduler  Successfully assigned default/php-apache-kata-clh-67f67d6f89-ccbq5 to eksa-cp02
  Normal  Pulling    55s   kubelet            Pulling image "registry.k8s.io/hpa-example"
  Normal  Pulled     54s   kubelet            Successfully pulled image "registry.k8s.io/hpa-example" in 389ms (389ms including waiting)
  Normal  Created    54s   kubelet            Created container php-apache
  Normal  Started    54s   kubelet            Started container php-apache

```

```
<<K9s-Shell>> Pod: default/php-apache-kata-clh-67f67d6f89-ccbq5 | Container: php-apache 
root@php-apache-kata-clh-67f67d6f89-ccbq5:/var/www/html# ip l
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
    link/ether 52:c6:14:6a:52:4b brd ff:ff:ff:ff:ff:ff
root@php-apache-kata-clh-67f67d6f89-ccbq5:/var/www/html# 

```

```
40453 ?        S      0:00 /opt/kata/libexec/virtiofsd --syslog --cache=auto --shared-dir=/run/kata-containers/shared/sandboxes/0a074afb4cc4fdf0c2f
  40454 ?        Sl     0:01 /opt/kata/bin/cloud-hypervisor --api-socket /run/vc/vm/0a074afb4cc4fdf0c2f223d5efc409d2697fb3cc66df922168014a8a936f76c3/
  40459 ?        Sl     0:00 /opt/kata/libexec/virtiofsd --syslog --cache=auto --shared-dir=/run/kata-containers/shared/sandboxes/0a074afb4cc4fdf0c2f
  40460 ?        I      0:00 [kworker/12:1-mm_percpu_wq]
  
```


```
To run an example with kata-stratovirt:
```
> kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/examples/test-deploy-kata-stratovirt.yaml
```
To run an example with kata-qemu:
```
> kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/examples/test-deploy-kata-qemu.yaml
```

```
