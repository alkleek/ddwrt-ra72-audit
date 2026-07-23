#!/usr/bin/env bash
set -Eeuo pipefail

out="phase6-output"
openwrt_tree="$out/openwrt"
ddwrt_files="$out/ddwrt-reference"
mkdir -p "$openwrt_tree" "$ddwrt_files"
report="$out/REPORT-PHASE6.txt"
exec > >(tee "$report") 2>&1

echo "DD-WRT RA72 phase 6 NAND and A/B boot safety audit"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: source audit only; no firmware is built and nothing is flashable."
echo

git clone --filter=blob:none --no-checkout "$OPENWRT_REPOSITORY" "$openwrt_tree"
git -C "$openwrt_tree" fetch --depth=1 origin "$OPENWRT_REF"
git -C "$openwrt_tree" checkout --detach FETCH_HEAD
git -C "$openwrt_tree" rev-parse HEAD | tee "$out/openwrt-commit.txt"

dts="$openwrt_tree/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ax6000.dts"
image="$openwrt_tree/target/linux/qualcommax/image/ipq50xx.mk"
upgrade="$openwrt_tree/target/linux/qualcommax/ipq50xx/base-files/lib/upgrade/platform.sh"
for file in "$dts" "$image" "$upgrade"; do test -s "$file"; done

awk '
  /partitions[[:space:]]*\{/ { capture=1 }
  capture {
    print
    line=$0
    opens += gsub(/\{/, "{", line)
    line=$0
    closes += gsub(/\}/, "}", line)
  }
  capture && opens > 0 && opens == closes { exit }
' "$dts" > "$out/openwrt-ra72-partitions.txt"
sed -n '/define Device\/xiaomi_ax6000/,/endef/p' "$image" > "$out/openwrt-ra72-image-profile.txt"
grep -n -A35 -B10 -E 'xiaomi_ax6000|xiaomi,ax6000' "$upgrade" \
  > "$out/openwrt-ra72-upgrade-handling.txt" || true

repository=""
for candidate in "$DDWRT_HTTPS_URL" "$DDWRT_SVN_URL"; do
  if svn info "$candidate" > "$out/ddwrt-svn-info.txt" 2>&1; then
    repository="$candidate"
    break
  fi
done
test -n "$repository"
cat "$out/ddwrt-svn-info.txt"

ddwrt_paths=(
  "src/router/Makefile.ipq60xx"
  "src/router/services/sysinit/sysinit-ipq807x.c"
  "src/linux/universal/linux-6.12-nss/arch/arm64/boot/dts/qcom/ipq5018-mr5500.dts"
  "src/linux/universal/linux-6.12-nss/arch/arm64/boot/dts/qcom/ipq5018-mx5500.dts"
)
for path in "${ddwrt_paths[@]}"; do
  destination="$ddwrt_files/$(basename "$path")"
  svn cat "$repository/$path" > "$destination"
  test -s "$destination"
done

keywords='nand|ubi|ubifs|ubinize|rootfs|rootfs_1|bootconfig|appsblenv|nvram|sysupgrade|flash|mtd|partition|factory|trx|fit|itb'
grep -RIniE "$keywords" "$ddwrt_files" > "$out/ddwrt-nand-boot-evidence.txt" || true
grep -RIniE "$keywords" "$dts" "$image" "$upgrade" > "$out/openwrt-nand-boot-evidence.txt" || true

cat > "$out/RA72-REQUIRED-LAYOUT.txt" <<'EOF'
Device: Xiaomi Mi AIoT AX6000 RA72 only
NAND erase block: 128 KiB
NAND page size: 2048 bytes
NAND total: 128 MiB
Stock A/B slots:
  rootfs   = 0x02400000 (36 MiB)
  rootfs_1 = 0x02400000 (36 MiB)
Boot selector:
  flag_boot_rootfs
  flag_last_success
Critical unique data:
  0:ART calibration partition
  0:APPSBLENV boot environment
Known-safe OpenWrt transition:
  factory initramfs UBI into inactive slot, then reviewed sysupgrade
EOF

has_ra72_profile=0
ddwrt_has_ra72=0
grep -q 'define Device/xiaomi_ax6000' "$out/openwrt-ra72-image-profile.txt" && has_ra72_profile=1
grep -RqiE 'xiaomi.{0,8}(ax6000|ra72)|ra72' "$ddwrt_files" && ddwrt_has_ra72=1

{
  echo "=== Required RA72 layout ==="
  cat "$out/RA72-REQUIRED-LAYOUT.txt"
  echo
  echo "=== Working OpenWrt partition definition ==="
  cat "$out/openwrt-ra72-partitions.txt"
  echo
  echo "=== Working OpenWrt image profile ==="
  cat "$out/openwrt-ra72-image-profile.txt"
  echo
  echo "=== Working OpenWrt upgrade handling ==="
  cat "$out/openwrt-ra72-upgrade-handling.txt"
  echo
  echo "=== DD-WRT NAND and boot evidence ==="
  cat "$out/ddwrt-nand-boot-evidence.txt"
} > "$out/NAND-BOOT-EVIDENCE.txt"

echo
echo "=== Automated classification ==="
echo "OpenWrt RA72 image profile found: $has_ra72_profile"
echo "Existing DD-WRT RA72 board/image handling found: $ddwrt_has_ra72"
echo
if (( has_ra72_profile != 1 )); then
  echo "RESULT: BLOCKED - selected OpenWrt reference is not the verified RA72 baseline."
  exit 1
fi
if (( ddwrt_has_ra72 == 1 )); then
  echo "RESULT: an existing DD-WRT RA72 reference was found and needs manual verification."
else
  echo "RESULT: DD-WRT has no existing RA72 A/B NAND image path."
  echo "A new RA72-specific image recipe and boot-slot policy are required."
fi
echo "NEXT: define a non-flashable boot-only prototype contract (kernel, DTB, initramfs,"
echo "size limits and UART acceptance checks) without writing NAND."
echo
echo "DO NOT FLASH: this artifact contains reports and source excerpts only."
