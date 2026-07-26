#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="$PWD/phase37-output"
REVIEW_DIR="$OUT_DIR/review"
WORK_DIR="$OUT_DIR/work"
SOURCE_ROOT="$WORK_DIR/ddwrt"
ROUTER_DIR="$SOURCE_ROOT/src/router"
LINUX_TREE="$SOURCE_ROOT/src/linux/universal/linux-6.12-nss"
ROOTFS_STAGE="$WORK_DIR/rootfs-extracted"
REPORT="$OUT_DIR/REPORT-PHASE37.txt"
STATUS_FILE="$REVIEW_DIR/phase37-status.txt"
BUILD_LOG="$REVIEW_DIR/userspace-build.log"
SOURCE_URL="${DDWRT_SOURCE_URL:-svn://svn.dd-wrt.com/DD-WRT}"
TOOLCHAIN_URL="${DDWRT_TOOLCHAIN_URL:-https://download1.dd-wrt.com/dd-wrtv2/downloads/toolchains/toolchains.tar.xz}"
REQUESTED_TARGET="${DDWRT_BUILD_TARGET:-auto}"
TOOLCHAIN_ARCHIVE="$WORK_DIR/toolchains.tar.xz"
TOOLCHAIN_EXTRACT="$WORK_DIR/toolchain-extract"

rm -rf "$OUT_DIR"
mkdir -p "$REVIEW_DIR" "$WORK_DIR"

cat > "$OUT_DIR/DO-NOT-BOOT-OR-FLASH.txt" <<'EOF'
PHASE 37 IS A REVIEW-ONLY DD-WRT USERSPACE/ROOTFS BUILD ATTEMPT.
ANY ROOTFS IN THIS ARTIFACT IS NOT COMPLETE FIRMWARE.
DO NOT BOOT, LOAD, INSTALL, DEPLOY, OR FLASH ANY PHASE 37 FILE.
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
  echo "Phase 37 stopped with status $(cat "$STATUS_FILE") (exit $code)."
  exit "$code"
}

trap cleanup EXIT
trap on_error ERR
exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 37 native uClibc userspace/rootfs build"
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

prepare_toolchain() {
  local archive_list="$WORK_DIR/toolchain-archive-list.txt"
  local selected_members="$WORK_DIR/selected-toolchain-members.txt"
  local selected_root
  local normalized_root

  echo "Downloading the official DD-WRT toolchain archive."
  echo "$TOOLCHAIN_URL" > "$REVIEW_DIR/toolchain-url.txt"
  if ! timeout 120m curl \
    --fail \
    --location \
    --retry 5 \
    --retry-delay 10 \
    --continue-at - \
    --output "$TOOLCHAIN_ARCHIVE" \
    "$TOOLCHAIN_URL"; then
    printf 'BLOCKED_DDWRT_TOOLCHAIN_DOWNLOAD_FAILED\n' > "$STATUS_FILE"
    return 1
  fi

  stat -c 'archive_size_bytes=%s' "$TOOLCHAIN_ARCHIVE" \
    > "$REVIEW_DIR/toolchain-archive-size.txt"
  sha256sum "$TOOLCHAIN_ARCHIVE" \
    > "$REVIEW_DIR/toolchain-archive-sha256.txt"

  echo "Indexing the official toolchain archive."
  if ! timeout 90m tar -tJf "$TOOLCHAIN_ARCHIVE" > "$archive_list"; then
    printf 'BLOCKED_DDWRT_TOOLCHAIN_ARCHIVE_INVALID\n' > "$STATUS_FILE"
    return 1
  fi

  if python3 - "$archive_list" \
    "$REVIEW_DIR/toolchain-aarch64-candidates.txt" \
    "$REVIEW_DIR/selected-toolchain-root.txt" \
    "$selected_members" <<'PY'
from __future__ import annotations

import pathlib
import sys

listing = pathlib.Path(sys.argv[1]).read_text(
    encoding="utf-8", errors="replace"
).splitlines()

compiler_suffix = "/bin/aarch64-linux-uclibc-gcc"
matches = sorted({
    line.strip().rstrip("/")
    for line in listing
    if line.strip().rstrip("/").endswith(compiler_suffix)
})

pathlib.Path(sys.argv[2]).write_text(
    "\n".join(matches) + ("\n" if matches else ""),
    encoding="utf-8",
)

if not matches:
    raise SystemExit("No aarch64-linux-uclibc-gcc in archive")


def score(path: str) -> tuple[int, int, str]:
    lower = path.lower()
    preference = 0
    if "cortex-a53" in lower or "cortex_a53" in lower:
        preference += 100
    if "ipq" in lower:
        preference += 20
    if "aarch64" in lower:
        preference += 10
    if "uclibc" in lower:
        preference += 5
    return preference, -len(path), path


selected = max(matches, key=score)
root = selected[: -len(compiler_suffix)]
pathlib.Path(sys.argv[3]).write_text(root + "\n", encoding="utf-8")
members = [
    line for line in listing
    if line.rstrip("/") == root.rstrip("/")
    or line.startswith(root.rstrip("/") + "/")
]
pathlib.Path(sys.argv[4]).write_text(
    "\n".join(members) + ("\n" if members else ""),
    encoding="utf-8",
)
PY
  then
    :
  else
    printf 'BLOCKED_DDWRT_UCLIBC_TOOLCHAIN_NOT_FOUND\n' > "$STATUS_FILE"
    return 1
  fi

  selected_root="$(cat "$REVIEW_DIR/selected-toolchain-root.txt")"
  if [[ -z "$selected_root" ]] || [[ ! -s "$selected_members" ]]; then
    printf 'BLOCKED_DDWRT_UCLIBC_TOOLCHAIN_NOT_FOUND\n' > "$STATUS_FILE"
    return 1
  fi

  echo "Extracting selected official toolchain: $selected_root"
  mkdir -p "$TOOLCHAIN_EXTRACT"
  if ! timeout 120m tar -xJf "$TOOLCHAIN_ARCHIVE" \
    -C "$TOOLCHAIN_EXTRACT" \
    -T "$selected_members"; then
    printf 'BLOCKED_DDWRT_UCLIBC_TOOLCHAIN_EXTRACTION_FAILED\n' \
      > "$STATUS_FILE"
    return 1
  fi

  printf 'selected_member_count=%s\n' \
    "$(wc -l < "$selected_members")" \
    > "$REVIEW_DIR/toolchain-selected-member-count.txt"
  rm -f "$TOOLCHAIN_ARCHIVE" "$archive_list" "$selected_members"
  normalized_root="${selected_root#./}"
  TOOLCHAIN_ROOT="$TOOLCHAIN_EXTRACT/$normalized_root"
  TOOLCHAIN_BIN="$TOOLCHAIN_ROOT/bin"
  export TOOLCHAIN_ROOT TOOLCHAIN_BIN
  export PATH="$TOOLCHAIN_BIN:$PATH"

  if [[ ! -x "$TOOLCHAIN_BIN/aarch64-linux-uclibc-gcc" ]]; then
    printf 'BLOCKED_DDWRT_UCLIBC_TOOLCHAIN_NOT_EXECUTABLE\n' \
      > "$STATUS_FILE"
    return 1
  fi

  {
    echo "selected_toolchain_root=$selected_root"
    echo "compiler=$(command -v aarch64-linux-uclibc-gcc)"
    echo "compiler_version=$(
      aarch64-linux-uclibc-gcc --version | head -n 1
    )"
    echo "compiler_machine=$(
      aarch64-linux-uclibc-gcc -dumpmachine
    )"
    echo "compiler_sysroot=$(
      aarch64-linux-uclibc-gcc -print-sysroot
    )"
    echo "toolchain_size=$(
      du -sh "$TOOLCHAIN_ROOT" | awk '{print $1}'
    )"
  } > "$REVIEW_DIR/selected-toolchain-contract.txt"

  printf 'int main(void) { return 0; }\n' \
    > "$WORK_DIR/toolchain-test.c"
  if ! aarch64-linux-uclibc-gcc \
    -Os \
    -Wl,--build-id=none \
    -o "$WORK_DIR/toolchain-test" \
    "$WORK_DIR/toolchain-test.c" \
    > "$REVIEW_DIR/toolchain-test.log" 2>&1; then
    printf 'BLOCKED_DDWRT_UCLIBC_TOOLCHAIN_TEST_FAILED\n' > "$STATUS_FILE"
    return 1
  fi

  if ! {
    file "$WORK_DIR/toolchain-test"
    aarch64-linux-uclibc-readelf -h "$WORK_DIR/toolchain-test"
  } > "$REVIEW_DIR/toolchain-test-elf.txt" 2>&1; then
    printf 'BLOCKED_DDWRT_UCLIBC_TOOLCHAIN_INSPECTION_FAILED\n' \
      > "$STATUS_FILE"
    return 1
  fi
  printf 'PASS\n' > "$REVIEW_DIR/toolchain-test-status.txt"
}

if ! prepare_toolchain; then
  exit 1
fi

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

if ! export_tree "src/linux/universal/linux-6.12-nss" required; then
  printf 'BLOCKED_DDWRT_LINUX_SOURCE_EXPORT_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

for optional_tree in \
  "src/include" \
  "src/shared"; do
  if ! export_tree "$optional_tree" optional; then
    echo "Optional source export failed: $optional_tree"
  fi
done

if [[ ! -s "$ROUTER_DIR/Makefile.ipq60xx" ]] || \
   [[ ! -s "$LINUX_TREE/Makefile" ]]; then
  printf 'BLOCKED_DDWRT_REQUIRED_SOURCE_INCOMPLETE\n' > "$STATUS_FILE"
  exit 1
fi

cp "$ROUTER_DIR/Makefile.ipq60xx" \
  "$REVIEW_DIR/Makefile.ipq60xx"

{
  echo "ddwrt_source=$SELECTED_URL"
  echo "ddwrt_svn_revision=$SVN_REVISION"
  echo "router_source_files=$(find "$ROUTER_DIR" -type f | wc -l)"
  echo "router_source_size=$(du -sh "$ROUTER_DIR" | awk '{print $1}')"
  echo "linux_source_files=$(find "$LINUX_TREE" -type f | wc -l)"
  echo "linux_source_size=$(du -sh "$LINUX_TREE" | awk '{print $1}')"
  echo "workspace_free_after_exports=$(df -h "$PWD" | awk 'NR==2 {print $4}')"
} | tee "$REVIEW_DIR/source-summary.txt"

find "$ROUTER_DIR/configs/ipq60xx" -maxdepth 3 -type f -print 2>/dev/null \
  | sed "s#^$ROUTER_DIR/##" | sort \
  > "$REVIEW_DIR/ipq60xx-config-files.txt" || true

select_platform_config() {
  local candidate
  local -a candidates=(
    "$ROUTER_DIR/configs/ipq60xx/.config_mx4200"
    "$ROUTER_DIR/configs/ipq60xx/.config_mr7350"
    "$ROUTER_DIR/configs/ipq60xx/.config_buffalo_wxr"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -s "$candidate" ]] && \
       grep -q '^CONFIG_UCLIBC=y$' "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if ! SELECTED_CONFIG="$(select_platform_config)"; then
  printf 'BLOCKED_DDWRT_IPQ60XX_CONFIG_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi

cp "$SELECTED_CONFIG" "$ROUTER_DIR/.config"
cp "$SELECTED_CONFIG" "$REVIEW_DIR/selected-ipq60xx.config"
printf '%s\n' "${SELECTED_CONFIG#"$ROUTER_DIR/"}" \
  > "$REVIEW_DIR/selected-ipq60xx-config-path.txt"
sha256sum "$REVIEW_DIR/selected-ipq60xx.config" \
  > "$REVIEW_DIR/selected-ipq60xx-config-sha256.txt"
grep -E \
  '^(PLATFORM|CONFIG_UCLIBC|CONFIG_IPQ|CONFIG_MX4200|CONFIG_MR7350)' \
  "$ROUTER_DIR/.config" \
  > "$REVIEW_DIR/selected-ipq60xx-config-summary.txt" || true

mkdir -p "$SOURCE_ROOT/opt"

HOST_CONFIG_MAKEFILE="$ROUTER_DIR/config/Makefile"
if [[ ! -f "$HOST_CONFIG_MAKEFILE" ]]; then
  printf 'BLOCKED_DDWRT_HOST_CONFIG_MAKEFILE_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi
cp "$HOST_CONFIG_MAKEFILE" \
  "$REVIEW_DIR/config-Makefile.before-fcommon"
printf '\noverride CFLAGS += -fcommon\n' \
  >> "$HOST_CONFIG_MAKEFILE"
cp "$HOST_CONFIG_MAKEFILE" \
  "$REVIEW_DIR/config-Makefile.after-fcommon"
if ! grep -q '^override CFLAGS += -fcommon$' \
  "$HOST_CONFIG_MAKEFILE"; then
  printf 'BLOCKED_DDWRT_HOST_CONFIG_FCOMMON_PATCH_FAILED\n' > "$STATUS_FILE"
  exit 1
fi
diff -u \
  "$REVIEW_DIR/config-Makefile.before-fcommon" \
  "$REVIEW_DIR/config-Makefile.after-fcommon" \
  > "$REVIEW_DIR/config-Makefile-fcommon.patch" || true

grep -RInE \
  '(/xfs/toolchains|toolchain-[^[:space:]]+|CROSS_COMPILE|ARCH[[:space:]]*[:?+]?=|aarch64[^[:space:]]*(gcc|uclibc|musl)|root\.ipq5018)' \
  "$ROUTER_DIR/Makefile.ipq60xx" \
  "$ROUTER_DIR/Makefile" \
  "$ROUTER_DIR/configs/ipq60xx" \
  > "$REVIEW_DIR/userspace-toolchain-contract.txt" 2>&1 || true

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
echo "PHASE37_SAFETY_BLOCK: $command_name \$*" >&2
exit 86
EOF
  chmod +x "$BLOCKER_DIR/$command_name"
done

QCOM_UBINIZE="$ROUTER_DIR/tools/qcom/ubinize-image.sh"
if [[ -f "$QCOM_UBINIZE" ]]; then
  cp "$QCOM_UBINIZE" "$REVIEW_DIR/ddwrt-ubinize-image.sh"
  mv "$QCOM_UBINIZE" "$QCOM_UBINIZE.phase37-disabled"
  cat > "$QCOM_UBINIZE" <<'EOF'
#!/usr/bin/env bash
echo "PHASE37_SAFETY_BLOCK: Qualcomm UBI packaging is disabled." >&2
exit 86
EOF
  chmod +x "$QCOM_UBINIZE"
fi

export PATH="$BLOCKER_DIR:$TOOLCHAIN_BIN:$PATH"
export ARCH=aarch64
export PLATFORM=aarch64
export LINUXDIR="$LINUX_TREE"
unset CC CXX AR AS LD NM OBJCOPY OBJDUMP RANLIB READELF STRIP || true

{
  echo "PATH=$PATH"
  echo "ARCH=$ARCH"
  echo "PLATFORM=$PLATFORM"
  echo "LINUXDIR=$LINUXDIR"
  echo "CROSS_COMPILER=$(command -v aarch64-linux-uclibc-gcc)"
  echo "CONFIG=${SELECTED_CONFIG#"$ROUTER_DIR/"}"
  echo "free_space_before_build=$(df -h "$PWD" | awk 'NR==2 {print $4}')"
} > "$REVIEW_DIR/userspace-build-environment.txt"

find "$SOURCE_ROOT" -type f \
  \( -name '*.ubi' -o -name '*.bin' -o -name '*.trx' \
     -o -name '*.img' \) \
  -print 2>/dev/null | sort \
  > "$WORK_DIR/prebuild-flashable-files.txt"

MAKE_COMMAND=(
  make
  -f Makefile.ipq60xx
  -j2
  V=1
  "LINUXDIR=$LINUX_TREE"
  ARCH=aarch64
  PLATFORM=aarch64
)
if [[ "$SELECTED_TARGET" != "__DEFAULT__" ]]; then
  MAKE_COMMAND+=("$SELECTED_TARGET")
fi
printf '%q ' "${MAKE_COMMAND[@]}" \
  > "$REVIEW_DIR/userspace-build-command.txt"
printf '\n' >> "$REVIEW_DIR/userspace-build-command.txt"

echo "Running a dry make expansion for diagnostic context."
DRY_RUN_COMMAND=(
  make
  -f Makefile.ipq60xx
  -n
  "LINUXDIR=$LINUX_TREE"
  ARCH=aarch64
  PLATFORM=aarch64
)
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

echo "Starting the native DD-WRT uClibc userspace/rootfs build."
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
    free_space="$(df -h "$PWD" | awk 'NR==2 {print $4}')"
    echo "Userspace build progress: elapsed=${elapsed}m rootfs_candidates=$root_candidates free_space=$free_space"
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

tail -n 1000 "$BUILD_LOG" \
  > "$REVIEW_DIR/userspace-build-tail.txt" || true

grep -n -i -m 100 -E \
  'fatal error:|error:|undefined reference|no rule to make target|not found|No such file' \
  "$BUILD_LOG" > "$REVIEW_DIR/first-build-errors.txt" || true

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
        "MISSING_DDWRT_UCLIBC_CROSS_TOOLCHAIN",
        r"aarch64-linux-uclibc-[^\s:]*(?:gcc|ld|strip)"
        r".*(?:not found|No such file)",
    ),
    (
        "MISSING_OR_WRONG_LINUX_SOURCE",
        r"src/linux/[^\s:]+: No such file or directory"
        r"|No rule to make target.*(?:linux|kernel)",
    ),
    (
        "MISSING_DDWRT_PLATFORM_CONFIG",
        r"Makefile\.ipq60xx:[0-9]+: \.config: No such file",
    ),
    (
        "DDWRT_HOST_CONFIG_MULTIPLE_DEFINITION",
        r"multiple definition of [`']current_menu",
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
        "INTENTIONAL_PHASE37_PACKAGING_STOP",
        r"PHASE37_SAFETY_BLOCK",
    ),
    (
        "OUT_OF_DISK_SPACE",
        r"No space left on device",
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

Phase 37 result
---------------
STATUS: $(cat "$STATUS_FILE")

The native DD-WRT uClibc userspace build did not produce a valid
root.ipq5018. The artifact contains the official toolchain contract,
pinned source revision, selected IPQ60xx configuration, full build log,
last 1000 lines, and automatic failure classification.

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
    aarch64-linux-uclibc-readelf -h "$ROOTFS_STAGE/bin/busybox" \
      > "$REVIEW_DIR/rootfs-busybox-elf-header.txt" 2>&1 || true
  fi
fi

find "$SOURCE_ROOT" -type f \
  \( -name '*.ubi' -o -name '*.bin' -o -name '*.trx' \
     -o -name '*.img' \) \
  -print 2>/dev/null | sort \
  > "$WORK_DIR/postbuild-flashable-files.txt"
comm -13 \
  "$WORK_DIR/prebuild-flashable-files.txt" \
  "$WORK_DIR/postbuild-flashable-files.txt" \
  > "$REVIEW_DIR/unexpected-flashable-build-files.txt"

{
  echo "superblock_status=$superblock_status"
  echo "extraction_status=$extraction_status"
  echo "userspace_build_status=$build_status"
} > "$REVIEW_DIR/rootfs-validation-status.txt"

if ! python3 work/validate-phase37.py \
  "$ROOTFS_REVIEW" \
  "$ROOTFS_STAGE" \
  "$REVIEW_DIR/rootfs-validation-status.txt" \
  "$REVIEW_DIR/rootfs-busybox-type.txt" \
  "$REVIEW_DIR/unexpected-flashable-build-files.txt" \
  "$REVIEW_DIR/phase37-integration-checks.txt"; then
  printf 'BLOCKED_DDWRT_ROOTFS_VALIDATION_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

printf 'RA72_DDWRT_UCLIBC_USERSPACE_ROOTFS_BUILD_PASS_REVIEW_ONLY\n' \
  > "$STATUS_FILE"

CHECK_COUNT="$(grep -c '=PASS$' \
  "$REVIEW_DIR/phase37-integration-checks.txt")"
ROOTFS_SIZE="$(stat -c '%s' "$ROOTFS_REVIEW")"

cat <<EOF

Phase 37 result
---------------
STATUS: RA72_DDWRT_UCLIBC_USERSPACE_ROOTFS_BUILD_PASS_REVIEW_ONLY

Verified:
- Official DD-WRT AArch64 uClibc toolchain: PASS
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
It contains no approved RA72 FIT pairing, UBI container, Xiaomi install
wrapper, or upgrade image. Qualcomm UBI packaging was deliberately disabled.
No router, SSH, UART, NAND partition, or boot variable was accessed.
Do not boot or flash any Phase 37 file.
EOF

echo
echo "Phase 37 completed: $(cat "$STATUS_FILE")"
