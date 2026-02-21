#!/bin/sh
set -e
/lib/systemd/systemd-networkd-wait-online

ARCH=$(uname -m)
RELEASEVER=42
BASE_URL=https://dl.fedoraproject.org/pub/fedora/linux/releases/$RELEASEVER/Everything/$ARCH/os/

ROOTFS_DEVICE=/dev/disk/by-id/virtio-data
ROOTFS_TYPE=xfs

if [ -b $ROOTFS_DEVICE ]; then
	mkfs.$ROOTFS_TYPE -f $ROOTFS_DEVICE
else
	ROOTFS_DEVICE=fs
	ROOTFS_TYPE=virtiofs
fi

mount -t $ROOTFS_TYPE $ROOTFS_DEVICE /mnt
trap 'umount -R /mnt 2>/dev/null || true' EXIT

mkdir -p /mnt/dev /mnt/proc /mnt/sys
mount -o bind /proc /mnt/proc
mount -o bind /sys /mnt/sys
mount -o bind /dev /mnt/dev

mkdir -p /mnt/etc/dracut.conf.d
echo 'add_drivers+=" virtiofs "' > /mnt/etc/dracut.conf.d/virtiofs.conf

# About rpmbootstrap, see https://github.com/shimarin/rpmbootstrap
rpmbootstrap -x /usr/libexec/platform-python --no-signature --no-scripts $BASE_URL /mnt "fedora-release"
rpm --root /mnt --import /mnt/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$RELEASEVER-$ARCH
rpmbootstrap -x /usr/libexec/platform-python $BASE_URL /mnt "dnf5"

echo -e 'search local\nnameserver 8.8.8.8\nnameserver 8.8.4.4\nnameserver 2001:4860:4860::8888\nnameserver 2001:4860:4860::8844' > /mnt/etc/resolv.conf

rm -rf /mnt/var/lib/rpm /mnt/usr/lib/sysimage/rpm
mkdir -p /mnt/usr/lib/sysimage/rpm
chroot /mnt rpm --initdb
echo $RELEASEVER > /mnt/etc/dnf/vars/releasever
chroot /mnt dnf install -y "dnf5" "passwd" "vim-minimal" "strace" "less" "kernel" "tar" "openssh-server" "openssh-clients" "NetworkManager" "iproute" "qemu-guest-agent" "grub2-common" "fedora-gpg-keys"

hostname > /mnt/etc/hostname
mkdir -p /mnt/etc/NetworkManager/system-connections
cat <<'EOF' > /mnt/etc/NetworkManager/system-connections/eth0.nmconnection
[connection]
id=eth0
type=ethernet
interface-name=eth0
autoconnect=yes

[ethernet]

[ipv4]
method=auto

[ipv6]
method=auto
EOF
chmod 600 /mnt/etc/NetworkManager/system-connections/eth0.nmconnection

sed -i 's/^\(root:\)[^:]*\(:.*\)$/\1\2/' /mnt/etc/shadow
mkdir -p /mnt/etc/systemd/resolved.conf.d
cat <<'EOF' > /mnt/etc/systemd/resolved.conf.d/mdns.conf
[Resolve]
MulticastDNS=yes
LLMNR=yes
EOF
echo 'LANG=ja_JP.utf8' > /mnt/etc/locale.conf
[ -f /etc/localtime ] && cp -a /etc/localtime /mnt/etc/

[ -d /root/.ssh ] && cp -a /root/.ssh /mnt/root/
[ -d /etc/ssh -a -d /mnt/etc/ssh ] && cp -a /etc/ssh/*_key /etc/ssh/*_key.pub /mnt/etc/ssh/

chroot /mnt systemctl enable sshd systemd-resolved qemu-guest-agent

umount /mnt/dev
umount /mnt/sys
umount /mnt/proc
umount /mnt

reboot

# Run
#  dnf install waypipe foot google-noto-sans-cjk-fonts epiphany
# to run GUI applications in the VM with Wayland forwarding via waypipe.