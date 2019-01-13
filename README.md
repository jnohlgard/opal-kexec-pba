opal-kexec-pba
==============

Alternative OPAL SED unlock image for pre-boot authentication (alternative to
LinuxPBA).

Introduction
------------

This repository contains some scripts for creating an initramfs and boot image
to use as a PBA image on OPAL encrypted hard disk and solid state drives.

See
[Drive-Trust-Alliance/sedutil](https://github.com/Drive-Trust-Alliance/sedutil)
for a more detailed explanation of self-encrypting drives (SED) and how to use
them with Linux.

Disclaimer
----------

These scripts have only been tested on a single machine, with a specific NVME
SED device, under UEFI. I won't be able to help you if it bricks your drive,
nor will I take any responsibility for any errors or flaws in the scripts which
may lead to ruined hard drives, leaked passwords or data, or anything other bad
things.

Features
--------

 - Uses the kexec mechanism to launch the regular OS kernel (only tested on
   Linux).
 - Faster boots since the UEFI firmware does not need to be executed twice
 - Defer boot process to a shell script in /boot
 - Provides optional warm reboot-method as an alternative if kexec is not
   possible (e.g. booting Windows)

Drawbacks
---------

 - No support for UEFI bootloaders such as rEFInd or GRUB2
 - No menus
 - Not well tested

Motivation
----------

The LinuxPBA provided in the DTA/sedutil repo requires a reboot after unlocking
in order to boot the regular OS, which can take a long time on some UEFI
firmwares.

Dependencies
------------

 - `sedutil-cli` from [sedutil](https://github.com/Drive-Trust-Alliance/sedutil)
 - `busybox` from [busybox](https://busybox.net)
 - `kexec` from [kexec-tools](https://kernel.org/pub/linux/utils/kernel/kexec/)
 - `hdparm` from [hdparm](https://sourceforge.net/projects/hdparm/)

All deps need to be built as static binaries or manually add the necessary
libraries.
`sedutil-cli` is used to unlock the drive and hide the shadow MBR to show the
real partitions.
`busybox` provides the shell.
`kexec` is used to load the kernel of regular OS and to execute it.
`hdparm` (-z option) is used to tell the kernel of the pre-boot environment to
re-read the partition table.

Usage
-----

When booting with a self-encrypting drive, the real file system is hidden and a
small partition is shown instead, this is sometimes called a _shadow MBR_.
The shadow MBR contains a minimal boot loader and a small system for unlocking
the drive. The boot loader I have used for this purpose is isolinux, copied
from sedutil's LinuxPBA. `isolinux` will launch a small Linux system for
unlocking the drive.
The init script in this repository will run opal-unlock until it succeeds in
unlocking at least one drive. After a drive has been unlocked, the init script
will either do a warm reset (system reboot back to UEFI/BIOS), or pass
execution on to a third stage boot loader named `boot.sh`.
`boot.sh` is a regular shell script, and is located on one of the regular
partitions of the drive (not in the shadow MBR area). This script allows us to
customize the boot process further without having to re-flash the shadow PBA
every time we do a kernel update or otherwise need to modify the boot.

An example `boot.sh` is provided in the scripts directory of this repo.

Quick recap:

Boot process with OPAL encrypted drive:

 1. UEFI/BIOS
 2. Start `isolinux` from shadow MBR
 3. Run minimal Linux system, `init` script takes over
 4. `init` calls sedutil to unlock the drive and unhide the normal partitions
 5. (a) Either: Reboot back to UEFI/BIOS
    (b) Or: `init` mounts `/boot`
 6. Pass execution on to `/boot/boot.sh`
 7. `boot.sh` loads a kernel and initramfs from `/boot` (`kexec -l`)
 8. `boot.sh` runs `kexec -e` to launch the full Linux system

Boot flags/kernel command-line
------------------------------

`init` handles only one command line option:

 - `boot=/dev/nvme0n1p1` - mount /dev/nvme0n1p1 as /boot before attempting to
   run /boot/boot.sh (at step 5b above)
 - `boot=reboot` - reboot system after unlocking (at step 5a above)

The example `boot.sh` handles some more options:

 - `kernel=FILENAME` - specify kernel filename to pass to kexec
 - `root=/dev/sda1` - specify root= option to pass to kexec'd kernel
 - `shell=1` - stop in an emergency shell before running `kexec -e`


Building initramfs and disk image
---------------------------------

This is not scripted (yet, feel free to provide one), below is an outline on how
to generate an image.

1. Create a local tree with all files for the initramfs
2. `find . -print0 | cpio --null -ov --format=newc > ../unlock.cpio`
3. `xz -9 -C crc32 unlock.cpio`
4. `dd if=/dev/zero of=opal.gptdisk bs=1M count=32`
5. `gdisk opal.gptdisk`
    - Create new partition table
    - Create new partition, default extents (whole "disk")
    - Type EF00
    - Set a parition name (might show up in the UEFI firmware boot menu)
    - `o`
    - `n` `[enter],[enter],[enter]`
    - `t` `EF00`
    - `c` `Unlock drive`
6. `losetup -f --show -o 1048576 opal.gptdisk`
7. `mount [loopback device] /mnt/opal`
8. Copy `bootdisk/EFI` to `/mnt/opal/EFI` (syslinux installation)
9. Copy isolinux `bootx64.efi` and `ldlinux.e64` to `/mnt/opal/EFI/Boot/`
10. Put a known good kernel at `/mnt/opal/EFI/Boot/bzImage`
11. Place `unlock.cpio.xz` at `/mnt/opal/EFI/Boot/unlock.cpio.xz`
12. `umount /mnt/opal`

It is also possible to start with the LinuxPBA image instead of an empty image,
mount it, and replace the syslinux.cfg, kernel bzImage, and initramfs.

The image generated above will only work on UEFI systems.

Building sedutil-cli as a static binary
---------------------------------------

Use the patch in `patches/sedutil-static.patch` to build sedutil-cli as a static
binary.

Setting up `/boot`
------------------

Place `boot.sh` and `warm-boot-conf.sh` in `/boot`. Modify `warm-boot-conf.sh`
with any settings you might need. The default behaviour is to let `boot.sh`
search the whole `/boot` disk for any kernels and pick the one with the newest
file modification date, which is most often the one we want to run.

Loading the PBA image into the shadow MBR
-----------------------------------------

With the drive unlocked:

    sedutil-cli --loadPBAimage password /path/to/opal.gptdisk /dev/nvme0n1

This takes a long time (several minutes for a few megabytes). Make a smaller
drive image (`dd` step above) if you want it to go faster.

Testing
-------
This has been tested on a single machine, with an Intel 6000p NVMe drive
(SSDPEKKF512G7), using UEFI boot, Secure Boot disabled.
I am using an image with these scripts as the primary unlock method on that
machine and have been using this for a few weeks now (2016-12-05).

Example initramfs layout
------------------------

    ├── bin/
    │   └── busybox*
    ├── boot/
    ├── dev/
    │   ├── console
    │   ├── null
    │   ├── tty
    │   └── zero
    ├── etc/
    ├── init*
    ├── lib -> lib64/
    ├── lib64/
    │   ├── ld-2.23.so*
    │   ├── ld-linux-x86-64.so.2 -> ld-2.23.so*
    │   ├── libc-2.23.so*
    │   ├── libc.so.6 -> libc-2.23.so*
    │   ├── liblzma.so.5 -> liblzma.so.5.2.2*
    │   ├── liblzma.so.5.2.2*
    │   ├── libpthread-2.23.so*
    │   ├── libpthread.so.0 -> libpthread-2.23.so*
    │   ├── libz.so.1 -> libz.so.1.2.8*
    │   └── libz.so.1.2.8*
    ├── mnt/
    │   └── root/
    ├── opal-unlock*
    ├── proc/
    ├── root/
    ├── sbin/
    │   ├── hdparm*
    │   ├── kexec*
    │   └── sedutil-cli*
    └── sys/
