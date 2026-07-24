#!/usr/bin/env bash
set -Eeuo pipefail

OUT="phase14-output"
REVIEW="$OUT/review"
REPORT="$OUT/REPORT-PHASE14.txt"
OPENWRT_DIR="${RUNNER_TEMP:-/tmp}/ddwrt-ra72-phase14-openwrt"
OPENWRT_REF="${OPENWRT_REF:-openwrt-25.12}"
DDWRT_URL="https://svn.dd-wrt.com/DD-WRT"

rm -rf "$OUT"
mkdir -p "$REVIEW"
rm -rf "$OPENWRT_DIR"

exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 14 platform-gap audit"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: analysis only; no firmware is built and nothing is flashable."
echo

grep -q "Model: RA72" device/RA72.txt
grep -q "SoC: Qualcomm IPQ5018" device/RA72.txt
grep -q "Board: IPQ5018 MP03.1" device/RA72.txt

echo "Cloning verified OpenWrt reference: $OPENWRT_REF"
git clone --filter=blob:none --no-checkout https://github.com/openwrt/openwrt.git "$OPENWRT_DIR"
git -C "$OPENWRT_DIR" fetch --depth=1 origin "$OPENWRT_REF"
git -C "$OPENWRT_DIR" checkout --detach FETCH_HEAD
git -C "$OPENWRT_DIR" rev-parse HEAD | tee "$REVIEW/openwrt-commit.txt"

echo
echo "Reading public DD-WRT source inventory"
if svn info "$DDWRT_URL" > "$REVIEW/svn-info.txt" 2>&1; then
  if ! svn list -R "$DDWRT_URL/src" > "$REVIEW/ddwrt-source-inventory.txt" 2>&1; then
    echo "DD-WRT recursive source listing was unavailable." >> "$REVIEW/ddwrt-source-inventory.txt"
  fi
else
  echo "DD-WRT SVN information was unavailable during this run." \
    > "$REVIEW/ddwrt-source-inventory.txt"
fi

echo "Collecting OpenWrt IPQ5018 components"
{
  find "$OPENWRT_DIR/target/linux/qualcommax" -type f 2>/dev/null
  find "$OPENWRT_DIR/package/kernel" -type f 2>/dev/null
} | sort -u | sed "s#^$OPENWRT_DIR/##" \
  | grep -Ei 'ipq50|ipq5018|qca8337|qca808|qca8k|ath10k|ath11k|nss|mdio|qcom' \
  > "$REVIEW/openwrt-ipq5018-components.txt" || true

grep -Ei 'ipq50|ipq5018|qca8337|qca808|qca8k|ath10k|ath11k|nss|mdio' \
  "$REVIEW/ddwrt-source-inventory.txt" \
  > "$REVIEW/ddwrt-ipq5018-matches.txt" || true

cat > "$REVIEW/missing-platform-components.txt" <<'EOF'
Phase 14 platform categories requiring integrated DD-WRT support

1. IPQ5018 SoC Device Tree and board-level DTS foundation
2. Clock, reset, pinctrl, interrupt and reserved-memory definitions
3. SPI-NAND, UBI, RA72 partitions and safe A/B boot handling
4. PCIe controller and PHY integration
5. MDIO, NSS-DP Ethernet, QCA8337 switch and QCA8081 2.5GbE PHY
6. ath10k/ath11k radios, firmware loading and per-device calibration data
7. DD-WRT target, profile, image recipe and platform initialization

Scattered driver files or text matches do not constitute an integrated target.
EOF

cat > "$REVIEW/source-import-plan.txt" <<'EOF'
Ordered source-import and integration plan

1. Establish the compatible DD-WRT kernel baseline and ARM64 DTS include tree.
2. Add the IPQ5018 SoC DTS foundation and required binding headers.
3. Integrate clocks, resets, pinctrl, interrupts and reserved-memory regions.
4. Integrate SPI-NAND, UBI, the exact RA72 partition map and safe A/B behavior.
5. Integrate NSS-DP Ethernet, MDIO, QCA8337 and QCA8081.
6. Integrate PCIe and Wi-Fi (ath11k/ath10k), firmware and ART calibration.
7. Add the DD-WRT build target, board profile, image recipe and defaults.
8. Produce only a boot-only prototype first and validate it through UART.

No permanent flash image should be produced before the boot-only prototype
passes serial-console, Ethernet, NAND, Wi-Fi calibration and recovery checks.
EOF

cat > "$REVIEW/phase14-status.txt" <<'EOF'
AUDIT_COMPLETE_PLATFORM_BASE_MISSING

The public DD-WRT source inventory may contain relevant Qualcomm drivers and
isolated IPQ5018 references, but it does not establish a complete, integrated
Xiaomi Mi AIoT AX6000 RA72 target. Phase 14 is analysis-only.
EOF

echo
cat "$REVIEW/missing-platform-components.txt"
echo
cat "$REVIEW/source-import-plan.txt"
echo
cat "$REVIEW/phase14-status.txt"
