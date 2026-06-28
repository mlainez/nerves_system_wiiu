#!/bin/sh

set -e

# Buildroot post-build hook. $1 = TARGET_DIR (the staging rootfs).
TARGET_DIR="$1"

# Mount points populated at runtime by erlinit:
#   /data  - F2FS application data partition (mmcblk0p3)
#   /boot  - the active FAT boot partition, so the kernel/boot config can be
#            updated from userspace if needed.
install -d "$TARGET_DIR/data"
install -d "$TARGET_DIR/boot"

# Compile the runtime fwup operations (revert / factory-reset / validate /
# status). ops.fw lands in the rootfs; revert.fw is the legacy alias.
mkdir -p "$TARGET_DIR/usr/share/fwup"
"$HOST_DIR/usr/bin/fwup" -c -f "$NERVES_DEFCONFIG_DIR/fwup-ops.conf" \
    -o "$TARGET_DIR/usr/share/fwup/ops.fw"
ln -sf ops.fw "$TARGET_DIR/usr/share/fwup/revert.fw"

# Copy the fwup includes next to the images so fwup.conf's include() resolves
# both at build time and when re-imaging from a published system.
cp -rf "$NERVES_DEFCONFIG_DIR/fwup_include" "$BINARIES_DIR"
