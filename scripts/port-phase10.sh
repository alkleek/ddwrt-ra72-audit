#!/usr/bin/env bash
set -Eeuo pipefail

out="phase10-output"
openwrt_tree="$out/openwrt"
ddwrt_tree="$out/ddwrt"
stage="$out/compile-stage"
review="$out/review"
report="$out/REPORT-PHASE10.txt"

mkdir -p "$openwrt_tree" "$ddwrt_tree" "$stage/include" "$stage/qcom" "$review"
exec > >(tee "$report") 2>&1

echo "DD-WRT RA72 phase 10 Device Tree compatibility compile"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: compiler audit only; no firmware is built and nothing is flashable."
echo

contract="device/RA72-DTS-COMPILE-CONTRACT.md"
test -s "$contract"
cp "$contract" "$out/RA72-DTS-COMPILE-CONTRACT.md"

cat > "$out/DO-NOT-BOOT-OR-FLASH.txt" <<'EOF'
PHASE 10 COMPILER TEST OUTPUT ONLY

Nothing in this artifact is firmware or approved for booting.
Do not boot, flash, install, TFTP, write, or deploy the generated DTB.
Exact source target: Xiaomi Mi AIoT AX6000, model RA72, IPQ5018 / MP03.1 only.
EOF

git clone --filter=blob:none --no-checkout "$OPENWRT_REPOSITORY" "$openwrt_tree"
git -C "$openwrt_tree" fetch --depth=1 origin "$OPENWRT_REF"
git -C "$openwrt_tree" checkout --detach FETCH_HEAD
git -C "$openwrt_tree" rev-parse HEAD | tee "$out/openwrt-commit.txt"

openwrt_qcom="$openwrt_tree/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom"
candidate_name="ipq5018-xiaomi-mi-aiot-ax6000-ra72.dts"
openwrt_dts="$openwrt_qcom/ipq5018-ax6000.dts"
test -s "$openwrt_dts"

repository=""
for candidate in "$DDWRT_HTTPS_URL" "$DDWRT_SVN_URL"; do
  if svn info "$candidate" > "$out/ddwrt-svn-info.txt" 2>&1; then
    repository="$candidate"
    break
  fi
done
test -n "$repository"

ddwrt_kernel="src/linux/universal/linux-6.12-nss"
ddwrt_qcom="$ddwrt_kernel/arch/arm64/boot/dts/qcom"
ddwrt_bindings="$ddwrt_kernel/include/dt-bindings"

echo "Exporting DD-WRT IPQ5018 Device Tree sources..."
svn export --force --quiet "$repository/$ddwrt_qcom" "$ddwrt_tree/qcom"

echo "Exporting DD-WRT Device Tree binding headers..."
if ! svn export --force --quiet "$repository/$ddwrt_bindings" \
  "$ddwrt_tree/include/dt-bindings"; then
  echo "WARN: complete DD-WRT dt-bindings export was unavailable."
  mkdir -p "$ddwrt_tree/include/dt-bindings"
fi

cp -a "$ddwrt_tree/qcom/." "$stage/qcom/"
cp "$openwrt_dts" "$stage/qcom/$candidate_name"

for source in "$openwrt_qcom/ipq5018-ess.dtsi" \
              "$openwrt_qcom/ipq5018.dtsi"; do
  if [[ -s "$source" ]]; then
    cp "$source" "$stage/qcom/"
  fi
done

bindings=(
  "dt-bindings/gpio/gpio.h"
  "dt-bindings/input/input.h"
  "dt-bindings/leds/common.h"
)

: > "$review/binding-provenance.tsv"
printf 'binding\tsource\tsha256\n' >> "$review/binding-provenance.tsv"

for binding in "${bindings[@]}"; do
  destination="$stage/include/$binding"
  mkdir -p "$(dirname "$destination")"

  if [[ -s "$ddwrt_tree/include/$binding" ]]; then
    cp "$ddwrt_tree/include/$binding" "$destination"
    provenance="DD-WRT public linux-6.12-nss"
  else
    curl --fail --location --silent --show-error \
      "$LINUX_BINDINGS_BASE/$binding" --output "$destination"
    provenance="upstream Linux v6.12 compatibility overlay"
  fi

  checksum="$(sha256sum "$destination" | awk '{print $1}')"
  printf '%s\t%s\t%s\n' "$binding" "$provenance" "$checksum" \
    >> "$review/binding-provenance.tsv"
done

cp -a "$ddwrt_tree/include/dt-bindings/." \
  "$stage/include/dt-bindings/" 2>/dev/null || true

# Restore the three explicitly reviewed compatibility headers after the
# broad DD-WRT binding copy, so provenance remains deterministic.
for binding in "${bindings[@]}"; do
  if grep -F "$binding" "$review/binding-provenance.tsv" \
      | grep -q 'upstream Linux'; then
    curl --fail --location --silent --show-error \
      "$LINUX_BINDINGS_BASE/$binding" --output "$stage/include/$binding"
  fi
done

candidate_dts="$stage/qcom/$candidate_name"
preprocessed="$review/ra72-ddwrt-compat.preprocessed.dts"
compiled="$review/ra72-ddwrt-compat.COMPILER-TEST-ONLY.dtb"
decompiled="$review/ra72-ddwrt-compat.decompiled.dts"
compile_log="$review/dtc-compile.log"

echo
echo "Preprocessing the RA72 candidate against the DD-WRT compatibility tree..."
set +e
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
  -I "$stage/include" \
  -I "$stage/qcom" \
  "$candidate_dts" "$preprocessed" > "$review/cpp.log" 2>&1
cpp_status=$?

dtc_status=99
if (( cpp_status == 0 )); then
  dtc -I dts -O dtb -@ -Wno-unit_address_vs_reg \
    -o "$compiled" "$preprocessed" > "$compile_log" 2>&1
  dtc_status=$?
fi

if (( dtc_status == 0 )); then
  dtc -I dtb -O dts -o "$decompiled" "$compiled" \
    > "$review/dtc-decompile.log" 2>&1
  decompile_status=$?
else
  decompile_status=99
fi
set -e

{
  printf 'stage\tstatus\n'
  printf 'cpp\t%s\n' "$cpp_status"
  printf 'dtc\t%s\n' "$dtc_status"
  printf 'decompile\t%s\n' "$decompile_status"
} > "$review/compile-status.tsv"

checks=(
  'xiaomi,ax6000'
  'qcom,ipq5018'
  'ethernet-switch@11'
  'ethernet-phy@8'
  'label = "lan1"'
  'label = "lan2"'
  'label = "lan3"'
  'label = "wan"'
)

{
  echo "RA72 Phase 10 compiled-tree verification"
  echo
  if [[ -s "$decompiled" ]]; then
    for check in "${checks[@]}"; do
      if grep -Fq "$check" "$decompiled"; then
        printf 'PASS\t%s\n' "$check"
      else
        printf 'FAIL\t%s\n' "$check"
      fi
    done
  else
    echo -e "BLOCKED\tNo decompiled DTB was produced."
  fi
} | tee "$review/compiled-tree-verification.tsv"

cp "$candidate_dts" "$review/$candidate_name"

echo
echo "=== Phase 10 result ==="
echo "C preprocessor exit status: $cpp_status"
echo "Device Tree compiler exit status: $dtc_status"
echo "Device Tree decompiler exit status: $decompile_status"

if (( cpp_status == 0 && dtc_status == 0 && decompile_status == 0 )) \
   && ! grep -q '^FAIL' "$review/compiled-tree-verification.tsv"; then
  echo "RESULT: PASS - the review-only RA72 DTS compiled in the compatibility tree."
  echo "This proves source-level syntax compatibility only."
else
  echo "RESULT: BLOCKED - the artifact contains the exact compiler diagnostics."
  echo "The next source adaptation must resolve those diagnostics."
fi

echo "DO NOT BOOT OR FLASH: the generated DTB is a compiler test object, not firmware."

# A diagnostic incompatibility is an expected audit result. Infrastructure
# errors above still stop the job; compile incompatibility is preserved in the
# report and artifact without hiding it behind a failed upload.
exit 0
