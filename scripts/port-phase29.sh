#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="$PWD/phase29-output"
REVIEW_DIR="$OUT_DIR/review"
PATCH_DIR="$OUT_DIR/patches"
WORK_DIR="$OUT_DIR/work"
REPORT="$OUT_DIR/REPORT-PHASE29.txt"
STATUS_FILE="$REVIEW_DIR/phase29-status.txt"
PHASE28_DIR="$PWD/phase28-output"

SOURCE_ROOT="$WORK_DIR/ddwrt"
KERNEL_OUT="$WORK_DIR/kernel-out"

rm -rf "$OUT_DIR" "$PHASE28_DIR"
mkdir -p "$REVIEW_DIR" "$PATCH_DIR" "$WORK_DIR"

cat > "$OUT_DIR/DO-NOT-FLASH.txt" <<'EOF'
PHASE 29 BUILDS A REVIEW DEVICE-TREE BLOB THROUGH THE DD-WRT KERNEL BUILD ONLY.
NO FIRMWARE, KERNEL IMAGE, UBI, BIN, ITB, OR TRX IMAGE IS BUILT.
NOTHING IN THIS ARTIFACT IS APPROVED FOR BOOTING OR FLASHING.
Exact device: Xiaomi Mi AIoT AX6000, model RA72, IPQ5018 / MP03.1 only.
This is not for Xiaomi Mi Router AX6000 or Redmi AX6000.
EOF

cleanup() {
  rm -rf "$WORK_DIR" "$PHASE28_DIR"
}

on_error() {
  local code=$?
  if [[ ! -f "$STATUS_FILE" ]]; then
    printf 'BLOCKED_UNEXPECTED_ERROR\n' > "$STATUS_FILE"
  fi
  echo "Phase 29 stopped with status $(cat "$STATUS_FILE") (exit $code)."
  exit "$code"
}

trap cleanup EXIT
trap on_error ERR
exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 29 native kernel DTB build"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: review DTB only; no firmware and no router access."
echo

echo "Reproducing the verified Phase 28 source patch..."
set +e
bash scripts/port-phase28.sh \
  2>&1 | tee "$REVIEW_DIR/phase28-bootstrap.log"
phase28_status=${PIPESTATUS[0]}
set -e

if [[ "$phase28_status" -ne 0 ]] \
    || [[ ! -f "$PHASE28_DIR/review/phase28-status.txt" ]] \
    || ! grep -qx \
      'RA72_NATIVE_Q6_MEMORY_INTEGRATION_PATCH_COMPILES_REVIEW_ONLY' \
      "$PHASE28_DIR/review/phase28-status.txt"; then
  printf 'BLOCKED_PHASE28_PATCH_REGENERATION_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

cp "$PHASE28_DIR/review/phase28-status.txt" \
  "$REVIEW_DIR/phase28-status.txt"
cp "$PHASE28_DIR/review/phase28-integration-checks.txt" \
  "$REVIEW_DIR/phase28-integration-checks.txt"
cp "$PHASE28_DIR/review/selected-ddwrt-source-url.txt" \
  "$REVIEW_DIR/selected-ddwrt-source-url.txt"
cp "$PHASE28_DIR/review/ddwrt-kernel-path.txt" \
  "$REVIEW_DIR/ddwrt-kernel-path.txt"
cp "$PHASE28_DIR/patches/"*.patch "$PATCH_DIR/"

SELECTED_URL="$(cat "$REVIEW_DIR/selected-ddwrt-source-url.txt")"
KERNEL_REL="$(cat "$REVIEW_DIR/ddwrt-kernel-path.txt")"
KERNEL_DIR="$SOURCE_ROOT/$KERNEL_REL"
PATCH_FILE="$PATCH_DIR/0001-ddwrt-add-xiaomi-mi-aiot-ax6000-ra72-review.patch"

echo "Selected public DD-WRT source: $SELECTED_URL"
echo "Selected native kernel tree: $KERNEL_REL"

svn info "$SELECTED_URL/$KERNEL_REL" \
  > "$REVIEW_DIR/ddwrt-kernel-svn-info.txt"

echo "Exporting the complete selected DD-WRT kernel tree."
echo "This is the longest Phase 29 step; progress is printed every 30 seconds."
mkdir -p "$(dirname "$KERNEL_DIR")"

set +e
timeout 120m svn export --force "$SELECTED_URL/$KERNEL_REL" "$KERNEL_DIR" \
  > "$REVIEW_DIR/kernel-export.log" 2>&1 &
export_pid=$!
while kill -0 "$export_pid" 2>/dev/null; do
  sleep 30
  exported_files="$(find "$KERNEL_DIR" -type f 2>/dev/null | wc -l)"
  exported_size="$(du -sh "$KERNEL_DIR" 2>/dev/null | cut -f1)"
  echo "Kernel export progress: files=$exported_files size=${exported_size:-0}"
done
wait "$export_pid"
export_status=$?
set -e

echo "kernel_export_status=$export_status" \
  > "$REVIEW_DIR/source-export-status.txt"
if [[ "$export_status" -ne 0 ]]; then
  printf 'BLOCKED_COMPLETE_DDWRT_KERNEL_EXPORT_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

mkdir -p "$SOURCE_ROOT/src/router"
timeout 10m svn cat "$SELECTED_URL/src/router/Makefile.ipq60xx" \
  > "$SOURCE_ROOT/src/router/Makefile.ipq60xx"

echo "Applying the verified Phase 28 patch to the full DD-WRT layout..."
patch --dry-run --batch -p1 -d "$SOURCE_ROOT" < "$PATCH_FILE" \
  > "$REVIEW_DIR/patch-dry-run.log" 2>&1
patch --batch -p1 -d "$SOURCE_ROOT" < "$PATCH_FILE" \
  > "$REVIEW_DIR/patch-apply.log" 2>&1

BOARD_DTS="$KERNEL_DIR/arch/arm64/boot/dts/qcom/ipq5018-xiaomi-ra72.dts"
BOARD_DTB="$KERNEL_OUT/arch/arm64/boot/dts/qcom/ipq5018-xiaomi-ra72.dtb"
QCOM_MAKEFILE="$KERNEL_DIR/arch/arm64/boot/dts/qcom/Makefile"
NATIVE_CONFIG="$KERNEL_DIR/.config_ipq6018"

test -f "$BOARD_DTS"
test -f "$QCOM_MAKEFILE"
test -f "$NATIVE_CONFIG"
grep -q 'ipq5018-xiaomi-ra72.dtb' "$QCOM_MAKEFILE"
grep -q '^CONFIG_ARM64=y$' "$NATIVE_CONFIG"
grep -q '^CONFIG_ARCH_QCOM=y$' "$NATIVE_CONFIG"

cp "$NATIVE_CONFIG" "$REVIEW_DIR/config-ipq6018.source"
sha256sum "$NATIVE_CONFIG" \
  > "$REVIEW_DIR/config-ipq6018.source.sha256"

mkdir -p "$KERNEL_OUT"
cp "$NATIVE_CONFIG" "$KERNEL_OUT/.config"

{
  echo "gcc=$(aarch64-linux-gnu-gcc --version | head -n1)"
  echo "make=$(make --version | head -n1)"
  echo "dtc=$(dtc --version 2>&1 | head -n1)"
  echo "kernel_rel=$KERNEL_REL"
} > "$REVIEW_DIR/build-tool-versions.txt"

MAKE_COMMON=(
  make
  -C "$KERNEL_DIR"
  O="$KERNEL_OUT"
  ARCH=arm64
  CROSS_COMPILE=aarch64-linux-gnu-
  KBUILD_BUILD_USER=github-actions
  KBUILD_BUILD_HOST=ddwrt-ra72-phase29
)

echo "Preparing the native DD-WRT IPQ6018 kernel configuration..."
set +e
timeout 45m "${MAKE_COMMON[@]}" olddefconfig \
  2>&1 | tee "$REVIEW_DIR/olddefconfig.log"
olddefconfig_status=${PIPESTATUS[0]}
set -e

if [[ "$olddefconfig_status" -ne 0 ]]; then
  {
    echo "olddefconfig_status=$olddefconfig_status"
    echo "dtb_build_status=99"
    echo "decompile_status=99"
    echo "roundtrip_status=99"
  } > "$REVIEW_DIR/build-status.txt"
  printf 'BLOCKED_NATIVE_DDWRT_OLDDEFCONFIG_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

cp "$KERNEL_OUT/.config" "$REVIEW_DIR/config-ipq6018.resolved"

echo "Building only qcom/ipq5018-xiaomi-ra72.dtb through native Kbuild..."
set +e
timeout 90m "${MAKE_COMMON[@]}" -j2 V=1 \
  qcom/ipq5018-xiaomi-ra72.dtb \
  2>&1 | tee "$REVIEW_DIR/native-kbuild.log"
dtb_build_status=${PIPESTATUS[0]}
set -e

if [[ "$dtb_build_status" -ne 0 || ! -s "$BOARD_DTB" ]]; then
  {
    echo "olddefconfig_status=$olddefconfig_status"
    echo "dtb_build_status=$dtb_build_status"
    echo "decompile_status=99"
    echo "roundtrip_status=99"
  } > "$REVIEW_DIR/build-status.txt"
  printf 'BLOCKED_NATIVE_DDWRT_KERNEL_DTB_BUILD_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

cp "$BOARD_DTB" "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dtb"
file "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dtb" \
  > "$REVIEW_DIR/native-dtb-file.txt"

decompile_status=0
dtc -I dtb -O dts \
  -o "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dts" \
  "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dtb" \
  > "$REVIEW_DIR/native-dtb-decompile.log" 2>&1 \
  || decompile_status=$?

roundtrip_status=99
if [[ "$decompile_status" -eq 0 ]]; then
  roundtrip_status=0
  dtc -I dts -O dtb \
    -o "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-roundtrip.dtb" \
    "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dts" \
    > "$REVIEW_DIR/native-dtb-roundtrip.log" 2>&1 \
    || roundtrip_status=$?
fi

{
  echo "olddefconfig_status=$olddefconfig_status"
  echo "dtb_build_status=$dtb_build_status"
  echo "decompile_status=$decompile_status"
  echo "roundtrip_status=$roundtrip_status"
} | tee "$REVIEW_DIR/build-status.txt"

if [[ "$decompile_status" -ne 0 || "$roundtrip_status" -ne 0 ]]; then
  printf 'BLOCKED_NATIVE_DDWRT_DTB_ROUNDTRIP_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

sha256sum \
  "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dtb" \
  "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-roundtrip.dtb" \
  > "$REVIEW_DIR/native-dtb-sha256.txt"

grep -i 'warning:' "$REVIEW_DIR/native-kbuild.log" \
  > "$REVIEW_DIR/native-kbuild-warnings.txt" || true
{
  echo "native_kbuild_warning_count=$(
    grep -ic 'warning:' "$REVIEW_DIR/native-kbuild.log" || true
  )"
  echo "native_decompile_warning_count=$(
    grep -ic 'warning:' "$REVIEW_DIR/native-dtb-decompile.log" || true
  )"
  echo "native_roundtrip_warning_count=$(
    grep -ic 'warning:' "$REVIEW_DIR/native-dtb-roundtrip.log" || true
  )"
} > "$REVIEW_DIR/warning-summary.txt"

find "$KERNEL_OUT" -type f \
  \( -name 'Image' -o -name '*.ubi' -o -name '*.bin' \
     -o -name '*.itb' -o -name '*.trx' -o -name '*.img' \) \
  -print > "$REVIEW_DIR/unexpected-firmware-files.txt"

echo "Running Phase 29 native-kernel integration checks..."
if ! python3 work/validate-phase29.py \
  "$REVIEW_DIR/phase28-status.txt" \
  "$REVIEW_DIR/build-status.txt" \
  "$REVIEW_DIR/config-ipq6018.resolved" \
  "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dts" \
  "$PATCH_FILE" \
  "$REVIEW_DIR/native-kbuild.log" \
  "$REVIEW_DIR/unexpected-firmware-files.txt" \
  "$REVIEW_DIR/phase29-integration-checks.txt"; then
  printf 'BLOCKED_NATIVE_DDWRT_KERNEL_DTB_VALIDATION_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

printf 'RA72_NATIVE_DDWRT_KERNEL_DTB_BUILD_PASS_REVIEW_ONLY\n' \
  > "$STATUS_FILE"

CHECK_COUNT="$(grep -c '=PASS$' \
  "$REVIEW_DIR/phase29-integration-checks.txt")"

cat <<EOF

Phase 29 result
---------------
STATUS: RA72_NATIVE_DDWRT_KERNEL_DTB_BUILD_PASS_REVIEW_ONLY

Verified:
- Full native DD-WRT kernel export: PASS
- Phase 28 patch regeneration and application: PASS
- Native .config_ipq6018 olddefconfig: PASS
- Native Kbuild qcom/ipq5018-xiaomi-ra72.dtb: PASS
- DTB decompile and round-trip compile: PASS
- RA72 identity, Ethernet, GE PHY, WAN PHY, and Q6 ranges: PASS
- Integration checks: $CHECK_COUNT/$CHECK_COUNT PASS
- Firmware/kernel image absence: PASS

Review DTB:
review/ipq5018-xiaomi-ra72.native-kbuild.dtb

Safety:
No DD-WRT firmware, kernel Image, UBI, BIN, ITB, TRX, or IMG was built.
No router, SSH session, UART, NAND partition, or boot variable was accessed.
The DTB is not boot-tested and is not approved for booting or flashing.
EOF

echo
echo "Phase 29 completed: $(cat "$STATUS_FILE")"
