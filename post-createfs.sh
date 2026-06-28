#!/bin/sh

set -e

# Buildroot post-image hook (BR2_ROOTFS_POST_IMAGE_SCRIPT). Runs after the
# rootfs images (rootfs.squashfs) are built. $1 = TARGET_DIR.

# 1. Assemble the FAT32 boot image (fw.img + kernel + boot config + Aroma
#    overlay) that fwup raw_writes to the active boot slot.
"$NERVES_DEFCONFIG_DIR/scripts/create-boot-img.sh"

# 2. Hand off to the Nerves common post-createfs, which stages the fwup config
#    and builds the .fw firmware artifacts.
FWUP_CONFIG="$NERVES_DEFCONFIG_DIR/fwup.conf"
"$BR2_EXTERNAL_NERVES_PATH/board/nerves-common/post-createfs.sh" "$TARGET_DIR" "$FWUP_CONFIG"
