### Configure and use your TPM 2.0 module on Ubuntu

#### Intro

A TPM module (or Trusted Platform Module) is an international standard for a secure cryptoprocessor, 
which is a dedicated micro-controller designed to secure hardware by integrating cryptographic keys into devices.

#### configure TPM 2.0 on Ubuntu

Verify if in /dev/ you have a tpm0 device:
```bash
sus@zeus:~$ ls /dev/tpm0
/dev/tpm0
```

#### Configuring the required services to control the TPM 2.0 Module

First off check if the tpm2-abrmd daemon is installed and it’s up and running:
```bash
sus@zeus:~$ systemctl status tpm2-abrmd
```
Note: Some Linux packaging may NOT load the TPM drivers automatically after installting, so, in some cases you may have to run modprobe manualy (or reboot your Linux system).
```bash
sus@zeus:~$   sudo modprobe tpm_tis_spi
```

If tpm2-abrmd is not  installed, but not running then you can run it via:

```bash
> apt install tpm2-tools
> systemctl start tpm2-abrmd
> systemctl enable tpm2-abrmd
```

See status

```bash
sus@zeus:~$ systemctl status tpm2-abrmd
● tpm2-abrmd.service - TPM2 Access Broker and Resource Management Daemon
     Loaded: loaded (/usr/lib/systemd/system/tpm2-abrmd.service; enabled; preset: enabled)
     Active: active (running) since Fri 2024-12-20 05:07:08 UTC; 15min ago
   Main PID: 1123 (tpm2-abrmd)
      Tasks: 7 (limit: 4599)
     Memory: 1.8M (peak: 2.1M)
        CPU: 4ms
     CGroup: /system.slice/tpm2-abrmd.service
             └─1123 /usr/sbin/tpm2-abrmd

Dec 20 05:07:08 zeus systemd[1]: Starting tpm2-abrmd.service - TPM2 Access Broker and Resource Management Daemon...
Dec 20 05:07:08 zeus systemd[1]: Started tpm2-abrmd.service - TPM2 Access Broker and Resource Management Daemon.
```


Verify via ```systemd-cryptenroll```

```
sus@zeus:~$ systemd-cryptenroll --tpm2-device=list
PATH        DEVICE     DRIVER
/dev/tpmrm0 VMW0004:00 tpm_tis
```




