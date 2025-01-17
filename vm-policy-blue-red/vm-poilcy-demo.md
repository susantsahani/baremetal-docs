Demo VM cilium policy

This demo inspried by cilium's [starwar demo](https://docs.cilium.io/en/stable/gettingstarted/demo). 

We deploy 4 vms separed by a label `org=blue` [blue-vm1](https://github.com/susantsahani/baremetal-docs/blob/main/vm-policy-blue-red/yaml/blue-vm1.yaml#L13]L13) 
`org=red` [red-vm1](https://github.com/susantsahani/baremetal-docs/blob/main/vm-policy-blue-red/yaml/red-vm1.yaml#L13)

Deploy
   
```bash
>k get svc,pods -o wide
NAME                       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE   SELECTOR
service/blue-vm1-service   ClusterIP   10.108.171.108   <none>        80/TCP,22/TCP   48m   kubevirt.io/domain=blue-vm1,name=blue-vm1,org=blue
service/blue-vm2-service   ClusterIP   10.110.210.130   <none>        80/TCP,22/TCP   48m   kubevirt.io/domain=blue-vm2,name=blue-vm2,org=blue
service/nginx-vm-multus    ClusterIP   10.104.148.46    <none>        80/TCP,22/TCP   14h   kubevirt.io/domain=nginx-vm-multus,name=nginx-vm-multus
service/red-vm1-service    ClusterIP   10.110.217.201   <none>        80/TCP,22/TCP   51m   kubevirt.io/domain=red-vm1,name=red-vm1,org=red
service/red-vm2-service    ClusterIP   10.100.106.19    <none>        80/TCP,22/TCP   48m   kubevirt.io/domain=red-vm2,name=red-vm2,org=red

NAME                                      READY   STATUS    RESTARTS   AGE   IP              NODE        NOMINATED NODE   READINESS GATES
pod/virt-launcher-blue-vm1-5bs7d          3/3     Running   0          48m   192.168.0.4     eksa-cp02   <none>           1/1
pod/virt-launcher-blue-vm2-wmrs7          3/3     Running   0          48m   192.168.0.133   eksa-cp02   <none>           1/1
pod/virt-launcher-red-vm1-5z8qc           3/3     Running   0          51m   192.168.0.29    eksa-cp02   <none>           1/1
pod/virt-launcher-red-vm2-m6jpl           3/3     Running   0          48m   192.168.0.35    eksa-cp02   <none>           1/1
```
Login to red-vm1 ping to red and blue vms IPs which is allowed.

```bash
ubuntu@red-vm1:~$ ping 192.168.0.133 
PING 192.168.0.133 (192.168.0.133) 56(84) bytes of data.
64 bytes from 192.168.0.133: icmp_seq=1 ttl=61 time=0.420 ms
64 bytes from 192.168.0.133: icmp_seq=2 ttl=61 time=0.376 ms

ubuntu@red-vm1:~$ ping 192.168.0.35 
PING 192.168.0.35 (192.168.0.35) 56(84) bytes of data.
64 bytes from 192.168.0.35: icmp_seq=1 ttl=61 time=0.410 ms
64 bytes from 192.168.0.35: icmp_seq=2 ttl=61 time=0.348 ms
```

Apply an L3/L4 Policy

When using Cilium, endpoint IP addresses are irrelevant when defining security policies. Instead, you can use the labels assigned 
to the pods to define security policies. The policies will be applied to the right pods based on the labels irrespective of where 
or when it is running within the cluster.

We’ll start with the basic policy restricting blue vms ssh/http requests to only the vmsthat have label (org=blue). 
This will not allow any vm that don’t have the org=blue label to even connect with the blue service. 
This is a simple policy that filters only on IP protocol (network layer 3) and TCP protocol (network layer 4), 
so it is often referred to as an L3/L4 network security policy.

```bash
> cat blue-policy.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "bluerule1"
spec:
  description: "L3-L4 policy to restrict blue vm access to blue vm only"
  endpointSelector:
    matchLabels:
      org: blue
  ingress:
  - fromEndpoints:
    - matchLabels:
        org: blue
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      - port: "22"
        protocol: TCP
```

Apply

```
> kc -f blue-policy.yaml
ciliumnetworkpolicy.cilium.io/bluerule1 created

> kubectl get cnp
NAME                     AGE
allow-within-namespace   25h
bluerule1                26s
rule1                    15h

> kubectl describe cnp bluerule1
Name:         bluerule1
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  cilium.io/v2
Kind:         CiliumNetworkPolicy
Metadata:
  Creation Timestamp:  2025-01-17T07:15:27Z
  Generation:          1
  Resource Version:    8506243
  UID:                 cbb423b1-447e-4d64-9217-90bcf8607a39
Spec:
  Description:  L3-L4 policy to restrict blue vm access to blue vm only
  Endpoint Selector:
    Match Labels:
      Org:  blue
  Ingress:
    From Endpoints:
      Match Labels:
        Org:  blue
    To Ports:
      Ports:
        Port:      80
        Protocol:  TCP
        Port:      22
        Protocol:  TCP
Status:
  Conditions:
    Last Transition Time:  2025-01-17T07:15:27Z
    Message:               Policy validation succeeded
    Status:                True
    Type:                  Valid
Events:                    <none>

```

Let's test the policy by accessing blue vm ssh which hangs
```bash
ubuntu@red-vm1:~$ ssh -vvv 192.168.0.133
OpenSSH_8.9p1 Ubuntu-3ubuntu0.6, OpenSSL 3.0.2 15 Mar 2022
debug1: Reading configuration data /etc/ssh/ssh_config
debug1: /etc/ssh/ssh_config line 19: include /etc/ssh/ssh_config.d/*.conf matched no files
debug1: /etc/ssh/ssh_config line 21: Applying options for *
debug2: resolve_canonicalize: hostname 192.168.0.133 is address
debug3: expanded UserKnownHostsFile '~/.ssh/known_hosts' -> '/home/ubuntu/.ssh/known_hosts'
debug3: expanded UserKnownHostsFile '~/.ssh/known_hosts2' -> '/home/ubuntu/.ssh/known_hosts2'
debug3: ssh_connect_direct: entering
debug1: Connecting to 192.168.0.133 [192.168.0.133] port 22.
debug3: set_sock_tos: set socket 3 IP_TOS 0x10
```
redvm to redvm is allowed
```
ubuntu@red-vm1:~$ ssh -vvv 192.168.0.133
OpenSSH_8.9p1 Ubuntu-3ubuntu0.6, OpenSSL 3.0.2 15 Mar 2022
debug1: Reading configuration data /etc/ssh/ssh_config
debug1: /etc/ssh/ssh_config line 19: include /etc/ssh/ssh_config.d/*.conf matched no files
debug1: /etc/ssh/ssh_config line 21: Applying options for *
debug2: resolve_canonicalize: hostname 192.168.0.133 is address
debug3: expanded UserKnownHostsFile '~/.ssh/known_hosts' -> '/home/ubuntu/.ssh/known_hosts'
debug3: expanded UserKnownHostsFile '~/.ssh/known_hosts2' -> '/home/ubuntu/.ssh/known_hosts2'
debug3: ssh_connect_direct: entering

```

Configs used for demo ->
[yaml configs](https://github.com/susantsahani/baremetal-docs/tree/main/vm-policy-blue-red/yaml)

