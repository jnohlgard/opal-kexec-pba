#!/bin/sh
# Put your kernel command line for the regular OS here
# example:
#export CMDLINE="root=/dev/nvme0n1p2 ro libata.allow_tpm=1 quiet splash"
# or:
export CMDLINE="root=/dev/mapper/nvme-root ro init=/usr/lib/systemd/systemd libata.allow_tpm=1 resume=/dev/mapper/nvme-swap add_efi_memmap i8042.reset=1 i8042.kbdreset=1 i8042.nomux=1 quiet splash systemd.legacy_systemd_cgroup_controller=yes"
