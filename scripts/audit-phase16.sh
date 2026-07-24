#!/usr/bin/env bash
set -uo pipefail

output_dir="phase16-output"
review_dir="$output_dir/review"
openwrt_dir="$output_dir/openwrt"
report_file="$output_dir/REPORT-PHASE16.txt"
status_file="$review_dir/phase16-status.txt"
attempts_file="$review_dir/ddwrt-source-attempts.txt"
svn_info_file="$review_dir/ddwrt-svn-info.txt"
inventory_file="$review_dir/ddwrt-source-inventory.txt"
kernel_file="$review_dir/ddwrt-kernel-candidates.txt"
dts_file="$review_dir/ddwrt-arm64-dts-roots.txt"
signal_file="$review_dir/ddwrt-ipq5018-signals.txt"
openwrt_file="$review_dir/openwrt-kernel-baseline.txt"

mkdir -p "$review_dir"
: > "$attempts_file"
: > "$svn_info_file"
: > "$inventory_file"
: > "$kernel_file"
: > "$dts_file"
: > "$signal_file"
: > "$openwrt_file"

openwrt_ref="${OPENWRT_REF:-openwrt-25.12}"
override_url="${DDWRT_SOURCE_URL:-}"

{
  echo "DD-WRT RA72 Phase 16 resilient source discovery and kernel baseline audit"
  echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
  echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
  echo "SAFETY: audit only; no firmware is built and nothing is flashable."
  echo
  echo "OpenWrt comparison reference: $openwrt_ref"
} > "$report_file"

echo "Cloning verified OpenWrt comparison reference: $openwrt_ref"
if git clone --filter=blob:none --no-checkout https://github.com/openwrt/openwrt.git "$openwrt_dir"; then
  if git -C "$openwrt_dir" fetch --depth=1 origin "$openwrt_ref" &&
     git -C "$openwrt_dir" checkout --detach FETCH_HEAD; then
    {
      git -C "$openwrt_dir" rev-parse HEAD
      git -C "$openwrt_dir" log -1 --format='%H%n%ci%n%s'
      find "$openwrt_dir/target/linux/qualcommax" -maxdepth 4 -type f \
        \( -iname '*ipq5018*' -o -iname '*ipq50*' -o -iname '*ax6000*' \) \
        2>/dev/null | sed "s#^$openwrt_dir/##" | sort
    } > "$openwrt_file"
  else
    echo "OPENWRT_REFERENCE_FETCH_FAILED" > "$openwrt_file"
  fi
else
  echo "OPENWRT_REFERENCE_CLONE_FAILED" > "$openwrt_file"
fi

declare -a candidates=()
if [[ -n "$override_url" ]]; then
  candidates+=("$override_url")
fi
candidates+=(
  "https://svn.dd-wrt.com/DD-WRT"
  "svn://svn.dd-wrt.com/DD-WRT"
)

declare -A seen=()
selected_url=""
for candidate in "${candidates[@]}"; do
  [[ -n "${seen[$candidate]:-}" ]] && continue
  seen["$candidate"]=1
  for attempt in 1 2 3; do
    printf 'URL=%s ATTEMPT=%s UTC=%s\n' \
      "$candidate" "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$attempts_file"
    temporary_info="$review_dir/svn-info-attempt.txt"
    if timeout 60s svn info "$candidate" > "$temporary_info" 2>&1; then
      selected_url="$candidate"
      {
        echo "Selected URL: $candidate"
        cat "$temporary_info"
      } > "$svn_info_file"
      echo "RESULT=SUCCESS" >> "$attempts_file"
      break 2
    else
      result=$?
      echo "RESULT=FAILED EXIT=$result" >> "$attempts_file"
      sed 's/^/  /' "$temporary_info" >> "$attempts_file"
      sleep 5
    fi
  done
done
rm -f "$review_dir/svn-info-attempt.txt"

if [[ -z "$selected_url" ]]; then
  status="AUDIT_INCOMPLETE_DDWRT_SOURCE_UNAVAILABLE_AFTER_RETRIES"
  echo "$status" > "$status_file"
  {
    echo
    echo "Result: $status"
    echo "The public DD-WRT source endpoint was unavailable after all configured retries."
    echo "This is not evidence that DD-WRT lacks an IPQ5018 foundation."
    echo "Review: review/ddwrt-source-attempts.txt"
  } >> "$report_file"
  exit 0
fi

echo "Reading public DD-WRT source inventory from $selected_url"
if ! timeout 25m svn list --recursive "$selected_url" > "$inventory_file" 2>> "$attempts_file"; then
  status="AUDIT_INCOMPLETE_DDWRT_INVENTORY_DOWNLOAD_FAILED"
  echo "$status" > "$status_file"
  {
    echo
    echo "Selected DD-WRT source: $selected_url"
    echo "Result: $status"
    echo "The endpoint responded, but the recursive inventory could not be completed."
  } >> "$report_file"
  exit 0
fi

grep -Ei '(^|/)(kernel|linux|src/linux|src/router|Makefile|config)' \
  "$inventory_file" > "$kernel_file" || true
grep -Ei '(^|/)(arch/arm64/boot/dts|dts/qcom|qcom/.*\.dtsi?$)' \
  "$inventory_file" > "$dts_file" || true
grep -Ei 'ipq5018|ipq50[0-9x]+|mp03|qca8337|qca8081|ax6000' \
  "$inventory_file" > "$signal_file" || true

kernel_count="$(wc -l < "$kernel_file")"
dts_count="$(wc -l < "$dts_file")"
signal_count="$(wc -l < "$signal_file")"
status="AUDIT_COMPLETE_DDWRT_SOURCE_AVAILABLE"
echo "$status" > "$status_file"

{
  echo
  echo "Selected DD-WRT source: $selected_url"
  echo "Result: $status"
  echo "Kernel/build candidate paths: $kernel_count"
  echo "Qualcomm ARM64 DTS candidate paths: $dts_count"
  echo "IPQ5018/IPQ50xx/RA72-related signals: $signal_count"
  echo
  echo "No match by itself proves RA72 support or produces safe firmware."
} >> "$report_file"

exit 0
