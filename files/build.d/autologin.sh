set -e
mkdir -p /etc/systemd/system/getty\@hvc0.service.d
echo -e '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux' > /etc/systemd/system/getty\@hvc0.service.d/override.conf

mkdir -p /etc/systemd/system/serial-getty\@ttyS0.service.d
echo -e '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin root --noclear %I 115200 linux' > /etc/systemd/system/serial-getty\@ttyS0.service.d/override.conf
