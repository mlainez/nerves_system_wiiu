#!/usr/bin/env bash
#
# Assemble the FAT32 boot image that fwup raw_writes to the active boot slot.
#
#   ::/fw.img                linux-loader (Starbuck/ARM payload, loaded by Aroma)
#   ::/linux/dtbImage.wiiu   the kernel (zImage with embedded DTB)
#   ::/linux/boot.cfg        linux-loader boot config
#   ::/linux/petitboot.conf  Petitboot menu (hold B on the GamePad to reach it)
#   ::/wiiu/...              Aroma cold-boot overlay (optional but required for
#                            the console to cold-boot to the Linux loader)
#
# root=/dev/mmcblk0p2 is intentional and slot-agnostic: fwup's mbr-a/mbr-b make
# the active rootfs MBR entry 1, which the kernel enumerates as mmcblk0p2. So
# the same image boots whether it lands in the A or B boot slot.
#
# Built with unprivileged host tools (mkfs.vfat + mtools) so it runs in the
# Nerves build sandbox — no root, no loop mounts.
#
# Env (set by Buildroot; overridable):
#   BINARIES_DIR          output images dir (bootpart.vfat lands here)
#   NERVES_DEFCONFIG_DIR  this system's source dir
#   HOST_DIR              Buildroot host tools
#   WIIU_BOOT_MB          boot partition size in MiB (default 128 — KEEP IN SYNC
#                         with BOOT_A_PART_COUNT in fwup_include/fwup-common.conf)
#   WIIU_FW_IMG           path to fw.img (default board/wiiu/fw.img)
#   WIIU_SDCARD_OVERLAY   path to the Aroma overlay dir containing wiiu/
#                         (default board/wiiu/sdcard)
set -euo pipefail

BOOT_MB="${WIIU_BOOT_MB:-128}"
BINARIES_DIR="${BINARIES_DIR:?BINARIES_DIR not set (run from Buildroot post-image)}"
DEFCONFIG_DIR="${NERVES_DEFCONFIG_DIR:?NERVES_DEFCONFIG_DIR not set}"
HOST_DIR="${HOST_DIR:?HOST_DIR not set}"

info() { printf '[boot-img] %s\n' "$*"; }
die()  { printf '[boot-img] ERROR: %s\n' "$*" >&2; exit 1; }

# Locate host tools (Buildroot puts mkfs.vfat in sbin, mtools in bin).
MKFSVFAT="$HOST_DIR/sbin/mkfs.vfat"
[ -x "$MKFSVFAT" ] || MKFSVFAT="$HOST_DIR/bin/mkfs.vfat"
MCOPY="$HOST_DIR/bin/mcopy"
MMD="$HOST_DIR/bin/mmd"
for t in "$MKFSVFAT" "$MCOPY" "$MMD"; do
  [ -x "$t" ] || die "missing host tool '$t' (need BR2_PACKAGE_HOST_DOSFSTOOLS + BR2_PACKAGE_HOST_MTOOLS)"
done

KERNEL="$BINARIES_DIR/dtbImage.wiiu"
FW_IMG="${WIIU_FW_IMG:-$DEFCONFIG_DIR/board/wiiu/fw.img}"
SD_OVERLAY="${WIIU_SDCARD_OVERLAY:-$DEFCONFIG_DIR/board/wiiu/sdcard}"
OUT="$BINARIES_DIR/bootpart.vfat"
STAGE="$BINARIES_DIR/.bootstage"

[ -f "$KERNEL" ] || die "kernel not found: $KERNEL"
[ -f "$FW_IMG" ] || die "fw.img not found: $FW_IMG (set WIIU_FW_IMG or drop one at board/wiiu/fw.img)"

# --- Generate the boot configs ---------------------------------------------
rm -rf "$STAGE"
mkdir -p "$STAGE/linux"
cp "$KERNEL" "$STAGE/linux/dtbImage.wiiu"

cat > "$STAGE/linux/petitboot.conf" <<'EOF'
default Nerves
timeout 1

label Nerves
  kernel /linux/dtbImage.wiiu
  args   root=/dev/mmcblk0p2 rootwait ro
EOF

cat > "$STAGE/linux/boot.cfg" <<'EOF'
[loader]
default=nerves

[profile:nerves]
name=Nerves
kernel=sdmc:/linux/dtbImage.wiiu
cmdline=root=/dev/mmcblk0p2 rootwait ro
EOF

# --- Build + populate the FAT image ----------------------------------------
rm -f "$OUT"
# mkfs.vfat -C takes a block count in 1 KiB blocks. BOOT_MB MiB == BOOT_MB*1024
# blocks == BOOT_MB*2048 sectors, matching BOOT_A_PART_COUNT.
"$MKFSVFAT" -F 32 -n NERVESBOOT -C "$OUT" "$(( BOOT_MB * 1024 ))" >/dev/null

# Aroma cold-boot overlay first (creates ::/wiiu and any payload.elf-side files).
if [ -d "$SD_OVERLAY/wiiu" ]; then
  info "including Aroma overlay from $SD_OVERLAY/wiiu"
  "$MCOPY" -s -i "$OUT" "$SD_OVERLAY/wiiu" ::/
else
  info "WARNING: no Aroma overlay at $SD_OVERLAY/wiiu"
  info "         the card won't cold-boot to the Linux loader. Populate it once"
  info "         from a working Aroma SD card (or set WIIU_SDCARD_OVERLAY)."
fi

# Loader + kernel + boot config.
"$MMD"   -i "$OUT" ::/linux
"$MCOPY" -i "$OUT" "$FW_IMG" ::/fw.img
"$MCOPY" -i "$OUT" "$STAGE/linux/dtbImage.wiiu" "::/linux/dtbImage.wiiu"
"$MCOPY" -i "$OUT" "$STAGE/linux/boot.cfg"      "::/linux/boot.cfg"
"$MCOPY" -i "$OUT" "$STAGE/linux/petitboot.conf" "::/linux/petitboot.conf"

rm -rf "$STAGE"
info "wrote $OUT (${BOOT_MB} MiB FAT32)"
