#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="$PWD/phase22-output"
REVIEW_DIR="$OUT_DIR/review"
PATCH_DIR="$OUT_DIR/patches"
WORK_DIR="$OUT_DIR/work"
REPORT="$OUT_DIR/REPORT-PHASE22.txt"
STATUS_FILE="$REVIEW_DIR/phase22-status.txt"

REFERENCE_DIR="$WORK_DIR/reference"
QCOM_ORIGINAL="$WORK_DIR/ddwrt-qcom-original"
QCOM_STAGE="$WORK_DIR/ddwrt-qcom-stage"
BINDINGS_DIR="$WORK_DIR/dt-bindings"
ROUTER_MAKEFILE_ORIGINAL="$WORK_DIR/Makefile.ipq60xx.original"
ROUTER_MAKEFILE_STAGE="$WORK_DIR/Makefile.ipq60xx"

SOURCE_URL="${DDWRT_SOURCE_URL:-svn://svn.dd-wrt.com/DD-WRT}"
REFERENCE_REPOSITORY="${REFERENCE_REPOSITORY:-https://github.com/openwrt/openwrt.git}"
REFERENCE_REF="${REFERENCE_REF:-openwrt-25.12}"
LINUX_DT_BINDINGS_URL="${LINUX_DT_BINDINGS_URL:-https://raw.githubusercontent.com/torvalds/linux/master/include/dt-bindings}"

rm -rf "$OUT_DIR"
mkdir -p "$REVIEW_DIR" "$PATCH_DIR" "$WORK_DIR"

cat > "$OUT_DIR/DO-NOT-FLASH.txt" <<'EOF'
PHASE 22 IS A DD-WRT SOURCE-INTEGRATION AND DEVICE-TREE COMPILE AUDIT ONLY.
NO FIRMWARE IMAGE IS BUILT. NOTHING IN THIS ARTIFACT IS FLASHABLE.
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
  echo "Phase 22 stopped with status $(cat "$STATUS_FILE") (exit $code)."
  exit "$code"
}

trap cleanup EXIT
trap on_error ERR
exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 22 temporary source integration and DTS compile"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: no firmware is built and no router is accessed."
echo

SOURCE_ATTEMPTS="$REVIEW_DIR/ddwrt-source-attempts.txt"
: > "$SOURCE_ATTEMPTS"

select_ddwrt_source() {
  local candidate
  local -a candidates=(
    "$SOURCE_URL"
    "svn://svn.dd-wrt.com/DD-WRT"
    "https://svn.dd-wrt.com/DD-WRT"
  )

  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    candidate="${candidate%/}"
    if grep -Fxq "$candidate" "$SOURCE_ATTEMPTS"; then
      continue
    fi
    printf '%s\n' "$candidate" >> "$SOURCE_ATTEMPTS"
    echo "Checking public DD-WRT source: $candidate"
    if timeout 10m svn cat "$candidate/src/router/Makefile.ipq60xx" \
        >/dev/null 2>>"$SOURCE_ATTEMPTS"; then
      printf '%s\n' "$candidate" > "$REVIEW_DIR/selected-ddwrt-source-url.txt"
      return 0
    fi
  done
  return 1
}

if ! select_ddwrt_source; then
  printf 'BLOCKED_DDWRT_SOURCE_UNAVAILABLE\n' > "$STATUS_FILE"
  exit 1
fi
SELECTED_URL="$(cat "$REVIEW_DIR/selected-ddwrt-source-url.txt")"

echo "Fetching verified RA72 GPL DTS reference..."
timeout 20m git clone --depth=1 --branch "$REFERENCE_REF" \
  "$REFERENCE_REPOSITORY" "$REFERENCE_DIR"
git -C "$REFERENCE_DIR" rev-parse HEAD \
  > "$REVIEW_DIR/reference-commit.txt"

BOARD_REFERENCE="$(find "$REFERENCE_DIR/target/linux/qualcommax" -type f \
  -name 'ipq5018-ax6000.dts' -print -quit)"
if [[ -z "$BOARD_REFERENCE" ]] \
    || ! grep -q 'xiaomi,ax6000' "$BOARD_REFERENCE"; then
  printf 'BLOCKED_VERIFIED_RA72_DTS_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi
printf '%s\n' "${BOARD_REFERENCE#"$REFERENCE_DIR/"}" \
  > "$REVIEW_DIR/reference-board-dts-path.txt"

echo "Selecting the native DD-WRT IPQ5018 kernel tree..."
DDWRT_KERNEL_REL=""
for candidate in \
  "src/linux/universal/linux-6.12-nss" \
  "src/linux/universal/linux-6.12" \
  "src/linux/universal/linux-6.6-nss" \
  "src/linux/universal/linux-6.6" \
  "src/linux/universal/linux-6.1"; do
  if timeout 5m svn info \
      "$SELECTED_URL/$candidate/arch/arm64/boot/dts/qcom/ipq5018.dtsi" \
      >/dev/null 2>&1; then
    DDWRT_KERNEL_REL="$candidate"
    break
  fi
done

if [[ -z "$DDWRT_KERNEL_REL" ]]; then
  printf 'BLOCKED_NATIVE_DDWRT_IPQ5018_BASE_NOT_FOUND\n' > "$STATUS_FILE"
  exit 1
fi
printf '%s\n' "$DDWRT_KERNEL_REL" > "$REVIEW_DIR/ddwrt-kernel-path.txt"

echo "Exporting the required DD-WRT source sections..."
timeout 35m svn export --force \
  "$SELECTED_URL/$DDWRT_KERNEL_REL/arch/arm64/boot/dts/qcom" \
  "$QCOM_ORIGINAL" >/dev/null
timeout 20m svn export --force \
  "$SELECTED_URL/$DDWRT_KERNEL_REL/include/dt-bindings" \
  "$BINDINGS_DIR" >/dev/null
timeout 10m svn cat "$SELECTED_URL/src/router/Makefile.ipq60xx" \
  > "$ROUTER_MAKEFILE_ORIGINAL"

cp -a "$QCOM_ORIGINAL" "$QCOM_STAGE"
cp "$ROUTER_MAKEFILE_ORIGINAL" "$ROUTER_MAKEFILE_STAGE"
BOARD_STAGE="$QCOM_STAGE/ipq5018-xiaomi-ra72.dts"
cp "$BOARD_REFERENCE" "$BOARD_STAGE"

echo "Adapting the verified RA72 board DTS to the native DD-WRT base..."
python3 - "$BOARD_STAGE" "$QCOM_STAGE" \
  "$REFERENCE_DIR/target/linux/qualcommax" "$REVIEW_DIR" <<'PY'
from __future__ import annotations

import hashlib
import pathlib
import re
import sys
import textwrap

board = pathlib.Path(sys.argv[1])
qcom = pathlib.Path(sys.argv[2])
reference_root = pathlib.Path(sys.argv[3])
review = pathlib.Path(sys.argv[4])
labels = ("q6_region", "q6_etr_region")


def balanced_block(text: str, pattern: re.Pattern[str]) -> tuple[int, int, str] | None:
    match = pattern.search(text)
    if not match:
        return None
    brace = text.find("{", match.start())
    depth = 0
    quoted = False
    escaped = False
    for index in range(brace, len(text)):
        char = text[index]
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
            continue
        if char == '"':
            quoted = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                semicolon = text.find(";", index)
                if semicolon < 0:
                    return None
                return match.start(), semicolon + 1, text[match.start():semicolon + 1]
    return None


def labelled_node(text: str, label: str) -> str | None:
    pattern = re.compile(
        rf"(?m)^[ \t]*{re.escape(label)}\s*:\s*[-A-Za-z0-9,._+@]+\s*\{{"
    )
    result = balanced_block(text, pattern)
    return result[2] if result else None


board_text = board.read_text(encoding="utf-8")
native_text = "\n".join(
    path.read_text(encoding="utf-8", errors="ignore")
    for path in qcom.glob("*.dts*")
)

# The upstream &ge_phy overlay is omitted only when the native DD-WRT tree has
# no matching label. No other board hardware node is removed.
if not re.search(r"(?m)^[ \t]*ge_phy\s*:", native_text):
    pattern = re.compile(r"(?m)^[ \t]*&ge_phy[ \t]*\{")
    result = balanced_block(board_text, pattern)
    if result:
        start, end, _ = result
        board_text = (
            board_text[:start]
            + "/* Phase 22: upstream-only &ge_phy overlay omitted for the "
              "native DD-WRT base. */\n"
            + board_text[end:]
        )

reference_files = sorted(
    (path for path in reference_root.rglob("*")
     if path.suffix in {".dts", ".dtsi"}),
    key=lambda path: (0 if "ipq5018" in path.name.lower() else 1, str(path)),
)

found: dict[str, tuple[pathlib.Path, str]] = {}
for label in labels:
    for path in reference_files:
        node = labelled_node(path.read_text(encoding="utf-8", errors="ignore"), label)
        if node:
            found[label] = (path, node)
            break

missing = [label for label in labels if label not in found]
if missing:
    raise SystemExit("Exact verified Q6 definitions missing: " + ", ".join(missing))

rows = ["label\tsource\tsha256"]
bundled = []
for label in labels:
    path, node = found[label]
    relative = path.relative_to(reference_root)
    digest = hashlib.sha256(node.encode()).hexdigest()
    rows.append(f"{label}\t{relative}\t{digest}")
    bundled.append(
        f"/* Exact source: {relative}; sha256: {digest} */\n{node}"
    )

(review / "q6-node-provenance.tsv").write_text(
    "\n".join(rows) + "\n", encoding="utf-8"
)
(review / "q6-reserved-memory-nodes.dtsi").write_text(
    "\n\n".join(bundled) + "\n", encoding="utf-8"
)

# Keep the generic DD-WRT ipq5018.dtsi untouched. Add exact missing Q6 nodes
# through a board-local reserved-memory overlay.
missing_native = [
    label for label in labels
    if not re.search(rf"(?m)^[ \t]*{re.escape(label)}\s*:", native_text)
]
if missing_native:
    additions = []
    for label in missing_native:
        _, node = found[label]
        additions.append(textwrap.indent(textwrap.dedent(node), "\t"))
    board_text = board_text.rstrip() + (
        "\n\n/* Phase 22: exact verified Q6 nodes required by the native "
        "DD-WRT IPQ5018 base. */\n"
        "&{/reserved-memory} {\n"
        + "\n\n".join(additions)
        + "\n};\n"
    )

board.write_text(board_text, encoding="utf-8")
(review / "ipq5018-xiaomi-ra72.review.dts").write_text(
    board_text, encoding="utf-8"
)
PY

echo "Registering the RA72 DTB and temporary Phase 21 image recipe..."
python3 - "$QCOM_STAGE/Makefile" "$ROUTER_MAKEFILE_STAGE" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

qcom_makefile = pathlib.Path(sys.argv[1])
router_makefile = pathlib.Path(sys.argv[2])
dtb_line = "dtb-$(CONFIG_ARCH_QCOM) += ipq5018-xiaomi-ra72.dtb"

qcom_text = qcom_makefile.read_text(encoding="utf-8")
if dtb_line not in qcom_text:
    lines = qcom_text.splitlines()
    positions = [
        index for index, line in enumerate(lines)
        if "ipq5018-" in line and ".dtb" in line
    ]
    if not positions:
        raise SystemExit("No native IPQ5018 DTB registration point found")
    lines.insert(positions[-1] + 1, dtb_line)
    qcom_text = "\n".join(lines) + "\n"
qcom_makefile.write_text(qcom_text, encoding="utf-8")

recipe = r"""#ra72-review
	cp $(ARCH)-uclibc/Image.itb.deflate $(ARCH)-uclibc/Image.itb
	tools/qcom/mkits.sh \
		-D xiaomi_mi_aiot_ax6000_ra72 \
		-o $(TOP)/$(ARCH)-uclibc/Image-ra72.itb.its \
		-k $(TOP)/$(ARCH)-uclibc/Image.itb \
		-C gzip \
		-d $(LINUXDIR)/arch/arm64/boot/dts/qcom/ipq5018-xiaomi-ra72.dtb \
		-a 0x41000000 \
		-e 0x41000000 \
		-c config@ra72 \
		-A arm64 \
		-v $(KERNELRELEASE)
	mkimage \
		-f $(TOP)/$(ARCH)-uclibc/Image-ra72.itb.its \
		$(TOP)/$(ARCH)-uclibc/Image-ra72.itb
	tools/qcom/ubinize-image.sh \
		--kernel $(TOP)/$(ARCH)-uclibc/Image-ra72.itb \
		--rootfs $(TOP)/$(ARCH)-uclibc/root.ipq5018 \
		$(TOP)/$(ARCH)-uclibc/xiaomi-mi-aiot-ax6000-ra72-review.ubi \
		-p 128KiB \
		-m 2048

"""

router_text = router_makefile.read_text(encoding="utf-8")
if "#ra72-review" not in router_text:
    marker = re.search(r"(?m)^#ax89[ \t]*$", router_text)
    if not marker:
        raise SystemExit("Expected #ax89 insertion marker not found")
    router_text = router_text[:marker.start()] + recipe + router_text[marker.start():]
router_makefile.write_text(router_text, encoding="utf-8")
PY

cp "$QCOM_STAGE/Makefile" "$REVIEW_DIR/qcom-Makefile.review"
cp "$ROUTER_MAKEFILE_STAGE" "$REVIEW_DIR/Makefile.ipq60xx.review"

echo "Resolving device-tree binding includes in the temporary compile tree..."
while IFS= read -r include; do
  relative="${include#dt-bindings/}"
  target="$BINDINGS_DIR/$relative"
  if [[ -L "$target" ]]; then
    rm -f "$target"
  fi
  if [[ ! -f "$target" ]]; then
    mkdir -p "$(dirname "$target")"
    curl --fail --location --silent --show-error \
      "$LINUX_DT_BINDINGS_URL/$relative" --output "$target"
  fi
done < <(grep -RhoE '<dt-bindings/[^>]+>' "$QCOM_STAGE" \
  | tr -d '<>' | sort -u)

CPP_LOG="$REVIEW_DIR/cpp.log"
DTC_LOG="$REVIEW_DIR/dtc-compile.log"
ROUNDTRIP_LOG="$REVIEW_DIR/dtc-roundtrip.log"

set +e
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
  -I "$QCOM_STAGE" -I "$WORK_DIR" \
  "$BOARD_STAGE" "$REVIEW_DIR/ra72.preprocessed.dts" \
  >"$CPP_LOG" 2>&1
cpp_status=$?

if [[ "$cpp_status" -eq 0 ]]; then
  dtc -@ -I dts -O dtb -o "$REVIEW_DIR/ipq5018-xiaomi-ra72.review.dtb" \
    "$REVIEW_DIR/ra72.preprocessed.dts" >"$DTC_LOG" 2>&1
  dtc_status=$?
else
  dtc_status=99
fi

if [[ "$dtc_status" -eq 0 ]]; then
  dtc -I dtb -O dts -o "$REVIEW_DIR/ra72.decompiled.dts" \
    "$REVIEW_DIR/ipq5018-xiaomi-ra72.review.dtb" >>"$DTC_LOG" 2>&1
  decompile_status=$?
else
  decompile_status=99
fi

if [[ "$decompile_status" -eq 0 ]]; then
  dtc -I dts -O dtb -o "$REVIEW_DIR/ra72.roundtrip.dtb" \
    "$REVIEW_DIR/ra72.decompiled.dts" >"$ROUNDTRIP_LOG" 2>&1
  roundtrip_status=$?
else
  roundtrip_status=99
fi
set -e

{
  echo "cpp_status=$cpp_status"
  echo "dtc_status=$dtc_status"
  echo "decompile_status=$decompile_status"
  echo "roundtrip_status=$roundtrip_status"
} | tee "$REVIEW_DIR/compile-status.txt"

if [[ "$cpp_status" -ne 0 || "$dtc_status" -ne 0 \
    || "$decompile_status" -ne 0 || "$roundtrip_status" -ne 0 ]]; then
  printf 'BLOCKED_RA72_DTS_COMPILE_FAILED\n' > "$STATUS_FILE"
  exit 1
fi

sha256sum \
  "$REVIEW_DIR/ipq5018-xiaomi-ra72.review.dtb" \
  "$REVIEW_DIR/ra72.roundtrip.dtb" \
  > "$REVIEW_DIR/dtb-sha256.txt"

PATCH_FILE="$PATCH_DIR/0001-ddwrt-add-xiaomi-mi-aiot-ax6000-ra72-review.patch"
echo "Generating the unified review patch..."
python3 - "$QCOM_ORIGINAL/Makefile" "$QCOM_STAGE/Makefile" \
  "$BOARD_STAGE" "$ROUTER_MAKEFILE_ORIGINAL" "$ROUTER_MAKEFILE_STAGE" \
  "$PATCH_FILE" "$DDWRT_KERNEL_REL" <<'PY'
from __future__ import annotations

import difflib
import pathlib
import sys

qcom_old = pathlib.Path(sys.argv[1])
qcom_new = pathlib.Path(sys.argv[2])
board = pathlib.Path(sys.argv[3])
router_old = pathlib.Path(sys.argv[4])
router_new = pathlib.Path(sys.argv[5])
patch_path = pathlib.Path(sys.argv[6])
kernel_rel = sys.argv[7]
qcom_rel = f"{kernel_rel}/arch/arm64/boot/dts/qcom"


def lines(path: pathlib.Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines(keepends=True)


parts = []
parts.extend(difflib.unified_diff(
    lines(qcom_old),
    lines(qcom_new),
    fromfile=f"a/{qcom_rel}/Makefile",
    tofile=f"b/{qcom_rel}/Makefile",
))
parts.extend(difflib.unified_diff(
    [],
    lines(board),
    fromfile="/dev/null",
    tofile=f"b/{qcom_rel}/ipq5018-xiaomi-ra72.dts",
))
parts.extend(difflib.unified_diff(
    lines(router_old),
    lines(router_new),
    fromfile="a/src/router/Makefile.ipq60xx",
    tofile="b/src/router/Makefile.ipq60xx",
))

patch_path.write_text("".join(parts), encoding="utf-8")
PY

echo "Validating that the unified patch applies to an untouched layout..."
PATCH_CHECK_ROOT="$WORK_DIR/patch-check"
QCOM_CHECK="$PATCH_CHECK_ROOT/$DDWRT_KERNEL_REL/arch/arm64/boot/dts/qcom"
mkdir -p "$QCOM_CHECK" "$PATCH_CHECK_ROOT/src/router"
cp "$QCOM_ORIGINAL/Makefile" "$QCOM_CHECK/Makefile"
cp "$ROUTER_MAKEFILE_ORIGINAL" \
  "$PATCH_CHECK_ROOT/src/router/Makefile.ipq60xx"
patch --dry-run --batch -p1 -d "$PATCH_CHECK_ROOT" < "$PATCH_FILE" \
  > "$REVIEW_DIR/patch-dry-run.log" 2>&1
patch --batch -p1 -d "$PATCH_CHECK_ROOT" < "$PATCH_FILE" \
  > "$REVIEW_DIR/patch-apply.log" 2>&1
cmp "$QCOM_CHECK/Makefile" "$QCOM_STAGE/Makefile"
cmp "$QCOM_CHECK/ipq5018-xiaomi-ra72.dts" "$BOARD_STAGE"
cmp "$PATCH_CHECK_ROOT/src/router/Makefile.ipq60xx" \
  "$ROUTER_MAKEFILE_STAGE"

echo "Running Phase 22 integration checks..."
python3 - "$BOARD_STAGE" "$REVIEW_DIR/ra72.decompiled.dts" \
  "$QCOM_STAGE/Makefile" "$ROUTER_MAKEFILE_STAGE" "$PATCH_FILE" \
  "$REVIEW_DIR/phase22-integration-checks.txt" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

board = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
decompiled = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
qcom_makefile = pathlib.Path(sys.argv[3]).read_text(encoding="utf-8")
router_makefile = pathlib.Path(sys.argv[4]).read_text(encoding="utf-8")
patch = pathlib.Path(sys.argv[5]).read_text(encoding="utf-8")
output = pathlib.Path(sys.argv[6])

match = re.search(
    r"(?ms)^#ra72-review[ \t]*\n(.*?)(?=^#[A-Za-z0-9]|\Z)",
    router_makefile,
)
recipe = match.group(0) if match else ""

checks = {
    "exact_compatible_xiaomi_ax6000": "xiaomi,ax6000" in board,
    "soc_compatible_ipq5018": "qcom,ipq5018" in board or "ipq5018" in board,
    "qca8337_switch_address_11": "ethernet-switch@11" in board,
    "qca8081_phy_address_8": "ethernet-phy@8" in board,
    "lan1_label_present": 'label = "lan1"' in decompiled,
    "lan2_label_present": 'label = "lan2"' in decompiled,
    "lan3_label_present": 'label = "lan3"' in decompiled,
    "wan_label_present": 'label = "wan"' in decompiled,
    "q6_region_present": "q6_region:" in board,
    "q6_etr_region_present": "q6_etr_region:" in board,
    "qcom_makefile_registers_ra72_dtb":
        "ipq5018-xiaomi-ra72.dtb" in qcom_makefile,
    "router_makefile_has_ra72_recipe": bool(recipe),
    "recipe_uses_exact_ra72_identity":
        "xiaomi_mi_aiot_ax6000_ra72" in recipe,
    "recipe_uses_ra72_dtb": "ipq5018-xiaomi-ra72.dtb" in recipe,
    "recipe_uses_ipq5018_rootfs": "root.ipq5018" in recipe,
    "recipe_uses_kernel_rootfs_ubi":
        "--kernel" in recipe and "--rootfs" in recipe,
    "recipe_uses_128k_peb": "-p 128KiB" in recipe,
    "recipe_uses_2048_min_io": "-m 2048" in recipe,
    "recipe_excludes_linksys_footer": ".LINKSYS" not in recipe,
    "recipe_excludes_linksys_models":
        not re.search(r"\b(?:MR5500|MX5500)\b", recipe, re.IGNORECASE),
    "recipe_excludes_trx_wrapper":
        not re.search(r"\btrx_n\b", recipe),
    "recipe_excludes_flash_commands":
        not re.search(
            r"\b(?:ubiformat|sysupgrade|fw_setenv|mtd[ \t]+write)\b",
            recipe,
            re.IGNORECASE,
        ),
    "unified_patch_contains_new_ra72_dts":
        "ipq5018-xiaomi-ra72.dts" in patch,
    "unified_patch_contains_makefile_integration":
        "Makefile.ipq60xx" in patch and "ipq5018-xiaomi-ra72.dtb" in patch,
}

output.write_text(
    "\n".join(
        f"{name}={'PASS' if value else 'FAIL'}"
        for name, value in sorted(checks.items())
    ) + "\n",
    encoding="utf-8",
)

failed = [name for name, value in checks.items() if not value]
if failed:
    print("Failed Phase 22 checks:", ", ".join(failed))
    raise SystemExit(1)
print(f"Phase 22 integration checks passed: {len(checks)}/{len(checks)}")
PY

printf 'RA72_SOURCE_INTEGRATION_PATCH_COMPILES_REVIEW_ONLY\n' > "$STATUS_FILE"

CHECK_COUNT="$(grep -c '=PASS$' "$REVIEW_DIR/phase22-integration-checks.txt")"
cat <<EOF

Phase 22 result
---------------
STATUS: RA72_SOURCE_INTEGRATION_PATCH_COMPILES_REVIEW_ONLY

Verified:
- Native DD-WRT kernel tree: $DDWRT_KERNEL_REL
- Exact RA72 DTS preprocess and compile: PASS
- DTB decompile and round-trip compile: PASS
- Qualcomm DTS Makefile integration: PASS
- Temporary Makefile.ipq60xx recipe integration: PASS
- Unified patch dry-run and application: PASS
- Integration checks: $CHECK_COUNT/$CHECK_COUNT PASS

Review patch:
patches/0001-ddwrt-add-xiaomi-mi-aiot-ax6000-ra72-review.patch

Safety:
No DD-WRT firmware was built. No UBI, BIN, or flashable image exists.
No router, SSH session, UART, NAND partition, or boot variable was accessed.
The patch is not boot-tested or flash-approved.
EOF

echo
echo "Phase 22 completed: $(cat "$STATUS_FILE")"
