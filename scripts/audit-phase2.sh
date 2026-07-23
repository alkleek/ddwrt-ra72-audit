#!/usr/bin/env bash
set -Eeuo pipefail

out="phase2-output"
mkdir -p "$out/snippets"
report="$out/REPORT-PHASE2.txt"
inventory="$out/ddwrt-source-inventory.txt"

exec > >(tee "$report") 2>&1

echo "DD-WRT RA72 phase 2 platform/build audit"
echo "Device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "Purpose: find a real DD-WRT IPQ5018 build target that can be used as a porting base."
echo "SAFETY: this workflow does not build firmware and produces nothing flashable."
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

svn list --recursive "$repository" > "$inventory"

device_terms='ipq5018|ipq50xx|ipq50|mr5500|mx2000|mx5500|rdp432|spnmx56|archer-ax55|x3000gs2|gl-b3000'
exact_terms='ra72|mp03|mi[_-]?aiot[_-]?ax6000|xiaomi[_-]?ax6000'
build_terms='(^|/)(configs?|rules|targets?|platforms?|profiles?|sysinit|Makefile|Kconfig|build)'

grep -Ei "$device_terms" "$inventory" > "$out/ipq5018-paths.txt" || true
grep -Ei "$exact_terms" "$inventory" > "$out/exact-ra72-paths.txt" || true
grep -Ei "$device_terms" "$inventory" | grep -Ei "$build_terms" \
  > "$out/build-profile-paths.txt" || true

echo "=== Exact RA72 path matches ==="
if [[ -s "$out/exact-ra72-paths.txt" ]]; then
  cat "$out/exact-ra72-paths.txt"
else
  echo "None."
fi
echo

echo "=== IPQ5018 paths outside imported Linux kernel trees ==="
grep -Eiv '^src/linux/' "$out/ipq5018-paths.txt" \
  > "$out/ipq5018-non-kernel-paths.txt" || true
if [[ -s "$out/ipq5018-non-kernel-paths.txt" ]]; then
  cat "$out/ipq5018-non-kernel-paths.txt"
else
  echo "None."
fi
echo

echo "=== Candidate DD-WRT build/profile paths ==="
if [[ -s "$out/build-profile-paths.txt" ]]; then
  cat "$out/build-profile-paths.txt"
else
  echo "None found by path name."
fi
echo

grep -Ei "$device_terms" "$inventory" \
  | grep -Ei '\.(dts|dtsi|mk|mak|config|txt|h|c)$|(^|/)(Makefile|Kconfig)$' \
  | head -n 160 > "$out/candidate-text-files.txt" || true

: > "$out/content-matches.txt"
count=0
while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  count=$((count + 1))
  safe_name=$(printf '%s' "$path" | tr '/ ' '__')
  destination="$out/snippets/${count}-${safe_name}"
  if timeout 30 svn cat "$repository/$path" > "$destination" 2>/dev/null; then
    if grep -Eini "$device_terms|$exact_terms" "$destination" \
      > "$destination.matches"; then
      {
        echo "--- $path"
        head -n 80 "$destination.matches"
      } >> "$out/content-matches.txt"
    else
      rm -f "$destination.matches"
    fi
  else
    rm -f "$destination"
  fi
done < "$out/candidate-text-files.txt"

echo "=== Relevant content excerpts ==="
if [[ -s "$out/content-matches.txt" ]]; then
  cat "$out/content-matches.txt"
else
  echo "No content matches were extracted."
fi
echo

exact_count=$(wc -l < "$out/exact-ra72-paths.txt")
profile_count=$(wc -l < "$out/build-profile-paths.txt")
non_kernel_count=$(wc -l < "$out/ipq5018-non-kernel-paths.txt")

echo "=== Automated classification ==="
echo "Exact RA72-named paths: $exact_count"
echo "Candidate build/profile paths: $profile_count"
echo "IPQ5018 non-kernel paths: $non_kernel_count"

if (( exact_count > 0 && profile_count > 0 )); then
  echo "RESULT: possible existing RA72/profile implementation; manual source review required."
elif (( profile_count > 0 )); then
  echo "RESULT: an IPQ5018 DD-WRT build/profile foundation may exist, but RA72 is not integrated."
  echo "NEXT: inspect the closest profile and create an RA72-only device definition and image layout."
elif (( non_kernel_count > 0 )); then
  echo "RESULT: IPQ5018 components exist, but this audit found no clear DD-WRT image profile."
  echo "NEXT: a new DD-WRT platform/profile integration is likely required before any image can be built."
else
  echo "RESULT: references appear limited to imported kernel support."
  echo "NEXT: DD-WRT platform integration must be created; kernel support alone is insufficient."
fi

echo
echo "DO NOT FLASH: every file in this artifact is a text audit result."
