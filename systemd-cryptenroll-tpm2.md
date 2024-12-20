### Setup TPM2 autodecrypt with systemd-cryptenroll on ubuntu


#### Install dracut

See [Install dracut](https://discourse.ubuntu.com/t/please-try-out-dracut/48975)

```bash
> sudo cp /boot/initrd.img-$(uname -r) /boot/initrd.img-$(uname -r).orig
> sudo apt install dracut-core
> sudo dracut -H --hostonly-mode=sloppy --force

# remove update-initramfs
sus@zeus:~$ sudo apt remove update-initramfs
```

#### Configure systemd-cryptenroll 

Figure out the encrypted parts
```
sus@zeus:~$ sudo lsblk -lf
NAME                  FSTYPE      FSVER    LABEL UUID                                   FSAVAIL FSUSE% MOUNTPOINTS
sr0
dm_crypt-0            LVM2_member LVM2 001       LjKNOp-2BLg-nAn3-2zB5-sR7w-mtuW-Jbkw7p
ubuntu--vg-ubuntu--lv ext4        1.0            37235b92-bf3f-476c-92a8-1f9ec2c515a0      4.9G    44% /
nvme0n1
nvme0n1p1             vfat        FAT32          ECFD-2A43                               944.8M     1% /boot/efi
nvme0n1p2             ext4        1.0            bcab7ebf-feb6-4362-b802-90942a9e8101      1.5G     7% /boot
nvme0n1p3             crypto_LUKS 2              a6825535-0609-4501-a464-ac23d96c834f


sus@zeus:~$ systemd-cryptenroll --tpm2-device=list
PATH        DEVICE     DRIVER
/dev/tpmrm0 VMW0004:00 tpm_tis

sus@zeus:~$ sudo cryptsetup luksDump /dev/nvme0n1p3
LUKS header information
Version:        2
Epoch:          3
Metadata area:  16384 [bytes]
Keyslots area:  16744448 [bytes]
UUID:           a6825535-0609-4501-a464-ac23d96c834f
Label:          (no label)
Subsystem:      (no subsystem)
Flags:          (no flags)

Data segments:
  0: crypt
        offset: 16777216 [bytes]
        length: (whole device)
        cipher: aes-xts-plain64
        sector: 512 [bytes]

Keyslots:
  0: luks2
        Key:        512 bits
        Priority:   normal
        Cipher:     aes-xts-plain64
        Cipher key: 512 bits
        PBKDF:      argon2id
        Time cost:  96
        Memory:     95298
Threads:    2
        Salt:       39 a2 01 f3 87 32 ec d2 26 6c e1 a2 5a d5 68 46
                    78 93 08 58 33 f8 00 41 bd 34 67 b2 c5 28 a6 d4
        AF stripes: 4000
        AF hash:    sha256
        Area offset:32768 [bytes]
        Area length:258048 [bytes]
        Digest ID:  0
Tokens:
Digests:
  0: pbkdf2
        Hash:       sha256
        Iterations: 399609
        Salt:       b4 e2 0b 9f 44 bd 1e 7e 38 4a e9 1b 2e c7 ea 51
                    c6 e2 50 4a 72 46 22 bb 88 1a 99 78 2e bd 66 9b
        Digest:     bc aa 5f 63 6d c5 6e 16 e0 cd d8 28 d0 ae 4e 8c
                    3a 60 3f 49 ee 26 c0 39 1f 4f 23 99 ce 06 0f 8a


```
```/dev/nvme0n1p3``` is the LUKS partition. Enter your LUKS password when prompt, and restart, you should not see a password prompt.
```bash
> sudo systemd-cryptenroll --wipe-slot tpm2 --tpm2-device auto --tpm2-pcrs "1+3+5+7+11+12+14+15" /dev/nvme0n1p3
```

#### Edit /etc/crypttab
```
sus@zeus:~$ sudo cat /etc/crypttab
dm_crypt-0 UUID=a6825535-0609-4501-a464-ac23d96c834f none luks,discard,tpm2-device=auto
```
#### Update dracut
```
> sudo dracut -H --hostonly-mode=sloppy --force
> sudo reboot
