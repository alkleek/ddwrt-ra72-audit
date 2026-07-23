#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p audit-output
report="audit-output/REPORT.txt"
inventory="audit-output/ddwrt-source-inventory.txt"

exec > >(tee "$report") 2>&1

echo "DD-WRT source feasibility audit"
echo "Device: Xiaomi Mi AIoT AX6000"
echo "Model: RA72"
echo "SoC: Qualcomm IPQ5018"
echo "Board: IPQ5018 MP03.1"
echo "This audit does not build or produce flashable firmware."
echo

repository=""
for candidate in "$DDWRT_HTTPS_URL" "$DDWRT_SVN_URL"; do
  echo "Testing DD-WRT source URL: $candidate"
  if svn info "$candidate" > audit-output/svn-info.txt 2>&1; then
    repository="$candidate"
    break
  fi
done

if [[ -z "$repository" ]]; then
  echo "RESULT: The public DD-WRT SVN source could not be reached."
  cat audit-output/svn-info.txt || true
  exit 1
fi

echo "Reachable source: $repository"
cat audit-output/svn-info.txt
echo
echo "Creating remote source inventory. No full checkout is performed."
svn list --recursive "$repository" > "$inventory"

patterns='ipq5018|ipq50|mp03|qca8337|qca8081|xiaomi|ax6000|ath11k|qualcommax'
grep -Ei "$patterns" "$inventory" > audit-output/relevant-paths.txt || true

echo
echo "Relevant paths found:"
cat audit-output/relevant-paths.txt || true
echo

if grep -Eqi 'ipq5018|ipq50' audit-output/relevant-paths.txt; then
  echo "RESULT: Public source contains IPQ5018/IPQ50xx references."
  echo "NEXT: Inspect the matching platform build files and determine whether"
  echo "the public tree can produce a bootable generic image before adding RA72."
else
  echo "RESULT: No IPQ5018/IPQ50xx platform reference was found in the public inventory."
  echo "A private RA72 build cannot proceed from this tree without first creating"
  echo "or importing an IPQ5018 DD-WRT platform implementation."
fi

echo
echo "SAFETY: No output from this audit is firmware. Do not flash any file."
