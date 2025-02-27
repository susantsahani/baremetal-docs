#### Installing Kata Containers from GitHub Releases

1. Install qemu-system
```bash
sudo apt-get update
sudo apt-get install -y \
    git \
    make \
    gcc \
    libglib2.0-dev \
    pkg-config \
    qemu-system
```
2. Download the Latest Kata Release

```bash
# Define the Kata version (Check latest version from GitHub)
KATA_VERSION=$(curl -s https://api.github.com/repos/kata-containers/kata-containers/releases/latest | grep -Po '"tag_name": "\K[^"]+')

# Download the Kata Containers tarball
curl -OL https://github.com/kata-containers/kata-containers/releases/download/${KATA_VERSION}/kata-static-${KATA_VERSION}-x86_64.tar.xz
```

3. Extract and install Kata
```
sudo mkdir -p /opt/kata
sudo tar -xJf kata-static-3.14.0-amd64.tar.xz -C /
```

4. Create Symlinks:
To make Kata binaries accessible system-wide:
```
sudo ln -sf /opt/kata/bin/kata-runtime /usr/local/bin/kata-runtime
sudo ln -sf /opt/kata/bin/containerd-shim-kata-v2 /usr/local/bin/containerd-shim-kata-v2
```

4. Verify installation

```
> kata-runtime --version
kata-runtime  : 3.14.0
   commit   : ae1be28ddd7043c0371b870d20e47eb5be034c17
   OCI specs: 1.1.0+dev

```

5. Configure containerd to Use Kata. Add runtime configuration in ```/etc/containerd/config.toml```

```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
   [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
      runtime_type = "io.containerd.kata.v2"
```

6. Restart containerd
```
> sudo systemctl restart containerd
> sudo systemctl status containerd
● containerd.service - containerd container runtime
     Loaded: loaded (/etc/systemd/system/containerd.service; enabled; vendor preset: enabled)
    Drop-In: /etc/systemd/system/containerd.service.d
             └─max-tasks.conf, memory-pressure.conf
     Active: active (running) since Thu 2025-02-27 06:24:31 UTC; 2min 10s ago
       Docs: https://containerd.io
    Process: 47801 ExecStartPre=/sbin/modprobe overlay (code=exited, status=0/SUCCESS)
   Main PID: 47802 (containerd)
      Tasks: 459
     Memory: 6.5G
        CPU: 4.931s
     CGroup: /system.slice/containerd.service

```

7. test with containerd with latest ubuntu image

```bash
sudo ctr image pull docker.io/library/ubuntu:latest
docker.io/library/ubuntu:latest:                                                  resolved       |++++++++++++++++++++++++++++++++++++++| 
index-sha256:72297848456d5d37d1262630108ab308d3e9ec7ed1c3286a32fe09856619a782:    done           |++++++++++++++++++++++++++++++++++++++| 
manifest-sha256:3afff29dffbc200d202546dc6c4f614edc3b109691e7ab4aa23d02b42ba86790: done           |++++++++++++++++++++++++++++++++++++++| 
config-sha256:a04dc4851cbcbb42b54d1f52a41f5f9eca6a5fd03748c3f6eb2cbeb238ca99bd:   done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:5a7813e071bfadf18aaa6ca8318be4824a9b6297b3240f2cc84c1db6f4113040:    done           |++++++++++++++++++++++++++++++++++++++| 
elapsed: 2.6 s                                                                    total:  28.4 M (10.9 MiB/s)                                      
unpacking linux/amd64 sha256:72297848456d5d37d1262630108ab308d3e9ec7ed1c3286a32fe09856619a782...
done: 1.107114124s

```

8. Run Ubuntu Container with Kata. Note kernel image is differes here.
```bash
sudo ctr run --runtime io.containerd.kata.v2 -t docker.io/library/ubuntu:latest kata-ubuntu bash
uname -a 
Linux localhost 6.12.13 #1 SMP Mon Feb 17 16:46:21 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux

```

9. List Running Kata Containers
```
sudo ctr containers list
CONTAINER      IMAGE                              RUNTIME                  
kata-ubuntu    docker.io/library/ubuntu:latest    io.containerd.kata.v2
```


10. Integrate with Kubernetes

```cat kata-runtimeclass.yaml```
```
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata
```

```
k create -f kata-runtimeclass.yaml
runtimeclass.node.k8s.io/kata created
```
Verify it:
```
kubectl get runtimeclass
NAME   HANDLER   AGE
kata   kata      4m1s

```

11. Deploy Netshoot in Kubernetes with Kata
    ```kata-nginx-pod.yaml```
```
apiVersion: v1
kind: Pod
metadata:
  name: kata-pod
spec:
  runtimeClassName: kata
  containers:
  - name: nginx
    image: nginx

```

Check the pod status 
```
> kubectl get pod netshoot-kata
NAME            READY   STATUS    RESTARTS   AGE
kata-pod   1/1     Running   0          2m2s
```

Once it’s running, you can access it:
```
sudo crictl ps | grep kata
d99b9be0935cf       b52e0b094bc0e       2 minutes ago       Running             nginx                     0                   34a83795768a1       kata-pod

```

verify whether it's running with qemu
```
pgrep -a qemu
52855 /opt/kata/bin/qemu-system-x86_64 -name sandbox-7edd4bf2bebd3781910c401f00bbec2e83938d11650078cef49416797f2ea01b -uuid 9b16d1d2-d2d8-4946-9570-0aaca9471cdb -machine q35,accel=kvm,nvdimm=on -cpu host,pmu=off -qmp unix:fd=3,server=on,wait=off -m 2048M,slots=10,maxmem=258203M -device pci-bridge,bus=pcie.0,id=pci-bridge-0,chassis_nr=1,shpc=off,addr=2,io-reserve=4k,mem-reserve=1m,pref64-reserve=1m -device virtio-serial-pci,disable-modern=false,id=serial0 -device virtconsole,chardev=charconsole0,id=console0 -chardev socket,id=charconsole0,path=/run/vc/vm/7edd4bf2bebd3781910c401f00bbec2e83938d11650078cef49416797f2ea01b/console.sock,server=on,wait=off -device nvdimm,id=nv0,memdev=mem0,unarmed=on -object memory-backend-file,id=mem0,mem-path=/opt/kata/share/kata-containers/kata-ubuntu-jammy.image,size=268435456,readonly=on -device virtio-scsi-pci,id=scsi0,disable-modern=false -object rng-random,id=rng0,filename=/dev/urandom -device virtio-rng-pci,rng=rng0 -device vhost-vsock-pci,disable-modern=false,vhostfd=4,id=vsock-3306626797,guest-cid=3306626797 -chardev socket,id=char-7fbe2d25d8bf214e,path=/run/vc/vm/7edd4bf2bebd3781910c401f00bbec2e83938d11650078cef49416797f2ea01b/vhost-fs.sock -device vhost-user-fs-pci,chardev=char-7fbe2d25d8bf214e,tag=kataShared,queue-size=1024 -netdev tap,id=network-0,vhost=on,vhostfds=5,fds=6 -device driver=virtio-net-pci,netdev=network-0,mac=b6:d3:f5:ac:e8:5c,disable-modern=false,mq=on,vectors=4 -rtc base=utc,driftfix=slew,clock=host -global kvm-pit.lost_tick_policy=discard -vga none -no-user-config -nodefaults -nographic --no-reboot -object memory-backend-file,id=dimm1,size=2048M,mem-path=/dev/shm,share=on -numa node,memdev=dimm1 -kernel /opt/kata/share/kata-containers/vmlinux-6.12.13-147 -append tsc=reliable no_timer_check rcupdate.rcu_expedited=1 i8042.direct=1 i8042.dumbkbd=1 i8042.nopnp=1 i8042.noaux=1 noreplace-smp reboot=k cryptomgr.notests net.ifnames=0 pci=lastbus=0 root=/dev/pmem0p1 rootflags=dax,data=ordered,errors=remount-ro ro rootfstype=ext4 console=hvc0 console=hvc1 quiet systemd.show_status=false panic=1 nr_cpus=64 selinux=0 systemd.unit=kata-containers.target systemd.mask=systemd-networkd.service systemd.mask=systemd-networkd.socket scsi_mod.scan=none cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1 -pidfile /run/vc/vm/7edd4bf2bebd3781910c401f00bbec2e83938d11650078cef49416797f2ea01b/pid -smp 1,cores=1,threads=1,sockets=64,maxcpus=64
53680 /opt/kata/bin/qemu-system-x86_64 -name sandbox-34a83795768a153dc62b14a16be14fa300728a547e5328cce530230d95b83c59 -uuid d149a7f3-b3d7-488a-96a7-a22ac965d7ee -machine q35,accel=kvm,nvdimm=on -cpu host,pmu=off -qmp unix:fd=3,server=on,wait=off -m 2048M,slots=10,maxmem=258203M -device pci-bridge,bus=pcie.0,id=pci-bridge-0,chassis_nr=1,shpc=off,addr=2,io-reserve=4k,mem-reserve=1m,pref64-reserve=1m -device virtio-serial-pci,disable-modern=false,id=serial0 -device virtconsole,chardev=charconsole0,id=console0 -chardev socket,id=charconsole0,path=/run/vc/vm/34a83795768a153dc62b14a16be14fa300728a547e5328cce530230d95b83c59/console.sock,server=on,wait=off -device nvdimm,id=nv0,memdev=mem0,unarmed=on -object memory-backend-file,id=mem0,mem-path=/opt/kata/share/kata-containers/kata-ubuntu-jammy.image,size=268435456,readonly=on -device virtio-scsi-pci,id=scsi0,disable-modern=false -object rng-random,id=rng0,filename=/dev/urandom -device virtio-rng-pci,rng=rng0 -device vhost-vsock-pci,disable-modern=false,vhostfd=4,id=vsock-1480487096,guest-cid=1480487096 -chardev socket,id=char-65465d9b0ca821ee,path=/run/vc/vm/34a83795768a153dc62b14a16be14fa300728a547e5328cce530230d95b83c59/vhost-fs.sock -device vhost-user-fs-pci,chardev=char-65465d9b0ca821ee,tag=kataShared,queue-size=1024 -netdev tap,id=network-0,vhost=on,vhostfds=5,fds=6 -device driver=virtio-net-pci,netdev=network-0,mac=12:34:92:2b:b7:c3,disable-modern=false,mq=on,vectors=4 -rtc base=utc,driftfix=slew,clock=host -global kvm-pit.lost_tick_policy=discard -vga none -no-user-config -nodefaults -nographic --no-reboot -object memory-backend-file,id=dimm1,size=2048M,mem-path=/dev/shm,share=on -numa node,memdev=dimm1 -kernel /opt/kata/share/kata-containers/vmlinux-6.12.13-147 -append tsc=reliable no_timer_check rcupdate.rcu_expedited=1 i8042.direct=1 i8042.dumbkbd=1 i8042.nopnp=1 i8042.noaux=1 noreplace-smp reboot=k cryptomgr.notests net.ifnames=0 pci=lastbus=0 root=/dev/pmem0p1 rootflags=dax,data=ordered,errors=remount-ro ro rootfstype=ext4 console=hvc0 console=hvc1 quiet systemd.show_status=false panic=1 nr_cpus=64 selinux=0 systemd.unit=kata-containers.target systemd.mask=systemd-networkd.service systemd.mask=systemd-networkd.socket scsi_mod.scan=none cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1 -pidfile /run/vc/vm/34a83795768a153dc62b14a16be14fa300728a547e5328cce530230d95b83c59/pid -smp 1,cores=1,threads=1,sockets=64,maxcpus=64

```

If we see the dir 
```
/opt/kata/bin
```
Then it already has diffrent vmm. By default kata uses the qemu-system-x86_64
```
cloud-hypervisor	 firecracker  kata-agent-ctl	    kata-manager     kata-runtime	   qemu-system-x86_64-snp-experimental
containerd-shim-kata-v2  genpolicy    kata-collect-data.sh  kata-manager.sh  kata-trace-forwarder  stratovirt
csi-kata-directvolume	 jailer       kata-ctl		    kata-monitor     qemu-system-x86_64
```




  




