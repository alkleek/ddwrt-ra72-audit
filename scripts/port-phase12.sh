#!/usr/bin/env bash
set -Eeuo pipefail

out="phase12-output"
openwrt_tree="$out/openwrt"
ddwrt_tree="$out/ddwrt"
stage="$out/compile-stage"
review="$out/review"
report="$out/REPORT-PHASE12.txt"

mkdir -p "$openwrt_tree" "$ddwrt_tree" "$stage/include" "$stage/qcom" "$review"
exec > >(tee "$report") 2>&1

  echo "DD-WRT RA72 phase 12 Device Tree compatibility compile"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: compiler audit only; no firmware is built and nothing is flashable."
echo

contract="device/RA72-PHASE12-DTS-COMPILE-CONTRACT.md"
test -s "$contract"
cp "$contract" "$out/RA72-PHASE12-DTS-COMPILE-CONTRACT.md"

cat > "$out/DO-NOT-BOOT-OR-FLASH.txt" <<'EOF'
PHASE 12 COMPILER TEST OUTPUT ONLY

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

# Keep the native DD-WRT IPQ5018 base includes. The RA72 board DTS is the
# only OpenWrt Device Tree source imported into this compiler-test tree.
test -s "$stage/qcom/ipq5018.dtsi"
test -s "$stage/qcom/ipq5018-ess.dtsi"

# OpenWrt applies an optional analogue PHY tuning property through the
# OpenWrt-only `ge_phy` label. The public DD-WRT IPQ5018 Device Tree inventory
# does not define that label, so omit only this overlay from the compiler-test
# copy. This does not claim that the PHY is supported or operational.
sed -i \
  '/^\/\/ IPQ5018 GE Phy -> QCA8337 PHY0$/,/^};$/d' \
  "$stage/qcom/$candidate_name"

cat > "$review/source-adaptations.txt" <<'EOF'
Compiler-test adaptations:
- Imported only the OpenWrt RA72 board DTS.
- Retained DD-WRT's native ipq5018.dtsi and ipq5018-ess.dtsi base includes.
- Removed the optional OpenWrt-only &ge_phy qcom,dac-preset-short-cable overlay.

Reasons:
- Overwriting DD-WRT's native IPQ5018 base includes with OpenWrt variants
  removed labels required by the DD-WRT tree, including q6_region,
  q6_etr_region, and ge_phy.
- The public DD-WRT IPQ5018 Device Tree inventory does not define the optional
  board-level ge_phy tuning label used by OpenWrt.

Safety:
- These are compiler-test composition changes only.
- They do not prove PHY, Ethernet, Wi-Fi, boot, or NAND operation.
- The generated object remains review-only and must not be booted or flashed.
EOF

bindings=(
  "dt-bindings/gpio/gpio.h"
  "dt-bindings/input/input.h"
  "dt-bindings/input/linux-event-codes.h"
  "dt-bindings/leds/common.h"
)

# In both Linux and some SVN exports, this dt-bindings path is a relative
# symlink to include/uapi/linux/input-event-codes.h.  A plain HTTP/SVN export
# can turn the symlink into a one-line file containing only
# "../../uapi/linux/input-event-codes.h", which cpp accepts but dtc then tries
# to parse as DTS.  Fetch the real target for this one binding.
fetch_binding() {
  local binding="$1"
  local destination="$2"
  local url="$LINUX_BINDINGS_BASE/$binding"

  if [[ "$binding" == "dt-bindings/input/linux-event-codes.h" ]]; then
    url="$LINUX_BINDINGS_BASE/uapi/linux/input-event-codes.h"
  fi

  rm -f "$destination"
  curl --fail --location --silent --show-error \
    "$url" --output "$destination"
}

: > "$review/binding-provenance.tsv"
printf 'binding\tsource\tsha256\n' >> "$review/binding-provenance.tsv"

for binding in "${bindings[@]}"; do
  destination="$stage/include/$binding"
  mkdir -p "$(dirname "$destination")"

  if [[ "$binding" == "dt-bindings/input/linux-event-codes.h" ]]; then
    fetch_binding "$binding" "$destination"
    provenance="upstream Linux v6.12 resolved symlink target"
  elif [[ -s "$ddwrt_tree/include/$binding" ]]; then
    cp "$ddwrt_tree/include/$binding" "$destination"
    provenance="DD-WRT public linux-6.12-nss"
  else
    fetch_binding "$binding" "$destination"
    provenance="upstream Linux v6.12 compatibility overlay"
  fi

  checksum="$(sha256sum "$destination" | awk '{print $1}')"
  printf '%s\t%s\t%s\n' "$binding" "$provenance" "$checksum" \
    >> "$review/binding-provenance.tsv"
done

cp -a "$ddwrt_tree/include/dt-bindings/." \
  "$stage/include/dt-bindings/" 2>/dev/null || true

# Restore the explicitly reviewed compatibility headers after the
# broad DD-WRT binding copy, so provenance remains deterministic.
for binding in "${bindings[@]}"; do
  if [[ "$binding" == "dt-bindings/input/linux-event-codes.h" ]] \
      || grep -F "$binding" "$review/binding-provenance.tsv" \
         | grep -q 'upstream Linux'; then
    # The broad DD-WRT copy may recreate this path as a dangling relative
    # symlink. Remove it before writing the reviewed upstream regular file.
    fetch_binding "$binding" "$stage/include/$binding"
  fi
done

# Fail with a clear infrastructure diagnostic if the symlink target was not
# materialized as a real C header.
event_codes="$stage/include/dt-bindings/input/linux-event-codes.h"
grep -q '^#define[[:space:]]\+KEY_RESTART[[:space:]]' "$event_codes"

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
  echo "RA72 Phase 12 compiled-tree verification"
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
  echo "=== Phase 12 result ==="
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
