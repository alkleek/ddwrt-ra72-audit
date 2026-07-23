#!/usr/bin/env bash
set -Eeuo pipefail

out="phase5-output"
openwrt_tree="$out/openwrt"
ddwrt_files="$out/ddwrt-reference"
mkdir -p "$openwrt_tree" "$ddwrt_files"
report="$out/REPORT-PHASE5.txt"

exec > >(tee "$report") 2>&1

echo "DD-WRT RA72 phase 5 hardware integration map"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: audit only; no firmware is built and nothing is flashable."
echo

echo "=== Working OpenWrt RA72 reference ==="
git clone --filter=blob:none --no-checkout "$OPENWRT_REPOSITORY" "$openwrt_tree"
git -C "$openwrt_tree" fetch --depth=1 origin "$OPENWRT_REF"
git -C "$openwrt_tree" checkout --detach FETCH_HEAD
git -C "$openwrt_tree" rev-parse HEAD | tee "$out/openwrt-commit.txt"

mapfile -t ra72_dts < <(
  find "$openwrt_tree/target/linux/qualcommax" -type f \
    \( -iname '*xiaomi*ax6000*.dts' -o -iname '*xiaomi*ax6000*.dtsi' \) \
    | sort
)

if (( ${#ra72_dts[@]} == 0 )); then
  echo "RESULT: the selected OpenWrt ref does not contain the RA72 device tree."
  exit 1
fi

printf '%s\n' "${ra72_dts[@]#"$openwrt_tree/"}" | tee "$out/openwrt-ra72-dts-paths.txt"

image_file="$openwrt_tree/target/linux/qualcommax/image/ipq50xx.mk"
test -f "$image_file"
device_block="$out/openwrt-ra72-device-definition.txt"
sed -n '/define Device\/xiaomi_ax6000/,/endef/p' "$image_file" > "$device_block"

grep -q 'SOC := ipq5018' "$device_block"
grep -q 'DEVICE_DTS_CONFIG := config@mp03\.1' "$device_block"
grep -q 'NAND_SIZE := 128m' "$device_block"

mkdir -p "$out/openwrt-reference"
for path in "${ra72_dts[@]}" "$image_file"; do
  cp "$path" "$out/openwrt-reference/$(basename "$path")"
done

echo
echo "=== DD-WRT IPQ5018 references ==="
repository=""
for candidate in "$DDWRT_HTTPS_URL" "$DDWRT_SVN_URL"; do
  echo "Testing source URL: $candidate"
  if svn info "$candidate" > "$out/ddwrt-svn-info.txt" 2>&1; then
    repository="$candidate"
    break
  fi
done
test -n "$repository"
cat "$out/ddwrt-svn-info.txt"

ddwrt_paths=(
  "src/linux/universal/linux-6.12-nss/arch/arm64/boot/dts/qcom/ipq5018-mr5500.dts"
  "src/linux/universal/linux-6.12-nss/arch/arm64/boot/dts/qcom/ipq5018-mx5500.dts"
  "src/linux/universal/linux-6.12-nss/arch/arm64/boot/dts/qcom/ipq5018-ess.dtsi"
  "src/linux/universal/linux-6.12-nss/arch/arm64/boot/dts/qcom/ipq5018-nss.dtsi"
  "src/router/Makefile.ipq60xx"
  "src/router/services/sysinit/sysinit-ipq807x.c"
)

for path in "${ddwrt_paths[@]}"; do
  destination="$ddwrt_files/$(basename "$path")"
  svn cat "$repository/$path" > "$destination"
  test -s "$destination"
  echo "$path"
done

cat > "$out/ra72-observed-hardware.txt" <<'EOF'
Identity: Xiaomi Mi AIoT AX6000
Model: RA72
SoC: Qualcomm IPQ5018
Board configuration: MP03.1
NAND: 128 MiB
Boot layout: Xiaomi A/B, rootfs and rootfs_1 are 0x02400000 each
Calibration partition: 0:ART, 0x00100000
Boot environment: 0:APPSBLENV
Ethernet switch: QCA8337
2.5 GbE PHY: QCA8081
MDIO controllers: 0x88000 and 0x90000
Observed PHY reset GPIO: 39
Wi-Fi families observed: IPQ5018, QCA9887, QCN6024/9024/9074
OpenWrt internal device ID: xiaomi_ax6000 (this ID means RA72 here)
EOF

keywords='model|compatible|mtd|partition|rootfs|art|caldata|nvmem|mac-address|qca8337|qca8081|mdio|gpio|ethernet|switch|wifi|ath10k|ath11k|firmware-name|button|led'

grep -RIniE "$keywords" "$out/openwrt-reference" \
  > "$out/openwrt-integration-lines.txt" || true
grep -RIniE "$keywords" "$ddwrt_files" \
  > "$out/ddwrt-integration-lines.txt" || true

{
  echo "=== OpenWrt RA72 device definition ==="
  cat "$device_block"
  echo
  echo "=== Known RA72 hardware facts ==="
  cat "$out/ra72-observed-hardware.txt"
  echo
  echo "=== OpenWrt RA72 integration lines ==="
  cat "$out/openwrt-integration-lines.txt"
  echo
  echo "=== DD-WRT reference integration lines ==="
  cat "$out/ddwrt-integration-lines.txt"
} > "$out/PORT-MAP-EVIDENCE.txt"

openwrt_lines=$(wc -l < "$out/openwrt-integration-lines.txt")
ddwrt_lines=$(wc -l < "$out/ddwrt-integration-lines.txt")

echo
echo "=== Automated classification ==="
echo "Working OpenWrt RA72 DTS files: ${#ra72_dts[@]}"
echo "OpenWrt integration evidence lines: $openwrt_lines"
echo "DD-WRT reference integration evidence lines: $ddwrt_lines"
echo "Verified OpenWrt identity: IPQ5018 / MP03.1 / 128 MiB NAND"
echo
echo "RESULT: the DD-WRT IPQ5018 template can now be mapped against the working RA72 definition."
echo "NEXT: manually resolve every difference in DTS, NAND/A-B image handling, board detection,"
echo "Ethernet, Wi-Fi calibration, MAC extraction, LEDs, and buttons before creating a boot-only prototype."
echo
echo "DO NOT FLASH: this artifact contains reports and public source excerpts only."
