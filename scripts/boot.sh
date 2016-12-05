#!/bin/sh
# Third stage bootloader which selects a kernel to execute

# Copyright (C) 2016  Joakim Nohlgård
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

: ${DEBUG:=1}

cmdline() {
    local value
    value=" $(cat /proc/cmdline) "
    value="${value##* $1=}"
    value="${value%% *}"
    [ -n "$value" ] && echo "$value"
}

. /boot/warm-boot-conf.sh


if [ -z "$KERNEL" ] ; then
    KERNEL=$(cmdline kernel)
fi
if [ -z "$KERNEL" ] ; then
    echo "No kernel specified, falling back to most recent kernel binary in /boot"
    KERNEL=$(find /boot -name 'vmlinu*' -type f -exec stat -c '%Y %n' {} + | sort -rn | head -n 1 | cut -d' ' -f 2-)
fi

echo "Using kernel: $KERNEL"

KVER=${KERNEL##*vmlinu?-}
KVER=${KVER%%.efi}
KDIR=$(dirname "${KERNEL}")

if [ "${DEBUG}" -ne 0 ] ; then
    echo "KDIR=${KDIR}"
    echo "KVER=${KVER}"
fi

: ${INITRD:=${KDIR}/initramfs-${KVER}.img}

echo "Looking for initial ramdisk ${INITRD}"

if [ -f ${INITRD} ] ; then
    echo "Found: ${INITRD}"
else
    echo "Not found"
    INITRD=
fi

: ${CMDLINE:=root=$(cmdline root) ro}

set -x

#echo kexec -l $KERNEL --command-line="$CMDLINE" --initrd="$INITRD"
kexec -l $KERNEL --command-line="$CMDLINE" --initrd="$INITRD"

if [ -n "$(cmdline shell)" ]; then
    echo "last chance shell"
    sh
fi

# Clean up.
umount /proc
umount /sys
umount /dev/pts
umount /dev/shm
umount /dev
umount -a -r

# Boot the real thing.
kexec -e
