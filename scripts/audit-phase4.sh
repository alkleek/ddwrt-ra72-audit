#!/usr/bin/env bash
set -Eeuo pipefail

out="phase4-output"
files="$out/template-files"
mkdir -p "$files"
report="$out/REPORT-PHASE4.txt"

exec > >(tee "$report") 2>&1

echo "DD-WRT RA72 phase 4 IPQ5018 template audit"
echo "Device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "Reference devices: Linksys MR5500 and Linksys MX5500"
echo "SAFETY: this phase does not build firmware and produces nothing flashable."
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

grep -Ei '(^|/)([^/]*(ipq5018|mr5500|mx5500)[^/]*)$' \
  "$out/ddwrt-source-inventory.txt" \
  | sort -u > "$out/ipq5018-template-paths.txt" || true

grep -Ei 'ipq5018|mr5500|mx5500' "$out/ddwrt-source-inventory.txt" \
  | grep -Ei '\.(c|h|dts|dtsi|mk|config|sh|txt)$|(^|/)Makefile[^/]*$|(^|/)\.config[^/]*$' \
  | sort -u > "$out/text-candidate-paths.txt" || true

specific_paths=(
  "src/router/Makefile.ipq60xx"
  "src/router/services/sysinit/sysinit-ipq807x.c"
  "src/router/configs/ipq60xx/.config_mr7350"
  "src/router/configs/ipq60xx/.config_mx4200"
  "src/linux/universal/linux-6.12/arch/arm64/boot/dts/qcom/ipq5018-mr5500.dts"
  "src/linux/universal/linux-6.12/arch/arm64/boot/dts/qcom/ipq5018-mx5500.dts"
)

for path in "${specific_paths[@]}"; do
  printf '%s\n' "$path"
done >> "$out/text-candidate-paths.txt"
sort -u -o "$out/text-candidate-paths.txt" "$out/text-candidate-paths.txt"

while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  safe_name=$(printf '%s' "$path" | sed 's#[/ ]#__#g')
  destination="$files/$safe_name"
  if timeout 90 svn cat "$repository/$path" > "$destination" 2>/dev/null; then
    if [[ ! -s "$destination" ]]; then
      rm -f "$destination"
    fi
  else
    rm -f "$destination"
    printf '%s\n' "$path" >> "$out/unreadable-paths.txt"
  fi
done < "$out/text-candidate-paths.txt"

grep -RIniE --binary-files=without-match \
  'mr5500|mx5500|ipq5018|HAVE_MR5500|HAVE_MX5500|load_nss_ipq50xx|root\.ipq5018|Image-factory' \
  "$files" > "$out/template-content-matches.txt" || true

grep -RIniE --binary-files=without-match \
  'machine|model|compatible|board|detect|nvram|mtd|ubi|caldata|art|mac|ethernet|switch|qca8337|qca8081|ath11k' \
  "$files" > "$out/integration-content-matches.txt" || true

echo "=== IPQ5018/MR5500/MX5500 source paths ==="
cat "$out/ipq5018-template-paths.txt"
echo

echo "=== Template implementation matches ==="
if [[ -s "$out/template-content-matches.txt" ]]; then
  head -n 800 "$out/template-content-matches.txt"
else
  echo "None."
fi
echo

echo "=== Board integration matches ==="
if [[ -s "$out/integration-content-matches.txt" ]]; then
  head -n 800 "$out/integration-content-matches.txt"
else
  echo "None."
fi
echo

path_count=$(wc -l < "$out/ipq5018-template-paths.txt")
file_count=$(find "$files" -type f | wc -l)
template_count=$(wc -l < "$out/template-content-matches.txt")
integration_count=$(wc -l < "$out/integration-content-matches.txt")

echo "=== Automated classification ==="
echo "Relevant source paths: $path_count"
echo "Collected text files: $file_count"
echo "Template matches: $template_count"
echo "Board-integration matches: $integration_count"

if (( file_count > 0 && template_count > 0 )); then
  echo "RESULT: a concrete IPQ5018 DD-WRT template exists and can be used as a porting reference."
  echo "NEXT: compare its DTS, image recipe, board detection, flash layout, Ethernet, Wi-Fi calibration, and MAC extraction with RA72."
else
  echo "RESULT: no complete readable IPQ5018 template was collected from the public tree."
  echo "NEXT: manual source mapping or a new platform implementation would be required."
fi

echo
echo "DO NOT FLASH: this artifact contains reports and public source excerpts only."
