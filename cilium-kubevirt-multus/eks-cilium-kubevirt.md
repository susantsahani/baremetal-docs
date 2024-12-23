**Installation**

All EKS-A clusters are deployed with the base edition of Cilium, which will need to be uninstalled before upgrading to Cilium OSS.

```
kubectl delete serviceaccount cilium --namespace kube-system
kubectl delete serviceaccount cilium-operator --namespace kube-system
kubectl delete secret hubble-ca-secret --namespace kube-system
kubectl delete secret hubble-server-certs --namespace kube-system
kubectl delete configmap cilium-config --namespace kube-system
kubectl delete clusterrole cilium
kubectl delete clusterrolebinding cilium
kubectl delete clusterrolebinding cilium-operator
kubectl delete secret cilium-ca --namespace kube-system
kubectl delete service hubble-peer --namespace kube-system
kubectl delete service cilium-agent --namespace kube-system
kubectl delete daemonset cilium --namespace kube-system
kubectl delete deployment cilium-operator --namespace kube-system
kubectl delete clusterrole cilium-operator
kubectl delete role  cilium-config-agent -n kube-system
kubectl delete rolebinding cilium-config-agent -n kube-system
kubectl delete secret sh.helm.release.v1.cilium.v1 -n kube-system
```

Now let's install cilium .
```
cilium uninstall
cilium install
```

Note is that the helm value `socketLB.hostNamespaceOnly=true` should be configured to [ensure compatibility with KubeVirt’s networking implementation](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/#socket-loadbalancer-bypass-in-pod-namespace) for virtual machine devices.

```
helm repo add cilium https://helm.cilium.io/
helm upgrade --install cilium cilium/cilium --version 1.16.5 \
   --namespace kube-system \
   --set operator.replicas=1 \
   --set cni.exclusive=false \
   --set socketLB.hostNamespaceOnly=true \
   --set bpf.masquerade=true \
   --set kubeProxyReplacement=true \
   --set prometheus.enabled=true \
   --set operator.prometheus.enabled=true \
   --set gatewayAPI.enabled=true \
   --set hubble.enabled=true \
   --set hubble.metrics.enableOpenMetrics=true \
   --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,httpV2:exemplars=true;labelsContext=source_ip\,source_namespace\,source_workload\,destination_ip\,destination_namespace\,destination_workload\,traffic_direction}"
```

  

```
> cilium status
    /¯¯\
 /¯¯\__/¯¯\    Cilium:                        OK
 \__/¯¯\__/    Operator:                   OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    OK
 \__/¯¯\__/    Hubble Relay:            OK
    \__/       ClusterMesh:               disabled
```

`cilium-health` is a tool available in Cilium that provides visibility into the overall health of the cluster’s networking connectivity. Use `cilium-health` to get visibility into the overall health of the cluster’s networking connectivity.

```
> kubectl -n kube-system exec ds/cilium -- cilium-health status
Defaulted container "cilium-agent" out of: cilium-agent, config (init), mount-cgroup (init), apply-sysctl-overwrites (init), mount-bpf-fs (init), clean-cilium-state (init), install-cni-binaries (init)
Probe time:   2024-12-16T08:03:15Z
Nodes:
  eksa-cp02 (localhost):
    Host connectivity to 10.20.22.216:
      ICMP to stack:   OK, RTT=325.55µs
      HTTP to agent:   OK, RTT=431.893µs
    Endpoint connectivity to 192.168.0.27:
      ICMP to stack:   OK, RTT=366.374µs
      HTTP to agent:   OK, RTT=466.474µs
```

### Cilium Connectivity Test

The `cilium connectivity test` command deploys a series of services and deployments, and CiliumNetworkPolicy will use various connectivity paths to connect. Connectivity paths include with and without service load-balancing and various network policy combinations.

_Output Truncated:_

```bash
cilium connectivity test 

ℹ️  Monitor aggregation detected, will skip some flow validation steps
✨ [cilium-eksa] Creating namespace cilium-test for connectivity check...
✨ [cilium-eksa] Deploying echo-same-node service...
✨ [cilium-eksa] Deploying DNS test server configmap...
✨ [cilium-eksa] Deploying same-node deployment...
✨ [cilium-eksa] Deploying client deployment...
✨ [cilium-eksa] Deploying client2 deployment...
🔭 Enabling Hubble telescope...
ℹ️  Expose Relay locally with:
   cilium hubble enable
   cilium hubble port-forward&
ℹ️  Cilium version: 1.14.0

✅ All 42 tests (191 actions) successful, 12 tests skipped, 1 scenarios skipped.

```

### Validate Hubble API access

To access the Hubble API, create a port forward to the Hubble service from your local machine or server. This will allow you to connect the Hubble client to the local port 4245 and access the Hubble Relay service in your Kubernetes cluster. For more information on this method, see [Use Port Forwarding to Access Application in a Cluster](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/).

```bash
kubectl port-forward -n kube-system svc/hubble-relay 4245:80
```

Validate that you have access to the Hubble API via the installed CLI and notice that both the nodes are connected and flows are being accounted for.

```bash
hubble status
Healthcheck (via localhost:4245): Ok
Current/Max Flows: 8,190/8,190 (100.00%)
Flows/s: 38.51
Connected Nodes: 2/2
```

Run `hubble observe` command in a different terminal against the local port to observe cluster-wide network events through Hubble Relay:

-   In this case, a client app sends a “wget request” to a server every few seconds, and that transaction can be seen below.
    

```bash
hubble observe --server localhost:4245 --follow

Sep  7 09:11:51.915: 192.168.0.33 (ID:64881) -> 192.168.2.200 (remote-node) to-overlay FORWARDED (IPv4)
Sep  7 09:11:51.915: 192.168.0.33 (ID:64881) -> 192.168.2.200 (remote-node) to-overlay FORWARDED (IPv4)
Sep  7 09:11:51.915: default/client:35552 (ID:458) -> default/server:80 (ID:2562) to-stack FORWARDED (TCP Flags: SYN)
Sep  7 09:11:51.915: 192.168.2.200 (ID:458) -> 192.168.1.12 (remote-node) to-overlay FORWARDED (IPv4)
Sep  7 09:11:51.915: 192.168.0.33 (ID:64881) -> 192.168.2.200 (host) to-stack FORWARDED (IPv4)
Sep  7 09:11:51.916: 192.168.1.12 (ID:2562) -> 192.168.2.200 (host) to-stack FORWARDED (IPv4)
Sep  7 09:11:51.917: 192.168.2.200 (ID:458) -> 192.168.1.12 (host) to-stack FORWARDED (IPv4)
```

### Accessing the Hubble UI

To access the Hubble UI, create a port forward to the Hubble service from your local machine or server. This will allow you to connect to the local port 12000 and access the Hubble UI service in your Kubernetes cluster. For more information on this method, see [Use Port Forwarding to Access Application in a Cluster](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/).

```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
```

-   This will redirect you to [http://localhost:12000](http://localhost:12000) in your browser.
    
-   You should see a screen with an invitation to select a namespace; use the namespace selector dropdown on the left top corner to select a namespace:
    

### VMs in Kubernetes with KubeVirt and Cilium

Deploy the Virtual Machine using the command:

```
> cat ubuntu.yaml

```

```
aapiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  namespace: kubevirt-demo
  name: nginx-vm
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/size: small
        kubevirt.io/domain: nginx-vm
        name: nginx-vm
    spec:
      domain:
        cpu:
          model: host-passthrough
          cores: 2
        devices:
          disks:
            - name: containerdisk
              disk:
                bus: virtio
            - name: cloudinitdisk
              disk:
                bus: virtio
          interfaces:
          - name: default
            masquerade: {}
        resources:
          requests:
            memory: 4096Mi
      networks:
      - name: default
        pod: {}
      volumes:
      - containerDisk:
          image: tedezed/ubuntu-container-disk:22.0
        name: containerdisk
      - cloudInitNoCloud:
          userData: |
            #cloud-config
            password: ubuntu
            chpasswd: { expire: False }
            runcmd:
              - sudo apt update
              - sudo apt install nginx -y
              - echo "IyEvYmluL2Jhc2gKCiMgR2VuZXJhdGUgdGhlIFNlY3JldCBQYWdlCmVjaG8gIjxoMT5TZWNyZXQgUGFnZTwvaDE+PHAgc2VjcmV0IHBhZ2U8L3A+IiA+IC92YXIvd3d3L2h0bWwvc2VjcmV0Lmh0bWwKCkdlbmVyYXRlIFZNIERldGFpbHMgUGFnZSB3aXRoIEhvc3RuYW1lIGFuZCBJUAplY2hvICJcbjxoMT5WTURldGFpbHM8L2gxPjxwPk5hbWU6ICQoaG9zdG5hbWUpPC9wPjxwPklQOiAkKGhvc3RuYW1lIC1JKTwvcD48cD5Mb2NhbGU6ICQobG9jYWxlKTwvcD4iID4gL3Zhci93d3cvaHRtbC9kZXRhaWxzLmh0bWwK" | base64 --decode | sudo bash
              - sudo sed -i 's|try_files $uri $uri/ =404;|try_files $uri $uri/ $uri.html =404;|' /etc/nginx/sites-available/default
              - sudo systemctl restart nginx
        name: cloudinitdisk
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: kubevirt-demo
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    kubevirt.io/domain: nginx-vm
    name: nginx-vm
```
Apply

```
> k apply -f ./ubuntu.yaml
virtualmachine.kubevirt.io/kubevirt-demo created
service/nginx created
```

```
> k get vms,pods,svc
NAME                                       AGE   STATUS    READY
virtualmachine.kubevirt.io/kubevirt-demo   30s   Stopped   False

NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)     AGE
service/nginx          ClusterIP   10.97.189.63     <none>        80/TCP      30s
```

```
> k get vms
NAME            AGE   STATUS    READY
kubevirt-demo   99s   Stopped   False
```

```
> virtctl start kubevirt-demo
VM kubevirt-demo was scheduled to start
```

```
> k get vms
NAME            AGE    STATUS    READY
kubevirt-demo   114s   Running   True
```

Login to to vm using virtctl ubuntu/ubuntu

```
> virtctl console kubevirt-demo
Successfully connected to kubevirt-demo console. The escape sequence is ^]

kubevirt-demo login: ubuntu
Password:
Welcome to Ubuntu 22.04.3 LTS (GNU/Linux 5.15.0-92-generic x86_64)

ubuntu@kubevirt-demo:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether d2:4e:99:cb:a7:38 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.2/24 metric 100 brd 10.0.2.255 scope global dynamic enp1s0
       valid_lft 86313483sec preferred_lft 86313483sec
    inet6 fe80::d04e:99ff:fecb:a738/64 scope link
       valid_lft forever preferred_lft forever
ubuntu@kubevirt-demo:~$ ip r
default via 10.0.2.1 dev enp1s0 proto dhcp src 10.0.2.2 metric 100
10.0.2.0/24 dev enp1s0 proto kernel scope link src 10.0.2.2 metric 100
10.0.2.1 dev enp1s0 proto dhcp scope link src 10.0.2.2 metric 100
10.96.0.10 via 10.0.2.1 dev enp1s0 proto dhcp src 10.0.2.2 metric 100
```

  
Now ping the desired machine. It's pingable

```
ubuntu@kubevirt-demo:~$ ping XX.XX.XX.XX
PING XX.XX.XX.XX (XX.XX.XX.XX) 56(84) bytes of data.
64 bytes from XX.XX.XX.XX: icmp_seq=1 ttl=61 time=0.467 ms
64 bytes from XX.XX.XX.XX: icmp_seq=2 ttl=61 time=0.518 ms
64 bytes from XX.XX.XX.XX: icmp_seq=3 ttl=61 time=0.499 ms
^Z
[1]+  Stopped                 ping 10.20.22.166
```

let's apply a simple cilium network policy to block admin machine

```
> cat block-macine.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "cidr-rule-block-admin"
  namespace: kubevirt-demo
spec:
  endpointSelector:
    matchLabels:
      name: kubevirt-demo
      name: nginx-vm
  egress:
    - toEntities:
      - host
    - toCIDRSet:
      - cidr: 0.0.0.0/0
        except:
          -  XX.XX.XX.XX/32
```

Now apply the rule
```
> k apply -f block-admin.yaml
ciliumnetworkpolicy.cilium.io/cidr-rule-block-machine created
```

Now ping the admin machine from inside the VM
```
ubuntu@kubevirt-demo:~$ ping  XX.XX.XX.XX 
PING  XX.XX.XX.XX  ( XX.XX.XX.XX ) 56(84) bytes of data.
^Z
[2]+  Stopped                 ping  XX.XX.XX.XX 
ubuntu@kubevirt-demo:~$
```

we can also inspect the policy details via `kubectl`

```
> kubectl get cnp
❯ kubectl get cnp -n kubevirt-demo
NAME                    AGE
allow-dns               8m2s
cidr-rule-block-admin   51m
```

```
❯ k describe cnp cidr-rule-block-admin -n kubevirt-demo
Name:         cidr-rule-block-admin
Namespace:    kubevirt-demo
Labels:       <none>
Annotations:  <none>
API Version:  cilium.io/v2
Kind:         CiliumNetworkPolicy
Metadata:
  Creation Timestamp:  2024-12-23T05:38:13Z
  Generation:          1
  Resource Version:    685963
  UID:                 d8477c11-cdf7-479a-bf1d-04f93cbb3007
Spec:
  Egress:
    To Entities:
      host
    To CIDR Set:
      Cidr:  0.0.0.0/0
      Except:
        XX.XX.XX.XX/32
  Endpoint Selector:
    Match Labels:
      Name:  nginx-vm
Status:
  Conditions:
    Last Transition Time:  2024-12-23T05:38:13Z
    Message:               Policy validation succeeded
    Status:                True
    Type:                  Valid
Events:                    <none>
```
  
Note: Here the cilium rule is applied based on the label _Name: nginx-vm_

```
Match Labels:
      Name:  nginx-vm <====
```

matches with VM's labels

```
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/size: small
        kubevirt.io/domain: nginx-vm
        name: nginx-vm <=====
    spec:
```

#### Condifure DNS

```
ubuntu@nginx-vm:~$ ping google.com
ping: google.com: Temporary failure in name resolution
```

```
❯ hubble observe --follow  -n kubevirt-demo
Dec 23 06:19:27.279: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:54117 (ID:23070) <> kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) policy-verdict:none EGRESS DENIED (UDP)
Dec 23 06:19:27.279: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:54117 (ID:23070) <> kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) Policy denied DROPPED (UDP)
Dec 23 06:19:27.279: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:60099 (ID:23070) <> kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) policy-verdict:none EGRESS DENIED (UDP)
Dec 23 06:19:27.279: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:60099 (ID:23070) <> kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) Policy denied DROPPED (UDP)
Dec 23 06:19:27.279: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:38034 (ID:23070) <> kube-system/coredns-9cf7fc5cc-cfc6n:53 (ID:42422) policy-verdict:none EGRESS DENIED (UDP)
Dec 23 06:19:27.279: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:38034 (ID:23070) <> kube-system/coredns-9cf7fc5cc-cfc6n:53 (ID:42422) Policy denied DROPPED (UDP)
Dec 23 06:19:27.279: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:49863 (ID:23070) <> kube-system/coredns-9cf7fc5cc-cfc6n:53 (ID:42422) policy-verdict:none EGRESS DENIED (UDP)
Dec 23 06:19:27.279: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:49863 (ID:23070) <> kube-system/coredns-9cf7fc5cc-cfc6n:53 (ID:42422) Policy denied DROPPED (UDP)
Dec 23 06:19:32.529: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:54117 (ID:23070) <> kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) policy-verdict:none EGRESS DENIED (UDP)
Dec 23 06:19:32.529: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:54117 (ID:23070) <> kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) Policy denied DROPPED (UDP)
Dec 23 06:19:32.529: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:49863 (ID:23070) <> kube-system/coredns-9cf7fc5cc-cfc6n:53 (ID:42422) policy-verdict:none EGRESS DENIED (UDP)
```

Create rule for DNS
```
❯ cat allow-dns.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "allow-dns"
  namespace: kubevirt-demo
spec:
  endpointSelector:
    matchLabels:
      name: kubevirt-demo
      name: nginx-vm
  egress:
    - toEndpoints:
      - matchLabels:
          io.kubernetes.pod.namespace: kube-system
          k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*"
```


```
ubuntu@nginx-vm:~$ curl google.com
<HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
<TITLE>301 Moved</TITLE></HEAD><BODY>
<H1>301 Moved</H1>
The document has moved
<A HREF="http://www.google.com/">here</A>.
</BODY></HTML>
```

See from hubble it's allowed
```
ec 23 06:33:12.761: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:51496 (ID:23070) -> kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) dns-request proxy FORWARDED (DNS Query google.com. A)
Dec 23 06:33:12.761: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:56200 (ID:23070) -> kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) dns-request proxy FORWARDED (DNS Query google.com. AAAA)
Dec 23 06:33:12.764: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:56200 (ID:23070) <- kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) dns-response proxy FORWARDED (DNS Answer RCode: Server Failure  TTL: 4294967295 (Proxy google.com. AAAA))
Dec 23 06:33:12.764: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:51496 (ID:23070) <- kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) dns-response proxy FORWARDED (DNS Answer RCode: Server Failure  TTL: 4294967295 (Proxy google.com. A))
Dec 23 06:33:12.764: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:56200 (ID:23070) -> kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) dns-request proxy FORWARDED (DNS Query google.com. AAAA)
Dec 23 06:33:12.764: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:51496 (ID:23070) -> kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) dns-request proxy FORWARDED (DNS Query google.com. A)
Dec 23 06:33:13.707: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:51496 (ID:23070) <- kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) to-proxy FORWARDED (UDP)
Dec 23 06:33:13.707: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:56200 (ID:23070) <- kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) to-proxy FORWARDED (UDP)
Dec 23 06:33:13.707: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:51496 (ID:23070) <- kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) dns-response proxy FORWARDED (DNS Answer RCode: Server Failure  TTL: 4294967295 (Proxy google.com. A))
Dec 23 06:33:13.707: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:56200 (ID:23070) <- kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) dns-response proxy FORWARDED (DNS Answer RCode: Server Failure  TTL: 4294967295 (Proxy google.com. AAAA))
Dec 23 06:33:14.762: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:51496 (ID:23070) <- kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) dns-response proxy FORWARDED (DNS Answer RCode: Server Failure  TTL: 4294967295 (Proxy google.com. A))
Dec 23 06:33:14.762: kubevirt-demo/virt-launcher-nginx-vm-7lx4p:56200 (ID:23070) <- kube-system/coredns-9cf7fc5cc-7wr4m:53 (ID:42422) dns-response proxy FORWARDED (DNS Answer RCode: Server Failure  TTL: 4294967295 (Proxy google.com. AAAA))
Dec 23 06:33:14.763: kubevirt-demo/virt-launcher-nginx-vm-7lx4p (ID:23070) -> 10.96.0.10 (ID:16777417) policy-verdict:L3-Only EGRESS ALLOWED (ICMPv4 DestinationUnreachable(Port))
```
  

See [https://docs.cilium.io/en/latest/security/policy/index.html](https://docs.cilium.io/en/latest/security/policy/index.html)
