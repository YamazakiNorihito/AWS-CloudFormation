## spec

instance : g6.xlarge
price: USD 0.8048/hour
region : us-east-2
vCPU:4
type:高速
<https://aws.amazon.com/jp/ec2/pricing/on-demand/>

## image

```bash
$ aws ec2 describe-images \
  --region us-east-2 \
  --owners amazon \
  --filters "Name=name,Values=Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04) *" \
           "Name=state,Values=available" \
  --query 'reverse(sort_by(Images, &CreationDate))[:1].[ImageId,Name,CreationDate]' \
  --output table \
  --profile 

```

## oolama install

confirm to installed drivers

```bash
$ nvidia-smi
Tue Sep 16 00:46:31 2025       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 570.172.08             Driver Version: 570.172.08     CUDA Version: 12.8     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA L4                      On  |   00000000:31:00.0 Off |                    0 |
| N/A   33C    P8             11W /   72W |       0MiB /  23034MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
                                                                                         
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+


$ nvcc --version
nvcc: NVIDIA (R) Cuda compiler driver
Copyright (c) 2005-2025 NVIDIA Corporation
Built on Fri_Feb_21_20:23:50_PST_2025
Cuda compilation tools, release 12.8, V12.8.93
Build cuda_12.8.r12.8/compiler.35583870_0
ubuntu@ip-172-31-13-105:~$ 
```

ストレージ と メモリ の状況を確認

```bash
ubuntu@ip-172-31-13-105:~$ df -h
Filesystem                      Size  Used Avail Use% Mounted on
/dev/root                        73G   50G   24G  68% /
tmpfs                           7.6G     0  7.6G   0% /dev/shm
tmpfs                           3.1G  1.1M  3.1G   1% /run
tmpfs                           5.0M     0  5.0M   0% /run/lock
efivarfs                        128K  3.8K  120K   4% /sys/firmware/efi/efivars
/dev/nvme0n1p15                 105M  6.1M   99M   6% /boot/efi
/dev/mapper/vg.01-lv_ephemeral  229G   28K  217G   1% /opt/dlami/nvme
tmpfs                           1.6G  4.0K  1.6G   1% /run/user/1000
ubuntu@ip-172-31-13-105:~$ lsblk
NAME                 MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0                  7:0    0  27.6M  1 loop /snap/amazon-ssm-agent/11797
loop1                  7:1    0  63.8M  1 loop /snap/core20/2599
loop2                  7:2    0  73.9M  1 loop /snap/core22/2045
loop3                  7:3    0  73.9M  1 loop /snap/core22/2111
loop4                  7:4    0  89.4M  1 loop /snap/lxd/31333
loop5                  7:5    0  49.3M  1 loop /snap/snapd/24792
loop6                  7:6    0  50.8M  1 loop /snap/snapd/25202
nvme0n1              259:0    0    75G  0 disk 
├─nvme0n1p1          259:2    0  74.9G  0 part /
├─nvme0n1p14         259:3    0     4M  0 part 
└─nvme0n1p15         259:4    0   106M  0 part /boot/efi
nvme1n1              259:1    0 232.8G  0 disk 
└─vg.01-lv_ephemeral 252:0    0 232.8G  0 lvm  /opt/dlami/nvme

```

メモリの確認

```bash
ubuntu@ip-172-31-13-105:~$ free -h
               total        used        free      shared  buff/cache   available
Mem:            15Gi       410Mi        13Gi       2.0Mi       853Mi        14Gi
Swap:             0B          0B          0B

ubuntu@ip-172-31-13-105:~$ lscpu
Architecture:             x86_64
  CPU op-mode(s):         32-bit, 64-bit
  Address sizes:          48 bits physical, 48 bits virtual
  Byte Order:             Little Endian
CPU(s):                   4
  On-line CPU(s) list:    0-3
Vendor ID:                AuthenticAMD
  Model name:             AMD EPYC 7R13 Processor
    CPU family:           25
    Model:                1
    Thread(s) per core:   2
    Core(s) per socket:   2
    Socket(s):            1
    Stepping:             1
    BogoMIPS:             5299.99
    Flags:                fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ht syscall nx mmxext fxsr_opt pdpe1gb rdtscp lm constant_tsc rep_good nopl nonstop_tsc cpuid extd_apicid aperfmperf tsc_known_freq pni pclmulqdq s
                          sse3 fma cx16 pcid sse4_1 sse4_2 x2apic movbe popcnt aes xsave avx f16c rdrand hypervisor lahf_lm cmp_legacy cr8_legacy abm sse4a misalignsse 3dnowprefetch topoext ssbd ibrs ibpb stibp vmmcall fsgsbase bmi1 avx2 smep bmi2 invpcid rdseed adx sma
                          p clflushopt clwb sha_ni xsaveopt xsavec xgetbv1 clzero xsaveerptr rdpru wbnoinvd arat npt nrip_save vaes vpclmulqdq rdpid
Virtualization features:  
  Hypervisor vendor:      KVM
  Virtualization type:    full
Caches (sum of all):      
  L1d:                    64 KiB (2 instances)
  L1i:                    64 KiB (2 instances)
  L2:                     1 MiB (2 instances)
  L3:                     8 MiB (1 instance)
NUMA:                     
  NUMA node(s):           1
  NUMA node0 CPU(s):      0-3
Vulnerabilities:          
  Gather data sampling:   Not affected
  Itlb multihit:          Not affected
  L1tf:                   Not affected
  Mds:                    Not affected
  Meltdown:               Not affected
  Mmio stale data:        Not affected
  Reg file data sampling: Not affected
  Retbleed:               Not affected
  Spec rstack overflow:   Mitigation; Safe RET
  Spec store bypass:      Mitigation; Speculative Store Bypass disabled via prctl
  Spectre v1:             Mitigation; usercopy/swapgs barriers and __user pointer sanitization
  Spectre v2:             Mitigation; Retpolines; IBPB conditional; IBRS_FW; STIBP always-on; RSB filling; PBRSB-eIBRS Not affected; BHI Not affected
  Srbds:                  Not affected
  Tsx async abort:        Not affected
ubuntu@ip-172-31-13-105:~$ 

```
