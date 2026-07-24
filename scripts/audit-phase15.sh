#!/usr/bin/env bash
set -Eeuo pipefail

OUT="phase15-output"
REVIEW="$OUT/review"
REPORT="$OUT/REPORT-PHASE15.txt"
OPENWRT_DIR="$OUT/openwrt"
DDWRT_URL="${DDWRT_SVN_URL:-https://svn.dd-wrt.com/DD-WRT}"
OPENWRT_REPOSITORY="https://github.com/openwrt/openwrt.git"
OPENWRT_REF="${OPENWRT_REF:-openwrt-25.12}"

rm -rf "$OUT"
mkdir -p "$REVIEW"

exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 15 kernel baseline and ARM64 DTS foundation audit"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: audit only; no firmware is built and nothing is flashable."
echo

test -f device/RA72-PORT-DRAFT-CONTRACT.md
test -f device/RA72-PHASE14-PLATFORM-GAP-CONTRACT.md
test -f device/RA72-PHASE15-KERNEL-BASELINE-CONTRACT.md

echo "Cloning verified OpenWrt comparison reference: $OPENWRT_REF"
if ! git clone --filter=blob:none --no-checkout "$OPENWRT_REPOSITORY" "$OPENWRT_DIR"; then
  echo "AUDIT_INCOMPLETE_OPENWRT_SOURCE_UNAVAILABLE" | tee "$REVIEW/phase15-status.txt"
  exit 0
fi
if ! git -C "$OPENWRT_DIR" fetch --depth=1 origin "$OPENWRT_REF"; then
  echo "AUDIT_INCOMPLETE_OPENWRT_REF_UNAVAILABLE" | tee "$REVIEW/phase15-status.txt"
  rm -rf "$OPENWRT_DIR"
  exit 0
fi
git -C "$OPENWRT_DIR" checkout --detach FETCH_HEAD
git -C "$OPENWRT_DIR" rev-parse HEAD | tee "$REVIEW/openwrt-commit.txt"

{
  echo "OpenWrt ref: $OPENWRT_REF"
  echo "OpenWrt commit: $(git -C "$OPENWRT_DIR" rev-parse HEAD)"
  echo
  echo "Qualcommax kernel baseline:"
  grep -E 'KERNEL_PATCHVER|KERNEL_TESTING_PATCHVER' \
    "$OPENWRT_DIR/target/linux/qualcommax/Makefile" || true
  echo
  echo "RA72 device definition:"
  sed -n '/define Device\/xiaomi_ax6000/,/endef/p' \
    "$OPENWRT_DIR/target/linux/qualcommax/image/ipq50xx.mk" || true
} > "$REVIEW/openwrt-kernel-baseline.txt"

echo "Reading public DD-WRT source inventory..."
if ! svn info "$DDWRT_URL" > "$REVIEW/svn-info.txt" 2>&1; then
  echo "AUDIT_INCOMPLETE_DDWRT_SOURCE_UNAVAILABLE" | tee "$REVIEW/phase15-status.txt"
  rm -rf "$OPENWRT_DIR"
  exit 0
fi

if ! svn list -R "$DDWRT_URL/src/linux/universal" \
  > "$REVIEW/ddwrt-universal-inventory.txt" 2>&1; then
  echo "AUDIT_INCOMPLETE_DDWRT_UNIVERSAL_TREE_UNAVAILABLE" \
    | tee "$REVIEW/phase15-status.txt"
  rm -rf "$OPENWRT_DIR"
  exit 0
fi

sed -n 's#^\(linux-[^/]*\)/.*#\1#p' \
  "$REVIEW/ddwrt-universal-inventory.txt" \
  | sort -Vu > "$REVIEW/ddwrt-kernel-candidates.txt"

grep -Ei '^linux-[^/]+/arch/arm64/boot/dts/' \
  "$REVIEW/ddwrt-universal-inventory.txt" \
  | sort -u > "$REVIEW/ddwrt-arm64-dts-roots.txt" || true

grep -Ei 'ipq5018|ipq50xx|ipq50|arch/arm64/boot/dts/qcom|qcom.*\.dts' \
  "$REVIEW/ddwrt-universal-inventory.txt" \
  | sort -u > "$REVIEW/ddwrt-ipq5018-signals.txt" || true

arm64_qcom_count="$(
  grep -Eic 'arch/arm64/boot/dts/qcom' \
    "$REVIEW/ddwrt-arm64-dts-roots.txt" || true
)"
ipq5018_count="$(
  grep -Eic 'ipq5018|ipq50xx|ipq50' \
    "$REVIEW/ddwrt-ipq5018-signals.txt" || true
)"

{
  echo
  echo "=== Result ==="
  echo "DD-WRT kernel candidates: $(wc -l < "$REVIEW/ddwrt-kernel-candidates.txt")"
  echo "Qualcomm ARM64 DTS entries: $arm64_qcom_count"
  echo "Explicit IPQ5018/IPQ50xx signals: $ipq5018_count"
  echo
} | tee -a "$REPORT"

if (( ipq5018_count > 0 )); then
  status="AUDIT_COMPLETE_IPQ5018_KERNEL_BASELINE_CANDIDATE_FOUND_REVIEW_REQUIRED"
elif (( arm64_qcom_count > 0 )); then
  status="AUDIT_COMPLETE_NEAREST_KERNEL_BASELINE_FOUND_IPQ5018_PORT_REQUIRED"
else
  status="AUDIT_COMPLETE_NO_DD_WRT_ARM64_QCOM_BASELINE"
fi

echo "$status" | tee "$REVIEW/phase15-status.txt"

cat > "$REVIEW/NEXT-STEPS.txt" <<'EOF'
Review REPORT-PHASE15.txt, phase15-status.txt, the kernel candidate list, and
the Qualcomm ARM64 DTS inventory. Do not build or flash firmware from this
audit. A later phase may select one reviewed DD-WRT kernel baseline and create
a source-only integration plan for RA72.
EOF

rm -rf "$OPENWRT_DIR"
echo
echo "Phase 15 audit complete. No firmware was built."
