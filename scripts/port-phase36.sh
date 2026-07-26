#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="$PWD/phase36-output"
REVIEW_DIR="$OUT_DIR/review"
WORK_DIR="$OUT_DIR/work"
SOURCE_ROOT="$WORK_DIR/ddwrt"
ROUTER_DIR="$SOURCE_ROOT/src/router"
ROOTFS_STAGE="$WORK_DIR/rootfs-extracted"
REPORT="$OUT_DIR/REPORT-PHASE36.txt"
STATUS_FILE="$REVIEW_DIR/phase36-status.txt"
BUILD_LOG="$REVIEW_DIR/userspace-build.log"
SOURCE_URL="${DDWRT_SOURCE_URL:-svn://svn.dd-wrt.com/DD-WRT}"
REQUESTED_TARGET="${DDWRT_BUILD_TARGET:-auto}"

rm -rf "$OUT_DIR"
mkdir -p "$REVIEW_DIR" "$WORK_DIR"

cat > "$OUT_DIR/DO-NOT-BOOT-OR-FLASH.txt" <<'EOF'
PHASE 36 IS A CORRECTED REVIEW-ONLY DD-WRT USERSPACE/ROOTFS BUILD ATTEMPT.
ANY ROOTFS IN THIS ARTIFACT IS NOT COMPLETE FIRMWARE.
DO NOT BOOT, LOAD, INSTALL, DEPLOY, OR FLASH ANY PHASE 36 FILE.
Exact device: Xiaomi Mi AIoT AX6000, model RA72, IPQ5018 / MP03.1 only.
This is not for Xiaomi Mi Router AX6000 or Redmi AX6000.
EOF

cleanup() {
  rm -rf "$WORK_DIR"
}

on_error() {
  local code=$?
  if [[ ! -f "$STATUS_FILE" ]]; then
    printf 'BLOCKED_UNEXPECTED_ERROR\n' > "$STATUS_FILE"
  fi
  echo "Phase 36 stopped with status $(cat "$STATUS_FILE") (exit $code)."
  exit "$code"
}

trap cleanup EXIT
trap on_error ERR
exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 36 corrected accelerated userspace/rootfs build"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: review-only rootfs component; no firmware and no router access."
echo

select_source() {
  local candidate
  local -a candidates=(
    "$SOURCE_URL"
    "svn://svn.dd-wrt.com/DD-WRT"
    "https://svn.dd-wrt.com/DD-WRT"
  )

  : > "$REVIEW_DIR/source-attempts.txt"
  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    candidate="${candidate%/}"
    if grep -Fxq "$candidate" "$REVIEW_DIR/source-attempts.txt"; then
      continue
    fi
    printf '%s\n' "$candidate" >> "$REVIEW_DIR/source-attempts.txt"
    echo "Checking public DD-WRT source: $candidate"
    if timeout 10m svn cat \
      "$candidate/src/router/Makefile.ipq60xx" > /dev/null 2>> \
      "$REVIEW_DIR/source-attempts.txt"; then
      printf '%s\n' "$candidate" \
        > "$REVIEW_DIR/selected-ddwrt-source-url.txt"
      return 0
    fi
  done
  return 1
}

if ! select_source; then
  printf 'BLOCKED_DDWRT_ROUTER_SOURCE_EXPORT_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

SELECTED_URL="$(cat "$REVIEW_DIR/selected-ddwrt-source-url.txt")"
if ! SVN_REVISION="$(timeout 10m svn info --show-item revision \
  "$SELECTED_URL")" || [[ -z "$SVN_REVISION" ]]; then
  printf 'BLOCKED_DDWRT_ROUTER_SOURCE_EXPORT_FAILED\n' > "$STATUS_FILE"
  exit 1
fi
printf '%s\n' "$SVN_REVISION" > "$REVIEW_DIR/ddwrt-svn-revision.txt"
svn info "$SELECTED_URL/src/router/Makefile.ipq60xx" \
  > "$REVIEW_DIR/makefile-ipq60xx-svn-info.txt"

echo "Pinned public DD-WRT SVN revision: $SVN_REVISION"

export_tree() {
  local relative_path="$1"
  local required="$2"
  local destination="$SOURCE_ROOT/$relative_path"
  local name
  local pid
  local status
  name="${relative_path//\//-}"

  if ! timeout 5m svn info \
    "$SELECTED_URL/$relative_path@$SVN_REVISION" > /dev/null 2>&1; then
    if [[ "$required" == required ]]; then
      echo "Required public source path is missing: $relative_path"
      return 1
    fi
    echo "Optional public source path is absent: $relative_path"
    return 0
  fi

  mkdir -p "$destination"
  echo "Exporting $relative_path at revision $SVN_REVISION"
  (
    trap - ERR
    exec timeout 180m svn export --force --quiet \
      "$SELECTED_URL/$relative_path@$SVN_REVISION" "$destination"
  ) > "$REVIEW_DIR/export-$name.log" 2>&1 &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    sleep 60
    if kill -0 "$pid" 2>/dev/null; then
      local files=0
      local bytes=0
      files="$(find "$destination" -type f 2>/dev/null | wc -l)"
      bytes="$(du -sh "$destination" 2>/dev/null | awk '{print $1}')"
      echo "Export progress $relative_path: files=$files size=${bytes:-0}"
    fi
  done

  if wait "$pid"; then
    status=0
  else
    status=$?
  fi
  echo "$relative_path export_status=$status" \
    >> "$REVIEW_DIR/source-export-status.txt"
  if [[ "$status" -ne 0 ]]; then
    return 1
  fi
}

: > "$REVIEW_DIR/source-export-status.txt"

if ! export_tree "src/router" required; then
  printf 'BLOCKED_DDWRT_ROUTER_SOURCE_EXPORT_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

for optional_tree in \
  "src/include" \
  "src/shared"; do
  if ! export_tree "$optional_tree" optional; then
    echo "Optional source export failed: $optional_tree"
  fi
done

if [[ ! -s "$ROUTER_DIR/Makefile.ipq60xx" ]]; then
  printf 'BLOCKED_DDWRT_ROUTER_SOURCE_EXPORT_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

cp "$ROUTER_DIR/Makefile.ipq60xx" \
  "$REVIEW_DIR/Makefile.ipq60xx"

{
  echo "ddwrt_source=$SELECTED_URL"
  echo "ddwrt_svn_revision=$SVN_REVISION"
  echo "router_source_files=$(find "$ROUTER_DIR" -type f | wc -l)"
  echo "router_source_size=$(du -sh "$ROUTER_DIR" | awk '{print $1}')"
  echo "workspace_free_before_build=$(df -h "$PWD" | awk 'NR==2 {print $4}')"
} | tee "$REVIEW_DIR/source-summary.txt"

find "$ROUTER_DIR/configs/ipq60xx" -maxdepth 3 -type f -print 2>/dev/null \
  | sed "s#^$ROUTER_DIR/##" | sort \
  > "$REVIEW_DIR/ipq60xx-config-files.txt" || true

grep -RInE \
  '(/xfs/toolchains|toolchain-[^[:space:]]+|CROSS_COMPILE|ARCH[[:space:]]*[:?+]?=|aarch64[^[:space:]]*(gcc|uclibc|musl)|root\.ipq5018)' \
  "$ROUTER_DIR/Makefile.ipq60xx" \
  "$ROUTER_DIR/Makefile" \
  "$ROUTER_DIR/configs/ipq60xx" \
  > "$REVIEW_DIR/userspace-toolchain-contract.txt" 2>&1 || true

{
  command -v aarch64-linux-gnu-gcc || true
  aarch64-linux-gnu-gcc --version 2>/dev/null | head -n 1 || true
  aarch64-linux-gnu-gcc -print-sysroot 2>/dev/null || true
  find /opt /usr/local "$PWD" -maxdepth 5 -type f \
    \( -name 'aarch64*-gcc' -o -name '*aarch64*gcc' \) \
    -print 2>/dev/null | head -n 100 || true
} > "$REVIEW_DIR/available-cross-toolchains.txt"

python3 - "$ROUTER_DIR/Makefile.ipq60xx" \
  "$REVIEW_DIR/make-targets.txt" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1]).read_text(
    encoding="utf-8", errors="replace"
)
targets: list[str] = []
seen: set[str] = set()
for raw in source.splitlines():
    if raw.startswith(("\t", " ")):
        continue
    match = re.match(r"^([A-Za-z0-9_.+/@%=-]+)\s*:(?![=])", raw)
    if not match:
        continue
    target = match.group(1)
    if target.startswith((".", "%")) or "$" in target:
        continue
    if target not in seen:
        seen.add(target)
        targets.append(target)

pathlib.Path(sys.argv[2]).write_text(
    "\n".join(targets) + ("\n" if targets else ""),
    encoding="utf-8",
)
PY

choose_target() {
  if [[ "$REQUESTED_TARGET" != auto ]]; then
    printf '%s\n' "$REQUESTED_TARGET"
    return
  fi

  local candidate
  for candidate in rootfs root.ipq5018 install all; do
    if grep -Fxq "$candidate" "$REVIEW_DIR/make-targets.txt"; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  printf '%s\n' "__DEFAULT__"
}

SELECTED_TARGET="$(choose_target)"
printf '%s\n' "$SELECTED_TARGET" > "$REVIEW_DIR/selected-make-target.txt"
echo "Selected native make target: $SELECTED_TARGET"

BLOCKER_DIR="$WORK_DIR/safety-blockers"
mkdir -p "$BLOCKER_DIR"
for command_name in ubinize ubiformat sysupgrade fw_setenv mtd; do
  cat > "$BLOCKER_DIR/$command_name" <<EOF
#!/usr/bin/env bash
echo "PHASE36_SAFETY_BLOCK: $command_name \$*" >&2
exit 86
EOF
  chmod +x "$BLOCKER_DIR/$command_name"
done

QCOM_UBINIZE="$ROUTER_DIR/tools/qcom/ubinize-image.sh"
if [[ -f "$QCOM_UBINIZE" ]]; then
  cp "$QCOM_UBINIZE" "$REVIEW_DIR/ddwrt-ubinize-image.sh"
  mv "$QCOM_UBINIZE" "$QCOM_UBINIZE.phase36-disabled"
  cat > "$QCOM_UBINIZE" <<'EOF'
#!/usr/bin/env bash
echo "PHASE36_SAFETY_BLOCK: Qualcomm UBI packaging is disabled." >&2
exit 86
EOF
  chmod +x "$QCOM_UBINIZE"
fi

export PATH="$BLOCKER_DIR:$PATH"
export ARCH=aarch64
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++
export AR=aarch64-linux-gnu-ar
export AS=aarch64-linux-gnu-as
export LD=aarch64-linux-gnu-ld
export NM=aarch64-linux-gnu-nm
export OBJCOPY=aarch64-linux-gnu-objcopy
export OBJDUMP=aarch64-linux-gnu-objdump
export RANLIB=aarch64-linux-gnu-ranlib
export READELF=aarch64-linux-gnu-readelf
export STRIP=aarch64-linux-gnu-strip

MAKE_COMMAND=(make -f Makefile.ipq60xx -j2 V=1)
if [[ "$SELECTED_TARGET" != "__DEFAULT__" ]]; then
  MAKE_COMMAND+=("$SELECTED_TARGET")
fi
printf '%q ' "${MAKE_COMMAND[@]}" \
  > "$REVIEW_DIR/userspace-build-command.txt"
printf '\n' >> "$REVIEW_DIR/userspace-build-command.txt"

echo "Running a dry make expansion for diagnostic context..."
DRY_RUN_COMMAND=(make -f Makefile.ipq60xx -n)
if [[ "$SELECTED_TARGET" != "__DEFAULT__" ]]; then
  DRY_RUN_COMMAND+=("$SELECTED_TARGET")
fi
if (
  trap - ERR
  cd "$ROUTER_DIR"
  timeout 10m "${DRY_RUN_COMMAND[@]}"
) > "$REVIEW_DIR/userspace-make-dry-run.log" 2>&1; then
  dry_run_status=0
else
  dry_run_status=$?
fi

echo "Starting the native DD-WRT userspace/rootfs build."
echo "A progress line is printed every five minutes."
start_epoch="$(date +%s)"
(
  trap - ERR
  cd "$ROUTER_DIR"
  exec timeout 300m "${MAKE_COMMAND[@]}"
) > "$BUILD_LOG" 2>&1 &
build_pid=$!

while kill -0 "$build_pid" 2>/dev/null; do
  sleep 300
  if kill -0 "$build_pid" 2>/dev/null; then
    elapsed="$((($(date +%s) - start_epoch) / 60))"
    root_candidates="$(find "$SOURCE_ROOT" -type f \
      -name 'root.ipq5018' -size +1M 2>/dev/null | wc -l)"
    echo "Userspace build progress: elapsed=${elapsed}m rootfs_candidates=$root_candidates"
  fi
done

if wait "$build_pid"; then
  build_status=0
else
  build_status=$?
fi

{
  echo "dry_run_status=$dry_run_status"
  echo "userspace_build_status=$build_status"
  echo "selected_target=$SELECTED_TARGET"
} | tee "$REVIEW_DIR/userspace-build-status.txt"

tail -n 500 "$BUILD_LOG" \
  > "$REVIEW_DIR/userspace-build-tail.txt" || true

find "$SOURCE_ROOT" -type f -name 'root.ipq5018' -size +1M \
  -print 2>/dev/null | sort > "$REVIEW_DIR/rootfs-candidates.txt"

ROOTFS_INPUT=""
while IFS= read -r candidate; do
  [[ -n "$candidate" ]] || continue
  if unsquashfs -s "$candidate" > /dev/null 2>&1; then
    ROOTFS_INPUT="$candidate"
    break
  fi
done < "$REVIEW_DIR/rootfs-candidates.txt"

python3 - "$BUILD_LOG" "$build_status" \
  "$REVIEW_DIR/build-failure-classification.txt" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

log = pathlib.Path(sys.argv[1]).read_text(
    encoding="utf-8", errors="replace"
)
status = int(sys.argv[2])

rules = [
    (
        "MISSING_DDWRT_CROSS_TOOLCHAIN",
        r"(?:/xfs/toolchains|toolchain-[^\s:]+)[^\n]*"
        r"(?:No such file|not found)"
        r"|(?:No such file|not found)[^\n]*"
        r"(?:/xfs/toolchains|toolchain-)",
    ),
    (
        "MISSING_OR_INCOMPATIBLE_AARCH64_TOOLCHAIN",
        r"aarch64[^\s:]*(?:gcc|ld|strip).*(?:not found|No such file)"
        r"|cannot find (?:crt|libc|[-]lc)"
        r"|C compiler cannot create executables",
    ),
    (
        "INCOMPLETE_DDWRT_SOURCE_OR_TARGET",
        r"No rule to make target|No targets specified and no makefile found",
    ),
    (
        "MISSING_SOURCE_OR_GENERATED_HEADER",
        r"fatal error: [^:\n]+: No such file or directory",
    ),
    (
        "MISSING_HOST_BUILD_TOOL",
        r"(?:command not found|No such file or directory).*(?:autoconf|automake|"
        r"cmake|flex|bison|gawk|perl|python|pkg-config)",
    ),
    (
        "INTENTIONAL_PHASE36_PACKAGING_STOP",
        r"PHASE36_SAFETY_BLOCK",
    ),
    (
        "COMPILE_OR_LINK_FAILURE",
        r"(?:collect2: error|undefined reference|Error [12]\b|recipe for target)",
    ),
]

classification = "BUILD_COMPLETED" if status == 0 else "UNCLASSIFIED_BUILD_FAILURE"
for name, pattern in rules:
    if re.search(pattern, log, re.IGNORECASE | re.DOTALL):
        classification = name
        break

pathlib.Path(sys.argv[3]).write_text(
    f"classification={classification}\n"
    f"make_exit_status={status}\n",
    encoding="utf-8",
)
PY

if [[ -z "$ROOTFS_INPUT" ]]; then
  if [[ "$build_status" -ne 0 ]]; then
    printf 'BLOCKED_DDWRT_USERSPACE_BUILD_FAILED\n' > "$STATUS_FILE"
  else
    printf 'BLOCKED_DDWRT_ROOTFS_NOT_PRODUCED\n' > "$STATUS_FILE"
  fi
  cat <<EOF

Phase 36 result
---------------
STATUS: $(cat "$STATUS_FILE")

The native DD-WRT userspace build did not produce a valid root.ipq5018.
The artifact contains the pinned source revision, selected make target,
toolchain contract, complete build log, last 500 lines, and automatic
failure classification. Use those files for the next correction.

No firmware was built and the router was not accessed.
EOF
  exit 1
fi

ROOTFS_REVIEW="$REVIEW_DIR/ra72-ddwrt-rootfs.review-only.squashfs"
cp "$ROOTFS_INPUT" "$ROOTFS_REVIEW"
sha256sum "$ROOTFS_REVIEW" > "$REVIEW_DIR/rootfs-sha256.txt"
stat -c 'rootfs_size_bytes=%s' "$ROOTFS_REVIEW" \
  > "$REVIEW_DIR/rootfs-size.txt"
file "$ROOTFS_REVIEW" > "$REVIEW_DIR/rootfs-file-type.txt"

if unsquashfs -s "$ROOTFS_REVIEW" \
  > "$REVIEW_DIR/rootfs-superblock.txt" 2>&1; then
  superblock_status=0
else
  superblock_status=$?
fi
rm -rf "$ROOTFS_STAGE"
if unsquashfs -d "$ROOTFS_STAGE" "$ROOTFS_REVIEW" \
  > "$REVIEW_DIR/rootfs-extraction.log" 2>&1; then
  extraction_status=0
else
  extraction_status=$?
fi

if [[ "$extraction_status" -eq 0 ]]; then
  {
    find "$ROOTFS_STAGE" -xdev -type f -printf '%P\t%s\n'
    find "$ROOTFS_STAGE" -xdev -type l -printf '%P\tLINK\n'
  } | sort > "$REVIEW_DIR/rootfs-file-manifest.txt"

  find "$ROOTFS_STAGE" -xdev -type f -perm /111 -print0 \
    | xargs -0 -r file > "$REVIEW_DIR/rootfs-executable-types.txt"

  if [[ -e "$ROOTFS_STAGE/bin/busybox" ]]; then
    file -L "$ROOTFS_STAGE/bin/busybox" \
      > "$REVIEW_DIR/rootfs-busybox-type.txt"
    aarch64-linux-gnu-readelf -h "$ROOTFS_STAGE/bin/busybox" \
      > "$REVIEW_DIR/rootfs-busybox-elf-header.txt" 2>&1 || true
  fi
fi

find "$SOURCE_ROOT" -type f \
  \( -name '*.ubi' -o -name '*.bin' -o -name '*.trx' -o -name '*.img' \) \
  -print 2>/dev/null | sort \
  > "$REVIEW_DIR/unexpected-flashable-build-files.txt"

{
  echo "superblock_status=$superblock_status"
  echo "extraction_status=$extraction_status"
  echo "userspace_build_status=$build_status"
} > "$REVIEW_DIR/rootfs-validation-status.txt"

if ! python3 work/validate-phase36.py \
  "$ROOTFS_REVIEW" \
  "$ROOTFS_STAGE" \
  "$REVIEW_DIR/rootfs-validation-status.txt" \
  "$REVIEW_DIR/rootfs-busybox-type.txt" \
  "$REVIEW_DIR/unexpected-flashable-build-files.txt" \
  "$REVIEW_DIR/phase36-integration-checks.txt"; then
  printf 'BLOCKED_DDWRT_ROOTFS_VALIDATION_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

printf 'RA72_DDWRT_USERSPACE_ROOTFS_BUILD_PASS_REVIEW_ONLY\n' \
  > "$STATUS_FILE"

CHECK_COUNT="$(grep -c '=PASS$' \
  "$REVIEW_DIR/phase36-integration-checks.txt")"
ROOTFS_SIZE="$(stat -c '%s' "$ROOTFS_REVIEW")"

cat <<EOF

Phase 36 result
---------------
STATUS: RA72_DDWRT_USERSPACE_ROOTFS_BUILD_PASS_REVIEW_ONLY

Verified:
- Public DD-WRT source pinned at revision $SVN_REVISION: PASS
- Native IPQ60xx userspace build was executed: PASS
- Valid root.ipq5018 SquashFS produced: PASS
- Rootfs extraction: PASS
- DD-WRT init and shell: PASS
- DD-WRT web interface files: PASS
- ARM64/AArch64 BusyBox: PASS
- Integration checks: $CHECK_COUNT/$CHECK_COUNT PASS
- Rootfs size: $ROOTFS_SIZE bytes

Review-only output:
review/ra72-ddwrt-rootfs.review-only.squashfs

Safety:
This rootfs is not complete firmware and is not boot-approved.
It contains no RA72 FIT pairing, UBI container, Xiaomi install wrapper, or
upgrade image. Qualcomm UBI packaging was deliberately disabled.
No router, SSH, UART, NAND partition, or boot variable was accessed.
Do not boot or flash any Phase 36 file.
EOF

echo
echo "Phase 36 completed: $(cat "$STATUS_FILE")"
