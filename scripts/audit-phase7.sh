#!/usr/bin/env bash
set -Eeuo pipefail

out="phase7-output"
openwrt_tree="$out/openwrt"
ddwrt_files="$out/ddwrt-reference"
mkdir -p "$openwrt_tree" "$ddwrt_files"
report="$out/REPORT-PHASE7.txt"
exec > >(tee "$report") 2>&1

echo "DD-WRT RA72 phase 7 boot-only prototype contract"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: planning audit only; no firmware is built and nothing is flashable."
echo

git clone --filter=blob:none --no-checkout "$OPENWRT_REPOSITORY" "$openwrt_tree"
git -C "$openwrt_tree" fetch --depth=1 origin "$OPENWRT_REF"
git -C "$openwrt_tree" checkout --detach FETCH_HEAD
git -C "$openwrt_tree" rev-parse HEAD | tee "$out/openwrt-commit.txt"

dts="$openwrt_tree/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ax6000.dts"
image="$openwrt_tree/target/linux/qualcommax/image/ipq50xx.mk"
test -s "$dts"
test -s "$image"

sed -n '/define Device\/xiaomi_ax6000/,/endef/p' "$image" \
  > "$out/openwrt-ra72-image-profile.txt"
grep -n -E 'chosen|bootargs|memory|reserved-memory|serial|uart|rootfs|ubi|config@mp03|KERNEL_SIZE|NAND_SIZE|BLOCKSIZE|PAGESIZE' \
  "$dts" "$image" > "$out/openwrt-boot-evidence.txt" || true

repository=""
for candidate in "$DDWRT_HTTPS_URL" "$DDWRT_SVN_URL"; do
  if svn info "$candidate" > "$out/ddwrt-svn-info.txt" 2>&1; then
    repository="$candidate"
    break
  fi
done
test -n "$repository"

ddwrt_paths=(
  "src/router/Makefile.ipq60xx"
  "src/linux/universal/linux-6.12-nss/arch/arm64/boot/dts/qcom/ipq5018-mr5500.dts"
  "src/linux/universal/linux-6.12-nss/arch/arm64/boot/dts/qcom/ipq5018-mx5500.dts"
)
for path in "${ddwrt_paths[@]}"; do
  destination="$ddwrt_files/$(basename "$path")"
  svn cat "$repository/$path" > "$destination"
  test -s "$destination"
done

grep -RIniE 'uImage|Image|itb|fit|initramfs|ramdisk|loadaddr|entry|bootm|booti|dtb|ipq5018|rootfs|ubi' \
  "$ddwrt_files" > "$out/ddwrt-boot-format-evidence.txt" || true

cat > "$out/BOOT-ONLY-CONTRACT.txt" <<'EOF'
Exact target:
  Xiaomi Mi AIoT AX6000, model RA72
  Qualcomm IPQ5018, MP03.1, 512 MiB RAM, 128 MiB NAND

Prototype purpose:
  Prove that a DD-WRT kernel, RA72 DTB and initramfs can reach a UART shell.

Hard safety boundaries:
  1. Do not erase, format or write any MTD partition.
  2. Do not modify flag_boot_rootfs, flag_last_success or bootloader environment.
  3. Do not include an automatic installer, sysupgrade path or NAND writer.
  4. Load the prototype into RAM using a verified bootloader command only.
  5. Keep the currently working OpenWrt installation and UART recovery available.

Known size limits:
  Stock rootfs slot: 36 MiB.
  Working OpenWrt KERNEL_SIZE: 36864 KiB.
  These are upper storage bounds, not verified RAM load addresses.

Prototype components:
  - ARM64 IPQ5018 kernel in a bootloader-supported container.
  - RA72-specific DTB derived from the working definition.
  - Minimal read-only initramfs with UART shell.
  - No writable overlay and no NAND utilities in the first prototype.

Acceptance checks, in order:
  1. Bootloader recognizes the in-RAM image.
  2. Kernel starts on IPQ5018 and prints to UART.
  3. RA72 model, RAM and clocks are detected.
  4. Initramfs reaches a shell.
  5. /proc/mtd is read-only inspected and matches the known layout.
  6. ART is detected but never written.
  7. Ethernet and Wi-Fi are diagnostic-only and not required for first success.
  8. Power cycle returns to the unchanged working OpenWrt installation.

Current blockers:
  - Exact RA72 bootloader RAM load address is not verified.
  - Supported boot command/container (bootm/booti/FIT) is not verified.
  - Maximum safe transfer/load region is not verified.
  - A DD-WRT RA72 DTB and initramfs target do not exist yet.
EOF

cat > "$out/REQUIRED-UART-DATA.txt" <<'EOF'
Before any boot-only image is built, capture these read-only bootloader details:

1. Full boot banner and bootloader version.
2. The complete output of the bootloader help command.
3. The complete output of the bootloader environment print command.
4. Commands available for RAM loading (for example TFTP or serial transfer).
5. Commands available for booting ARM64/FIT images.
6. Reported RAM start, RAM size, existing load address and kernel address.

Do not run saveenv, setenv, erase, nand write, mtd, ubi, reset-to-default,
or any command that changes persistent storage.
EOF

has_profile=0
has_ddwrt_ipq5018=0
grep -q 'define Device/xiaomi_ax6000' "$out/openwrt-ra72-image-profile.txt" && has_profile=1
grep -Rqi 'ipq5018' "$ddwrt_files" && has_ddwrt_ipq5018=1

echo "=== Automated classification ==="
echo "Verified OpenWrt RA72 baseline found: $has_profile"
echo "DD-WRT IPQ5018 boot/build references found: $has_ddwrt_ipq5018"
echo
if (( has_profile != 1 || has_ddwrt_ipq5018 != 1 )); then
  echo "RESULT: BLOCKED - required source baseline is missing."
  exit 1
fi
echo "RESULT: a boot-only contract can be defined, but a prototype must not be built"
echo "until the exact bootloader commands and safe RAM addresses are captured."
echo "NEXT: collect the read-only UART bootloader data listed in REQUIRED-UART-DATA.txt."
echo
echo "DO NOT FLASH: this artifact contains reports and source excerpts only."
