#!/bin/sh
PURPLE='\033[0;35m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

#############################
# Linux Installation #
#############################

# Define the root directory to /home/container.
# We can only write in /home/container and /tmp in the container.
ROOTFS_DIR=/home/container

export PATH=$PATH:~/.local/usr/bin

PROOT_VERSION="5.3.0" # Some releases do not have static builds attached.

# Detect the machine architecture.
ARCH=$(uname -m)

# Check machine architecture to make sure it is supported.
# If not, we exit with a non-zero status code.
if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
else
  printf "Unsupported CPU architecture: ${ARCH}"
  exit 1
fi

# Download & decompress the Linux root file system if not already installed.
if [ ! -e "$ROOTFS_DIR/.installed" ]; then
      url="https://fra1lxdmirror01.do.letsbuildthe.cloud/images/ubuntu/focal/${ARCH_ALT}/default/"
      LATEST_VERSION=$(curl -s $url | grep -oP 'href="\K[^"]+/' | sort -r | head -n 1)
      curl -Ls "${url}${LATEST_VERSION}/rootfs.tar.xz" -o $ROOTFS_DIR/rootfs.tar.xz
      tar -xf $ROOTFS_DIR/rootfs.tar.xz -C "$ROOTFS_DIR"
      mkdir $ROOTFS_DIR/home/container/ -p
fi

################################
# Package Installation & Setup #
#################################

# Download run.sh
curl -Ls "https://raw.githubusercontent.com/nkyo/Pterodactyl-VPS-Egg/main/run.sh" -o "$ROOTFS_DIR/home/container/run.sh"
# Make run.sh executable.
chmod +x "$ROOTFS_DIR/home/container/run.sh"

# Download static proot.
if [ ! -e "$ROOTFS_DIR/.installed" ]; then
    # Download the packages from their sources
    mkdir -p "$ROOTFS_DIR/usr/local/bin"
    curl -Ls "https://github.com/proot-me/proot/releases/download/v${PROOT_VERSION}/proot-v${PROOT_VERSION}-${ARCH}-static" -o "$ROOTFS_DIR/usr/local/bin/proot"
    # Make PRoot executable.
    chmod 755 "$ROOTFS_DIR/usr/local/bin/proot"
fi

# Clean-up after installation complete & finish up.
if [ ! -e "$ROOTFS_DIR/.installed" ]; then
    # Add DNS Resolver nameservers to resolv.conf.
    printf "nameserver 1.1.1.1\nnameserver 1.0.0.1" > "${ROOTFS_DIR}/etc/resolv.conf"
    # Wipe the files we downloaded into /tmp previously.
    rm -rf $ROOTFS_DIR/rootfs.tar.xz /tmp/sbin
    # Create .installed to later check whether OS is installed.
    touch "$ROOTFS_DIR/.installed"
fi

###########################
# Start PRoot environment #
###########################

# Get primary port from vps.config
port=$(grep -oP 'port=\K\d+' "$ROOTFS_DIR/vps.config")

# This command starts PRoot and binds several important directories
# from the host file system to our special root file system.
"$ROOTFS_DIR/usr/local/bin/proot" \
--rootfs="${ROOTFS_DIR}" \
-0 -w "/root" -b /dev -b /sys -b /proc -b /etc/resolv.conf -p $port:$port --kill-on-exit \
/bin/sh "$ROOTFS_DIR/run.sh"
