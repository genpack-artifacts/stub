#!/bin/sh
set -e

ROOTFS_DEVICE=/dev/disk/by-id/virtio-data
ROOTFS_TYPE=xfs

if [ -b $ROOTFS_DEVICE ]; then
	mkfs.$ROOTFS_TYPE -f $ROOTFS_DEVICE
else
	ROOTFS_DEVICE=fs
	ROOTFS_TYPE=virtiofs
fi

mount -t $ROOTFS_TYPE $ROOTFS_DEVICE /mnt

MIRROR="http://ports.ubuntu.com/ubuntu-ports"

case "$(uname -m)" in
    x86_64)
        ARCH="amd64"
	MIRROR="http://jp.archive.ubuntu.com/ubuntu"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    riscv64)
        ARCH="riscv64"
	;;
    *)
        echo "Unsupported architecture"
        exit 1
        ;;
esac

/usr/sbin/debootstrap --include="ubuntu-minimal,initramfs-tools,openssh-server,linux-generic,avahi-daemon,qemu-guest-agent,locales-all" --components=main,universe --arch=$ARCH resolute /mnt $MIRROR

sed -i 's/^\(root:\)[^:]*\(:.*\)$/\1\2/' /mnt/etc/shadow
echo -e "$ROOTFS_DEVICE\t/\t$ROOTFS_TYPE\tdefaults\t1 1" > /mnt/etc/fstab
echo -e "#/dev/disk/by-id/virtio-swap\tnone\tswap\tsw\t0 0" >> /mnt/etc/fstab
echo -e "#/dev/disk/by-id/virtio-docker\t/var/lib/docker\txfs\tdefaults,noatime\t0 0" >> /mnt/etc/fstab
echo -e "#/dev/disk/by-id/virtio-mysql\t/var/lib/mysql\txfs\tdefaults,noatime\t0 0" >> /mnt/etc/fstab
echo -e "network:\n  version: 2\n  renderer: networkd\n  ethernets:\n    eth0:\n      dhcp4: true\n      dhcp6: true" > /mnt/etc/netplan/99_config.yaml
sed -i 's/^#MulticastDNS=.*/MulticastDNS=yes/' /mnt/etc/systemd/resolved.conf
sed -i 's/^#LLMNR=.*/LLMNR=yes/' /mnt/etc/systemd/resolved.conf

[ -f /etc/localtime ] && cp -a /etc/localtime /mnt/etc/

[ -d /root/.ssh ] && cp -a /root/.ssh /mnt/root/
[ -d /etc/ssh -a -d /mnt/etc/ssh ] && cp -a /etc/ssh/*_key /etc/ssh/*_key.pub /mnt/etc/ssh/

echo -e 'deb http://archive.ubuntu.com/ubuntu/ noble-updates main universe\ndeb http://security.ubuntu.com/ubuntu/ noble-security main universe' >> /mnt/etc/apt/sources.list

echo -e 'virtiofs' >> /mnt/etc/initramfs-tools/modules
PATH=$PATH:/usr/sbin chroot /mnt /usr/sbin/update-initramfs -u

umount /mnt
reboot
