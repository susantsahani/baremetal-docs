### Setup TPM2 autodecrypt with systemd-cryptenroll on ubuntu

The ```systemd-cryptsetup``` component of systemd (which is responsible for assembling encrypted volumes during boot) gained direct support for unlocking encrypted storage with three types of security hardware:

    Unlocking with FIDO2 security tokens (well, at least with those which implement the hmac-secret extension; most do). i.e. your YubiKeys (series 5 and above), Nitrokey FIDO2, AuthenTrend ATKey.Pro and such.

    Unlocking with TPM2 security chips (pretty ubiquitous on non-budget PCs/laptops/…)

    Unlocking with PKCS#11 security tokens, i.e. your smartcards and older YubiKeys (the ones that implement PIV). (Strictly speaking this was supported on older systemd already, but was a lot more "manual".)

Unlocking with TPM2

Most modern (non-budget) PC hardware (and other kind of hardware too) nowadays comes with a TPM2 security chip. In many ways a TPM2 chip is a smartcard that is soldered onto the mainboard of your system. Unlike your usual USB-connected security tokens you thus cannot remove them from your PC, which means they address quite a different security scenario: they aren't immediately comparable to a physical key you can take with you that unlocks some door, but they are a key you leave at the door, but that refuses to be turned by anyone but you.

Here's how you enroll your LUKS2 volume with your TPM2 chip:
```bash
# systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/sda5
```

Modify your /etc/crypttab to unlock via TPM2:
```
myvolume /dev/sda5 - tpm2-device=auto
```


#### Steps to unlock volume via systemd-cryptenroll


#### Install dracut

By default dracut is not installed and the default [update-initramfs](https://manpages.ubuntu.com/manpages/jammy/man8/update-initramfs.8.html)
does not support systemd hooks out of the box. Hence we need to install dracut which works seamlessly. 

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

Verify and see the tokens
```
 sudo cryptsetup luksDump /dev/nvme0n1p3
[sudo] password for sus: 
LUKS header information
Version:        2
Epoch:          9
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
  2: luks2
        Key:        512 bits
        Priority:   normal
        Cipher:     aes-xts-plain64
        Cipher key: 512 bits
        PBKDF:      pbkdf2
        Hash:       sha512
        Iterations: 1000
        Salt:       c2 de e7 eb 2e 8f 6d 77 ff 25 75 a1 8a 37 df eb 
                    69 88 92 ba 5b 51 1e 2e 0d cd 8d 04 19 c8 b9 bb 
        AF stripes: 4000
        AF hash:    sha512
        Area offset:548864 [bytes]
        Area length:258048 [bytes]
        Digest ID:  0
Tokens: <================================================================Here
  1: systemd-tpm2
        tpm2-hash-pcrs:   1+3+5+7+11+12+14+15
        tpm2-pcr-bank:    sha256
        tpm2-pubkey:
                    (null)
        tpm2-pubkey-pcrs: 
        tpm2-primary-alg: ecc
        tpm2-blob:        00 7e 00 20 c4 42 d0 04 7a 47 ac 13 f2 00 94 a4
                    a0 45 07 03 d5 ce e7 66 7f 08 10 91 4c ec c3 ca
                    2d 51 ae 26 00 10 cf 38 b1 0b e5 41 ae 80 14 52
                    42 76 2b 82 49 f6 90 35 6b a4 e1 2e 30 e3 57 31
                    f8 aa be d6 c9 c4 fb f2 99 9f 48 58 5a 4f b7 e8
                    4d 2a a5 99 1a c6 23 19 fb ac df ca 58 02 ee 44
                    07 ed 2b e7 e6 1b cc 47 9a fe eb 6a 2a 0f b1 b2
                    8c 73 92 a9 6d 61 25 3e 66 8a d3 3c 65 0c 24 86
                    00 4e 00 08 00 0b 00 00 00 12 00 20 28 1f 3f 81
                    c9 62 98 61 45 c0 17 fa 8a a7 c2 5b 68 1f c5 e8
                    a7 9e ef 46 c7 67 88 34 09 83 7d a2 00 10 00 20
                    61 49 16 ed 9e d9 7d f7 b0 20 b7 c2 00 91 b5 91
                    21 9f f8 45 29 b1 a9 51 af 8e 8e eb eb 71 e8 e2
        tpm2-policy-hash:
                    28 1f 3f 81 c9 62 98 61 45 c0 17 fa 8a a7 c2 5b
                    68 1f c5 e8 a7 9e ef 46 c7 67 88 34 09 83 7d a2
        tpm2-pin:         false
        tpm2-pcrlock:     false
        tpm2-salt:        false
        tpm2-srk:         true
        Keyslot:    2
Digests:
  0: pbkdf2
        Hash:       sha256
        Iterations: 399609
        Salt:       b4 e2 0b 9f 44 bd 1e 7e 38 4a e9 1b 2e c7 ea 51 
                    c6 e2 50 4a 72 46 22 bb 88 1a 99 78 2e bd 66 9b 
        Digest:     bc aa 5f 63 6d c5 6e 16 e0 cd d8 28 d0 ae 4e 8c 
                    3a 60 3f 49 ee 26 c0 39 1f 4f 23 99 ce 06 0f 8a 
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

After reboot you should not see a password prompt
