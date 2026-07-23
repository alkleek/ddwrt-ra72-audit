#!/usr/bin/env bash
set -Eeuo pipefail

out="phase8-output"
openwrt_tree="$out/openwrt"
mkdir -p "$openwrt_tree"
report="$out/REPORT-PHASE8.txt"
exec > >(tee "$report") 2>&1

echo "DD-WRT RA72 phase 8 runtime-DTB contract audit"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: source audit only; no firmware is built and nothing is flashable."
echo

contract="device/RA72-RUNTIME-DTB-CONTRACT.md"
test -s "$contract"

git clone --filter=blob:none --no-checkout "$OPENWRT_REPOSITORY" "$openwrt_tree"
git -C "$openwrt_tree" fetch --depth=1 origin "$OPENWRT_REF"
git -C "$openwrt_tree" checkout --detach FETCH_HEAD
git -C "$openwrt_tree" rev-parse HEAD | tee "$out/openwrt-commit.txt"

dts="$openwrt_tree/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ax6000.dts"
image="$openwrt_tree/target/linux/qualcommax/image/ipq50xx.mk"
test -s "$dts"
test -s "$image"

cp "$contract" "$out/RA72-RUNTIME-DTB-CONTRACT.md"
sed -n '/define Device\/xiaomi_ax6000/,/endef/p' "$image" \
  > "$out/openwrt-ra72-image-profile.txt"

grep -n -E 'mdio|ethernet-switch@11|ethernet-phy@8|gpio.*39|lan1|lan2|lan3|wan|ART|calibration|mac-address|pcie|wifi|led|button|reset' \
  "$dts" > "$out/openwrt-ra72-hardware-evidence.txt" || true

checks=(
  'compatible = "xiaomi,ax6000"'
  'qcom,ipq5018'
  'ethernet-switch@11'
  'ethernet-phy@8'
  'label = "lan1"'
  'label = "lan2"'
  'label = "lan3"'
  'label = "wan"'
  'define Device/xiaomi_ax6000'
)

{
  echo "RA72 source verification matrix"
  echo
  for check in "${checks[@]}"; do
    if grep -RFq "$check" "$dts" "$image"; then
      printf 'PASS\t%s\n' "$check"
    else
      printf 'FAIL\t%s\n' "$check"
    fi
  done
} | tee "$out/RA72-VERIFICATION-MATRIX.tsv"

if grep -q '^FAIL' "$out/RA72-VERIFICATION-MATRIX.tsv"; then
  echo "RESULT: BLOCKED - the selected OpenWrt source no longer matches the verified RA72 contract."
  exit 1
fi

cat > "$out/DDWRT-RA72-PORT-SKELETON.md" <<'EOF'
# DD-WRT RA72 port skeleton — non-flashable

This is an implementation checklist, not source code or firmware.

## Required target identity

- Xiaomi Mi AIoT AX6000
- Model RA72
- Qualcomm IPQ5018 / MP03.1
- Reject Xiaomi Mi Router AX6000 and Redmi AX6000

## Required integration work

1. Add an RA72-specific ARM64 device tree.
2. Preserve all reserved-memory regions used by trusted firmware and WCSS.
3. Define both MDIO controllers, QCA8337 switch, three LAN ports and QCA8081 WAN.
4. Define all three Wi-Fi radios and read calibration only from the ART partition.
5. Add board detection, MAC extraction, LEDs and reset button handling.
6. Add an initramfs-only target before any persistent image target.
7. Keep all NAND write/install logic absent from the first prototype.
8. Verify a bootloader-supported image container and safe RAM load address using UART.

## First prototype acceptance

- Loaded to RAM only
- Starts an ARM64 kernel
- Reaches a serial shell
- Reads, but never writes, the MTD layout
- A power cycle returns to the unchanged working OpenWrt installation

No item in this document authorizes flashing.
EOF

echo
echo "RESULT: the working runtime DTB contract matches the selected OpenWrt RA72 source."
echo "A DD-WRT port skeleton can now be maintained without storing the raw device DTB."
echo "BLOCKER: a RAM-only DD-WRT prototype still requires verified U-Boot load/container details."
echo "DO NOT FLASH: all phase 8 outputs are reports only."
