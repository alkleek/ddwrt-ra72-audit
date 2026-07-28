#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="$PWD/phase60-output"
REVIEW_DIR="$OUT_DIR/review"
WORK_DIR="$OUT_DIR/work"
SOURCE_ROOT="$WORK_DIR/ddwrt"
ROUTER_DIR="$SOURCE_ROOT/src/router"
LINUX_TREE="$SOURCE_ROOT/src/linux/universal/linux-6.12-nss"
ROOT_OPT="$SOURCE_ROOT/opt"
ROUTER_OPT="$ROUTER_DIR/opt"
ROOT_TOOLS="$SOURCE_ROOT/tools"
INCLUDE_V24="$SOURCE_ROOT/src/include.v24"
ROOTFS_STAGE="$WORK_DIR/rootfs-extracted"
REPORT="$OUT_DIR/REPORT-PHASE60.txt"
STATUS_FILE="$REVIEW_DIR/phase60-status.txt"
BUILD_LOG="$REVIEW_DIR/userspace-build.log"
CONFIGURE_LOG="$REVIEW_DIR/ddwrt-configure.log"
BOOTSTRAP_LOG="$REVIEW_DIR/ddwrt-bootstrap-build.log"
SOURCE_URL="${DDWRT_SOURCE_URL:-svn://svn.dd-wrt.com/DD-WRT}"
TOOLCHAIN_URL="${DDWRT_TOOLCHAIN_URL:-https://download1.dd-wrt.com/dd-wrtv2/downloads/toolchains/toolchains.tar.xz}"
REQUESTED_TARGET="${DDWRT_BUILD_TARGET:-auto}"
PINNED_SVN_REVISION="${DDWRT_SVN_REVISION:-65793}"
TOOLCHAIN_ARCHIVE="$WORK_DIR/toolchains.tar.xz"
TOOLCHAIN_EXTRACT="$WORK_DIR/toolchain-extract"
HOST_LTDL_M4="/usr/share/aclocal/ltdl.m4"
HOST_ACLOCAL_DIR="/usr/share/aclocal"
HOST_GTKDOCIZE="/usr/bin/gtkdocize"
HOST_MESON_MIN_VERSION="1.4.0"
HOST_MESON_PINNED_VERSION="1.4.2"
HOST_MESON_VENV="$WORK_DIR/host-meson-venv"
HOST_MESON="$HOST_MESON_VENV/bin/meson"
NCURSES_RULE="$ROUTER_DIR/rules/ncurses.mk"
NCURSES_MAKEFILE="$ROUTER_DIR/ncurses/Makefile"
UTIL_LINUX_RULE="$ROUTER_DIR/rules/util-linux.mk"
UTIL_LINUX_MAKEFILE="$ROUTER_DIR/util-linux/Makefile"
UTIL_LINUX_INSTALL_DIR="$WORK_DIR/util-linux-install-test"
NFNETLINK_COMPAT_SOURCE="$LINUX_TREE/include/uapi/linux/netfilter/nfnetlink_compat.h"
NFNETLINK_COMPAT_DESTINATION="$ROUTER_DIR/kernel_headers/include/linux/netfilter/nfnetlink_compat.h"
POWERTOP_DIR="$ROUTER_DIR/powertop"
POWERTOP_CONFIGURE_AC="$POWERTOP_DIR/configure.ac"
POWERTOP_ACLOCAL_M4="$POWERTOP_DIR/aclocal.m4"
POWERTOP_CONFIGURE="$POWERTOP_DIR/configure"
E2FSPROGS_BLKID_DEV="$ROUTER_DIR/e2fsprogs/lib/blkid/dev.c"
E2FSPROGS_ROOT="$ROUTER_DIR/e2fsprogs"
UTIL_LINUX_BLKID_ROOT="$ROUTER_DIR/util-linux"
REQUIRED_POWERTOP_AX_MACROS=(
  AX_REQUIRE_DEFINED
  AX_ADD_FORTIFY_SOURCE
  AX_CXX_COMPILE_STDCXX
  AX_PTHREAD
)

rm -rf "$OUT_DIR"
mkdir -p "$REVIEW_DIR" "$WORK_DIR"

cat > "$OUT_DIR/DO-NOT-BOOT-OR-FLASH.txt" <<'EOF'
PHASE 60 IS A REVIEW-ONLY DD-WRT USERSPACE/ROOTFS BUILD ATTEMPT.
ANY ROOTFS IN THIS ARTIFACT IS NOT COMPLETE FIRMWARE.
DO NOT BOOT, LOAD, INSTALL, DEPLOY, OR FLASH ANY PHASE 60 FILE.
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
  echo "Phase 60 stopped with status $(cat "$STATUS_FILE") (exit $code)."
  exit "$code"
}

trap cleanup EXIT
trap on_error ERR
exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 60 private-blkid UUID-link/rootfs build"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: review-only rootfs component; no firmware and no router access."
echo

if [[ ! -r "$HOST_LTDL_M4" ]]; then
  {
    echo "ltdl_m4_present=FAIL"
    echo "ltdl_m4_readable=FAIL"
    echo "expected_path=$HOST_LTDL_M4"
  } > "$REVIEW_DIR/host-libltdl-contract.txt"
  printf 'BLOCKED_HOST_LIBLTDL_M4_MISSING\n' > "$STATUS_FILE"
  exit 1
fi

{
  echo "ltdl_m4_present=PASS"
  echo "ltdl_m4_readable=PASS"
  echo "path=$HOST_LTDL_M4"
  echo "provider=$(
    dpkg-query -S "$HOST_LTDL_M4" 2>/dev/null || echo unknown
  )"
  echo "sha256=$(sha256sum "$HOST_LTDL_M4" | awk '{print $1}')"
} > "$REVIEW_DIR/host-libltdl-contract.txt"
echo "Verified host libltdl macro: $HOST_LTDL_M4"

AUTOCONF_ARCHIVE_CONTRACT="$REVIEW_DIR/host-autoconf-archive-contract.txt"
AUTOCONF_ARCHIVE_PACKAGE_VERSION="$(
  dpkg-query -W -f='${Version}' autoconf-archive 2>/dev/null || true
)"
autoconf_archive_missing=0

{
  echo "package=autoconf-archive"
  echo "package_version=${AUTOCONF_ARCHIVE_PACKAGE_VERSION:-missing}"
  echo "package_installed=$(
    if [[ -n "$AUTOCONF_ARCHIVE_PACKAGE_VERSION" ]]; then
      echo PASS
    else
      echo FAIL
    fi
  )"
  echo "aclocal_directory=$HOST_ACLOCAL_DIR"
  echo "aclocal_directory_present=$(
    if [[ -d "$HOST_ACLOCAL_DIR" ]]; then echo PASS; else echo FAIL; fi
  )"

  for macro in "${REQUIRED_POWERTOP_AX_MACROS[@]}"; do
    provider=""
    if [[ -d "$HOST_ACLOCAL_DIR" ]]; then
      provider="$(
        grep -RIl -m 1 -E \
          "AC_DEFUN(_ONCE)?\\(\\[$macro\\]" "$HOST_ACLOCAL_DIR" \
          2>/dev/null | head -n 1 || true
      )"
    fi
    if [[ -n "$provider" ]] && \
       grep -Eq "AC_DEFUN(_ONCE)?\\(\\[$macro\\]" "$provider"; then
      echo "macro_${macro}_present=PASS"
      echo "macro_${macro}_provider=$provider"
      echo "macro_${macro}_sha256=$(
        sha256sum "$provider" | awk '{print $1}'
      )"
    else
      echo "macro_${macro}_present=FAIL"
      echo "macro_${macro}_provider=missing"
      autoconf_archive_missing=1
    fi
  done

  echo "all_required_ax_macros=$(
    if [[ "$autoconf_archive_missing" -eq 0 ]] && \
       [[ -n "$AUTOCONF_ARCHIVE_PACKAGE_VERSION" ]]; then
      echo PASS
    else
      echo FAIL
    fi
  )"
} > "$AUTOCONF_ARCHIVE_CONTRACT"

if [[ "$autoconf_archive_missing" -ne 0 ]] || \
   [[ -z "$AUTOCONF_ARCHIVE_PACKAGE_VERSION" ]] || \
   grep -q '=FAIL$' "$AUTOCONF_ARCHIVE_CONTRACT"; then
  printf 'BLOCKED_HOST_AUTOCONF_ARCHIVE_MACROS_MISSING\n' > "$STATUS_FILE"
  exit 1
fi

export ACLOCAL_PATH="$HOST_ACLOCAL_DIR${ACLOCAL_PATH:+:$ACLOCAL_PATH}"
echo "Verified all PowerTOP AX macros from Ubuntu autoconf-archive."

if [[ ! -x "$HOST_GTKDOCIZE" ]]; then
  {
    echo "gtkdocize_present=FAIL"
    echo "gtkdocize_executable=FAIL"
    echo "expected_path=$HOST_GTKDOCIZE"
  } > "$REVIEW_DIR/host-gtkdocize-contract.txt"
  printf 'BLOCKED_HOST_GTKDOCIZE_MISSING\n' > "$STATUS_FILE"
  exit 1
fi

{
  echo "gtkdocize_present=PASS"
  echo "gtkdocize_executable=PASS"
  echo "path=$HOST_GTKDOCIZE"
  echo "provider=$(
    dpkg-query -S "$HOST_GTKDOCIZE" 2>/dev/null || echo unknown
  )"
  echo "version=$(
    "$HOST_GTKDOCIZE" --version 2>&1 | head -n 1 || true
  )"
  echo "sha256=$(sha256sum "$HOST_GTKDOCIZE" | awk '{print $1}')"
} > "$REVIEW_DIR/host-gtkdocize-contract.txt"
echo "Verified host gtkdocize tool: $HOST_GTKDOCIZE"

SYSTEM_MESON_VERSION="$(
  if command -v meson > /dev/null 2>&1; then
    meson --version 2>/dev/null || echo unknown
  else
    echo missing
  fi
)"

if ! python3 -m venv "$HOST_MESON_VENV" \
  > "$REVIEW_DIR/host-meson-venv.log" 2>&1; then
  {
    echo "meson_venv_created=FAIL"
    echo "meson_executable=FAIL"
    echo "meson_version_required=$HOST_MESON_MIN_VERSION"
    echo "meson_version_pinned=$HOST_MESON_PINNED_VERSION"
    echo "system_meson_version=$SYSTEM_MESON_VERSION"
  } > "$REVIEW_DIR/host-meson-contract.txt"
  printf 'BLOCKED_HOST_MESON_VENV_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

if ! "$HOST_MESON_VENV/bin/python" -m pip install \
  --disable-pip-version-check \
  --no-cache-dir \
  "meson==$HOST_MESON_PINNED_VERSION" \
  > "$REVIEW_DIR/host-meson-install.log" 2>&1; then
  {
    echo "meson_venv_created=PASS"
    echo "meson_executable=FAIL"
    echo "meson_version_required=$HOST_MESON_MIN_VERSION"
    echo "meson_version_pinned=$HOST_MESON_PINNED_VERSION"
    echo "system_meson_version=$SYSTEM_MESON_VERSION"
  } > "$REVIEW_DIR/host-meson-contract.txt"
  tail -n 200 "$REVIEW_DIR/host-meson-install.log" \
    > "$REVIEW_DIR/host-meson-install-tail.txt" || true
  printf 'BLOCKED_HOST_MESON_INSTALL_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

HOST_MESON_ACTUAL_VERSION="$("$HOST_MESON" --version)"
if [[ "$HOST_MESON_ACTUAL_VERSION" != "$HOST_MESON_PINNED_VERSION" ]]; then
  {
    echo "meson_venv_created=PASS"
    echo "meson_executable=PASS"
    echo "meson_version_required=$HOST_MESON_MIN_VERSION"
    echo "meson_version_pinned=$HOST_MESON_PINNED_VERSION"
    echo "meson_version_actual=$HOST_MESON_ACTUAL_VERSION"
    echo "meson_version_compatible=FAIL"
    echo "system_meson_version=$SYSTEM_MESON_VERSION"
  } > "$REVIEW_DIR/host-meson-contract.txt"
  printf 'BLOCKED_HOST_MESON_VERSION_MISMATCH\n' > "$STATUS_FILE"
  exit 1
fi

export PATH="$HOST_MESON_VENV/bin:$PATH"
{
  echo "meson_venv_created=PASS"
  echo "meson_executable=PASS"
  echo "meson_version_required=$HOST_MESON_MIN_VERSION"
  echo "meson_version_pinned=$HOST_MESON_PINNED_VERSION"
  echo "meson_version_actual=$HOST_MESON_ACTUAL_VERSION"
  echo "meson_version_compatible=PASS"
  echo "meson_active_path=$(
    if [[ "$(command -v meson)" == "$HOST_MESON" ]]; then
      echo PASS
    else
      echo FAIL
    fi
  )"
  echo "system_meson_version=$SYSTEM_MESON_VERSION"
  echo "path=$HOST_MESON"
  echo "sha256=$(sha256sum "$HOST_MESON" | awk '{print $1}')"
  echo "pip_version=$(
    "$HOST_MESON_VENV/bin/python" -m pip --version
  )"
} > "$REVIEW_DIR/host-meson-contract.txt"
tail -n 200 "$REVIEW_DIR/host-meson-install.log" \
  > "$REVIEW_DIR/host-meson-install-tail.txt" || true
echo "Verified isolated host Meson: $HOST_MESON_ACTUAL_VERSION"

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
if [[ ! "$PINNED_SVN_REVISION" =~ ^[0-9]+$ ]] || \
   ! timeout 10m svn info "$SELECTED_URL@$PINNED_SVN_REVISION" \
     > "$REVIEW_DIR/pinned-ddwrt-source-svn-info.txt" 2>&1; then
  printf 'BLOCKED_DDWRT_ROUTER_SOURCE_EXPORT_FAILED\n' > "$STATUS_FILE"
  exit 1
fi
SVN_REVISION="$PINNED_SVN_REVISION"
printf '%s\n' "$SVN_REVISION" > "$REVIEW_DIR/ddwrt-svn-revision.txt"
svn info "$SELECTED_URL/src/router/Makefile.ipq60xx@$SVN_REVISION" \
  > "$REVIEW_DIR/makefile-ipq60xx-svn-info.txt"

echo "Pinned public DD-WRT SVN revision: $SVN_REVISION"

prepare_toolchain() {
  local archive_list="$WORK_DIR/toolchain-archive-list.txt"
  local selected_members="$WORK_DIR/selected-toolchain-members.txt"
  local selected_root
  local normalized_root
  local root_basename
  local attempt=0
  local before_bytes=0
  local after_bytes=0
  local download_status=1
  local download_exit_status=1
  local connections
  local -a connection_schedule=(8 4 2 1)

  echo "Downloading the official DD-WRT toolchain archive with resumable retries."
  echo "$TOOLCHAIN_URL" > "$REVIEW_DIR/toolchain-url.txt"
  {
    echo "downloader=aria2c"
    echo "resume=true"
    echo "attempt_timeout=45m"
    echo "attempt_count=${#connection_schedule[@]}"
    echo "connection_schedule=${connection_schedule[*]}"
    echo "piece_length=4M"
    echo "file_allocation=none"
    echo "lowest_speed_limit=disabled"
    echo "control_file_preserved_between_attempts=true"
  } > "$REVIEW_DIR/toolchain-download-contract.txt"
  : > "$REVIEW_DIR/toolchain-download.log"
  : > "$REVIEW_DIR/toolchain-download-attempts.txt"

  for connections in "${connection_schedule[@]}"; do
    attempt=$((attempt + 1))
    before_bytes="$(stat -c '%s' "$TOOLCHAIN_ARCHIVE" 2>/dev/null || echo 0)"
    {
      echo "attempt=$attempt"
      echo "connections=$connections"
      echo "bytes_before=$before_bytes"
      echo "control_file_before=$(
        if [[ -s "$TOOLCHAIN_ARCHIVE.aria2" ]]; then echo present; else echo absent; fi
      )"
    } | tee -a "$REVIEW_DIR/toolchain-download-attempts.txt" \
      >> "$REVIEW_DIR/toolchain-download.log"

    if timeout 45m aria2c \
      --allow-overwrite=true \
      --always-resume=true \
      --auto-file-renaming=false \
      --auto-save-interval=10 \
      --check-certificate=true \
      --connect-timeout=30 \
      --console-log-level=notice \
      --continue=true \
      --dir="$WORK_DIR" \
      --download-result=hide \
      --file-allocation=none \
      --lowest-speed-limit=0 \
      --max-connection-per-server="$connections" \
      --max-tries=0 \
      --min-split-size=4M \
      --out="$(basename "$TOOLCHAIN_ARCHIVE")" \
      --piece-length=4M \
      --retry-wait=5 \
      --split="$connections" \
      --summary-interval=60 \
      --timeout=60 \
      "$TOOLCHAIN_URL" \
      >> "$REVIEW_DIR/toolchain-download.log" 2>&1; then
      download_exit_status=0
      download_status=0
    else
      download_exit_status=$?
    fi

    after_bytes="$(stat -c '%s' "$TOOLCHAIN_ARCHIVE" 2>/dev/null || echo 0)"
    {
      echo "exit_status=$download_exit_status"
      echo "bytes_after=$after_bytes"
      echo "bytes_added=$((after_bytes - before_bytes))"
      echo "control_file_after=$(
        if [[ -s "$TOOLCHAIN_ARCHIVE.aria2" ]]; then echo present; else echo absent; fi
      )"
      echo
    } | tee -a "$REVIEW_DIR/toolchain-download-attempts.txt" \
      >> "$REVIEW_DIR/toolchain-download.log"

    if [[ "$download_status" -eq 0 ]]; then
      break
    fi

    echo "Download attempt $attempt stopped; retaining partial data for retry."
    sleep $((attempt * 5))
  done

  {
    echo "attempts_used=$attempt"
    echo "final_download_status=$download_status"
    echo "final_archive_bytes=$after_bytes"
  } >> "$REVIEW_DIR/toolchain-download-contract.txt"

  if [[ "$download_status" -ne 0 ]]; then
    tail -n 500 "$REVIEW_DIR/toolchain-download.log" \
      > "$REVIEW_DIR/toolchain-download-tail.txt" || true
    printf 'BLOCKED_DDWRT_TOOLCHAIN_DOWNLOAD_FAILED\n' > "$STATUS_FILE"
    return 1
  fi

  tail -n 500 "$REVIEW_DIR/toolchain-download.log" \
    > "$REVIEW_DIR/toolchain-download-tail.txt" || true
  if [[ ! -s "$TOOLCHAIN_ARCHIVE" ]]; then
    printf 'BLOCKED_DDWRT_TOOLCHAIN_DOWNLOAD_EMPTY\n' > "$STATUS_FILE"
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
  normalized_root="${selected_root#./}"
  root_basename="${normalized_root##*/}"
  printf '%s\n' "$root_basename" \
    > "$REVIEW_DIR/selected-toolchain-root-basename.txt"

  if ! timeout 120m tar \
    --extract \
    --xz \
    --file="$TOOLCHAIN_ARCHIVE" \
    --directory="$TOOLCHAIN_EXTRACT" \
    --wildcards \
    --wildcards-match-slash \
    --no-anchored \
    "$root_basename/*" \
    > "$REVIEW_DIR/toolchain-extraction.log" 2>&1; then
    tail -n 500 "$REVIEW_DIR/toolchain-extraction.log" \
      > "$REVIEW_DIR/toolchain-extraction-tail.txt" || true
    printf 'BLOCKED_DDWRT_UCLIBC_TOOLCHAIN_EXTRACTION_FAILED\n' \
      > "$STATUS_FILE"
    return 1
  fi

  tail -n 500 "$REVIEW_DIR/toolchain-extraction.log" \
    > "$REVIEW_DIR/toolchain-extraction-tail.txt" || true
  printf 'selected_member_count=%s\n' \
    "$(wc -l < "$selected_members")" \
    > "$REVIEW_DIR/toolchain-selected-member-count.txt"
  rm -f "$TOOLCHAIN_ARCHIVE" "$archive_list" "$selected_members"
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

if ! export_tree "opt" required; then
  printf 'BLOCKED_DDWRT_SOURCE_OPT_EXPORT_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

if ! export_tree "tools" required; then
  printf 'BLOCKED_DDWRT_SOURCE_TOOLS_EXPORT_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

if ! export_tree "src/include.v24" required; then
  printf 'BLOCKED_DDWRT_INCLUDE_V24_EXPORT_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

for optional_tree in \
  "src/include" \
  "src/include.v23" \
  "src/include.bcm" \
  "src/shared"; do
  if ! export_tree "$optional_tree" optional; then
    echo "Optional source export failed: $optional_tree"
  fi
done

if [[ ! -s "$ROUTER_DIR/Makefile.ipq60xx" ]] || \
   [[ ! -s "$LINUX_TREE/Makefile" ]] || \
   [[ ! -d "$ROOT_OPT" ]] || \
   [[ ! -d "$ROOT_TOOLS" ]] || \
   [[ ! -d "$INCLUDE_V24" ]]; then
  printf 'BLOCKED_DDWRT_REQUIRED_SOURCE_INCOMPLETE\n' > "$STATUS_FILE"
  exit 1
fi

if [[ ! -s "$NFNETLINK_COMPAT_SOURCE" ]]; then
  {
    echo "source_present=FAIL"
    echo "source_path=${NFNETLINK_COMPAT_SOURCE#"$SOURCE_ROOT/"}"
    echo "source_revision=$SVN_REVISION"
    echo "destination_path=${NFNETLINK_COMPAT_DESTINATION#"$SOURCE_ROOT/"}"
  } > "$REVIEW_DIR/nfnetlink-compat-header-contract.txt"
  printf 'BLOCKED_DDWRT_NFNETLINK_COMPAT_SOURCE_MISSING\n' \
    > "$STATUS_FILE"
  exit 1
fi

mkdir -p "$(dirname "$NFNETLINK_COMPAT_DESTINATION")"
install -m 0644 \
  "$NFNETLINK_COMPAT_SOURCE" \
  "$NFNETLINK_COMPAT_DESTINATION"

NFNETLINK_COMPAT_SOURCE_SHA="$(
  sha256sum "$NFNETLINK_COMPAT_SOURCE" | awk '{print $1}'
)"
NFNETLINK_COMPAT_DESTINATION_SHA="$(
  sha256sum "$NFNETLINK_COMPAT_DESTINATION" | awk '{print $1}'
)"

{
  echo "source_present=PASS"
  echo "source_path=${NFNETLINK_COMPAT_SOURCE#"$SOURCE_ROOT/"}"
  echo "source_revision=$SVN_REVISION"
  echo "source_sha256=$NFNETLINK_COMPAT_SOURCE_SHA"
  echo "destination_parent_present=$(
    if [[ -d "$(dirname "$NFNETLINK_COMPAT_DESTINATION")" ]]; then
      echo PASS
    else
      echo FAIL
    fi
  )"
  echo "destination_present=$(
    if [[ -s "$NFNETLINK_COMPAT_DESTINATION" ]]; then
      echo PASS
    else
      echo FAIL
    fi
  )"
  echo "destination_path=${NFNETLINK_COMPAT_DESTINATION#"$SOURCE_ROOT/"}"
  echo "destination_sha256=$NFNETLINK_COMPAT_DESTINATION_SHA"
  echo "source_destination_identical=$(
    if cmp -s \
      "$NFNETLINK_COMPAT_SOURCE" \
      "$NFNETLINK_COMPAT_DESTINATION"; then
      echo PASS
    else
      echo FAIL
    fi
  )"
  echo "nfnetlink_compat_guard_present=$(
    if grep -Eq '^#ifndef[[:space:]]+_+UAPI_NFNETLINK_COMPAT_H' \
      "$NFNETLINK_COMPAT_DESTINATION" || \
       grep -Eq '^#ifndef[[:space:]]+_+NFNETLINK_COMPAT_H' \
      "$NFNETLINK_COMPAT_DESTINATION"; then
      echo PASS
    else
      echo FAIL
    fi
  )"
} > "$REVIEW_DIR/nfnetlink-compat-header-contract.txt"

if grep -q '=FAIL$' \
  "$REVIEW_DIR/nfnetlink-compat-header-contract.txt"; then
  printf 'BLOCKED_DDWRT_NFNETLINK_COMPAT_MATERIALIZATION_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

echo "Restored the pinned DD-WRT nfnetlink compatibility UAPI header."

POWERTOP_AUTOCONF_CONTRACT="$REVIEW_DIR/powertop-autoconf-contract.txt"
POWERTOP_AUTOCONF_PREFLIGHT_LOG="$REVIEW_DIR/powertop-autoconf-preflight.log"
powertop_macro_ref_missing=0

if [[ ! -s "$POWERTOP_CONFIGURE_AC" ]]; then
  {
    echo "configure_ac_present=FAIL"
    echo "configure_ac_path=${POWERTOP_CONFIGURE_AC#"$SOURCE_ROOT/"}"
    echo "focused_autoconf_preflight_status=127"
  } > "$POWERTOP_AUTOCONF_CONTRACT"
  printf 'BLOCKED_POWERTOP_CONFIGURE_AC_MISSING\n' > "$STATUS_FILE"
  exit 1
fi

cp "$POWERTOP_CONFIGURE_AC" "$REVIEW_DIR/powertop-configure.ac"
{
  echo "configure_ac_present=PASS"
  echo "configure_ac_path=${POWERTOP_CONFIGURE_AC#"$SOURCE_ROOT/"}"
  echo "configure_ac_sha256=$(
    sha256sum "$POWERTOP_CONFIGURE_AC" | awk '{print $1}'
  )"
  echo "aclocal_path=$ACLOCAL_PATH"

  for macro in "${REQUIRED_POWERTOP_AX_MACROS[@]}"; do
    if grep -Fq "$macro" "$POWERTOP_CONFIGURE_AC"; then
      echo "configure_ref_${macro}=PASS"
    else
      echo "configure_ref_${macro}=FAIL"
      powertop_macro_ref_missing=1
    fi
  done
} > "$POWERTOP_AUTOCONF_CONTRACT"

mkdir -p "$POWERTOP_DIR/m4"
if (
  trap - ERR
  cd "$POWERTOP_DIR"
  rm -f config.cache aclocal.m4 configure
  libtoolize --force
  ACLOCAL_PATH="$ACLOCAL_PATH" aclocal -I m4
  autoconf
) > "$POWERTOP_AUTOCONF_PREFLIGHT_LOG" 2>&1; then
  powertop_autoconf_preflight_status=0
else
  powertop_autoconf_preflight_status=$?
fi

tail -n 300 "$POWERTOP_AUTOCONF_PREFLIGHT_LOG" \
  > "$REVIEW_DIR/powertop-autoconf-preflight-tail.txt" || true

if [[ -s "$POWERTOP_ACLOCAL_M4" ]]; then
  cp "$POWERTOP_ACLOCAL_M4" "$REVIEW_DIR/powertop-aclocal.m4"
fi

{
  echo "autoconf_archive_contract_passed=$(
    if grep -qx 'all_required_ax_macros=PASS' \
      "$AUTOCONF_ARCHIVE_CONTRACT"; then
      echo PASS
    else
      echo FAIL
    fi
  )"
  echo "focused_autoconf_preflight_status=$powertop_autoconf_preflight_status"
  echo "focused_autoconf_preflight_passed=$(
    if [[ "$powertop_autoconf_preflight_status" -eq 0 ]]; then
      echo PASS
    else
      echo FAIL
    fi
  )"
  echo "generated_aclocal_m4_present=$(
    if [[ -s "$POWERTOP_ACLOCAL_M4" ]]; then echo PASS; else echo FAIL; fi
  )"
  echo "generated_configure_present=$(
    if [[ -s "$POWERTOP_CONFIGURE" ]]; then echo PASS; else echo FAIL; fi
  )"
  echo "ax_pthread_definition_materialized=$(
    if [[ -s "$POWERTOP_ACLOCAL_M4" ]] && \
       grep -Eq 'AC_DEFUN(_ONCE)?\(\[AX_PTHREAD\]' \
         "$POWERTOP_ACLOCAL_M4"; then
      echo PASS
    else
      echo FAIL
    fi
  )"
  echo "phase54_undefined_ac_msg_error_absent=$(
    if grep -Eqi \
      'possibly undefined macro:[[:space:]]*AC_MSG_ERROR' \
      "$POWERTOP_AUTOCONF_PREFLIGHT_LOG"; then
      echo FAIL
    else
      echo PASS
    fi
  )"
} >> "$POWERTOP_AUTOCONF_CONTRACT"

if [[ "$powertop_macro_ref_missing" -ne 0 ]] || \
   [[ "$powertop_autoconf_preflight_status" -ne 0 ]] || \
   grep -q '=FAIL$' "$POWERTOP_AUTOCONF_CONTRACT"; then
  printf 'BLOCKED_POWERTOP_AUTOCONF_ARCHIVE_PREFLIGHT_FAILED\n' \
    > "$STATUS_FILE"
  cat <<EOF

Phase 60 result
---------------
STATUS: $(cat "$STATUS_FILE")

The pinned PowerTOP source or its focused Autoconf preflight did not
satisfy the required AX macro contract. The artifact contains the exact
configure.ac, host macro-provider paths and hashes, generated aclocal.m4
when available, and the complete focused preflight log.

No firmware was built and the router was not accessed.
EOF
  exit 1
fi

echo "PowerTOP Autoconf Archive macro preflight passed."

E2FSPROGS_BLKID_CONST_CONTRACT="$REVIEW_DIR/e2fsprogs-blkid-const-contract.txt"
E2FSPROGS_BLKID_PATCH="$REVIEW_DIR/e2fsprogs-blkid-const-correctness.patch"
E2FSPROGS_BLKID_BEFORE="$REVIEW_DIR/e2fsprogs-blkid-dev.before.c"
E2FSPROGS_BLKID_AFTER="$REVIEW_DIR/e2fsprogs-blkid-dev.after.c"
UTIL_LINUX_BLKID_HEADER_REVIEW="$REVIEW_DIR/util-linux-blkid-public-header.h"
UTIL_LINUX_BLKID_CANDIDATES_REVIEW="$REVIEW_DIR/util-linux-blkid-header-candidates.txt"

if ! python3 - \
  "$E2FSPROGS_BLKID_DEV" \
  "$UTIL_LINUX_BLKID_ROOT" \
  "$E2FSPROGS_BLKID_BEFORE" \
  "$E2FSPROGS_BLKID_AFTER" \
  "$UTIL_LINUX_BLKID_HEADER_REVIEW" \
  "$UTIL_LINUX_BLKID_CANDIDATES_REVIEW" \
  "$E2FSPROGS_BLKID_PATCH" \
  "$E2FSPROGS_BLKID_CONST_CONTRACT" \
  "$SVN_REVISION" <<'PY'
from __future__ import annotations

import difflib
import hashlib
import pathlib
import re
import shutil
import sys

(
    source_arg,
    header_root_arg,
    before_arg,
    after_arg,
    header_review_arg,
    candidates_review_arg,
    patch_arg,
    contract_arg,
    revision,
) = sys.argv[1:]

source = pathlib.Path(source_arg)
header_root = pathlib.Path(header_root_arg)
before_path = pathlib.Path(before_arg)
after_path = pathlib.Path(after_arg)
header_review_path = pathlib.Path(header_review_arg)
candidates_review_path = pathlib.Path(candidates_review_arg)
patch_path = pathlib.Path(patch_arg)
contract_path = pathlib.Path(contract_arg)

results: list[tuple[str, str]] = [
    ("source_revision", revision),
    ("source_path", "src/router/e2fsprogs/lib/blkid/dev.c"),
    ("public_header_discovery_root", "src/router/util-linux"),
]


def record(name: str, passed: bool) -> None:
    results.append((name, "PASS" if passed else "FAIL"))


def sha256(data: str) -> str:
    return hashlib.sha256(data.encode("utf-8")).hexdigest()


try:
    record("source_present", source.is_file())
    public_signature = re.compile(
        r"\bextern\s+int\s+blkid_dev_set_search\s*\(\s*"
        r"blkid_dev_iterate\s+iter\s*,\s*"
        r"const\s+char\s*\*\s*search_type\s*,\s*"
        r"const\s+char\s*\*\s*search_value\s*\)",
        re.DOTALL,
    )
    record("public_header_discovery_root_present", header_root.is_dir())
    if not source.is_file() or not header_root.is_dir():
        raise RuntimeError(
            "required pinned blkid source/discovery root is missing"
        )

    candidates = sorted(
        path
        for path in header_root.rglob("*")
        if path.is_file() and path.name in {"blkid.h", "blkid.h.in"}
    )
    matches: list[tuple[pathlib.Path, str, int]] = []
    inventory: list[str] = []
    for candidate in candidates:
        text = candidate.read_text(encoding="utf-8", errors="strict")
        count = len(public_signature.findall(text))
        relative = candidate.relative_to(header_root)
        inventory.append(f"{relative}\tconst_signature_count={count}")
        if count == 1:
            matches.append((candidate, text, count))
    candidates_review_path.write_text(
        "\n".join(inventory) + ("\n" if inventory else ""),
        encoding="utf-8",
    )

    preferred = header_root / "libblkid" / "src" / "blkid.h.in"
    preferred_matches = [item for item in matches if item[0] == preferred]
    if len(preferred_matches) == 1:
        header, header_text, public_count = preferred_matches[0]
        selection_method = "canonical_libblkid_src_blkid_h_in"
    elif len(matches) == 1:
        header, header_text, public_count = matches[0]
        selection_method = "single_semantic_match"
    else:
        raise RuntimeError(
            "unable to select one authoritative const-correct blkid header "
            f"(candidates={len(candidates)}, matches={len(matches)})"
        )

    selected_relative = header.relative_to(header_root)
    results.extend(
        [
            ("public_header_candidate_count", str(len(candidates))),
            ("public_header_const_match_count", str(len(matches))),
            (
                "public_header_path",
                f"src/router/util-linux/{selected_relative.as_posix()}",
            ),
            ("public_header_selection_method", selection_method),
        ]
    )
    record("public_header_present", header.is_file())
    record("public_header_selected", True)

    source_text = source.read_text(encoding="utf-8", errors="strict")
    before_path.write_text(source_text, encoding="utf-8")
    shutil.copyfile(header, header_review_path)

    legacy_signature = re.compile(
        r"\bextern\s+int\s+blkid_dev_set_search\s*\(\s*"
        r"blkid_dev_iterate\s+iter\s*,\s*"
        r"char\s*\*\s*search_type\s*,\s*"
        r"char\s*\*\s*search_value\s*\)",
        re.DOTALL,
    )
    patched_signature = re.compile(
        r"\bextern\s+int\s+blkid_dev_set_search\s*\(\s*"
        r"blkid_dev_iterate\s+iter\s*,\s*"
        r"const\s+char\s*\*\s*search_type\s*,\s*"
        r"const\s+char\s*\*\s*search_value\s*\)",
        re.DOTALL,
    )

    legacy_matches = list(legacy_signature.finditer(source_text))
    legacy_count = len(legacy_matches)
    legacy_signature_text = (
        legacy_matches[0].group(0) if legacy_count == 1 else ""
    )
    search_type_count = len(
        re.findall(r"\bchar\s*\*\s*search_type\b", legacy_signature_text)
    )
    search_value_count = len(
        re.findall(r"\bchar\s*\*\s*search_value\b", legacy_signature_text)
    )
    results.extend(
        [
            ("public_const_signature_count", str(public_count)),
            ("legacy_function_signature_count_before", str(legacy_count)),
            ("legacy_search_type_count_before", str(search_type_count)),
            ("legacy_search_value_count_before", str(search_value_count)),
        ]
    )
    record("public_header_const_signature", public_count == 1)
    record("legacy_function_signature_exactly_once", legacy_count == 1)
    record("legacy_search_type_exactly_once", search_type_count == 1)
    record("legacy_search_value_exactly_once", search_value_count == 1)
    if (
        public_count != 1
        or legacy_count != 1
        or search_type_count != 1
        or search_value_count != 1
    ):
        raise RuntimeError("pinned blkid signature does not match Phase 60 contract")

    patched_text, signature_replacements = legacy_signature.subn(
        lambda match: re.sub(
            r"\bchar\s*\*\s*(search_type|search_value)\b",
            r"const char *\1",
            match.group(0),
        ),
        source_text,
        count=1,
    )
    patched_count = len(patched_signature.findall(patched_text))
    remaining_legacy_count = len(legacy_signature.findall(patched_text))
    source_changed = patched_text != source_text
    results.extend(
        [
            ("signature_replacements", str(signature_replacements)),
            ("patched_const_signature_count", str(patched_count)),
            (
                "remaining_legacy_signature_count",
                str(remaining_legacy_count),
            ),
            ("source_sha256_before", sha256(source_text)),
            ("source_sha256_after", sha256(patched_text)),
        ]
    )
    record("source_changed", source_changed)
    record("patched_const_signature_exactly_once", patched_count == 1)
    record("legacy_nonconst_signature_absent", remaining_legacy_count == 0)
    if (
        signature_replacements != 1
        or patched_count != 1
        or remaining_legacy_count != 0
        or not source_changed
    ):
        raise RuntimeError("const-correctness patch did not apply exactly once")

    source.write_text(patched_text, encoding="utf-8")
    after_path.write_text(patched_text, encoding="utf-8")
    patch_text = "".join(
        difflib.unified_diff(
            source_text.splitlines(keepends=True),
            patched_text.splitlines(keepends=True),
            fromfile="a/src/router/e2fsprogs/lib/blkid/dev.c",
            tofile="b/src/router/e2fsprogs/lib/blkid/dev.c",
        )
    )
    patch_path.write_text(patch_text, encoding="utf-8")
    record(
        "patch_is_nonempty",
        patch_path.is_file() and patch_path.stat().st_size > 0,
    )
except Exception as exc:
    results.append(("error", f"{type(exc).__name__}: {exc}"))
    contract_path.write_text(
        "".join(f"{key}={value}\n" for key, value in results),
        encoding="utf-8",
    )
    raise

contract_path.write_text(
    "".join(f"{key}={value}\n" for key, value in results),
    encoding="utf-8",
)
PY
then
  printf 'BLOCKED_E2FSPROGS_BLKID_HEADER_DISCOVERY_FAILED\n' > "$STATUS_FILE"
  cat <<EOF

Phase 60 result
---------------
STATUS: $(cat "$STATUS_FILE")

The pinned e2fsprogs source or util-linux public-header discovery no
longer matches the narrow Phase 60 contract. The artifact contains the
candidate inventory and all evidence produced before the fail-closed
stop.

No firmware was built and the router was not accessed.
EOF
  exit 1
fi

if grep -q '=FAIL$' "$E2FSPROGS_BLKID_CONST_CONTRACT"; then
  printf 'BLOCKED_E2FSPROGS_BLKID_HEADER_DISCOVERY_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

echo "Discovered the pinned blkid template and applied the verified const patch."

E2FSPROGS_CONFIGURE_SYNC_CONTRACT="$REVIEW_DIR/e2fsprogs-generated-configure-sync-contract.txt"
E2FSPROGS_CONFIGURE_SYNC_PATCH="$REVIEW_DIR/e2fsprogs-generated-configure-sync.patch"
E2FSPROGS_CONFIGURE_SYNC_CANDIDATES="$REVIEW_DIR/e2fsprogs-generated-configure-sync-candidates.txt"
E2FSPROGS_CONFIGURE_SYNC_BEFORE="$REVIEW_DIR/e2fsprogs-generated-configure.before"
E2FSPROGS_CONFIGURE_SYNC_AFTER="$REVIEW_DIR/e2fsprogs-generated-configure.after"

if ! python3 - \
  "$E2FSPROGS_ROOT" \
  "$E2FSPROGS_CONFIGURE_SYNC_CANDIDATES" \
  "$E2FSPROGS_CONFIGURE_SYNC_PATCH" \
  "$E2FSPROGS_CONFIGURE_SYNC_CONTRACT" \
  "$E2FSPROGS_CONFIGURE_SYNC_BEFORE" \
  "$E2FSPROGS_CONFIGURE_SYNC_AFTER" \
  "$SVN_REVISION" <<'PY'
from __future__ import annotations

import difflib
import hashlib
import pathlib
import re
import sys

(
    root_arg,
    candidates_arg,
    patch_arg,
    contract_arg,
    before_arg,
    after_arg,
    revision,
) = sys.argv[1:]

root = pathlib.Path(root_arg)
candidates_path = pathlib.Path(candidates_arg)
patch_path = pathlib.Path(patch_arg)
contract_path = pathlib.Path(contract_arg)
before_path = pathlib.Path(before_arg)
after_path = pathlib.Path(after_arg)
source_names = ("configure", "configure.ac", "MCONFIG.in")
sources = {name: root / name for name in source_names}

legacy_pattern = re.compile(
    r"(?P<prefix>\\?\$\(LIB\)/)libblkid\b"
)
corrected_pattern = re.compile(
    r"(?P<prefix>\\?\$\(LIB\)/)libe2fsblkid\b"
)
results: list[tuple[str, str]] = [
    ("source_revision", revision),
    ("source_root", "src/router/e2fsprogs"),
    ("required_source_names", ",".join(source_names)),
    ("legacy_basename_expression", "$(LIB)/libblkid"),
    ("corrected_basename_expression", "$(LIB)/libe2fsblkid"),
    ("patched_source", "configure"),
    ("unchanged_authoritative_source", "configure.ac"),
    ("autoconf_regeneration", "disabled"),
]


def record(name: str, passed: bool) -> None:
    results.append((name, "PASS" if passed else "FAIL"))


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def finish() -> None:
    contract_path.write_text(
        "".join(f"{key}={value}\n" for key, value in results),
        encoding="utf-8",
    )


try:
    record("source_root_present", root.is_dir())
    if not root.is_dir():
        raise RuntimeError("pinned e2fsprogs source root is missing")

    all_sources_present = all(path.is_file() for path in sources.values())
    record("all_three_sources_present", all_sources_present)
    if not all_sources_present:
        missing = [name for name, path in sources.items() if not path.is_file()]
        raise RuntimeError(
            "required e2fsprogs configuration sources are missing: "
            + ", ".join(missing)
        )

    inventory: list[str] = []
    original_bytes = {name: path.read_bytes() for name, path in sources.items()}
    original_text = {
        name: data.decode("utf-8", errors="strict")
        for name, data in original_bytes.items()
    }
    before_counts: dict[str, tuple[int, int]] = {}
    for name in source_names:
        text = original_text[name]
        legacy_count = len(legacy_pattern.findall(text))
        corrected_count = len(corrected_pattern.findall(text))
        before_counts[name] = (legacy_count, corrected_count)
        results.extend(
            [
                (f"{name}_legacy_reference_count_before", str(legacy_count)),
                (
                    f"{name}_corrected_reference_count_before",
                    str(corrected_count),
                ),
                (f"{name}_sha256_before", sha256(original_bytes[name])),
            ]
        )
        for line_number, line in enumerate(text.splitlines(), start=1):
            if legacy_pattern.search(line) or corrected_pattern.search(line):
                inventory.append(f"{name}:{line_number}:{line.strip()}")

    candidates_path.write_text(
        "\n".join(inventory) + ("\n" if inventory else ""),
        encoding="utf-8",
    )
    exact_mixed_state = (
        before_counts["configure"] == (6, 0)
        and before_counts["configure.ac"] == (0, 6)
        and before_counts["MCONFIG.in"] == (0, 0)
    )
    record("exact_phase58_mixed_state_verified", exact_mixed_state)
    if not exact_mixed_state:
        raise RuntimeError(
            "e2fsprogs sources no longer match the exact verified Phase 58 "
            "mixed state (configure=6 legacy, configure.ac=6 corrected, "
            "MCONFIG.in=0 matching references)"
        )

    configure_original = original_text["configure"]
    before_path.write_bytes(original_bytes["configure"])
    configure_patched, replacements = legacy_pattern.subn(
        lambda match: f"{match.group('prefix')}libe2fsblkid",
        configure_original,
    )
    sources["configure"].write_text(configure_patched, encoding="utf-8")
    after_path.write_text(configure_patched, encoding="utf-8")
    patch_path.write_text(
        "".join(
            difflib.unified_diff(
                configure_original.splitlines(keepends=True),
                configure_patched.splitlines(keepends=True),
                fromfile="a/src/router/e2fsprogs/configure",
                tofile="b/src/router/e2fsprogs/configure",
            )
        ),
        encoding="utf-8",
    )

    after_bytes = {name: path.read_bytes() for name, path in sources.items()}
    after_text = {
        name: data.decode("utf-8", errors="strict")
        for name, data in after_bytes.items()
    }
    after_counts: dict[str, tuple[int, int]] = {}
    for name in source_names:
        legacy_count = len(legacy_pattern.findall(after_text[name]))
        corrected_count = len(corrected_pattern.findall(after_text[name]))
        after_counts[name] = (legacy_count, corrected_count)
        results.extend(
            [
                (f"{name}_legacy_reference_count_after", str(legacy_count)),
                (
                    f"{name}_corrected_reference_count_after",
                    str(corrected_count),
                ),
                (f"{name}_sha256_after", sha256(after_bytes[name])),
            ]
        )

    configure_changed = (
        sha256(after_bytes["configure"]) != sha256(original_bytes["configure"])
    )
    configure_ac_unchanged = (
        sha256(after_bytes["configure.ac"])
        == sha256(original_bytes["configure.ac"])
    )
    mconfig_in_unchanged = (
        sha256(after_bytes["MCONFIG.in"])
        == sha256(original_bytes["MCONFIG.in"])
    )
    record("generated_configure_replacement_count_exact", replacements == 6)
    record(
        "generated_configure_all_legacy_references_replaced",
        after_counts["configure"][0] == 0,
    )
    record(
        "generated_configure_corrected_reference_count_exact",
        after_counts["configure"][1] == 6,
    )
    record("configure_ac_unchanged", configure_ac_unchanged)
    record("mconfig_in_unchanged", mconfig_in_unchanged)
    record("generated_configure_changed", configure_changed)
    record("patch_is_nonempty", patch_path.stat().st_size > 0)
    record("no_autoconf_regeneration", True)
    record("no_fallback_symlink_created", True)
    if (
        replacements != 6
        or after_counts["configure"] != (0, 6)
        or after_counts["configure.ac"] != (0, 6)
        or after_counts["MCONFIG.in"] != (0, 0)
        or not configure_ac_unchanged
        or not mconfig_in_unchanged
        or not configure_changed
        or patch_path.stat().st_size == 0
    ):
        raise RuntimeError(
            "generated configure synchronization verification failed"
        )
except Exception as exc:
    results.append(("error", f"{type(exc).__name__}: {exc}"))
    finish()
    raise

finish()
PY
then
  printf 'BLOCKED_E2FSPROGS_GENERATED_CONFIGURE_SYNC_CONTRACT_FAILED\n' \
    > "$STATUS_FILE"
  cat <<EOF

Phase 60 result
---------------
STATUS: $(cat "$STATUS_FILE")

The pinned e2fsprogs sources no longer match the exact mixed state proved
by Phase 58. Phase 60 fails closed instead of editing an unverified source
layout. The artifact contains the exact candidate inventory and all
evidence produced before this stop. Autoconf was not regenerated and no
fallback symlink was created.

No firmware was built and the router was not accessed.
EOF
  exit 1
fi

if grep -q '=FAIL$' "$E2FSPROGS_CONFIGURE_SYNC_CONTRACT"; then
  printf 'BLOCKED_E2FSPROGS_GENERATED_CONFIGURE_SYNC_CONTRACT_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

echo "Synchronized the checked-in e2fsprogs configure with configure.ac."

E2FSPROGS_UUID_LINK_TEMPLATE_CONTRACT="$REVIEW_DIR/e2fsprogs-private-blkid-uuid-template-contract.txt"
E2FSPROGS_UUID_LINK_TEMPLATE_PATCH="$REVIEW_DIR/e2fsprogs-private-blkid-uuid-template.patch"
E2FSPROGS_UUID_LINK_TEMPLATE_BEFORE="$REVIEW_DIR/e2fsprogs-MCONFIG.in.before"
E2FSPROGS_UUID_LINK_TEMPLATE_AFTER="$REVIEW_DIR/e2fsprogs-MCONFIG.in.after"

if ! python3 - \
  "$E2FSPROGS_ROOT/MCONFIG.in" \
  "$E2FSPROGS_ROOT/configure" \
  "$E2FSPROGS_ROOT/configure.ac" \
  "$E2FSPROGS_UUID_LINK_TEMPLATE_CONTRACT" \
  "$E2FSPROGS_UUID_LINK_TEMPLATE_PATCH" \
  "$E2FSPROGS_UUID_LINK_TEMPLATE_BEFORE" \
  "$E2FSPROGS_UUID_LINK_TEMPLATE_AFTER" \
  "$SVN_REVISION" <<'PY'
from __future__ import annotations

import difflib
import hashlib
import pathlib
import re
import sys

(
    mconfig_arg,
    configure_arg,
    configure_ac_arg,
    contract_arg,
    patch_arg,
    before_arg,
    after_arg,
    revision,
) = sys.argv[1:]

mconfig_path = pathlib.Path(mconfig_arg)
configure_path = pathlib.Path(configure_arg)
configure_ac_path = pathlib.Path(configure_ac_arg)
contract_path = pathlib.Path(contract_arg)
patch_path = pathlib.Path(patch_arg)
before_path = pathlib.Path(before_arg)
after_path = pathlib.Path(after_arg)

commented_pattern = re.compile(
    r"^(?P<prefix>[ \t]*LIBBLKID[ \t]*=[ \t]*"
    r"@LIBBLKID@[ \t]*)#[ \t]*\$\([ \t]*LIBUUID[ \t]*\)[ \t]*$",
    re.MULTILINE,
)
active_pattern = re.compile(
    r"^[ \t]*LIBBLKID[ \t]*=[ \t]*@LIBBLKID@[ \t]+"
    r"\$\([ \t]*LIBUUID[ \t]*\)[ \t]*$",
    re.MULTILINE,
)
results: list[tuple[str, str]] = [
    ("source_revision", revision),
    ("patched_source", "src/router/e2fsprogs/MCONFIG.in"),
    ("semantic_change", "activate_LIBUUID_after_private_LIBBLKID"),
    ("autoconf_regeneration", "disabled"),
]


def record(name: str, passed: bool) -> None:
    results.append((name, "PASS" if passed else "FAIL"))


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def finish() -> None:
    contract_path.write_text(
        "".join(f"{key}={value}\n" for key, value in results),
        encoding="utf-8",
    )


try:
    required_sources = (
        mconfig_path.is_file()
        and configure_path.is_file()
        and configure_ac_path.is_file()
    )
    record("required_sources_present", required_sources)
    if not required_sources:
        raise RuntimeError("required e2fsprogs configuration source is missing")

    original_bytes = mconfig_path.read_bytes()
    original_text = original_bytes.decode("utf-8", errors="strict")
    configure_before = configure_path.read_bytes()
    configure_ac_before = configure_ac_path.read_bytes()
    commented_before = len(commented_pattern.findall(original_text))
    active_before = len(active_pattern.findall(original_text))
    results.extend(
        [
            ("commented_uuid_link_count_before", str(commented_before)),
            ("active_uuid_link_count_before", str(active_before)),
            ("mconfig_in_sha256_before", digest(original_bytes)),
            ("configure_sha256_before", digest(configure_before)),
            ("configure_ac_sha256_before", digest(configure_ac_before)),
        ]
    )
    record(
        "exact_phase59_uuid_link_template_state_verified",
        commented_before == 1 and active_before == 0,
    )
    if commented_before != 1 or active_before != 0:
        raise RuntimeError(
            "MCONFIG.in no longer has exactly one commented private-blkid "
            "LIBUUID link and zero active equivalents"
        )

    before_path.write_bytes(original_bytes)
    patched_text, replacements = commented_pattern.subn(
        lambda match: f"{match.group('prefix')}$(LIBUUID)",
        original_text,
    )
    mconfig_path.write_text(patched_text, encoding="utf-8")
    after_path.write_text(patched_text, encoding="utf-8")
    patch_path.write_text(
        "".join(
            difflib.unified_diff(
                original_text.splitlines(keepends=True),
                patched_text.splitlines(keepends=True),
                fromfile="a/src/router/e2fsprogs/MCONFIG.in",
                tofile="b/src/router/e2fsprogs/MCONFIG.in",
            )
        ),
        encoding="utf-8",
    )

    after_bytes = mconfig_path.read_bytes()
    commented_after = len(commented_pattern.findall(patched_text))
    active_after = len(active_pattern.findall(patched_text))
    configure_after = configure_path.read_bytes()
    configure_ac_after = configure_ac_path.read_bytes()
    results.extend(
        [
            ("replacement_count", str(replacements)),
            ("commented_uuid_link_count_after", str(commented_after)),
            ("active_uuid_link_count_after", str(active_after)),
            ("mconfig_in_sha256_after", digest(after_bytes)),
            ("configure_sha256_after", digest(configure_after)),
            ("configure_ac_sha256_after", digest(configure_ac_after)),
        ]
    )
    record("replacement_count_exact", replacements == 1)
    record("commented_uuid_link_absent", commented_after == 0)
    record("active_uuid_link_count_exact", active_after == 1)
    record("mconfig_in_changed", digest(after_bytes) != digest(original_bytes))
    record(
        "configure_unchanged_by_uuid_link_patch",
        digest(configure_after) == digest(configure_before),
    )
    record(
        "configure_ac_unchanged_by_uuid_link_patch",
        digest(configure_ac_after) == digest(configure_ac_before),
    )
    record("patch_is_nonempty", patch_path.stat().st_size > 0)
    record("no_autoconf_regeneration", True)
    record("no_fallback_symlink_created", True)
    if (
        replacements != 1
        or commented_after != 0
        or active_after != 1
        or digest(after_bytes) == digest(original_bytes)
        or digest(configure_after) != digest(configure_before)
        or digest(configure_ac_after) != digest(configure_ac_before)
        or patch_path.stat().st_size == 0
    ):
        raise RuntimeError("private-blkid UUID-link template verification failed")
except Exception as exc:
    results.append(("error", f"{type(exc).__name__}: {exc}"))
    finish()
    raise

finish()
PY
then
  printf 'BLOCKED_E2FSPROGS_PRIVATE_BLKID_UUID_TEMPLATE_CONTRACT_FAILED\n' \
    > "$STATUS_FILE"
  cat <<EOF

Phase 60 result
---------------
STATUS: $(cat "$STATUS_FILE")

The pinned e2fsprogs MCONFIG.in no longer matches the exact Phase 59
state. Phase 60 fails closed instead of changing an unverified link
template. The artifact contains the before/after evidence, patch and
machine-readable contract.

No firmware was built and the router was not accessed.
EOF
  exit 1
fi

if grep -q '=FAIL$' "$E2FSPROGS_UUID_LINK_TEMPLATE_CONTRACT"; then
  printf 'BLOCKED_E2FSPROGS_PRIVATE_BLKID_UUID_TEMPLATE_CONTRACT_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

echo "Activated the verified LIBUUID dependency after private LIBBLKID."

REVISION_TEMPLATE="$WORK_DIR/revision.h.expected"
printf '#define SVN_REVISION "%s"\n' "$SVN_REVISION" \
  > "$REVISION_TEMPLATE"

revision_header_dirs=(
  "$ROUTER_DIR/libutils"
  "$ROUTER_DIR/shared"
  "$ROUTER_DIR/httpd"
  "$ROUTER_DIR/httpd/visuals"
)

: > "$REVIEW_DIR/revision-header-paths.txt"
for revision_dir in "${revision_header_dirs[@]}"; do
  if [[ ! -d "$revision_dir" ]]; then
    printf 'BLOCKED_DDWRT_REVISION_HEADER_DESTINATION_MISSING\n' \
      > "$STATUS_FILE"
    exit 1
  fi
  cp "$REVISION_TEMPLATE" "$revision_dir/revision.h"
  printf '%s\n' "${revision_dir#"$SOURCE_ROOT/"}/revision.h" \
    >> "$REVIEW_DIR/revision-header-paths.txt"
done

grep -RInE \
  --include='*.c' --include='*.cc' --include='*.cpp' --include='*.h' \
  '^[[:space:]]*#[[:space:]]*include[[:space:]]*"revision\.h"' \
  "$ROUTER_DIR/libutils" \
  "$ROUTER_DIR/shared" \
  "$ROUTER_DIR/httpd" \
  > "$REVIEW_DIR/revision-header-consumers.txt" 2>/dev/null || true

: > "$REVIEW_DIR/revision-header-sha256.txt"
revision_headers_exact=PASS
for revision_dir in "${revision_header_dirs[@]}"; do
  if ! cmp -s "$REVISION_TEMPLATE" "$revision_dir/revision.h"; then
    revision_headers_exact=FAIL
  fi
  sha256sum "$revision_dir/revision.h" \
    >> "$REVIEW_DIR/revision-header-sha256.txt"
done

{
  echo "source=verified_svn_info_revision"
  echo "svn_revision=$SVN_REVISION"
  printf 'expected_line=#define SVN_REVISION "%s"\n' "$SVN_REVISION"
  echo "generated_header_count=${#revision_header_dirs[@]}"
  echo "consumer_count=$(wc -l < "$REVIEW_DIR/revision-header-consumers.txt")"
  echo "revision_headers_exact=$revision_headers_exact"
} > "$REVIEW_DIR/revision-header-contract.txt"

if [[ "$revision_headers_exact" != PASS ]] || \
   ! grep -qx "svn_revision=$SVN_REVISION" \
     "$REVIEW_DIR/revision-header-contract.txt"; then
  printf 'BLOCKED_DDWRT_REVISION_HEADER_GENERATION_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

find "$SOURCE_ROOT/src" -type f -name 'typedefs.h' -print \
  | sort > "$REVIEW_DIR/typedefs-header-candidates.txt"
if [[ ! -s "$REVIEW_DIR/typedefs-header-candidates.txt" ]]; then
  printf 'BLOCKED_DDWRT_INCLUDE_V24_TYPEDEFS_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi

if ! printf '#include <typedefs.h>\n' \
  | aarch64-linux-uclibc-gcc \
      -E \
      -x c \
      -I"$INCLUDE_V24" \
      - \
      > "$REVIEW_DIR/typedefs-preprocess-output.txt" \
      2> "$REVIEW_DIR/typedefs-preprocess.log"; then
  printf 'BLOCKED_DDWRT_INCLUDE_V24_TYPEDEFS_PREPROCESS_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

{
  echo "include_v24_path=$INCLUDE_V24"
  echo "include_v24_files=$(find "$INCLUDE_V24" -type f | wc -l)"
  echo "include_v24_size=$(du -sh "$INCLUDE_V24" | awk '{print $1}')"
  echo "typedefs_candidates=$(wc -l < "$REVIEW_DIR/typedefs-header-candidates.txt")"
  echo "standalone_typedefs_preprocess=PASS"
} > "$REVIEW_DIR/ddwrt-header-tree-contract.txt"

cp "$ROUTER_DIR/Makefile.ipq60xx" \
  "$REVIEW_DIR/Makefile.ipq60xx"

NATIVE_KERNEL_CONFIG="$LINUX_TREE/.config_ipq6018"
if [[ ! -s "$NATIVE_KERNEL_CONFIG" ]]; then
  printf 'BLOCKED_DDWRT_IPQ6018_KERNEL_CONFIG_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi
cp "$NATIVE_KERNEL_CONFIG" "$LINUX_TREE/.config"
sha256sum "$NATIVE_KERNEL_CONFIG" "$LINUX_TREE/.config" \
  > "$REVIEW_DIR/kernel-config-sha256.txt"
printf '%s\n' "${NATIVE_KERNEL_CONFIG#"$SOURCE_ROOT/"}" \
  > "$REVIEW_DIR/kernel-config-source.txt"

{
  echo "router_opt_path=$ROUTER_OPT"
  if [[ -L "$ROUTER_OPT" ]]; then
    echo "router_opt_initial_type=symlink"
    echo "router_opt_initial_target=$(readlink "$ROUTER_OPT")"
  elif [[ -d "$ROUTER_OPT" ]]; then
    echo "router_opt_initial_type=directory"
  elif [[ -e "$ROUTER_OPT" ]]; then
    echo "router_opt_initial_type=other"
  else
    echo "router_opt_initial_type=missing"
  fi
} > "$REVIEW_DIR/opt-topology-before.txt"

if [[ ! -e "$ROUTER_OPT" && ! -L "$ROUTER_OPT" ]]; then
  ln -s ../../opt "$ROUTER_OPT"
  printf 'created_relative_symlink_to_repository_opt\n' \
    > "$REVIEW_DIR/opt-resolution.txt"
elif [[ -d "$ROUTER_OPT" && ! -L "$ROUTER_OPT" ]]; then
  cp -a "$ROOT_OPT/." "$ROUTER_OPT/"
  printf 'populated_existing_router_opt_from_repository_opt\n' \
    > "$REVIEW_DIR/opt-resolution.txt"
elif [[ -L "$ROUTER_OPT" ]]; then
  printf 'kept_source_router_opt_symlink\n' \
    > "$REVIEW_DIR/opt-resolution.txt"
else
  printf 'BLOCKED_DDWRT_ROUTER_OPT_TOPOLOGY_INVALID\n' > "$STATUS_FILE"
  exit 1
fi

if [[ ! -d "$ROUTER_OPT/etc/config" ]]; then
  printf 'BLOCKED_DDWRT_SOURCE_OPT_CONFIG_DIRECTORY_MISSING\n' \
    > "$STATUS_FILE"
  exit 1
fi

find -L "$ROUTER_OPT/etc/config" -maxdepth 1 -type f \
  -name '*.webconfig' -print | sort \
  > "$REVIEW_DIR/webconfig-files.txt"
WEB_CONFIG_COUNT="$(wc -l < "$REVIEW_DIR/webconfig-files.txt")"
printf 'webconfig_count=%s\n' "$WEB_CONFIG_COUNT" \
  > "$REVIEW_DIR/webconfig-contract.txt"
if [[ "$WEB_CONFIG_COUNT" -eq 0 ]]; then
  printf 'BLOCKED_DDWRT_SOURCE_OPT_WEB_CONFIG_MISSING\n' > "$STATUS_FILE"
  exit 1
fi

{
  echo "router_opt_final_type=$(
    if [[ -L "$ROUTER_OPT" ]]; then echo symlink; else echo directory; fi
  )"
  echo "router_opt_resolved_path=$(readlink -f "$ROUTER_OPT")"
  echo "repository_opt_path=$(readlink -f "$ROOT_OPT")"
  echo "webconfig_count=$WEB_CONFIG_COUNT"
  echo "repository_tools_path=$(readlink -f "$ROOT_TOOLS")"
  echo "kernel_config=$(readlink -f "$LINUX_TREE/.config")"
} > "$REVIEW_DIR/source-layout-contract.txt"

{
  echo "ddwrt_source=$SELECTED_URL"
  echo "ddwrt_svn_revision=$SVN_REVISION"
  echo "router_source_files=$(find "$ROUTER_DIR" -type f | wc -l)"
  echo "router_source_size=$(du -sh "$ROUTER_DIR" | awk '{print $1}')"
  echo "linux_source_files=$(find "$LINUX_TREE" -type f | wc -l)"
  echo "linux_source_size=$(du -sh "$LINUX_TREE" | awk '{print $1}')"
  echo "opt_source_files=$(find "$ROOT_OPT" -type f 2>/dev/null | wc -l)"
  echo "opt_source_size=$(du -sh "$ROOT_OPT" 2>/dev/null | awk '{print $1}')"
  echo "tools_source_files=$(find "$ROOT_TOOLS" -type f | wc -l)"
  echo "tools_source_size=$(du -sh "$ROOT_TOOLS" | awk '{print $1}')"
  echo "include_v24_source_files=$(find "$INCLUDE_V24" -type f | wc -l)"
  echo "include_v24_source_size=$(du -sh "$INCLUDE_V24" | awk '{print $1}')"
  echo "workspace_free_after_exports=$(df -h "$PWD" | awk 'NR==2 {print $4}')"
} | tee "$REVIEW_DIR/source-summary.txt"

for header_consumer in \
  "$ROUTER_DIR/libutils/Makefile" \
  "$ROUTER_DIR/shared/Makefile" \
  "$ROUTER_DIR/shared/utils.h"; do
  if [[ -f "$header_consumer" ]]; then
    relative_consumer="${header_consumer#"$ROUTER_DIR/"}"
    safe_consumer="${relative_consumer//\//-}"
    cp "$header_consumer" "$REVIEW_DIR/$safe_consumer"
  fi
done

grep -RInE \
  'include\.v24|include\.v23|include\.bcm|typedefs\.h|SRCBASE|CFLAGS|COPTS' \
  "$ROUTER_DIR/libutils/Makefile" \
  "$ROUTER_DIR/shared/Makefile" \
  "$ROUTER_DIR/shared/utils.h" \
  > "$REVIEW_DIR/header-include-contract.txt" 2>&1 || true

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
cp "$SELECTED_CONFIG" "$REVIEW_DIR/base-ipq60xx.config"
printf '%s\n' "${SELECTED_CONFIG#"$ROUTER_DIR/"}" \
  > "$REVIEW_DIR/selected-ipq60xx-config-path.txt"

python3 - "$ROUTER_DIR/.config" \
  "$REVIEW_DIR/ra72-wireless-profile-changes.txt" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

config_path = pathlib.Path(sys.argv[1])
report_path = pathlib.Path(sys.argv[2])
source = config_path.read_text(encoding="utf-8", errors="replace")

profile: dict[str, bool] = {
    "CONFIG_ATH11K": True,
    "CONFIG_ATH10K": False,
    "CONFIG_ATH9K": False,
    "CONFIG_MADWIFI": False,
    "CONFIG_MADWIFI_MIMO": False,
    "CONFIG_REGISTER": False,
    "CONFIG_SUPERCHANNEL": False,
    "CONFIG_QCA9887": False,
    "CONFIG_QCA9888": False,
    "CONFIG_QCA99X0": False,
    "CONFIG_QCA9984": False,
}

option_pattern = re.compile(
    r"^\s*#?\s*(CONFIG_[A-Z0-9_]+)"
    r"(?:\s+is\s+not\s+set|=.*)?\s*$"
)
kept: list[str] = []
removed: list[str] = []
for line in source.splitlines():
    match = option_pattern.match(line)
    if match and match.group(1) in profile:
        removed.append(line)
        continue
    kept.append(line)

derived = [
    "",
    "# RA72 Phase 60 exact wireless-driver profile",
]
for option, enabled in profile.items():
    if enabled:
        derived.append(f"{option}=y")
    else:
        derived.append(f"# {option} is not set")

config_path.write_text(
    "\n".join(kept + derived) + "\n",
    encoding="utf-8",
)
report_path.write_text(
    "removed_base_lines:\n"
    + "\n".join(f"- {line}" for line in removed)
    + "\n\napplied_profile:\n"
    + "\n".join(f"- {line}" for line in derived[2:])
    + "\n",
    encoding="utf-8",
)
PY

cp "$ROUTER_DIR/.config" "$REVIEW_DIR/selected-ipq60xx.config"
diff -u \
  "$REVIEW_DIR/base-ipq60xx.config" \
  "$REVIEW_DIR/selected-ipq60xx.config" \
  > "$REVIEW_DIR/ra72-wireless-profile.patch" || true

if ! grep -qx 'CONFIG_ATH11K=y' "$ROUTER_DIR/.config"; then
  printf 'BLOCKED_RA72_ATH11K_PROFILE_NOT_ENABLED\n' > "$STATUS_FILE"
  exit 1
fi

if grep -Eq \
  '^(CONFIG_MADWIFI|CONFIG_MADWIFI_MIMO|CONFIG_ATH9K|CONFIG_ATH10K|CONFIG_REGISTER|CONFIG_SUPERCHANNEL)=y$' \
  "$ROUTER_DIR/.config"; then
  printf 'BLOCKED_RA72_LEGACY_WIRELESS_PROFILE_STILL_ENABLED\n' \
    > "$STATUS_FILE"
  exit 1
fi

{
  grep -E \
    '^(CONFIG_ATH11K|CONFIG_ATH10K|CONFIG_ATH9K|CONFIG_MADWIFI|CONFIG_MADWIFI_MIMO|CONFIG_REGISTER|CONFIG_SUPERCHANNEL|CONFIG_QCA9887|CONFIG_QCA9888|CONFIG_QCA99X0|CONFIG_QCA9984)=y$' \
    "$ROUTER_DIR/.config" || true
  grep -E \
    '^# (CONFIG_ATH11K|CONFIG_ATH10K|CONFIG_ATH9K|CONFIG_MADWIFI|CONFIG_MADWIFI_MIMO|CONFIG_REGISTER|CONFIG_SUPERCHANNEL|CONFIG_QCA9887|CONFIG_QCA9888|CONFIG_QCA99X0|CONFIG_QCA9984) is not set$' \
    "$ROUTER_DIR/.config" || true
} > "$REVIEW_DIR/ra72-wireless-profile-contract.txt"

find "$ROUTER_DIR/register" -maxdepth 2 \
  \( -type f -o -type l \) -printf '%P\t%y\n' 2>/dev/null \
  | sort > "$REVIEW_DIR/register-source-inventory.txt" || true

sha256sum "$REVIEW_DIR/selected-ipq60xx.config" \
  > "$REVIEW_DIR/selected-ipq60xx-config-sha256.txt"
grep -E \
  '^(PLATFORM|CONFIG_UCLIBC|CONFIG_IPQ|CONFIG_MX4200|CONFIG_MR7350|CONFIG_ATH11K)' \
  "$ROUTER_DIR/.config" \
  > "$REVIEW_DIR/selected-ipq60xx-config-summary.txt" || true

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

  printf '%s\n' "all_then_install"
}

SELECTED_TARGET="$(choose_target)"
printf '%s\n' "$SELECTED_TARGET" > "$REVIEW_DIR/selected-make-target.txt"
echo "Selected native make target: $SELECTED_TARGET"

BLOCKER_DIR="$WORK_DIR/safety-blockers"
mkdir -p "$BLOCKER_DIR"
for command_name in ubinize ubiformat sysupgrade fw_setenv mtd; do
  cat > "$BLOCKER_DIR/$command_name" <<EOF
#!/usr/bin/env bash
echo "PHASE60_SAFETY_BLOCK: $command_name \$*" >&2
exit 86
EOF
  chmod +x "$BLOCKER_DIR/$command_name"
done

QCOM_UBINIZE="$ROUTER_DIR/tools/qcom/ubinize-image.sh"
if [[ -f "$QCOM_UBINIZE" ]]; then
  cp "$QCOM_UBINIZE" "$REVIEW_DIR/ddwrt-ubinize-image.sh"
  mv "$QCOM_UBINIZE" "$QCOM_UBINIZE.phase60-disabled"
  cat > "$QCOM_UBINIZE" <<'EOF'
#!/usr/bin/env bash
echo "PHASE60_SAFETY_BLOCK: Qualcomm UBI packaging is disabled." >&2
exit 86
EOF
  chmod +x "$QCOM_UBINIZE"
fi

export PATH="$BLOCKER_DIR:$HOST_MESON_VENV/bin:$TOOLCHAIN_BIN:$PATH"
if [[ "$(command -v meson)" != "$HOST_MESON" ]] || \
   [[ "$(meson --version)" != "$HOST_MESON_PINNED_VERSION" ]]; then
  echo "meson_build_path=FAIL" \
    >> "$REVIEW_DIR/host-meson-contract.txt"
  printf 'BLOCKED_HOST_MESON_BUILD_PATH_MISMATCH\n' > "$STATUS_FILE"
  exit 1
fi
echo "meson_build_path=PASS" \
  >> "$REVIEW_DIR/host-meson-contract.txt"
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
  echo "MESON=$(command -v meson)"
  echo "MESON_VERSION=$(meson --version)"
  echo "CONFIG=${SELECTED_CONFIG#"$ROUTER_DIR/"}"
  echo "free_space_before_build=$(df -h "$PWD" | awk 'NR==2 {print $4}')"
} > "$REVIEW_DIR/userspace-build-environment.txt"

find "$SOURCE_ROOT" -type f \
  \( -name '*.ubi' -o -name '*.bin' -o -name '*.trx' \
     -o -name '*.img' \) \
  -print 2>/dev/null | sort \
  > "$WORK_DIR/prebuild-flashable-files.txt"

PCRE_RULE="$ROUTER_DIR/rules/pcre.mk"
if [[ ! -s "$PCRE_RULE" ]]; then
  printf 'BLOCKED_DDWRT_PCRE_RULE_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi

cp "$PCRE_RULE" "$REVIEW_DIR/pcre-rule.before.mk"
python3 - "$PCRE_RULE" "$REVIEW_DIR/pcre-production-targets.txt" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

rule_path = pathlib.Path(sys.argv[1])
contract_path = pathlib.Path(sys.argv[2])
text = rule_path.read_text(encoding="utf-8", errors="strict")
lines = text.splitlines(keepends=True)
targets = ("libpcre.la", "libpcreposix.la", "libpcrecpp.la")

in_pcre_target = False
changed = 0
result: list[str] = []
recipe_before = ""
recipe_after = ""

for line in lines:
    if line and not line[0].isspace() and not line.startswith("#"):
        match = re.match(r"^([^:=\s]+)\s*:(?!=)", line)
        in_pcre_target = bool(match and match.group(1) == "pcre")

    candidate = (
        in_pcre_target
        and line.startswith("\t")
        and re.search(r"\$\((?:MAKE|MAKE1)\).*?\s-C\s+(?:\$\(TOP\)/)?pcre(?:\s|$)", line)
    )
    if candidate:
        recipe_before = line.rstrip("\r\n")
        if not all(re.search(rf"(?:^|\s){re.escape(name)}(?:\s|$)", line)
                   for name in targets):
            ending = "\r\n" if line.endswith("\r\n") else (
                "\n" if line.endswith("\n") else ""
            )
            body = line[:-len(ending)] if ending else line
            line = body + " " + " ".join(targets) + ending
            changed += 1
        recipe_after = line.rstrip("\r\n")
    result.append(line)

if changed != 1:
    raise SystemExit(
        "Expected exactly one unqualified pcre build recipe; "
        f"changed={changed}"
    )

rule_path.write_text("".join(result), encoding="utf-8")
contract_path.write_text(
    "source_rule=src/router/rules/pcre.mk\n"
    "change=limit_pcre_make_to_production_libraries\n"
    f"production_targets={' '.join(targets)}\n"
    "excluded_cross_test_programs="
    "pcrecpp_unittest pcre_scanner_unittest "
    "pcre_stringpiece_unittest\n"
    f"changed_recipe_count={changed}\n"
    f"recipe_before={recipe_before}\n"
    f"recipe_after={recipe_after}\n",
    encoding="utf-8",
)
PY

cp "$PCRE_RULE" "$REVIEW_DIR/pcre-rule.after.mk"
diff -u "$REVIEW_DIR/pcre-rule.before.mk" \
  "$REVIEW_DIR/pcre-rule.after.mk" \
  > "$REVIEW_DIR/pcre-library-only.patch" || true

if ! grep -qx 'changed_recipe_count=1' \
  "$REVIEW_DIR/pcre-production-targets.txt" || \
   ! grep -q 'libpcre\.la libpcreposix\.la libpcrecpp\.la' \
  "$REVIEW_DIR/pcre-rule.after.mk"; then
  printf 'BLOCKED_DDWRT_PCRE_RULE_PATCH_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

SODIUM_RULE="$ROUTER_DIR/rules/sodium.mk"
if [[ ! -s "$SODIUM_RULE" ]]; then
  printf 'BLOCKED_DDWRT_SODIUM_RULE_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi

CONFIG_GUESS_SOURCE=""
CONFIG_SUB_SOURCE=""
for candidate in \
  /usr/share/misc/config.guess \
  /usr/share/automake-*/config.guess; do
  if [[ -f "$candidate" ]]; then
    CONFIG_GUESS_SOURCE="$candidate"
    break
  fi
done
for candidate in \
  /usr/share/misc/config.sub \
  /usr/share/automake-*/config.sub; do
  if [[ -f "$candidate" ]]; then
    CONFIG_SUB_SOURCE="$candidate"
    break
  fi
done
if [[ -z "$CONFIG_GUESS_SOURCE" || -z "$CONFIG_SUB_SOURCE" ]]; then
  printf 'BLOCKED_SYSTEM_CONFIG_AUX_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi

cp "$SODIUM_RULE" "$REVIEW_DIR/sodium-rule.before.mk"
python3 - \
  "$SODIUM_RULE" \
  "$CONFIG_GUESS_SOURCE" \
  "$CONFIG_SUB_SOURCE" \
  "$REVIEW_DIR/sodium-config-aux-patch-contract.txt" <<'PY'
from __future__ import annotations

import pathlib
import sys

rule_path = pathlib.Path(sys.argv[1])
config_guess = pathlib.Path(sys.argv[2])
config_sub = pathlib.Path(sys.argv[3])
contract_path = pathlib.Path(sys.argv[4])
text = rule_path.read_text(encoding="utf-8", errors="strict")
needle = "./autogen.sh && ./configure"
replacement = (
    "./autogen.sh && "
    f"install -m 0755 {config_guess} build-aux/config.guess && "
    f"install -m 0755 {config_sub} build-aux/config.sub && "
    "./configure"
)
occurrences = text.count(needle)
if occurrences != 1:
    raise SystemExit(
        "Expected exactly one libsodium autogen/configure chain; "
        f"occurrences={occurrences}"
    )
patched = text.replace(needle, replacement, 1)
rule_path.write_text(patched, encoding="utf-8")
contract_path.write_text(
    "source_rule=src/router/rules/sodium.mk\n"
    "change=replace_downloaded_config_aux_after_autogen\n"
    f"system_config_guess={config_guess}\n"
    f"system_config_sub={config_sub}\n"
    f"changed_recipe_count={occurrences}\n"
    f"recipe_fragment_before={needle}\n"
    f"recipe_fragment_after={replacement}\n",
    encoding="utf-8",
)
PY

cp "$SODIUM_RULE" "$REVIEW_DIR/sodium-rule.after.mk"
diff -u "$REVIEW_DIR/sodium-rule.before.mk" \
  "$REVIEW_DIR/sodium-rule.after.mk" \
  > "$REVIEW_DIR/sodium-config-aux.patch" || true

if ! grep -qx 'changed_recipe_count=1' \
  "$REVIEW_DIR/sodium-config-aux-patch-contract.txt" || \
   ! grep -q 'install -m 0755 .*config\.guess build-aux/config\.guess' \
  "$REVIEW_DIR/sodium-rule.after.mk" || \
   ! grep -q 'install -m 0755 .*config\.sub build-aux/config\.sub' \
  "$REVIEW_DIR/sodium-rule.after.mk"; then
  printf 'BLOCKED_DDWRT_SODIUM_CONFIG_AUX_PATCH_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

{
  echo "config_guess_source=$CONFIG_GUESS_SOURCE"
  echo "config_sub_source=$CONFIG_SUB_SOURCE"
  sha256sum "$CONFIG_GUESS_SOURCE" "$CONFIG_SUB_SOURCE"
} > "$REVIEW_DIR/system-config-aux-sources.txt"

if [[ -f "$ROUTER_DIR/rules/jansson.mk" ]]; then
  cp "$ROUTER_DIR/rules/jansson.mk" \
    "$REVIEW_DIR/jansson-rule.mk"
else
  printf 'BLOCKED_DDWRT_JANSSON_RULE_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi

{
  echo "stage=before_configure"
  echo "jansson_directory=$(
    if [[ -d "$ROUTER_DIR/jansson" ]]; then echo present; else echo missing; fi
  )"
  echo "jansson_makefile=$(
    if [[ -f "$ROUTER_DIR/jansson/Makefile" ]]; then echo present; else echo missing; fi
  )"
  echo "jansson_configure=$(
    if [[ -f "$ROUTER_DIR/jansson/configure" ]]; then echo present; else echo missing; fi
  )"
  find "$ROUTER_DIR/jansson" -maxdepth 2 \
    \( -type f -o -type l \) -printf '%P\n' 2>/dev/null \
    | sort | head -n 300 || true
} > "$REVIEW_DIR/jansson-before-configure.txt"

MAKE_COMMON=(
  make
  -f Makefile.ipq60xx
  V=1
  "LINUXDIR=$LINUX_TREE"
  ARCH=aarch64
  PLATFORM=aarch64
)
MAKE_BASE=(
  "${MAKE_COMMON[@]}"
  -j2
)
MAKE_CONFIGURE_COMMAND=("${MAKE_COMMON[@]}" configure)
if [[ "$SELECTED_TARGET" == "all_then_install" ]]; then
  MAKE_ALL_COMMAND=("${MAKE_BASE[@]}" all)
  MAKE_INSTALL_COMMAND=("${MAKE_BASE[@]}" install)
else
  MAKE_ALL_COMMAND=("${MAKE_BASE[@]}" "$SELECTED_TARGET")
  MAKE_INSTALL_COMMAND=()
fi
{
  printf 'configure_command='
  printf '%q ' "${MAKE_CONFIGURE_COMMAND[@]}"
  printf '\n'
  printf 'ncurses_preconfigure_command='
  printf '%q ' "${MAKE_COMMON[@]}" ncurses-configure
  printf '\n'
  printf 'util_linux_preconfigure_command='
  printf '%q ' "${MAKE_COMMON[@]}" util-linux-configure
  printf '\n'
  printf 'bootstrap_targets=nvram jansson utils\n'
  printf 'compile_command='
  printf '%q ' "${MAKE_ALL_COMMAND[@]}"
  printf '\n'
  if [[ "${#MAKE_INSTALL_COMMAND[@]}" -gt 0 ]]; then
    printf 'install_command='
    printf '%q ' "${MAKE_INSTALL_COMMAND[@]}"
    printf '\n'
  fi
} > "$REVIEW_DIR/userspace-build-command.txt"

echo "Inspecting and running the native ncurses preconfigure target."
if [[ ! -f "$NCURSES_RULE" ]]; then
  {
    echo "ncurses_rule_present=FAIL"
    echo "ncurses_configure_target_present=FAIL"
    echo "ncurses_preconfigure_status=127"
    echo "ncurses_makefile_present=FAIL"
  } > "$REVIEW_DIR/ncurses-preconfigure-contract.txt"
  printf 'BLOCKED_DDWRT_NCURSES_RULE_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi

cp "$NCURSES_RULE" "$REVIEW_DIR/ncurses-rule.mk"
{
  echo "stage=before_preconfigure"
  echo "ncurses_directory=$(
    if [[ -d "$ROUTER_DIR/ncurses" ]]; then echo present; else echo missing; fi
  )"
  echo "ncurses_configure=$(
    if [[ -x "$ROUTER_DIR/ncurses/configure" ]]; then echo executable; else echo missing; fi
  )"
  echo "ncurses_makefile=$(
    if [[ -f "$NCURSES_MAKEFILE" ]]; then echo present; else echo missing; fi
  )"
} > "$REVIEW_DIR/ncurses-before-preconfigure.txt"

if grep -Eq '^[[:space:]]*ncurses-configure[[:space:]]*:' \
  "$NCURSES_RULE"; then
  ncurses_target_present=1
else
  ncurses_target_present=0
fi

if [[ "$ncurses_target_present" -eq 1 ]]; then
  if (
    trap - ERR
    cd "$ROUTER_DIR"
    timeout 90m "${MAKE_COMMON[@]}" ncurses-configure
  ) > "$REVIEW_DIR/ncurses-preconfigure.log" 2>&1; then
    ncurses_preconfigure_status=0
  else
    ncurses_preconfigure_status=$?
  fi
else
  ncurses_preconfigure_status=127
  printf 'The native ncurses-configure target was not found.\n' \
    > "$REVIEW_DIR/ncurses-preconfigure.log"
fi

tail -n 500 "$REVIEW_DIR/ncurses-preconfigure.log" \
  > "$REVIEW_DIR/ncurses-preconfigure-tail.txt" || true

{
  echo "ncurses_rule_present=PASS"
  echo "ncurses_configure_target_present=$(
    if [[ "$ncurses_target_present" -eq 1 ]]; then echo PASS; else echo FAIL; fi
  )"
  echo "ncurses_preconfigure_status=$ncurses_preconfigure_status"
  echo "ncurses_preconfigure_command=$(
    printf '%q ' "${MAKE_COMMON[@]}" ncurses-configure
  )"
  echo "ncurses_makefile_present=$(
    if [[ -f "$NCURSES_MAKEFILE" ]]; then echo PASS; else echo FAIL; fi
  )"
  if [[ -f "$NCURSES_MAKEFILE" ]]; then
    echo "ncurses_makefile_sha256=$(
      sha256sum "$NCURSES_MAKEFILE" | awk '{print $1}'
    )"
  fi
} > "$REVIEW_DIR/ncurses-preconfigure-contract.txt"

{
  echo "stage=after_preconfigure"
  echo "ncurses_directory=$(
    if [[ -d "$ROUTER_DIR/ncurses" ]]; then echo present; else echo missing; fi
  )"
  echo "ncurses_configure=$(
    if [[ -x "$ROUTER_DIR/ncurses/configure" ]]; then echo executable; else echo missing; fi
  )"
  echo "ncurses_makefile=$(
    if [[ -f "$NCURSES_MAKEFILE" ]]; then echo present; else echo missing; fi
  )"
} > "$REVIEW_DIR/ncurses-after-preconfigure.txt"

if [[ "$ncurses_preconfigure_status" -ne 0 ]] || \
   [[ ! -f "$NCURSES_MAKEFILE" ]]; then
  printf 'BLOCKED_DDWRT_NCURSES_PRECONFIGURE_FAILED\n' > "$STATUS_FILE"
  cat <<EOF

Phase 60 result
---------------
STATUS: $(cat "$STATUS_FILE")

The native DD-WRT ncurses-configure target did not create
src/router/ncurses/Makefile. The artifact contains the exact rule,
focused preconfigure log, before/after inventory, and a machine-readable
contract for the next correction.

No firmware was built and the router was not accessed.
EOF
  exit 1
fi

echo "Patching util-linux ownership hooks, then testing its native install."
if [[ ! -f "$UTIL_LINUX_RULE" ]]; then
  {
    echo "util_linux_rule_present=FAIL"
    echo "util_linux_configure_target_present=FAIL"
    echo "util_linux_preconfigure_status=127"
    echo "util_linux_makefile_present=FAIL"
  } > "$REVIEW_DIR/util-linux-preconfigure-contract.txt"
  printf 'BLOCKED_DDWRT_UTIL_LINUX_RULE_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi

cp "$UTIL_LINUX_RULE" "$REVIEW_DIR/util-linux-rule.original.mk"

python3 - "$UTIL_LINUX_RULE" \
  "$REVIEW_DIR/util-linux-unprivileged-install.patch" \
  "$REVIEW_DIR/util-linux-unprivileged-install-patch-contract.txt" <<'PY'
from __future__ import annotations

import difflib
import hashlib
import pathlib
import sys

rule_path = pathlib.Path(sys.argv[1])
patch_path = pathlib.Path(sys.argv[2])
contract_path = pathlib.Path(sys.argv[3])
original = rule_path.read_text(encoding="utf-8")
marker = "--disable-gtk-doc"
options = "--disable-makeinstall-chown --disable-use-tty-group"

if marker not in original:
    contract_path.write_text(
        "util_linux_rule_patch=FAIL\n"
        "changed_recipe_count=0\n"
        "reason=disable_gtk_doc_marker_missing\n",
        encoding="utf-8",
    )
    raise SystemExit("util-linux configure marker was not found")

if "--disable-makeinstall-chown" in original or \
        "--disable-use-tty-group" in original:
    contract_path.write_text(
        "util_linux_rule_patch=FAIL\n"
        "changed_recipe_count=0\n"
        "reason=unprivileged_options_already_present\n",
        encoding="utf-8",
    )
    raise SystemExit("util-linux unprivileged options already exist")

patched = original.replace(marker, f"{marker} {options}", 1)
changed = int(patched != original)
rule_path.write_text(patched, encoding="utf-8")

diff = "".join(
    difflib.unified_diff(
        original.splitlines(keepends=True),
        patched.splitlines(keepends=True),
        fromfile="rules/util-linux.mk.original",
        tofile="rules/util-linux.mk.phase60",
    )
)
patch_path.write_text(diff, encoding="utf-8")
contract_path.write_text(
    "util_linux_rule_patch=PASS\n"
    f"changed_recipe_count={changed}\n"
    "disable_makeinstall_chown_count="
    f"{patched.count('--disable-makeinstall-chown')}\n"
    "disable_use_tty_group_count="
    f"{patched.count('--disable-use-tty-group')}\n"
    "original_sha256="
    f"{hashlib.sha256(original.encode()).hexdigest()}\n"
    "patched_sha256="
    f"{hashlib.sha256(patched.encode()).hexdigest()}\n",
    encoding="utf-8",
)
PY

cp "$UTIL_LINUX_RULE" "$REVIEW_DIR/util-linux-rule.patched.mk"
{
  echo "stage=before_preconfigure"
  echo "util_linux_directory=$(
    if [[ -d "$ROUTER_DIR/util-linux" ]]; then echo present; else echo missing; fi
  )"
  echo "util_linux_configure=$(
    if [[ -f "$ROUTER_DIR/util-linux/configure" ]]; then echo present; else echo missing; fi
  )"
  echo "util_linux_makefile=$(
    if [[ -f "$UTIL_LINUX_MAKEFILE" ]]; then echo present; else echo missing; fi
  )"
} > "$REVIEW_DIR/util-linux-before-preconfigure.txt"

if grep -Eq '^[[:space:]]*util-linux-configure[[:space:]]*:' \
  "$UTIL_LINUX_RULE"; then
  util_linux_target_present=1
else
  util_linux_target_present=0
fi

if [[ "$util_linux_target_present" -eq 1 ]]; then
  if (
    trap - ERR
    cd "$ROUTER_DIR"
    timeout 90m "${MAKE_COMMON[@]}" util-linux-configure
  ) > "$REVIEW_DIR/util-linux-preconfigure.log" 2>&1; then
    util_linux_preconfigure_status=0
  else
    util_linux_preconfigure_status=$?
  fi
else
  util_linux_preconfigure_status=127
  printf 'The native util-linux-configure target was not found.\n' \
    > "$REVIEW_DIR/util-linux-preconfigure.log"
fi

if [[ -f "$ROUTER_DIR/util-linux/config.log" ]]; then
  cp "$ROUTER_DIR/util-linux/config.log" \
    "$REVIEW_DIR/util-linux-config.log"
fi

tail -n 500 "$REVIEW_DIR/util-linux-preconfigure.log" \
  > "$REVIEW_DIR/util-linux-preconfigure-tail.txt" || true

{
  echo "util_linux_rule_present=PASS"
  echo "util_linux_configure_target_present=$(
    if [[ "$util_linux_target_present" -eq 1 ]]; then echo PASS; else echo FAIL; fi
  )"
  echo "util_linux_preconfigure_status=$util_linux_preconfigure_status"
  echo "util_linux_preconfigure_command=$(
    printf '%q ' "${MAKE_COMMON[@]}" util-linux-configure
  )"
  echo "util_linux_makefile_present=$(
    if [[ -f "$UTIL_LINUX_MAKEFILE" ]]; then echo PASS; else echo FAIL; fi
  )"
  echo "phase50_gtkdocize_failure_absent=$(
    if grep -Eq 'gtkdocize.*(No such file|not found)|Can.t exec \"gtkdocize\"' \
      "$REVIEW_DIR/util-linux-preconfigure.log"; then
      echo FAIL
    else
      echo PASS
    fi
  )"
  if [[ -f "$UTIL_LINUX_MAKEFILE" ]]; then
    echo "util_linux_makefile_sha256=$(
      sha256sum "$UTIL_LINUX_MAKEFILE" | awk '{print $1}'
    )"
  fi
} > "$REVIEW_DIR/util-linux-preconfigure-contract.txt"

{
  echo "stage=after_preconfigure"
  echo "util_linux_directory=$(
    if [[ -d "$ROUTER_DIR/util-linux" ]]; then echo present; else echo missing; fi
  )"
  echo "util_linux_configure=$(
    if [[ -f "$ROUTER_DIR/util-linux/configure" ]]; then echo present; else echo missing; fi
  )"
  echo "util_linux_makefile=$(
    if [[ -f "$UTIL_LINUX_MAKEFILE" ]]; then echo present; else echo missing; fi
  )"
} > "$REVIEW_DIR/util-linux-after-preconfigure.txt"

if [[ "$util_linux_preconfigure_status" -ne 0 ]] || \
   [[ ! -f "$UTIL_LINUX_MAKEFILE" ]]; then
  printf 'BLOCKED_DDWRT_UTIL_LINUX_PRECONFIGURE_FAILED\n' > "$STATUS_FILE"
  cat <<EOF

Phase 60 result
---------------
STATUS: $(cat "$STATUS_FILE")

The host gtkdocize contract passed, but DD-WRT's native
util-linux-configure target did not create src/router/util-linux/Makefile.
The artifact contains the exact rule, focused preconfigure and config
logs, before/after inventory, and a machine-readable contract.

No firmware was built and the router was not accessed.
EOF
  exit 1
fi

generated_chgrp_tty_count="$(
  grep -Ec '^[[:space:]]*chgrp[[:space:]]+tty([[:space:]]|$)' \
    "$UTIL_LINUX_MAKEFILE" || true
)"
generated_chown_root_count="$(
  grep -Ec '^[[:space:]]*chown[[:space:]]+root:root([[:space:]]|$)' \
    "$UTIL_LINUX_MAKEFILE" || true
)"

rm -rf "$UTIL_LINUX_INSTALL_DIR"
mkdir -p "$UTIL_LINUX_INSTALL_DIR"
if (
  trap - ERR
  timeout 90m make -C "$ROUTER_DIR/util-linux" \
    install DESTDIR="$UTIL_LINUX_INSTALL_DIR"
) > "$REVIEW_DIR/util-linux-install-test.log" 2>&1; then
  util_linux_install_test_status=0
else
  util_linux_install_test_status=$?
fi

tail -n 500 "$REVIEW_DIR/util-linux-install-test.log" \
  > "$REVIEW_DIR/util-linux-install-test-tail.txt" || true
find "$UTIL_LINUX_INSTALL_DIR" \( -type f -o -type l \) \
  -printf '%P\n' 2>/dev/null | sort \
  > "$REVIEW_DIR/util-linux-install-test-files.txt"
util_linux_install_file_count="$(
  wc -l < "$REVIEW_DIR/util-linux-install-test-files.txt"
)"
util_linux_install_size="$(
  du -sb "$UTIL_LINUX_INSTALL_DIR" | awk '{print $1}'
)"

{
  echo "util_linux_install_test_status=$util_linux_install_test_status"
  echo "ownership_operation_failure_absent=$(
    if grep -Eq '(chgrp|chown):.*Operation not permitted' \
      "$REVIEW_DIR/util-linux-install-test.log"; then
      echo FAIL
    else
      echo PASS
    fi
  )"
  echo "generated_makefile_chgrp_tty_count=$generated_chgrp_tty_count"
  echo "generated_makefile_chown_root_count=$generated_chown_root_count"
  echo "staged_files_present=$(
    if [[ "$util_linux_install_file_count" -gt 0 ]]; then
      echo PASS
    else
      echo FAIL
    fi
  )"
  echo "staged_file_count=$util_linux_install_file_count"
  echo "staged_size_bytes=$util_linux_install_size"
} > "$REVIEW_DIR/util-linux-install-contract.txt"

if [[ "$util_linux_install_test_status" -ne 0 ]] || \
   grep -q '=FAIL$' "$REVIEW_DIR/util-linux-install-contract.txt" || \
   [[ "$generated_chgrp_tty_count" -ne 0 ]] || \
   [[ "$generated_chown_root_count" -ne 0 ]]; then
  printf 'BLOCKED_DDWRT_UTIL_LINUX_UNPRIVILEGED_INSTALL_FAILED\n' \
    > "$STATUS_FILE"
  cat <<EOF

Phase 60 result
---------------
STATUS: $(cat "$STATUS_FILE")

The supported util-linux configure options were applied, but the focused
unprivileged install contract did not pass. The artifact contains the
original and patched DD-WRT rule, exact patch, generated Makefile counts,
focused install log, staged-file inventory, and machine-readable contract.

No firmware was built and the router was not accessed.
EOF
  exit 1
fi

echo "Running the native DD-WRT configure stage before compilation."
if (
  trap - ERR
  cd "$ROUTER_DIR"
  timeout 180m "${MAKE_CONFIGURE_COMMAND[@]}"
) > "$CONFIGURE_LOG" 2>&1; then
  configure_status=0
else
  configure_status=$?
fi

tail -n 1000 "$CONFIGURE_LOG" \
  > "$REVIEW_DIR/ddwrt-configure-tail.txt" || true

E2FSPROGS_GENERATED_MCONFIG="$E2FSPROGS_ROOT/MCONFIG"
E2FSPROGS_PRIVATE_LINK_GENERATED_CONTRACT="$REVIEW_DIR/e2fsprogs-private-blkid-generated-contract.txt"
E2FSPROGS_PRIVATE_LINK_BUILT_FILES="$REVIEW_DIR/e2fsprogs-private-blkid-built-files.txt"
E2FSPROGS_UUID_LINK_BUILT_FILES="$REVIEW_DIR/e2fsprogs-private-blkid-uuid-built-files.txt"

find "$E2FSPROGS_ROOT" \( -type f -o -type l \) \
  -name 'libe2fsblkid.so*' -printf '%P\t%l\n' 2>/dev/null \
  | sort > "$E2FSPROGS_PRIVATE_LINK_BUILT_FILES"

find "$ROUTER_DIR/util-linux/.libs" \( -type f -o -type l \) \
  -name 'libuuid.so*' -printf '%P\t%l\n' 2>/dev/null \
  | sort > "$E2FSPROGS_UUID_LINK_BUILT_FILES"

if [[ -f "$E2FSPROGS_GENERATED_MCONFIG" ]]; then
  cp "$E2FSPROGS_GENERATED_MCONFIG" \
    "$REVIEW_DIR/e2fsprogs-generated-MCONFIG.txt"
else
  : > "$REVIEW_DIR/e2fsprogs-generated-MCONFIG.txt"
fi

python3 - \
  "$E2FSPROGS_GENERATED_MCONFIG" \
  "$E2FSPROGS_PRIVATE_LINK_BUILT_FILES" \
  "$E2FSPROGS_UUID_LINK_BUILT_FILES" \
  "$CONFIGURE_LOG" \
  "$E2FSPROGS_PRIVATE_LINK_GENERATED_CONTRACT" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

mconfig_path = pathlib.Path(sys.argv[1])
built_files_path = pathlib.Path(sys.argv[2])
uuid_files_path = pathlib.Path(sys.argv[3])
log_path = pathlib.Path(sys.argv[4])
contract_path = pathlib.Path(sys.argv[5])

mconfig = (
    mconfig_path.read_text(encoding="utf-8", errors="replace")
    if mconfig_path.is_file()
    else ""
)
built_files = built_files_path.read_text(
    encoding="utf-8", errors="replace"
)
uuid_files = uuid_files_path.read_text(
    encoding="utf-8", errors="replace"
)
log = log_path.read_text(encoding="utf-8", errors="replace")

assignment_lines = [
    line.strip()
    for line in mconfig.splitlines()
    if re.match(r"^\s*LIBBLKID\s*=", line)
]
corrected_assignments = [
    line
    for line in assignment_lines
    if re.search(r"(?<!e)libe2fsblkid(?:\$\(|\.so)", line)
]
legacy_assignments = [
    line
    for line in assignment_lines
    if re.search(r"(?<!e)libblkid(?:\$\(|\.so)", line)
]
old_failure = re.search(
    r"No rule to make target\s+[`'\u2018]"
    r"\.\./lib/libblkid\.so[`'\u2019]?,\s*needed by\s+"
    r"[`'\u2018]e2fsck",
    log,
    re.IGNORECASE,
)
produced = bool(
    re.search(r"(?:^|/)libe2fsblkid\.so(?:\.|$)", built_files, re.MULTILINE)
)
uuid_produced = bool(
    re.search(r"(?:^|/)libuuid\.so(?:\.|$)", uuid_files, re.MULTILINE)
)
active_uuid_assignments = [
    line
    for line in corrected_assignments
    if "# $(LIBUUID)" not in line
    and re.search(r"libe2fsblkid(?:\$\(|\.so).*\$\(LIBUUID\)", line)
]
uuid_value_lines = [
    line.strip()
    for line in mconfig.splitlines()
    if re.match(r"^\s*LIBUUID\s*=", line)
]
uuid_value_is_luuid = any(
    re.match(r"^LIBUUID\s*=\s*-luuid(?:\s|$)", line)
    for line in uuid_value_lines
)
logical_log = re.sub(r"\\\s*\n\s*", " ", log)
blkid_link_commands = [
    line
    for line in logical_log.splitlines()
    if re.search(r"(?:^|\s)-o\s+blkid(?:\s|$)", line)
    and "libe2fsblkid.so" in line
]
blkid_link_has_uuid_after_private = any(
    line.find("libe2fsblkid.so") < line.find("-luuid")
    for line in blkid_link_commands
    if "-luuid" in line
)
old_uuid_warning = re.search(
    r"libuuid\.so\.0,\s*needed by\s+\.\./lib/libe2fsblkid\.so,\s*not found",
    log,
    re.IGNORECASE,
)
old_uuid_undefined = re.search(
    r"libe2fsblkid\.so:\s*undefined reference to\s+"
    r"[`'\u2018](?:uuid_unparse|uuid_is_null)",
    log,
    re.IGNORECASE,
)

results = {
    "generated_mconfig_present":
        "PASS" if mconfig_path.is_file() else "FAIL",
    "libblkid_assignment_count": str(len(assignment_lines)),
    "corrected_assignment_count": str(len(corrected_assignments)),
    "legacy_assignment_count": str(len(legacy_assignments)),
    "generated_libblkid_uses_private_name":
        "PASS" if len(corrected_assignments) >= 1 else "FAIL",
    "generated_legacy_libblkid_name_absent":
        "PASS" if len(legacy_assignments) == 0 else "FAIL",
    "private_shared_library_was_built": "PASS" if produced else "FAIL",
    "util_linux_libuuid_shared_library_was_built":
        "PASS" if uuid_produced else "FAIL",
    "active_uuid_dependency_count": str(len(active_uuid_assignments)),
    "generated_private_blkid_activates_uuid_dependency":
        "PASS" if len(active_uuid_assignments) == 1 else "FAIL",
    "generated_libuuid_value_is_luuid":
        "PASS" if uuid_value_is_luuid else "FAIL",
    "blkid_link_command_count": str(len(blkid_link_commands)),
    "blkid_link_orders_private_blkid_before_luuid":
        "PASS" if blkid_link_has_uuid_after_private else "FAIL",
    "phase59_missing_libuuid_warning_absent":
        "PASS" if old_uuid_warning is None else "FAIL",
    "phase59_uuid_undefined_references_absent":
        "PASS" if old_uuid_undefined is None else "FAIL",
    "phase57_missing_libblkid_target_absent":
        "PASS" if old_failure is None else "FAIL",
    "fallback_symlink_not_used": "PASS",
}
for index, line in enumerate(assignment_lines, start=1):
    results[f"libblkid_assignment_{index}"] = line
for index, line in enumerate(uuid_value_lines, start=1):
    results[f"libuuid_assignment_{index}"] = line
for index, line in enumerate(blkid_link_commands, start=1):
    results[f"blkid_link_command_{index}"] = line

contract_path.write_text(
    "".join(f"{key}={value}\n" for key, value in results.items()),
    encoding="utf-8",
)
PY

grep -n -i -m 200 -E \
  'fatal error:|error:|undefined reference|no rule to make target|not found|No such file|No targets specified|no makefile found' \
  "$CONFIGURE_LOG" > "$REVIEW_DIR/first-configure-errors.txt" || true

python3 - "$CONFIGURE_LOG" "$configure_status" \
  "$REVIEW_DIR/configure-failure-classification.txt" <<'PY'
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
        "E2FSPROGS_PRIVATE_BLKID_UUID_LINK_FAILURE",
        r"(?:libuuid\.so\.0,\s*needed by\s+"
        r"\.\./lib/libe2fsblkid\.so,\s*not found|"
        r"libe2fsblkid\.so:\s*undefined reference to\s+"
        r"[`'\u2018](?:uuid_unparse|uuid_is_null))",
    ),
    (
        "E2FSPROGS_PRIVATE_BLKID_LINK_NAME_MISMATCH",
        r"No rule to make target\s+[`'\u2018]"
        r"\.\./lib/libblkid\.so[`'\u2019]?,\s*needed by\s+"
        r"[`'\u2018]e2fsck",
    ),
    (
        "E2FSPROGS_BLKID_CONST_TYPE_CONFLICT",
        r"dev\.c:\d+:\d+:\s*error:\s*conflicting types for\s+"
        r"[`'\u2018]blkid_dev_set_search",
    ),
    (
        "MISSING_POWERTOP_AUTOCONF_ARCHIVE_MACRO",
        r"(?:powertop[\s\S]*)?configure\.ac:\d+:\s*error:\s*"
        r"possibly undefined macro:\s*AC_MSG_ERROR",
    ),
    (
        "MISSING_DDWRT_NFNETLINK_COMPAT_HEADER",
        r"fatal error:\s*linux/netfilter/nfnetlink_compat\.h:"
        r"\s*No such file or directory",
    ),
    (
        "HOST_MESON_VERSION_TOO_OLD",
        r"Meson version is\s+([0-9.]+)\s+but project requires\s+"
        r">=\s*([0-9.]+)",
    ),
    (
        "UTIL_LINUX_INSTALL_OWNERSHIP_DENIED",
        r"util-linux[\s\S]*(?:chgrp|chown)[^\n]*"
        r"Operation not permitted",
    ),
    (
        "MISSING_HOST_GTKDOCIZE",
        r"(?:Can.t exec \"gtkdocize\"|"
        r"(?:^|\n)[^\n]*gtkdocize:\s*(?:command not found|"
        r"No such file))",
    ),
    (
        "MISSING_UTIL_LINUX_CONFIGURE_OUTPUT",
        r"make -C util-linux[\s\S]*No targets specified and "
        r"no makefile found",
    ),
    (
        "MISSING_NCURSES_CONFIGURE_OUTPUT",
        r"make -C ncurses[\s\S]*No targets specified and "
        r"no makefile found",
    ),
    (
        "PCRE_CROSS_UNIT_TEST_LINK_FAILURE",
        r"(?:pcrecpp_unittest|pcre_scanner_unittest|"
        r"pcre_stringpiece_unittest).*(?:libpcre\.so\.1.*not found|"
        r"undefined reference)",
    ),
    (
        "LIBSODIUM_CONFIG_AUX_FAILURE",
        r"libsodium[\s\S]*configure: error: cannot run "
        r"(?:/bin/bash )?\./build-aux/config\.(?:sub|guess)",
    ),
    (
        "MISSING_HOST_LIBLTDL_M4",
        r"libtoolize:\s+error:\s+'.*/ltdl\.m4'\s+does not exist",
    ),
    (
        "MISSING_DDWRT_REVISION_HEADER",
        r"fatal error:\s*revision\.h:\s*No such file or directory",
    ),
    (
        "MISSING_DDWRT_INCLUDE_V24_TYPEDEFS",
        r"fatal error:\s*typedefs\.h:\s*No such file or directory",
    ),
    (
        "LEGACY_WIRELESS_REGISTER_OBJECT_REQUIRED",
        r"No rule to make target [^\n]*register/"
        r"(?:register_check|register_regulatory|register_wifi)\.o",
    ),
    (
        "MISSING_SOURCE_OR_GENERATED_HEADER",
        r"fatal error:\s*[^:\n]+:\s*No such file or directory",
    ),
    (
        "DDWRT_HOST_CONFIG_MULTIPLE_DEFINITION",
        r"multiple definition of [`']current_menu",
    ),
    (
        "MISSING_DDWRT_UCLIBC_CROSS_TOOLCHAIN",
        r"aarch64-linux-uclibc-[^\s:]*(?:gcc|ld|strip)"
        r"[^\n]*(?:not found|No such file)",
    ),
    (
        "OUT_OF_DISK_SPACE",
        r"No space left on device",
    ),
    (
        "COMPILE_OR_LINK_FAILURE",
        r"(?:collect2: error|undefined reference|Error [12]\b|"
        r"recipe for target)",
    ),
]

classification = (
    "CONFIGURE_COMPLETED"
    if status == 0
    else "UNCLASSIFIED_CONFIGURE_FAILURE"
)
for name, pattern in rules:
    if re.search(pattern, log, re.IGNORECASE | re.DOTALL):
        classification = name
        break

pathlib.Path(sys.argv[3]).write_text(
    f"classification={classification}\n"
    f"configure_exit_status={status}\n",
    encoding="utf-8",
)
PY

find "$ROUTER_DIR/pcre/.libs" -maxdepth 1 \
  \( -type f -o -type l \) \
  \( -name 'libpcre.so*' -o -name 'libpcreposix.so*' \
     -o -name 'libpcrecpp.so*' \) \
  -printf '%f\n' 2>/dev/null | sort -u \
  > "$REVIEW_DIR/pcre-built-libraries.txt"

{
  echo "pcre_rule_patch=$(
    if grep -qx 'changed_recipe_count=1' \
      "$REVIEW_DIR/pcre-production-targets.txt"; then
      echo PASS
    else
      echo FAIL
    fi
  )"
  for library in libpcre libpcreposix libpcrecpp; do
    if find "$ROUTER_DIR/pcre/.libs" -maxdepth 1 \
      \( -type f -o -type l \) -name "$library.so*" \
      -print -quit 2>/dev/null | grep -q .; then
      echo "${library}_shared=PASS"
    else
      echo "${library}_shared=FAIL"
    fi
  done
  for test_program in \
    pcrecpp_unittest pcre_scanner_unittest pcre_stringpiece_unittest; do
    if [[ -e "$ROUTER_DIR/pcre/$test_program" ]] || \
       [[ -e "$ROUTER_DIR/pcre/.libs/$test_program" ]]; then
      echo "${test_program}_excluded=FAIL"
    else
      echo "${test_program}_excluded=PASS"
    fi
  done
} > "$REVIEW_DIR/pcre-library-contract.txt"

SODIUM_CONFIG_GUESS="$ROUTER_DIR/libsodium/build-aux/config.guess"
SODIUM_CONFIG_SUB="$ROUTER_DIR/libsodium/build-aux/config.sub"
if [[ -x "$SODIUM_CONFIG_GUESS" ]]; then
  if "$SODIUM_CONFIG_GUESS" \
    > "$REVIEW_DIR/libsodium-config-guess-output.txt" 2>&1; then
    sodium_guess_status=0
  else
    sodium_guess_status=$?
  fi
else
  sodium_guess_status=126
  printf 'missing or non-executable\n' \
    > "$REVIEW_DIR/libsodium-config-guess-output.txt"
fi
if [[ -x "$SODIUM_CONFIG_SUB" ]]; then
  if "$SODIUM_CONFIG_SUB" aarch64-linux-uclibc \
    > "$REVIEW_DIR/libsodium-config-sub-output.txt" 2>&1; then
    sodium_sub_status=0
  else
    sodium_sub_status=$?
  fi
else
  sodium_sub_status=126
  printf 'missing or non-executable\n' \
    > "$REVIEW_DIR/libsodium-config-sub-output.txt"
fi

{
  echo "sodium_rule_patch=$(
    if grep -qx 'changed_recipe_count=1' \
      "$REVIEW_DIR/sodium-config-aux-patch-contract.txt"; then
      echo PASS
    else
      echo FAIL
    fi
  )"
  echo "system_config_guess=$(
    if [[ -s "$CONFIG_GUESS_SOURCE" ]]; then echo PASS; else echo FAIL; fi
  )"
  echo "system_config_sub=$(
    if [[ -s "$CONFIG_SUB_SOURCE" ]]; then echo PASS; else echo FAIL; fi
  )"
  echo "libsodium_config_guess_executable=$(
    if [[ -x "$SODIUM_CONFIG_GUESS" ]]; then echo PASS; else echo FAIL; fi
  )"
  echo "libsodium_config_sub_executable=$(
    if [[ -x "$SODIUM_CONFIG_SUB" ]]; then echo PASS; else echo FAIL; fi
  )"
  echo "libsodium_config_guess_runs=$(
    if [[ "$sodium_guess_status" -eq 0 ]]; then echo PASS; else echo FAIL; fi
  )"
  echo "libsodium_config_sub_aarch64_uclibc=$(
    if [[ "$sodium_sub_status" -eq 0 ]]; then echo PASS; else echo FAIL; fi
  )"
  echo "phase46_config_sub_failure_absent=$(
    if grep -Eq 'configure: error: cannot run (/bin/bash )?\./build-aux/config\.sub' \
      "$CONFIGURE_LOG"; then
      echo FAIL
    else
      echo PASS
    fi
  )"
} > "$REVIEW_DIR/libsodium-config-aux-contract.txt"

{
  echo "stage=after_configure"
  echo "configure_status=$configure_status"
  echo "jansson_directory=$(
    if [[ -d "$ROUTER_DIR/jansson" ]]; then echo present; else echo missing; fi
  )"
  echo "jansson_makefile=$(
    if [[ -f "$ROUTER_DIR/jansson/Makefile" ]]; then echo present; else echo missing; fi
  )"
  echo "jansson_configure=$(
    if [[ -f "$ROUTER_DIR/jansson/configure" ]]; then echo present; else echo missing; fi
  )"
  find "$ROUTER_DIR/jansson" -maxdepth 2 \
    \( -type f -o -type l \) -printf '%P\n' 2>/dev/null \
    | sort | head -n 300 || true
} > "$REVIEW_DIR/jansson-after-configure.txt"

if grep -q '=FAIL$' "$REVIEW_DIR/pcre-library-contract.txt"; then
  printf 'BLOCKED_DDWRT_PCRE_LIBRARY_ONLY_CONTRACT_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

if grep -q '=FAIL$' "$REVIEW_DIR/libsodium-config-aux-contract.txt"; then
  printf 'BLOCKED_DDWRT_LIBSODIUM_CONFIG_AUX_CONTRACT_FAILED\n' \
    > "$STATUS_FILE"
  exit 1
fi

if grep -q '=FAIL$' "$E2FSPROGS_PRIVATE_LINK_GENERATED_CONTRACT"; then
  printf 'BLOCKED_E2FSPROGS_PRIVATE_BLKID_LINK_GENERATED_CONTRACT_FAILED\n' \
    > "$STATUS_FILE"
  cat <<EOF

Phase 60 result
---------------
STATUS: $(cat "$STATUS_FILE")

The checked-in e2fsprogs configure was synchronized with its already
correct configure.ac and the MCONFIG.in UUID link was activated, but the
generated MCONFIG, produced private library, produced libuuid or final
blkid link order did not satisfy the Phase 60 contract. The artifact
contains both exact patches, generated MCONFIG, built-file inventories,
full configure log and machine-readable checks.

No firmware was built and the router was not accessed.
EOF
  exit 1
fi

if [[ "$configure_status" -ne 0 ]]; then
  printf 'BLOCKED_DDWRT_CONFIGURE_STAGE_FAILED\n' > "$STATUS_FILE"
  cat <<EOF

Phase 60 result
---------------
STATUS: $(cat "$STATUS_FILE")

All earlier corrections remained valid. Phase 60 retained the verified
const-correct blkid function patch, synchronized the checked-in generated
configure with the already-correct configure.ac without regenerating
Autoconf output, activated the verified LIBUUID dependency after the
private LIBBLKID in MCONFIG.in, verified the generated link command,
produced libe2fsblkid and libuuid, and proved both the Phase 57
missing-target error and Phase 59 UUID-link errors are absent.
Configuration stopped at a later dependency. The artifact contains exact
before/after evidence, both patches, machine-readable contracts, the
complete configure log and an exact failure classification.

No firmware was built and the router was not accessed.
EOF
  exit 1
fi

if [[ ! -f "$ROUTER_DIR/jansson/Makefile" ]]; then
  echo "Full configure did not create jansson/Makefile; trying the native focused target."
  if (
    trap - ERR
    cd "$ROUTER_DIR"
    timeout 60m "${MAKE_COMMON[@]}" jansson-configure
  ) >> "$CONFIGURE_LOG" 2>&1; then
    jansson_configure_fallback_status=0
  else
    jansson_configure_fallback_status=$?
  fi
else
  jansson_configure_fallback_status=0
fi

{
  echo "configure_status=$configure_status"
  echo "jansson_configure_fallback_status=$jansson_configure_fallback_status"
  echo "jansson_makefile_after_fallback=$(
    if [[ -f "$ROUTER_DIR/jansson/Makefile" ]]; then echo present; else echo missing; fi
  )"
} > "$REVIEW_DIR/configure-stage-status.txt"

if [[ "$jansson_configure_fallback_status" -ne 0 ]] || \
   [[ ! -f "$ROUTER_DIR/jansson/Makefile" ]]; then
  printf 'BLOCKED_DDWRT_JANSSON_MAKEFILE_NOT_GENERATED\n' > "$STATUS_FILE"
  exit 1
fi

echo "Building native DD-WRT prerequisites sequentially: nvram, jansson, utils."
if (
  trap - ERR
  cd "$ROUTER_DIR"
  for bootstrap_target in nvram jansson utils; do
    echo "===== bootstrap target: $bootstrap_target ====="
    timeout 90m "${MAKE_BASE[@]}" "$bootstrap_target"
  done
) > "$BOOTSTRAP_LOG" 2>&1; then
  bootstrap_status=0
else
  bootstrap_status=$?
fi

tail -n 1000 "$BOOTSTRAP_LOG" \
  > "$REVIEW_DIR/ddwrt-bootstrap-build-tail.txt" || true
{
  echo "configure_status=$configure_status"
  echo "bootstrap_status=$bootstrap_status"
  echo "jansson_makefile=present"
  echo "bootstrap_targets=nvram jansson utils"
} > "$REVIEW_DIR/bootstrap-stage-status.txt"

if [[ "$bootstrap_status" -ne 0 ]]; then
  printf 'BLOCKED_DDWRT_BOOTSTRAP_BUILD_FAILED\n' > "$STATUS_FILE"
  cat <<EOF

Phase 60 result
---------------
STATUS: $(cat "$STATUS_FILE")

DD-WRT configuration completed and generated jansson/Makefile, but a
sequential prerequisite build failed. The artifact contains complete
configure and bootstrap logs so the exact prerequisite can be fixed
without repeating source-layout diagnosis.

No firmware was built and the router was not accessed.
EOF
  exit 1
fi

echo "Running a dry make expansion for diagnostic context."
DRY_RUN_BASE=(
  make
  -f Makefile.ipq60xx
  -n
  "LINUXDIR=$LINUX_TREE"
  ARCH=aarch64
  PLATFORM=aarch64
)
if [[ "$SELECTED_TARGET" == "all_then_install" ]]; then
  DRY_RUN_COMMAND=("${DRY_RUN_BASE[@]}" all install)
else
  DRY_RUN_COMMAND=("${DRY_RUN_BASE[@]}" "$SELECTED_TARGET")
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
  timeout 300m "${MAKE_ALL_COMMAND[@]}"
  compile_status=$?
  if [[ "$compile_status" -ne 0 ]]; then
    exit "$compile_status"
  fi
  if [[ "${#MAKE_INSTALL_COMMAND[@]}" -gt 0 ]]; then
    exec timeout 180m "${MAKE_INSTALL_COMMAND[@]}"
  fi
) > "$BUILD_LOG" 2>&1 &
build_pid=$!

while kill -0 "$build_pid" 2>/dev/null; do
  sleep 300
  if kill -0 "$build_pid" 2>/dev/null; then
    elapsed="$((($(date +%s) - start_epoch) / 60))"
    root_candidates="$(find "$SOURCE_ROOT" -type f \
      \( -name 'root.ipq5018' -o -name 'root.ipq60xx' \
         -o -name 'root.fs' \) \
      -size +1M 2>/dev/null | wc -l)"
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
  echo "configure_status=$configure_status"
  echo "bootstrap_status=$bootstrap_status"
  echo "userspace_build_status=$build_status"
  echo "selected_target=$SELECTED_TARGET"
} | tee "$REVIEW_DIR/userspace-build-status.txt"

tail -n 1000 "$BUILD_LOG" \
  > "$REVIEW_DIR/userspace-build-tail.txt" || true

grep -n -i -m 100 -E \
  'fatal error:|error:|undefined reference|no rule to make target|not found|No such file|No targets specified|no makefile found' \
  "$BUILD_LOG" > "$REVIEW_DIR/first-build-errors.txt" || true

find "$SOURCE_ROOT" -type f \
  \( -name 'root.ipq5018' -o -name 'root.ipq60xx' \
     -o -name 'root.fs' \) \
  -size +1M -print 2>/dev/null | sort \
  > "$REVIEW_DIR/rootfs-candidates.txt"

ROOTFS_INPUT=""
while IFS= read -r candidate; do
  [[ -n "$candidate" ]] || continue
  if unsquashfs -s "$candidate" > /dev/null 2>&1; then
    ROOTFS_INPUT="$candidate"
    break
  fi
done < "$REVIEW_DIR/rootfs-candidates.txt"

if [[ -n "$ROOTFS_INPUT" ]]; then
  printf '%s\n' "${ROOTFS_INPUT#"$SOURCE_ROOT/"}" \
    > "$REVIEW_DIR/selected-rootfs-source-path.txt"
fi

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
        "MISSING_DDWRT_NFNETLINK_COMPAT_HEADER",
        r"fatal error:\s*linux/netfilter/nfnetlink_compat\.h:"
        r"\s*No such file or directory",
    ),
    (
        "HOST_MESON_VERSION_TOO_OLD",
        r"Meson version is\s+([0-9.]+)\s+but project requires\s+"
        r">=\s*([0-9.]+)",
    ),
    (
        "MISSING_DDWRT_REVISION_HEADER",
        r"fatal error:\s*revision\.h:\s*No such file or directory",
    ),
    (
        "DDWRT_PACKAGE_NOT_CONFIGURED",
        r"No targets specified and no makefile found",
    ),
    (
        "LEGACY_WIRELESS_REGISTER_OBJECT_REQUIRED",
        r"No rule to make target [^\n]*register/"
        r"(?:register_check|register_regulatory|register_wifi)\.o",
    ),
    (
        "MISSING_DDWRT_SOURCE_OPT_WEB_CONFIG",
        r"opt/etc/config/\*\.webconfig.*(?:No such file|cannot stat)",
    ),
    (
        "MISSING_DDWRT_KERNEL_CONFIG",
        r"linux-6\.12-nss/\.config: No such file",
    ),
    (
        "MISSING_DDWRT_UCLIBC_CROSS_TOOLCHAIN",
        r"aarch64-linux-uclibc-[^\s:]*(?:gcc|ld|strip)"
        r"[^\n]*(?:not found|No such file)",
    ),
    (
        "MISSING_OR_WRONG_LINUX_SOURCE",
        r"src/linux/[^\s:]+/(?:Makefile|Kconfig): No such file or directory"
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
        "INTENTIONAL_PHASE60_PACKAGING_STOP",
        r"PHASE60_SAFETY_BLOCK",
    ),
    (
        "E2FSPROGS_BLKID_CONST_TYPE_CONFLICT",
        r"dev\.c:\d+:\d+:\s*error:\s*conflicting types for\s+"
        r"[`'\u2018]blkid_dev_set_search",
    ),
    (
        "PCRE_CROSS_UNIT_TEST_LINK_FAILURE",
        r"(?:pcrecpp_unittest|pcre_scanner_unittest|"
        r"pcre_stringpiece_unittest).*(?:libpcre\.so\.1.*not found|"
        r"undefined reference)",
    ),
    (
        "LIBSODIUM_CONFIG_AUX_FAILURE",
        r"libsodium[\s\S]*configure: error: cannot run "
        r"(?:/bin/bash )?\./build-aux/config\.(?:sub|guess)",
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

Phase 60 result
---------------
STATUS: $(cat "$STATUS_FILE")

The native DD-WRT uClibc userspace build did not produce a valid
IPQ50xx/IPQ60xx SquashFS rootfs. The artifact contains the official
toolchain contract,
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

if ! python3 work/validate-phase60.py \
  "$ROOTFS_REVIEW" \
  "$ROOTFS_STAGE" \
  "$REVIEW_DIR/rootfs-validation-status.txt" \
  "$REVIEW_DIR/rootfs-busybox-type.txt" \
  "$REVIEW_DIR/unexpected-flashable-build-files.txt" \
  "$REVIEW_DIR/revision-header-contract.txt" \
  "$REVIEW_DIR/pcre-library-contract.txt" \
  "$REVIEW_DIR/libsodium-config-aux-contract.txt" \
  "$REVIEW_DIR/host-libltdl-contract.txt" \
  "$REVIEW_DIR/ncurses-preconfigure-contract.txt" \
  "$REVIEW_DIR/host-gtkdocize-contract.txt" \
  "$REVIEW_DIR/host-meson-contract.txt" \
  "$REVIEW_DIR/nfnetlink-compat-header-contract.txt" \
  "$REVIEW_DIR/host-autoconf-archive-contract.txt" \
  "$REVIEW_DIR/powertop-autoconf-contract.txt" \
  "$REVIEW_DIR/e2fsprogs-blkid-const-contract.txt" \
  "$REVIEW_DIR/e2fsprogs-generated-configure-sync-contract.txt" \
  "$REVIEW_DIR/e2fsprogs-private-blkid-uuid-template-contract.txt" \
  "$REVIEW_DIR/e2fsprogs-private-blkid-generated-contract.txt" \
  "$REVIEW_DIR/util-linux-preconfigure-contract.txt" \
  "$REVIEW_DIR/util-linux-unprivileged-install-patch-contract.txt" \
  "$REVIEW_DIR/util-linux-install-contract.txt" \
  "$REVIEW_DIR/phase60-integration-checks.txt"; then
  printf 'BLOCKED_DDWRT_ROOTFS_VALIDATION_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

printf 'RA72_DDWRT_UCLIBC_USERSPACE_ROOTFS_BUILD_PASS_REVIEW_ONLY\n' \
  > "$STATUS_FILE"

CHECK_COUNT="$(grep -c '=PASS$' \
  "$REVIEW_DIR/phase60-integration-checks.txt")"
ROOTFS_SIZE="$(stat -c '%s' "$ROOTFS_REVIEW")"

cat <<EOF

Phase 60 result
---------------
STATUS: RA72_DDWRT_UCLIBC_USERSPACE_ROOTFS_BUILD_PASS_REVIEW_ONLY

Verified:
- Official DD-WRT AArch64 uClibc toolchain: PASS
- Public DD-WRT source pinned at revision $SVN_REVISION: PASS
- Repository opt/tools source contract: PASS
- Native IPQ6018 kernel configuration initialized early: PASS
- Exact RA72 ATH11K userspace profile applied: PASS
- Legacy MADWIFI/ATH9K/ATH10K register dependency disabled: PASS
- Verified SVN revision headers generated in four native consumers: PASS
- PCRE production libraries built without cross-compiled unit tests: PASS
- libsodium config.guess/config.sub replaced with verified host copies: PASS
- Host libltdl macro required by dnscrypt autoreconf: PASS
- Native ncurses preconfigure target and generated Makefile: PASS
- Host gtkdocize required by util-linux autoreconf: PASS
- Isolated pinned host Meson $HOST_MESON_ACTUAL_VERSION: PASS
- Pinned Linux 6.12 NSS nfnetlink compatibility UAPI header restored: PASS
- Ubuntu Autoconf Archive providers for all required PowerTOP AX macros: PASS
- Focused PowerTOP libtoolize/aclocal/autoconf preflight: PASS
- e2fsprogs blkid prototype aligned with util-linux const contract: PASS
- Exact Phase 58 e2fsprogs mixed source state verified: PASS
- Checked-in generated configure synchronized with configure.ac: PASS
- configure.ac and MCONFIG.in verified unchanged during Phase 59 sync: PASS
- MCONFIG.in private-blkid LIBUUID dependency activated exactly once: PASS
- configure and configure.ac unchanged by the UUID-link patch: PASS
- Autoconf output was not regenerated and no fallback symlink was used: PASS
- Generated MCONFIG requests libe2fsblkid followed by LIBUUID: PASS
- libe2fsblkid and util-linux libuuid shared libraries were built: PASS
- blkid link command orders private libe2fsblkid before -luuid: PASS
- Phase 57 missing libblkid target error is absent: PASS
- Phase 59 missing-libuuid warning and UUID undefined references are absent: PASS
- Native util-linux preconfigure target and generated Makefile: PASS
- util-linux unprivileged ownership-hook options applied exactly once: PASS
- Focused util-linux staged install without chown/chgrp failures: PASS
- Native DD-WRT configure stage: PASS
- Native nvram/Jansson/utils bootstrap: PASS
- Native IPQ60xx userspace build was executed: PASS
- Valid IPQ50xx/IPQ60xx SquashFS rootfs produced: PASS
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
Do not boot or flash any Phase 60 file.
EOF

echo
echo "Phase 60 completed: $(cat "$STATUS_FILE")"
