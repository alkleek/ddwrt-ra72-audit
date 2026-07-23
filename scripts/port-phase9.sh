#!/usr/bin/env bash
set -Eeuo pipefail

out="phase9-output"
openwrt_tree="$out/openwrt"
ddwrt_tree="$out/ddwrt"
draft="$out/port-draft"
mkdir -p "$openwrt_tree" "$ddwrt_tree" "$draft"
report="$out/REPORT-PHASE9.txt"
exec > >(tee "$report") 2>&1

echo "DD-WRT RA72 phase 9 source-port draft"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: source generation only; no firmware is built and nothing is flashable."
echo

contract="device/RA72-PORT-DRAFT-CONTRACT.md"
test -s "$contract"
cp "$contract" "$out/RA72-PORT-DRAFT-CONTRACT.md"

git clone --filter=blob:none --no-checkout "$OPENWRT_REPOSITORY" "$openwrt_tree"
git -C "$openwrt_tree" fetch --depth=1 origin "$OPENWRT_REF"
git -C "$openwrt_tree" checkout --detach FETCH_HEAD
git -C "$openwrt_tree" rev-parse HEAD | tee "$out/openwrt-commit.txt"

openwrt_dts="$openwrt_tree/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ax6000.dts"
openwrt_image="$openwrt_tree/target/linux/qualcommax/image/ipq50xx.mk"
test -s "$openwrt_dts"
test -s "$openwrt_image"

grep -q 'compatible = "xiaomi,ax6000"' "$openwrt_dts"
grep -q 'ethernet-switch@11' "$openwrt_dts"
grep -q 'ethernet-phy@8' "$openwrt_dts"
grep -q 'define Device/xiaomi_ax6000' "$openwrt_image"

repository=""
for candidate in "$DDWRT_HTTPS_URL" "$DDWRT_SVN_URL"; do
  if svn info "$candidate" > "$out/ddwrt-svn-info.txt" 2>&1; then
    repository="$candidate"
    break
  fi
done
test -n "$repository"

ddwrt_dts_dir="src/linux/universal/linux-6.12-nss/arch/arm64/boot/dts/qcom"
mkdir -p "$ddwrt_tree/$ddwrt_dts_dir"

references=(
  "ipq5018-mr5500.dts"
  "ipq5018-mx5500.dts"
  "ipq5018-ess.dtsi"
  "ipq5018-nss.dtsi"
)

for name in "${references[@]}"; do
  svn cat "$repository/$ddwrt_dts_dir/$name" \
    > "$ddwrt_tree/$ddwrt_dts_dir/$name"
  test -s "$ddwrt_tree/$ddwrt_dts_dir/$name"
done

candidate_dts="$draft/ipq5018-xiaomi-mi-aiot-ax6000-ra72.dts"
cp "$openwrt_dts" "$candidate_dts"

cat > "$draft/DO-NOT-BUILD-BOOT-OR-FLASH.txt" <<'EOF'
PHASE 9 SOURCE DRAFT ONLY

This directory contains a first-pass DTS transplant for code review.
It is not known to compile in DD-WRT and is not a firmware image.
Do not boot, flash, install, or write it to any router partition.
Exact target: Xiaomi Mi AIoT AX6000, model RA72, IPQ5018 / MP03.1 only.
EOF

grep -E '^[[:space:]]*#include[[:space:]]+' "$candidate_dts" \
  | sed -E 's/^[[:space:]]*#include[[:space:]]+[<"]([^>"]+)[>"].*$/\1/' \
  | sort -u > "$draft/openwrt-dts-includes.txt" || true

{
  echo -e "include\tDD-WRT status"
  while IFS= read -r include; do
    [[ -n "$include" ]] || continue
    base="$(basename "$include")"
    if svn info "$repository/$ddwrt_dts_dir/$base" >/dev/null 2>&1; then
      echo -e "$include\tPRESENT"
    else
      echo -e "$include\tMISSING_OR_DIFFERENT"
    fi
  done < "$draft/openwrt-dts-includes.txt"
} | tee "$draft/include-compatibility.tsv"

mkdir -p "$out/patch-root/$ddwrt_dts_dir"
cp "$candidate_dts" \
  "$out/patch-root/$ddwrt_dts_dir/ipq5018-xiaomi-mi-aiot-ax6000-ra72.dts"

(
  cd "$out/patch-root"
  diff -u /dev/null \
    "$ddwrt_dts_dir/ipq5018-xiaomi-mi-aiot-ax6000-ra72.dts" || true
) > "$draft/0001-ddwrt-add-ra72-dts.DRAFT.patch"

checks=(
  'compatible = "xiaomi,ax6000"'
  'qcom,ipq5018'
  'ethernet-switch@11'
  'ethernet-phy@8'
  'label = "lan1"'
  'label = "lan2"'
  'label = "lan3"'
  'label = "wan"'
)

{
  echo "RA72 Phase 9 candidate verification"
  echo
  for check in "${checks[@]}"; do
    if grep -Fq "$check" "$candidate_dts"; then
      printf 'PASS\t%s\n' "$check"
    else
      printf 'FAIL\t%s\n' "$check"
    fi
  done
} | tee "$draft/candidate-verification.tsv"

if grep -q '^FAIL' "$draft/candidate-verification.tsv"; then
  echo "RESULT: BLOCKED - candidate lost a required RA72 hardware property."
  exit 1
fi

missing_count="$(
  grep -c 'MISSING_OR_DIFFERENT' "$draft/include-compatibility.tsv" || true
)"

echo
echo "RESULT: first RA72 DD-WRT DTS source draft generated."
echo "Unresolved DD-WRT include dependencies: $missing_count"
echo "NEXT: adapt the include graph and compile the DTS in DD-WRT's kernel tree."
echo "DO NOT BUILD/BOOT/FLASH: Phase 9 outputs are review-only source drafts."
