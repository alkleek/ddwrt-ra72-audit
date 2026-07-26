#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="$PWD/phase33-output"
REVIEW_DIR="$OUT_DIR/review"
PATCH_DIR="$OUT_DIR/patches"
MODULE_OUT_DIR="$OUT_DIR/modules"
WORK_DIR="$OUT_DIR/work"
REPORT="$OUT_DIR/REPORT-PHASE33.txt"
STATUS_FILE="$REVIEW_DIR/phase33-status.txt"
PHASE28_DIR="$PWD/phase28-output"

SOURCE_ROOT="$WORK_DIR/ddwrt"
MODULE_STAGE="$WORK_DIR/modules-stage"

rm -rf "$OUT_DIR" "$PHASE28_DIR"
mkdir -p "$REVIEW_DIR" "$PATCH_DIR" "$MODULE_OUT_DIR" "$WORK_DIR"

cat > "$OUT_DIR/DO-NOT-LOAD-BOOT-OR-FLASH.txt" <<'EOF'
PHASE 33 BUILDS REVIEW-ONLY ARM64 KERNEL COMPONENTS AND KERNEL MODULES.
NO COMPLETE DD-WRT FIRMWARE IS BUILT.
NO ROOTFS, FIT, UBI, BIN, ITB, TRX, IMG, FACTORY, OR UPGRADE IMAGE IS BUILT.
DO NOT LOAD, BOOT, OR FLASH ANY FILE FROM THIS ARTIFACT.
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
  echo "Phase 33 stopped with status $(cat "$STATUS_FILE") (exit $code)."
  exit "$code"
}

trap cleanup EXIT
trap on_error ERR
exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 33 native ARM64 kernel-modules build"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: review components only; no firmware and no router access."
echo "BUILD MODE: native in-tree DD-WRT kernel and module build."
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

{
  echo "gcc=$(aarch64-linux-gnu-gcc --version | head -n1)"
  echo "make=$(make --version | head -n1)"
  echo "dtc=$(dtc --version 2>&1 | head -n1)"
  echo "depmod=$(depmod --version 2>&1 | head -n1)"
  echo "kernel_rel=$KERNEL_REL"
  echo "build_mode=in-tree"
} > "$REVIEW_DIR/build-tool-versions.txt"

MAKE_COMMON=(
  make
  -C "$KERNEL_DIR"
  ARCH=arm64
  CROSS_COMPILE=aarch64-linux-gnu-
  KBUILD_BUILD_USER=github-actions
  KBUILD_BUILD_HOST=ddwrt-ra72-phase33
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
    echo "modules_build_status=99"
    echo "modules_install_status=99"
    echo "decompile_status=99"
    echo "roundtrip_status=99"
    echo "module_count=0"
  } > "$REVIEW_DIR/build-status.txt"
  printf 'BLOCKED_NATIVE_DDWRT_OLDDEFCONFIG_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

cp "$KERNEL_DIR/.config" "$REVIEW_DIR/config-ipq6018.resolved"
grep '^CONFIG_.*=m$' "$KERNEL_DIR/.config" \
  > "$REVIEW_DIR/module-config-symbols.txt" || true

{
  for symbol in \
    CONFIG_ARM64 CONFIG_ARCH_QCOM CONFIG_OF CONFIG_MODULES \
    CONFIG_MTD CONFIG_MTD_RAW_NAND CONFIG_MTD_NAND_QCOM \
    CONFIG_MTD_UBI CONFIG_MTD_UBI_BLOCK CONFIG_UBIFS_FS \
    CONFIG_NET CONFIG_NET_DSA CONFIG_NET_DSA_QCA8K \
    CONFIG_QCOM_PPE CONFIG_PCS_QCOM_IPQ9574 \
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

find "$KERNEL_DIR" -type f \
  \( -name '*.ubi' -o -name '*.bin' -o -name '*.itb' \
     -o -name '*.trx' -o -name '*.img' -o -name 'rootfs*' \) \
  -print | sort > "$WORK_DIR/prebuild-firmware-files.txt"

echo "Building Image, exact RA72 DTB, and all configured modules in-tree."
echo "A progress line is printed every five minutes while Kbuild is running."
timeout 300m "${MAKE_COMMON[@]}" -j2 V=1 \
  Image qcom/ipq5018-xiaomi-ra72.dtb modules \
  > "$REVIEW_DIR/native-kernel-modules-kbuild.log" 2>&1 &
build_pid=$!
progress_ticks=0
while kill -0 "$build_pid" 2>/dev/null; do
  sleep 30
  progress_ticks=$((progress_ticks + 1))
  if (( progress_ticks % 10 == 0 )); then
    elapsed_minutes=$((progress_ticks / 2))
    built_modules="$(
      find "$KERNEL_DIR" -type f -name '*.ko' 2>/dev/null | wc -l
    )"
    echo "Kbuild progress: elapsed=${elapsed_minutes}m modules=$built_modules"
  fi
done
if wait "$build_pid"; then
  native_build_status=0
else
  native_build_status=$?
fi

if [[ "$native_build_status" -ne 0 \
      || ! -s "$KERNEL_IMAGE" \
      || ! -s "$BOARD_DTB" ]]; then
  {
    echo "build_mode=in-tree"
    echo "olddefconfig_status=$olddefconfig_status"
    echo "kernel_image_build_status=$native_build_status"
    echo "dtb_build_status=$native_build_status"
    echo "modules_build_status=$native_build_status"
    echo "modules_install_status=99"
    echo "decompile_status=99"
    echo "roundtrip_status=99"
    echo "module_count=0"
  } > "$REVIEW_DIR/build-status.txt"
  grep -n -i -E \
    'fatal error:|error:|undefined reference|undefined!|no rule to make target' \
    "$REVIEW_DIR/native-kernel-modules-kbuild.log" \
    > "$REVIEW_DIR/first-build-errors.txt" || true
  printf 'BLOCKED_NATIVE_DDWRT_KERNEL_MODULES_BUILD_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

KERNEL_RELEASE="$("${MAKE_COMMON[@]}" -s kernelrelease)"
echo "$KERNEL_RELEASE" > "$REVIEW_DIR/kernel-release.txt"

echo "Installing the built modules into an isolated review staging directory."
mkdir -p "$MODULE_STAGE"
if timeout 60m "${MAKE_COMMON[@]}" \
    INSTALL_MOD_PATH="$MODULE_STAGE" \
    INSTALL_MOD_STRIP=1 \
    modules_install \
    2>&1 | tee "$REVIEW_DIR/modules-install.log"; then
  modules_install_status=0
else
  modules_install_status=${PIPESTATUS[0]}
fi

if [[ "$modules_install_status" -ne 0 ]]; then
  {
    echo "build_mode=in-tree"
    echo "olddefconfig_status=$olddefconfig_status"
    echo "kernel_image_build_status=0"
    echo "dtb_build_status=0"
    echo "modules_build_status=0"
    echo "modules_install_status=$modules_install_status"
    echo "decompile_status=99"
    echo "roundtrip_status=99"
    echo "module_count=0"
  } > "$REVIEW_DIR/build-status.txt"
  printf 'BLOCKED_NATIVE_DDWRT_MODULES_INSTALL_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

STAGED_RELEASE_DIR="$MODULE_STAGE/lib/modules/$KERNEL_RELEASE"
test -d "$STAGED_RELEASE_DIR"
rm -f "$STAGED_RELEASE_DIR/build" "$STAGED_RELEASE_DIR/source"
rsync -a "$STAGED_RELEASE_DIR/" "$MODULE_OUT_DIR/"

find "$MODULE_OUT_DIR" -type f -name '*.ko' -printf '%P\n' | sort \
  > "$REVIEW_DIR/module-list.txt"
module_count="$(wc -l < "$REVIEW_DIR/module-list.txt")"
test "$module_count" -gt 0

while IFS= read -r module_rel; do
  file "$MODULE_OUT_DIR/$module_rel"
done < "$REVIEW_DIR/module-list.txt" \
  > "$REVIEW_DIR/module-file-types.txt"

find "$MODULE_OUT_DIR" -type f -name '*.ko' -print0 \
  | sort -z \
  | xargs -0 sha256sum \
  > "$REVIEW_DIR/module-sha256.txt"

{
  echo "kernel_release=$KERNEL_RELEASE"
  echo "configured_module_symbol_count=$(
    wc -l < "$REVIEW_DIR/module-config-symbols.txt"
  )"
  echo "module_count=$module_count"
  echo "module_tree_size_bytes=$(
    du -sb "$MODULE_OUT_DIR" | cut -f1
  )"
} > "$REVIEW_DIR/module-summary.txt"

{
  find "$MODULE_OUT_DIR" -maxdepth 1 -type f \
    -name 'modules.*' -printf '%f\n' | sort
} > "$REVIEW_DIR/module-dependency-audit.txt"

qca8k_count="$(
  find "$MODULE_OUT_DIR" -type f -name 'qca8k*.ko' | wc -l
)"
qcom_ppe_count="$(
  find "$MODULE_OUT_DIR" -type f -iname '*qcom*ppe*.ko' | wc -l
)"
pcs_ipq9574_count="$(
  find "$MODULE_OUT_DIR" -type f -iname '*ipq9574*.ko' | wc -l
)"
{
  echo "qca8k_module_count=$qca8k_count"
  find "$MODULE_OUT_DIR" -type f -name 'qca8k*.ko' -printf '%P\n' | sort
  echo "qcom_ppe_module_count=$qcom_ppe_count"
  find "$MODULE_OUT_DIR" -type f -iname '*qcom*ppe*.ko' -printf '%P\n' | sort
  echo "pcs_ipq9574_module_count=$pcs_ipq9574_count"
  find "$MODULE_OUT_DIR" -type f -iname '*ipq9574*.ko' -printf '%P\n' | sort
} > "$REVIEW_DIR/critical-module-resolution.txt"

if [[ "$qca8k_count" -eq 0 ]]; then
  printf 'BLOCKED_NATIVE_DDWRT_KERNEL_MODULES_VALIDATION_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

cp "$KERNEL_IMAGE" "$REVIEW_DIR/ra72-native-kernel-Image.review-only"
cp "$BOARD_DTB" "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dtb"

file "$REVIEW_DIR/ra72-native-kernel-Image.review-only" \
  > "$REVIEW_DIR/native-kernel-image-file.txt"
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
  echo "build_mode=in-tree"
  echo "olddefconfig_status=$olddefconfig_status"
  echo "kernel_image_build_status=0"
  echo "dtb_build_status=0"
  echo "modules_build_status=0"
  echo "modules_install_status=$modules_install_status"
  echo "decompile_status=$decompile_status"
  echo "roundtrip_status=$roundtrip_status"
  echo "module_count=$module_count"
} | tee "$REVIEW_DIR/build-status.txt"

if [[ "$decompile_status" -ne 0 || "$roundtrip_status" -ne 0 ]]; then
  printf 'BLOCKED_NATIVE_DDWRT_DTB_ROUNDTRIP_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

find "$KERNEL_DIR" -type f \
  \( -name '*.ubi' -o -name '*.bin' -o -name '*.itb' \
     -o -name '*.trx' -o -name '*.img' -o -name 'rootfs*' \) \
  -print | sort > "$WORK_DIR/postbuild-firmware-files.txt"
comm -13 \
  "$WORK_DIR/prebuild-firmware-files.txt" \
  "$WORK_DIR/postbuild-firmware-files.txt" \
  > "$REVIEW_DIR/unexpected-firmware-files.txt"

grep -i 'warning:' "$REVIEW_DIR/native-kernel-modules-kbuild.log" \
  > "$REVIEW_DIR/native-kbuild-warnings.txt" || true
{
  echo "native_kbuild_warning_count=$(
    grep -ic 'warning:' "$REVIEW_DIR/native-kernel-modules-kbuild.log" || true
  )"
  echo "modules_install_warning_count=$(
    grep -ic 'warning:' "$REVIEW_DIR/modules-install.log" || true
  )"
  echo "native_decompile_warning_count=$(
    grep -ic 'warning:' "$REVIEW_DIR/native-dtb-decompile.log" || true
  )"
  echo "native_roundtrip_warning_count=$(
    grep -ic 'warning:' "$REVIEW_DIR/native-dtb-roundtrip.log" || true
  )"
} > "$REVIEW_DIR/warning-summary.txt"

echo "Running Phase 33 native kernel-module integration checks..."
if ! python3 work/validate-phase33.py \
  "$REVIEW_DIR/phase28-status.txt" \
  "$REVIEW_DIR/build-status.txt" \
  "$REVIEW_DIR/config-ipq6018.resolved" \
  "$REVIEW_DIR/ipq5018-xiaomi-ra72.native-kbuild.dts" \
  "$PATCH_FILE" \
  "$REVIEW_DIR/native-kernel-modules-kbuild.log" \
  "$REVIEW_DIR/modules-install.log" \
  "$REVIEW_DIR/unexpected-firmware-files.txt" \
  "$REVIEW_DIR/ra72-native-kernel-Image.review-only" \
  "$REVIEW_DIR/native-kernel-image-file.txt" \
  "$REVIEW_DIR/module-list.txt" \
  "$REVIEW_DIR/module-file-types.txt" \
  "$REVIEW_DIR/module-dependency-audit.txt" \
  "$REVIEW_DIR/critical-module-resolution.txt" \
  "$REVIEW_DIR/phase33-integration-checks.txt"; then
  printf 'BLOCKED_NATIVE_DDWRT_KERNEL_MODULES_VALIDATION_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

printf 'RA72_NATIVE_DDWRT_KERNEL_MODULES_BUILD_PASS_REVIEW_ONLY\n' \
  > "$STATUS_FILE"

CHECK_COUNT="$(grep -c '=PASS$' \
  "$REVIEW_DIR/phase33-integration-checks.txt")"

cat <<EOF

Phase 33 result
---------------
STATUS: RA72_NATIVE_DDWRT_KERNEL_MODULES_BUILD_PASS_REVIEW_ONLY

Verified:
- Full native DD-WRT kernel export: PASS
- Phase 28 patch regeneration and application: PASS
- Exact Xiaomi Mi AIoT AX6000 RA72 identity: PASS
- Native .config_ipq6018 olddefconfig: PASS
- Native in-tree ARM64 Image and exact RA72 DTB build: PASS
- Native configured kernel-modules build: PASS
- Isolated modules_install staging: PASS
- QCA8337/QCA8K DSA module staged: PASS
- ARM64 module architecture audit: PASS
- Module dependency metadata: PASS
- DTB decompile and round-trip compile: PASS
- Integration checks: $CHECK_COUNT/$CHECK_COUNT PASS
- Staged kernel modules: $module_count
- Firmware/rootfs absence: PASS

Safety:
These are review components, not complete DD-WRT firmware.
No rootfs or flashable image was built.
No router, SSH session, UART, NAND partition, or boot variable was accessed.
Do not load, boot, or flash any Phase 33 file.
EOF

echo
echo "Phase 33 completed: $(cat "$STATUS_FILE")"
