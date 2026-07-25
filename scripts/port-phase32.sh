#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="$PWD/phase32-output"
REVIEW_DIR="$OUT_DIR/review"
PATCH_DIR="$OUT_DIR/patches"
WORK_DIR="$OUT_DIR/work"
REPORT="$OUT_DIR/REPORT-PHASE32.txt"
STATUS_FILE="$REVIEW_DIR/phase32-status.txt"
PHASE28_DIR="$PWD/phase28-output"

SOURCE_ROOT="$WORK_DIR/ddwrt"

rm -rf "$OUT_DIR" "$PHASE28_DIR"
mkdir -p "$REVIEW_DIR" "$PATCH_DIR" "$WORK_DIR"

cat > "$OUT_DIR/DO-NOT-BOOT-OR-FLASH.txt" <<'EOF'
PHASE 32 BUILDS A RAW ARM64 KERNEL IMAGE AND AN EXACT-MODEL REVIEW DTB.
THE RAW IMAGE IS NOT COMPLETE DD-WRT FIRMWARE AND IS NOT BOOT-APPROVED.
NO ROOTFS, MODULE PACKAGE, FIT, UBI, BIN, ITB, TRX, OR IMG IS BUILT.
DO NOT BOOT OR FLASH ANY FILE FROM THIS ARTIFACT.
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
  echo "Phase 32 stopped with status $(cat "$STATUS_FILE") (exit $code)."
  exit "$code"
}

trap cleanup EXIT
trap on_error ERR
exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 32 in-tree native ARM64 kernel Image build"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: review kernel and DTB only; no firmware and no router access."
echo "CORRECTION: native in-tree build; no O= output directory."
echo

echo "Reproducing the verified Phase 28 source patch..."
if bash scripts/port-phase28.sh \
    2>&1 | tee "$REVIEW_DIR/phase28-bootstrap.log"; then
  phase28_status=0
else
  phase28_status=${PIPESTATUS[0]}
fi

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
cp "$PHASE28_DIR/review/model-identity-resolution.txt" \
  "$REVIEW_DIR/model-identity-resolution.txt"
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
echo "Progress is printed every 30 seconds."
mkdir -p "$(dirname "$KERNEL_DIR")"

timeout 120m svn export --force "$SELECTED_URL/$KERNEL_REL" "$KERNEL_DIR" \
  > "$REVIEW_DIR/kernel-export.log" 2>&1 &
export_pid=$!
while kill -0 "$export_pid" 2>/dev/null; do
  sleep 30
  exported_files="$(find "$KERNEL_DIR" -type f 2>/dev/null | wc -l)"
  exported_size="$(du -sh "$KERNEL_DIR" 2>/dev/null | cut -f1)"
  echo "Kernel export progress: files=$exported_files size=${exported_size:-0}"
done
if wait "$export_pid"; then
  export_status=0
else
  export_status=$?
fi

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
BOARD_DTB="$KERNEL_DIR/arch/arm64/boot/dts/qcom/ipq5018-xiaomi-ra72.dtb"
KERNEL_IMAGE="$KERNEL_DIR/arch/arm64/boot/Image"
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

cp "$NATIVE_CONFIG" "$KERNEL_DIR/.config"

test -f "$KERNEL_DIR/include/linux/types.h"
test -f "$KERNEL_DIR/include/linux/stddef.h"
test -f "$KERNEL_DIR/include/linux/lzma/Types.h"
test -f "$KERNEL_DIR/lib/lzma/LzFind.c"

{
  echo "phase31_out_of_tree_types_header_failure=CONFIRMED"
  echo "phase31_out_of_tree_stddef_header_failure=CONFIRMED"
  echo "root_cause=DD-WRT relative include paths were resolved from O= output tree"
  echo "phase32_correction=native in-tree build without O="
  echo "source_include_linux_types=PASS"
  echo "source_include_linux_stddef=PASS"
  echo "source_include_linux_lzma_types=PASS"
  echo "source_lib_lzma_lzfind=PASS"
} > "$REVIEW_DIR/phase31-root-cause-and-phase32-correction.txt"

{
  echo "gcc=$(aarch64-linux-gnu-gcc --version | head -n1)"
  echo "make=$(make --version | head -n1)"
  echo "dtc=$(dtc --version 2>&1 | head -n1)"
  echo "kernel_rel=$KERNEL_REL"
  echo "build_mode=in-tree"
} > "$REVIEW_DIR/build-tool-versions.txt"

MAKE_COMMON=(
  make
  -C "$KERNEL_DIR"
  ARCH=arm64
  CROSS_COMPILE=aarch64-linux-gnu-
  KBUILD_BUILD_USER=github-actions
  KBUILD_BUILD_HOST=ddwrt-ra72-phase32
)

echo "Preparing the native DD-WRT IPQ6018 kernel configuration in-tree..."
if timeout 45m "${MAKE_COMMON[@]}" olddefconfig \
    2>&1 | tee "$REVIEW_DIR/olddefconfig.log"; then
  olddefconfig_status=0
else
  olddefconfig_status=${PIPESTATUS[0]}
fi

if [[ "$olddefconfig_status" -ne 0 ]]; then
  {
    echo "build_mode=in-tree"
    echo "olddefconfig_status=$olddefconfig_status"
    echo "kernel_image_build_status=99"
    echo "dtb_build_status=99"
    echo "decompile_status=99"
    echo "roundtrip_status=99"
  } > "$REVIEW_DIR/build-status.txt"
  printf 'BLOCKED_NATIVE_DDWRT_OLDDEFCONFIG_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

cp "$KERNEL_DIR/.config" "$REVIEW_DIR/config-ipq6018.resolved"

{
  for symbol in \
    CONFIG_ARM64 CONFIG_ARCH_QCOM CONFIG_OF CONFIG_MODULES \
    CONFIG_MTD CONFIG_MTD_RAW_NAND CONFIG_MTD_NAND_QCOM \
    CONFIG_MTD_UBI CONFIG_MTD_UBI_BLOCK CONFIG_UBIFS_FS \
    CONFIG_NET CONFIG_NET_DSA CONFIG_NET_DSA_QCA8K \
    CONFIG_MDIO_IPQ4019 CONFIG_AT803X_PHY CONFIG_QCA808X_PHY \
    CONFIG_PHY_QCOM_ETH_UNIPHY CONFIG_PCIE_QCOM \
    CONFIG_QCOM_Q6V5_COMMON CONFIG_QCOM_Q6V5_MPD \
    CONFIG_QCOM_Q6V5_WCSS CONFIG_QCOM_SMEM CONFIG_QCOM_SMP2P; do
    if ! grep -E "^${symbol}=(y|m)$" "$KERNEL_DIR/.config"; then
      if ! grep -F "# ${symbol} is not set" "$KERNEL_DIR/.config"; then
        echo "${symbol}=UNKNOWN"
      fi
    fi
  done
} > "$REVIEW_DIR/ra72-kernel-config-inventory.txt"

find "$KERNEL_DIR" -type f -name '*.ko' -print | sort \
  > "$WORK_DIR/prebuild-module-files.txt"
find "$KERNEL_DIR" -type f \
  \( -name '*.ubi' -o -name '*.bin' -o -name '*.itb' \
     -o -name '*.trx' -o -name '*.img' -o -name 'rootfs*' \) \
  -print | sort > "$WORK_DIR/prebuild-firmware-files.txt"

echo "Building the raw ARM64 Image and exact RA72 DTB in the native source tree."
echo "This avoids the Phase 31 O= relative-include failure."
if timeout 240m "${MAKE_COMMON[@]}" -j2 V=1 \
    Image qcom/ipq5018-xiaomi-ra72.dtb \
    2>&1 | tee "$REVIEW_DIR/native-kernel-kbuild.log"; then
  native_build_status=0
else
  native_build_status=${PIPESTATUS[0]}
fi

if [[ "$native_build_status" -ne 0 \
      || ! -s "$KERNEL_IMAGE" \
      || ! -s "$BOARD_DTB" ]]; then
  {
    echo "build_mode=in-tree"
    echo "olddefconfig_status=$olddefconfig_status"
    echo "kernel_image_build_status=$native_build_status"
    echo "dtb_build_status=$native_build_status"
    echo "decompile_status=99"
    echo "roundtrip_status=99"
  } > "$REVIEW_DIR/build-status.txt"
  cp "$KERNEL_DIR/.config" "$REVIEW_DIR/config-ipq6018.resolved" || true
  grep -n -i -E \
    'fatal error:|error:|undefined reference|no rule to make target' \
    "$REVIEW_DIR/native-kernel-kbuild.log" \
    > "$REVIEW_DIR/first-build-errors.txt" || true
  printf 'BLOCKED_NATIVE_DDWRT_IN_TREE_KERNEL_IMAGE_BUILD_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

cp "$KERNEL_IMAGE" "$REVIEW_DIR/ra72-native-kernel-Image.review-only"
cp "$BOARD_DTB" "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dtb"

file "$REVIEW_DIR/ra72-native-kernel-Image.review-only" \
  > "$REVIEW_DIR/native-kernel-image-file.txt"
file "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dtb" \
  > "$REVIEW_DIR/native-dtb-file.txt"
stat -c 'kernel_image_size_bytes=%s' \
  "$REVIEW_DIR/ra72-native-kernel-Image.review-only" \
  > "$REVIEW_DIR/native-kernel-image-size.txt"

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
  echo "build_mode=in-tree"
  echo "olddefconfig_status=$olddefconfig_status"
  echo "kernel_image_build_status=$native_build_status"
  echo "dtb_build_status=$native_build_status"
  echo "decompile_status=$decompile_status"
  echo "roundtrip_status=$roundtrip_status"
} | tee "$REVIEW_DIR/build-status.txt"

if [[ "$decompile_status" -ne 0 || "$roundtrip_status" -ne 0 ]]; then
  printf 'BLOCKED_NATIVE_DDWRT_DTB_ROUNDTRIP_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

sha256sum \
  "$REVIEW_DIR/ra72-native-kernel-Image.review-only" \
  "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dtb" \
  "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-roundtrip.dtb" \
  > "$REVIEW_DIR/native-build-sha256.txt"

grep -i 'warning:' "$REVIEW_DIR/native-kernel-kbuild.log" \
  > "$REVIEW_DIR/native-kbuild-warnings.txt" || true
{
  echo "native_kbuild_warning_count=$(
    grep -ic 'warning:' "$REVIEW_DIR/native-kernel-kbuild.log" || true
  )"
  echo "native_decompile_warning_count=$(
    grep -ic 'warning:' "$REVIEW_DIR/native-dtb-decompile.log" || true
  )"
  echo "native_roundtrip_warning_count=$(
    grep -ic 'warning:' "$REVIEW_DIR/native-dtb-roundtrip.log" || true
  )"
} > "$REVIEW_DIR/warning-summary.txt"

find "$KERNEL_DIR" -type f -name '*.ko' -print | sort \
  > "$WORK_DIR/postbuild-module-files.txt"
comm -13 \
  "$WORK_DIR/prebuild-module-files.txt" \
  "$WORK_DIR/postbuild-module-files.txt" \
  > "$REVIEW_DIR/module-files-built.txt"
find "$KERNEL_DIR" -type f \
  \( -name '*.ubi' -o -name '*.bin' -o -name '*.itb' \
     -o -name '*.trx' -o -name '*.img' -o -name 'rootfs*' \) \
  -print | sort > "$WORK_DIR/postbuild-firmware-files.txt"
comm -13 \
  "$WORK_DIR/prebuild-firmware-files.txt" \
  "$WORK_DIR/postbuild-firmware-files.txt" \
  > "$REVIEW_DIR/unexpected-firmware-files.txt"

echo "Running Phase 32 in-tree native-kernel integration checks..."
if ! python3 work/validate-phase32.py \
  "$REVIEW_DIR/phase28-status.txt" \
  "$REVIEW_DIR/build-status.txt" \
  "$REVIEW_DIR/config-ipq6018.resolved" \
  "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dts" \
  "$PATCH_FILE" \
  "$REVIEW_DIR/native-kernel-kbuild.log" \
  "$REVIEW_DIR/unexpected-firmware-files.txt" \
  "$REVIEW_DIR/module-files-built.txt" \
  "$REVIEW_DIR/ra72-native-kernel-Image.review-only" \
  "$REVIEW_DIR/native-kernel-image-file.txt" \
  "$REVIEW_DIR/phase31-root-cause-and-phase32-correction.txt" \
  "$REVIEW_DIR/build-tool-versions.txt" \
  "$REVIEW_DIR/phase32-integration-checks.txt"; then
  printf 'BLOCKED_NATIVE_DDWRT_IN_TREE_KERNEL_IMAGE_VALIDATION_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

printf 'RA72_NATIVE_DDWRT_IN_TREE_KERNEL_IMAGE_BUILD_PASS_REVIEW_ONLY\n' \
  > "$STATUS_FILE"

CHECK_COUNT="$(grep -c '=PASS$' \
  "$REVIEW_DIR/phase32-integration-checks.txt")"
IMAGE_SIZE="$(stat -c '%s' \
  "$REVIEW_DIR/ra72-native-kernel-Image.review-only")"

cat <<EOF

Phase 32 result
---------------
STATUS: RA72_NATIVE_DDWRT_IN_TREE_KERNEL_IMAGE_BUILD_PASS_REVIEW_ONLY

Verified:
- Full native DD-WRT kernel export: PASS
- Phase 28 patch regeneration and application: PASS
- Exact model identity Xiaomi Mi AIoT AX6000 RA72: PASS
- Native .config_ipq6018 olddefconfig: PASS
- Phase 31 O= include-path root cause: CONFIRMED
- Native in-tree build mode without O=: PASS
- Native Kbuild raw ARM64 Image: PASS
- Native Kbuild qcom/ipq5018-xiaomi-ra72.dtb: PASS
- DTB decompile and round-trip compile: PASS
- RA72 core kernel configuration foundations: PASS
- Integration checks: $CHECK_COUNT/$CHECK_COUNT PASS
- Kernel Image size: $IMAGE_SIZE bytes
- Firmware/rootfs/module-package absence: PASS

Review-only outputs:
review/ra72-native-kernel-Image.review-only
review/ipq5018-xiaomi-ra72.native-kbuild.dtb

Safety:
The raw Image is not complete DD-WRT firmware and is not boot-approved.
No rootfs, module package, FIT, UBI, BIN, ITB, TRX, or IMG was built.
No router, SSH session, UART, NAND partition, or boot variable was accessed.
Do not boot or flash any Phase 32 file.
EOF

echo
echo "Phase 32 completed: $(cat "$STATUS_FILE")"
