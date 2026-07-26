#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="$PWD/phase34-output"
REVIEW_DIR="$OUT_DIR/review"
WORK_DIR="$OUT_DIR/work"
REPORT="$OUT_DIR/REPORT-PHASE34.txt"
STATUS_FILE="$REVIEW_DIR/phase34-status.txt"
PHASE33_DIR="$PWD/phase33-output"

rm -rf "$OUT_DIR" "$PHASE33_DIR"
mkdir -p "$REVIEW_DIR" "$WORK_DIR"

cat > "$OUT_DIR/DO-NOT-LOAD-BOOT-OR-FLASH.txt" <<'EOF'
PHASE 34 BUILDS A REVIEW-ONLY FIT/ITB KERNEL CONTAINER.
IT CONTAINS ONLY A RAW ARM64 KERNEL AND THE EXACT RA72 DTB.
IT DOES NOT CONTAIN A ROOTFS, DD-WRT USERSPACE, MODULE PACKAGE, OR FIRMWARE.
DO NOT LOAD, BOOT, OR FLASH THE ITB OR ANY OTHER PHASE 34 FILE.
Exact device: Xiaomi Mi AIoT AX6000, model RA72, IPQ5018 / MP03.1 only.
This is not for Xiaomi Mi Router AX6000 or Redmi AX6000.
EOF

cleanup() {
  rm -rf "$WORK_DIR" "$PHASE33_DIR"
}

on_error() {
  local code=$?
  if [[ ! -f "$STATUS_FILE" ]]; then
    printf 'BLOCKED_UNEXPECTED_ERROR\n' > "$STATUS_FILE"
  fi
  echo "Phase 34 stopped with status $(cat "$STATUS_FILE") (exit $code)."
  exit "$code"
}

trap cleanup EXIT
trap on_error ERR
exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 34 review-only FIT kernel-container build"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: no complete firmware and no router access."
echo

echo "Reproducing the verified Phase 33 kernel and module build..."
if bash scripts/port-phase33.sh \
    2>&1 | tee "$REVIEW_DIR/phase33-bootstrap.log"; then
  phase33_status=0
else
  phase33_status=${PIPESTATUS[0]}
fi

if [[ "$phase33_status" -ne 0 ]] \
    || [[ ! -f "$PHASE33_DIR/review/phase33-status.txt" ]] \
    || ! grep -qx \
      'RA72_NATIVE_DDWRT_KERNEL_MODULES_BUILD_PASS_REVIEW_ONLY' \
      "$PHASE33_DIR/review/phase33-status.txt"; then
  printf 'BLOCKED_PHASE33_REGENERATION_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

cp "$PHASE33_DIR/review/phase33-status.txt" \
  "$REVIEW_DIR/phase33-status.txt"
cp "$PHASE33_DIR/review/build-status.txt" \
  "$REVIEW_DIR/phase33-build-status.txt"
cp "$PHASE33_DIR/review/module-summary.txt" \
  "$REVIEW_DIR/phase33-module-summary.txt"
cp "$PHASE33_DIR/review/critical-module-resolution.txt" \
  "$REVIEW_DIR/phase33-critical-module-resolution.txt"
cp "$PHASE33_DIR/review/selected-ddwrt-source-url.txt" \
  "$REVIEW_DIR/selected-ddwrt-source-url.txt"

KERNEL_INPUT="$PHASE33_DIR/review/ra72-native-kernel-Image.review-only"
DTB_INPUT="$PHASE33_DIR/review/ipq5018-xiaomi-ra72.native-kbuild.dtb"
KERNEL_RELEASE="$(cat "$PHASE33_DIR/review/kernel-release.txt")"
SELECTED_URL="$(cat "$REVIEW_DIR/selected-ddwrt-source-url.txt")"

test -s "$KERNEL_INPUT"
test -s "$DTB_INPUT"
test -n "$KERNEL_RELEASE"

MKITS_REL="src/router/tools/qcom/mkits.sh"
MKITS="$WORK_DIR/mkits.sh"

echo "Fetching DD-WRT's public Qualcomm FIT recipe helper..."
if timeout 10m svn cat "$SELECTED_URL/$MKITS_REL" > "$MKITS"; then
  mkits_fetch_status=0
else
  mkits_fetch_status=$?
fi

if [[ "$mkits_fetch_status" -ne 0 || ! -s "$MKITS" ]]; then
  printf 'BLOCKED_DDWRT_MKITS_FETCH_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

chmod +x "$MKITS"
cp "$MKITS" "$REVIEW_DIR/ddwrt-mkits.sh"
sha256sum "$REVIEW_DIR/ddwrt-mkits.sh" \
  > "$REVIEW_DIR/ddwrt-mkits.sha256"
svn info "$SELECTED_URL/$MKITS_REL" \
  > "$REVIEW_DIR/ddwrt-mkits-svn-info.txt"

KERNEL_GZIP="$WORK_DIR/ra72-native-kernel-Image.gz"
ITS="$REVIEW_DIR/ra72-fit-kernel-container.its"
FIT="$REVIEW_DIR/ra72-fit-kernel-container.review-only.itb"
FIT_DTS_FULL="$WORK_DIR/fit-decompiled-full.dts"
FIT_STRUCTURE="$REVIEW_DIR/fit-structure.txt"
EXTRACTED_GZIP="$WORK_DIR/extracted-kernel.gz"
EXTRACTED_IMAGE="$WORK_DIR/extracted-kernel-Image"
EXTRACTED_DTB="$WORK_DIR/extracted-ra72.dtb"

gzip -9 -n -c "$KERNEL_INPUT" > "$KERNEL_GZIP"
gzip -t "$KERNEL_GZIP"

echo "Generating the RA72 FIT source with DD-WRT mkits.sh..."
set +e
bash "$MKITS" \
  -D xiaomi_mi_aiot_ax6000_ra72 \
  -o "$ITS" \
  -k "$KERNEL_GZIP" \
  -C gzip \
  -d "$DTB_INPUT" \
  -a 0x41000000 \
  -e 0x41000000 \
  -c config@ra72 \
  -A arm64 \
  -v "$KERNEL_RELEASE" \
  > "$REVIEW_DIR/mkits.log" 2>&1
mkits_status=$?

if [[ "$mkits_status" -eq 0 ]]; then
  mkimage -f "$ITS" "$FIT" \
    > "$REVIEW_DIR/fit-build.log" 2>&1
  fit_generation_status=$?
else
  fit_generation_status=99
fi
set -e

if [[ "$mkits_status" -ne 0 \
      || "$fit_generation_status" -ne 0 \
      || ! -s "$ITS" \
      || ! -s "$FIT" ]]; then
  {
    echo "phase33_regeneration_status=$phase33_status"
    echo "mkits_fetch_status=$mkits_fetch_status"
    echo "mkits_status=$mkits_status"
    echo "fit_generation_status=$fit_generation_status"
    echo "fit_listing_status=99"
    echo "fit_decompile_status=99"
    echo "kernel_extraction_status=99"
    echo "dtb_extraction_status=99"
  } > "$REVIEW_DIR/fit-build-status.txt"
  printf 'BLOCKED_RA72_FIT_GENERATION_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

fit_listing_status=0
dumpimage -l "$FIT" > "$REVIEW_DIR/fit-image-list.txt" 2>&1 \
  || fit_listing_status=$?

fit_decompile_status=0
dtc -I dtb -O dts -o "$FIT_DTS_FULL" "$FIT" \
  > "$REVIEW_DIR/fit-decompile.log" 2>&1 \
  || fit_decompile_status=$?

if [[ "$fit_decompile_status" -eq 0 ]]; then
  python3 - "$FIT_DTS_FULL" "$FIT_STRUCTURE" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1]).read_text(
    encoding="utf-8", errors="replace"
)
sanitized = re.sub(
    r"(?ms)^([ \t]*)data[ \t]*=[ \t]*\[.*?\];",
    r"\1data = [PAYLOAD OMITTED FROM STRUCTURE REPORT];",
    source,
)
pathlib.Path(sys.argv[2]).write_text(sanitized, encoding="utf-8")
PY
fi

kernel_extraction_status=0
dumpimage -T flat_dt -p 0 -o "$EXTRACTED_GZIP" "$FIT" \
  > "$REVIEW_DIR/fit-extraction.log" 2>&1 \
  || kernel_extraction_status=$?

dtb_extraction_status=0
dumpimage -T flat_dt -p 1 -o "$EXTRACTED_DTB" "$FIT" \
  >> "$REVIEW_DIR/fit-extraction.log" 2>&1 \
  || dtb_extraction_status=$?

{
  echo "phase33_regeneration_status=$phase33_status"
  echo "mkits_fetch_status=$mkits_fetch_status"
  echo "mkits_status=$mkits_status"
  echo "fit_generation_status=$fit_generation_status"
  echo "fit_listing_status=$fit_listing_status"
  echo "fit_decompile_status=$fit_decompile_status"
  echo "kernel_extraction_status=$kernel_extraction_status"
  echo "dtb_extraction_status=$dtb_extraction_status"
} | tee "$REVIEW_DIR/fit-build-status.txt"

if [[ "$fit_listing_status" -ne 0 \
      || "$fit_decompile_status" -ne 0 \
      || "$kernel_extraction_status" -ne 0 \
      || "$dtb_extraction_status" -ne 0 ]]; then
  printf 'BLOCKED_RA72_FIT_EXTRACTION_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

kernel_gzip_test=FAIL
if gzip -t "$EXTRACTED_GZIP"; then
  kernel_gzip_test=PASS
fi

gunzip -c "$EXTRACTED_GZIP" > "$EXTRACTED_IMAGE"

kernel_payload_match=FAIL
if cmp -s "$KERNEL_INPUT" "$EXTRACTED_IMAGE"; then
  kernel_payload_match=PASS
fi

dtb_payload_match=FAIL
if cmp -s "$DTB_INPUT" "$EXTRACTED_DTB"; then
  dtb_payload_match=PASS
fi

{
  echo "kernel_gzip_test=$kernel_gzip_test"
  echo "kernel_payload_match=$kernel_payload_match"
  echo "dtb_payload_match=$dtb_payload_match"
} | tee "$REVIEW_DIR/fit-payload-comparison.txt"

if [[ "$kernel_gzip_test" != PASS \
      || "$kernel_payload_match" != PASS \
      || "$dtb_payload_match" != PASS ]]; then
  printf 'BLOCKED_RA72_FIT_PAYLOAD_MISMATCH\n' > "$STATUS_FILE"
  exit 1
fi

file "$FIT" > "$REVIEW_DIR/fit-file-type.txt"
stat -c 'fit_size_bytes=%s' "$FIT" > "$REVIEW_DIR/fit-size.txt"
sha256sum \
  "$KERNEL_INPUT" \
  "$DTB_INPUT" \
  "$KERNEL_GZIP" \
  "$FIT" \
  "$EXTRACTED_IMAGE" \
  "$EXTRACTED_DTB" \
  > "$REVIEW_DIR/fit-input-output-sha256.txt"

find "$OUT_DIR" -type f \
  \( -name '*.ubi' -o -name '*.bin' -o -name '*.trx' \
     -o -name '*.img' -o -name 'rootfs*' \) \
  -print | sort > "$REVIEW_DIR/unexpected-flashable-files.txt"

echo "Running Phase 34 FIT integration checks..."
if ! python3 work/validate-phase34.py \
  "$REVIEW_DIR/phase33-status.txt" \
  "$REVIEW_DIR/fit-build-status.txt" \
  "$REVIEW_DIR/fit-image-list.txt" \
  "$REVIEW_DIR/fit-structure.txt" \
  "$REVIEW_DIR/fit-payload-comparison.txt" \
  "$REVIEW_DIR/ddwrt-mkits.sh" \
  "$FIT" \
  "$REVIEW_DIR/unexpected-flashable-files.txt" \
  "$REVIEW_DIR/phase34-integration-checks.txt"; then
  printf 'BLOCKED_RA72_FIT_VALIDATION_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

printf 'RA72_DDWRT_FIT_KERNEL_CONTAINER_BUILD_PASS_REVIEW_ONLY\n' \
  > "$STATUS_FILE"

CHECK_COUNT="$(grep -c '=PASS$' \
  "$REVIEW_DIR/phase34-integration-checks.txt")"
FIT_SIZE="$(stat -c '%s' "$FIT")"

cat <<EOF

Phase 34 result
---------------
STATUS: RA72_DDWRT_FIT_KERNEL_CONTAINER_BUILD_PASS_REVIEW_ONLY

Verified:
- Phase 33 native kernel and modules regeneration: PASS
- Public DD-WRT Qualcomm mkits.sh fetch: PASS
- Deterministic gzip ARM64 kernel payload: PASS
- Exact RA72 DTB payload: PASS
- Load address 0x41000000: PASS
- Entry address 0x41000000: PASS
- FIT/ITB generation and listing: PASS
- FIT decompile: PASS
- Kernel extraction and byte comparison: PASS
- DTB extraction and byte comparison: PASS
- Integration checks: $CHECK_COUNT/$CHECK_COUNT PASS
- FIT size: $FIT_SIZE bytes
- Rootfs and flashable-firmware absence: PASS

Review-only output:
review/ra72-fit-kernel-container.review-only.itb

Safety:
The ITB is not complete DD-WRT firmware and is not boot-approved.
It contains no rootfs, userspace, module package, UBI, or install wrapper.
No router, SSH session, UART, NAND partition, or boot variable was accessed.
Do not load, boot, or flash any Phase 34 file.
EOF

echo
echo "Phase 34 completed: $(cat "$STATUS_FILE")"
