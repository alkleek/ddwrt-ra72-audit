#!/usr/bin/env bash
set -Eeuo pipefail

out="phase3-output"
tree="$out/build-tree"
mkdir -p "$tree"
report="$out/REPORT-PHASE3.txt"

exec > >(tee "$report") 2>&1

echo "DD-WRT RA72 phase 3 build-system audit"
echo "Device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "Purpose: locate the DD-WRT files required to add a new IPQ5018 target."
echo "SAFETY: no firmware is built and nothing in this artifact is flashable."
echo

repository=""
for candidate in "$DDWRT_HTTPS_URL" "$DDWRT_SVN_URL"; do
  echo "Testing source URL: $candidate"
  if svn info "$candidate" > "$out/svn-info.txt" 2>&1; then
    repository="$candidate"
    break
  fi
done

if [[ -z "$repository" ]]; then
  echo "RESULT: public DD-WRT SVN source is unreachable."
  cat "$out/svn-info.txt" || true
  exit 1
fi

echo "Reachable source: $repository"
cat "$out/svn-info.txt"
echo

svn list --recursive "$repository" > "$out/ddwrt-source-inventory.txt"

candidate_roots=(
  "src/router/configs"
  "src/router/rules"
  "src/router/services/sysinit"
)

for relative in "${candidate_roots[@]}"; do
  echo "Exporting build-system area: $relative"
  destination="$tree/${relative#src/router/}"
  mkdir -p "$(dirname "$destination")"
  if ! timeout 900 svn export --force --quiet "$repository/$relative" "$destination"; then
    echo "WARN: could not export $relative"
  fi
done

while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  destination="$tree/top-level/$(printf '%s' "$path" | tr '/' '_')"
  mkdir -p "$(dirname "$destination")"
  timeout 60 svn cat "$repository/$path" > "$destination" 2>/dev/null || rm -f "$destination"
done < <(
  grep -E '^src/router/(Makefile[^/]*|Kconfig[^/]*)$' "$out/ddwrt-source-inventory.txt" \
    | head -n 100
)

search_terms='ipq5018|ipq50xx|ipq50|ipq6018|ipq807|ipq9574|qualcomm|qca-nss|nss-dp|ath11k'
exact_terms='(^|[^d])ra72([^0-9a-z]|$)|mp03(\.1)?|mi[ _-]?aiot[ _-]?ax6000|xiaomi[ _-]?ax6000'

grep -RIniE --binary-files=without-match "$search_terms" "$tree" \
  > "$out/qualcomm-build-matches.txt" || true
grep -RIniE --binary-files=without-match "$exact_terms" "$tree" \
  > "$out/exact-ra72-build-matches.txt" || true

find "$tree/configs" -type f 2>/dev/null | sort > "$out/config-files.txt" || true
find "$tree/rules" -type f 2>/dev/null | sort > "$out/rule-files.txt" || true
find "$tree/services/sysinit" -type f 2>/dev/null | sort \
  > "$out/sysinit-files.txt" || true

grep -Ei 'ipq|qualcomm|nss|ath11k|arm64|aarch64' "$out/config-files.txt" \
  > "$out/qualcomm-config-candidates.txt" || true
grep -Ei 'ipq|qualcomm|nss|ath11k|arm64|aarch64' "$out/rule-files.txt" \
  > "$out/qualcomm-rule-candidates.txt" || true
grep -Ei 'ipq|qualcomm|nss|ath11k|arm64|aarch64' "$out/sysinit-files.txt" \
  > "$out/qualcomm-sysinit-candidates.txt" || true

echo "=== Exact RA72 build-system matches ==="
if [[ -s "$out/exact-ra72-build-matches.txt" ]]; then
  head -n 200 "$out/exact-ra72-build-matches.txt"
else
  echo "None."
fi
echo

echo "=== Qualcomm/IPQ build-system content matches ==="
if [[ -s "$out/qualcomm-build-matches.txt" ]]; then
  head -n 500 "$out/qualcomm-build-matches.txt"
else
  echo "None."
fi
echo

echo "=== Candidate Qualcomm configuration files ==="
if [[ -s "$out/qualcomm-config-candidates.txt" ]]; then
  cat "$out/qualcomm-config-candidates.txt"
else
  echo "No Qualcomm-named configuration file."
fi
echo

echo "=== Candidate Qualcomm rule files ==="
if [[ -s "$out/qualcomm-rule-candidates.txt" ]]; then
  cat "$out/qualcomm-rule-candidates.txt"
else
  echo "No Qualcomm-named rule file."
fi
echo

echo "=== Candidate Qualcomm sysinit files ==="
if [[ -s "$out/qualcomm-sysinit-candidates.txt" ]]; then
  cat "$out/qualcomm-sysinit-candidates.txt"
else
  echo "No Qualcomm-named sysinit file."
fi
echo

match_count=$(wc -l < "$out/qualcomm-build-matches.txt")
exact_count=$(wc -l < "$out/exact-ra72-build-matches.txt")
config_count=$(wc -l < "$out/qualcomm-config-candidates.txt")
rule_count=$(wc -l < "$out/qualcomm-rule-candidates.txt")
sysinit_count=$(wc -l < "$out/qualcomm-sysinit-candidates.txt")

echo "=== Automated classification ==="
echo "Exact RA72 build matches: $exact_count"
echo "Qualcomm/IPQ content matches: $match_count"
echo "Candidate config files: $config_count"
echo "Candidate rule files: $rule_count"
echo "Candidate sysinit files: $sysinit_count"

if (( exact_count > 0 )); then
  echo "RESULT: possible RA72 integration text exists; manual review is required."
elif (( match_count > 0 && (config_count + rule_count + sysinit_count) > 0 )); then
  echo "RESULT: DD-WRT has Qualcomm build-system templates that may seed a new RA72 port."
  echo "NEXT: identify the closest ARM64/IPQ template and map the RA72 DTS, NAND layout, and board detection."
elif (( match_count > 0 )); then
  echo "RESULT: Qualcomm components are referenced, but no clearly named platform template was found."
  echo "NEXT: inspect the matching generic build logic manually before attempting a new target."
else
  echo "RESULT: this public build-system subset exposes no usable Qualcomm target template."
  echo "NEXT: a substantially new private platform integration would be required."
fi

echo
echo "DO NOT FLASH: this artifact contains reports and source excerpts only."
