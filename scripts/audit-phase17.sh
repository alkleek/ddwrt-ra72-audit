#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="phase17-output"
REVIEW_DIR="$OUT_DIR/review"
REPORT="$OUT_DIR/REPORT-PHASE17.txt"
STATUS_FILE="$REVIEW_DIR/phase17-status.txt"
SOURCE_INFO="$REVIEW_DIR/ddwrt-source-info.txt"
INVENTORY="${RUNNER_TEMP:-/tmp}/ddwrt-phase17-source-inventory.txt"
SOURCE_URL="${DDWRT_SOURCE_URL:-svn://svn.dd-wrt.com/DD-WRT}"

mkdir -p "$REVIEW_DIR"

write_report() {
  local status="$1"
  local all_count="${2:-0}"
  local exact_count="${3:-0}"
  local mp03_count="${4:-0}"
  local build_count="${5:-0}"
  local kernel_count="${6:-0}"
  local driver_count="${7:-0}"

  cat > "$REPORT" <<EOF
DD-WRT RA72 Phase 17 IPQ5018 foundation classification

Exact device: Xiaomi Mi AIoT AX6000, model RA72
SoC/board: Qualcomm IPQ5018 / MP03.1
Not for: Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000

SAFETY: source audit only. No firmware is built, nothing is written to a router,
and nothing in this artifact is flashable.

DD-WRT source: $SOURCE_URL
Classification: $status

All IPQ5018/IPQ50xx/RA72-related signals: $all_count
Exact RA72/Mi AIoT AX6000 signals: $exact_count
MP03 board signals: $mp03_count
Build/profile candidate signals: $build_count
Kernel/Device Tree candidate signals: $kernel_count
Driver candidate signals: $driver_count

Interpretation:
- An exact name match is a signal, not proof of a working DD-WRT target.
- Build/profile candidates require manual source review.
- Kernel, Device Tree, or driver references alone do not constitute a buildable
  RA72 DD-WRT port.

Next decision is based on the classification and the accompanying candidate lists.
EOF
}

fail_audit() {
  local reason="$1"
  printf '%s\n' "$reason" > "$STATUS_FILE"
  write_report "$reason"
  exit 1
}

: > "$SOURCE_INFO"
source_ok=0
for attempt in 1 2 3; do
  if timeout 3m svn info "$SOURCE_URL" > "$SOURCE_INFO" 2>&1; then
    source_ok=1
    break
  fi
  printf '\nAttempt %s failed; retrying.\n' "$attempt" >> "$SOURCE_INFO"
  sleep 5
done

if [[ "$source_ok" -ne 1 ]]; then
  fail_audit "SOURCE_DISCOVERY_FAILED"
fi

if ! timeout 25m svn list --recursive "$SOURCE_URL" > "$INVENTORY" 2> "$REVIEW_DIR/svn-list-errors.txt"; then
  fail_audit "SOURCE_INVENTORY_FAILED"
fi

signal_re='ipq5018|ipq50[0-9x]+|mp03|qca8337|qca8081|ra72|mi.?aiot.*ax6000|xiaomi.*ax6000'
grep -Ei "$signal_re" "$INVENTORY" | sort -u > "$REVIEW_DIR/all-ipq5018-signals.txt" || true
grep -Ei 'ra72|mi.?aiot.*ax6000' "$INVENTORY" | sort -u > "$REVIEW_DIR/exact-ra72-device-signals.txt" || true
grep -Ei 'mp03' "$INVENTORY" | sort -u > "$REVIEW_DIR/mp03-board-signals.txt" || true

grep -Ei '(^|/)(configs?|rules|targets?|profiles?|platforms?|tools)(/|$)|(^|/)(Makefile|Kconfig|Config\.in)$' \
  "$REVIEW_DIR/all-ipq5018-signals.txt" | sort -u > "$REVIEW_DIR/build-profile-candidates.txt" || true
grep -Ei 'linux|kernel|arch/arm64|boot/dts|dts|dtsi' \
  "$REVIEW_DIR/all-ipq5018-signals.txt" | sort -u > "$REVIEW_DIR/kernel-dts-candidates.txt" || true
grep -Ei 'drivers|ath11k|nss|ssdk|qca8k|mdio|ethernet|net/' \
  "$REVIEW_DIR/all-ipq5018-signals.txt" | sort -u > "$REVIEW_DIR/driver-candidates.txt" || true

count_lines() {
  awk 'END { print NR + 0 }' "$1"
}

all_count="$(count_lines "$REVIEW_DIR/all-ipq5018-signals.txt")"
exact_count="$(count_lines "$REVIEW_DIR/exact-ra72-device-signals.txt")"
mp03_count="$(count_lines "$REVIEW_DIR/mp03-board-signals.txt")"
build_count="$(count_lines "$REVIEW_DIR/build-profile-candidates.txt")"
kernel_count="$(count_lines "$REVIEW_DIR/kernel-dts-candidates.txt")"
driver_count="$(count_lines "$REVIEW_DIR/driver-candidates.txt")"

if (( exact_count > 0 )); then
  status="DIRECT_RA72_SUPPORT_SIGNAL_FOUND"
elif (( build_count > 0 )); then
  status="IPQ5018_BUILD_FOUNDATION_CANDIDATE_FOUND"
elif (( kernel_count > 0 || driver_count > 0 )); then
  status="KERNEL_DRIVER_SIGNALS_ONLY_NO_BUILD_PROFILE_FOUND"
else
  status="NO_ACTIONABLE_IPQ5018_FOUNDATION_FOUND"
fi

printf '%s\n' "$status" > "$STATUS_FILE"
cat > "$REVIEW_DIR/phase17-counts.txt" <<EOF
all_ipq5018_signals=$all_count
exact_ra72_device_signals=$exact_count
mp03_board_signals=$mp03_count
build_profile_candidates=$build_count
kernel_dts_candidates=$kernel_count
driver_candidates=$driver_count
EOF

write_report "$status" "$all_count" "$exact_count" "$mp03_count" \
  "$build_count" "$kernel_count" "$driver_count"

printf 'Phase 17 complete: %s\n' "$status"

