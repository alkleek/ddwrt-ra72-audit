#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="$PWD/phase27-output"
REVIEW_DIR="$OUT_DIR/review"
PATCH_DIR="$OUT_DIR/patches"
WORK_DIR="$OUT_DIR/work"
REPORT="$OUT_DIR/REPORT-PHASE27.txt"
STATUS_FILE="$REVIEW_DIR/phase27-status.txt"

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
LINUX_INCLUDE_URL="${LINUX_INCLUDE_URL:-https://raw.githubusercontent.com/torvalds/linux/master/include}"

rm -rf "$OUT_DIR"
mkdir -p "$REVIEW_DIR" "$PATCH_DIR" "$WORK_DIR"

cat > "$OUT_DIR/DO-NOT-FLASH.txt" <<'EOF'
PHASE 27 IS A DD-WRT SOURCE-INTEGRATION AND DEVICE-TREE COMPILE AUDIT ONLY.
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
  echo "Phase 27 stopped with status $(cat "$STATUS_FILE") (exit $code)."
  exit "$code"
}

trap cleanup EXIT
trap on_error ERR
exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 27 temporary source integration and DTS compile"
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
adapt_status=0
python3 - "$BOARD_STAGE" "$QCOM_STAGE" \
  "$REFERENCE_DIR/target/linux/qualcommax" "$REVIEW_DIR" \
  <<'PY' || adapt_status=$?
from __future__ import annotations

import pathlib
import re
import sys

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


board_text = board.read_text(encoding="utf-8")
native_base = qcom / "ipq5018.dtsi"
if not native_base.is_file():
    raise SystemExit("Native DD-WRT ipq5018.dtsi was not exported")
native_base_text = native_base.read_text(encoding="utf-8")

# DD-WRT already carries the IPQ5018 internal GE PHY at MDIO address 7, but
# this native baseline names the node ethernet-phy@0 and does not label it.
# The imported RA72 board and native dp1 node both reference &ge_phy. Label
# that exact existing node and correct its unit address; never add a duplicate.
ge_phy_referenced = bool(
    re.search(r"&ge_phy\b", board_text)
    or re.search(r"&ge_phy\b", native_base_text)
)
ge_phy_label_before = bool(
    re.search(r"(?m)^[ \t]*ge_phy\s*:", native_base_text)
)
candidate_pattern = re.compile(
    r"(?m)^(?P<indent>[ \t]*)"
    r"(?:(?P<label>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*)?"
    r"ethernet-phy@(?P<unit>[0-9a-fA-F]+)[ \t]*\{"
)
ge_phy_candidates: list[re.Match[str]] = []
for match in candidate_pattern.finditer(native_base_text):
    exact_header = re.compile(re.escape(match.group(0)))
    result = balanced_block(native_base_text, exact_header)
    if not result:
        continue
    _, _, block = result
    if (
        'compatible = "ethernet-phy-id004d.d0c0"' in block
        and re.search(r"(?m)^[ \t]*reg[ \t]*=[ \t]*<7>[ \t]*;", block)
    ):
        ge_phy_candidates.append(match)

ge_phy_action = "USE_NATIVE_LABELED_NODE"
original_unit = "7"
if ge_phy_referenced and not ge_phy_label_before:
    if len(ge_phy_candidates) != 1:
        raise SystemExit(
            "Expected exactly one existing IPQ5018 internal GE PHY candidate; "
            f"found {len(ge_phy_candidates)}"
        )
    candidate = ge_phy_candidates[0]
    original_unit = candidate.group("unit")
    replacement = candidate.group("indent") + "ge_phy: ethernet-phy@7 {"
    native_base_text = (
        native_base_text[:candidate.start()]
        + replacement
        + native_base_text[candidate.end():]
    )
    native_base.write_text(native_base_text, encoding="utf-8")
    ge_phy_action = "LABEL_EXISTING_INTERNAL_PHY_AND_NORMALIZE_UNIT_ADDRESS"

ge_phy_label_after = bool(
    re.search(
        r"(?m)^[ \t]*ge_phy\s*:\s*ethernet-phy@7[ \t]*\{",
        native_base_text,
    )
)
if ge_phy_referenced and not ge_phy_label_after:
    raise SystemExit("The required ge_phy label was not integrated")

(review / "ge-phy-resolution.txt").write_text(
    "\n".join(
        [
            f"ge_phy_referenced={'YES' if ge_phy_referenced else 'NO'}",
            f"native_label_before={'YES' if ge_phy_label_before else 'NO'}",
            f"matching_internal_phy_candidates={len(ge_phy_candidates)}",
            f"original_unit_address={original_unit}",
            f"action={ge_phy_action}",
            f"native_label_after={'YES' if ge_phy_label_after else 'NO'}",
        ]
    )
    + "\n",
    encoding="utf-8",
)

native_text = "\n".join(
    path.read_text(encoding="utf-8", errors="ignore")
    for path in qcom.glob("*.dts*")
)

# The current verified RA72 DTS no longer references q6_region or
# q6_etr_region. Phase 22 failed because it required both historical labels
# even when the current board source did not use them. Phase 27 treats a label
# as required only when the imported board DTS actually references it.
resolution_rows = ["label\treferenced_by_board\tdefined_in_native\taction"]
unresolved = []
for label in labels:
    referenced = bool(re.search(rf"&{re.escape(label)}\b", board_text))
    defined_native = bool(
        re.search(rf"(?m)^[ \t]*{re.escape(label)}\s*:", native_text)
    )
    if referenced and not defined_native:
        unresolved.append(label)
        action = "BLOCKED_UNRESOLVED_REFERENCE"
    elif referenced:
        action = "USE_NATIVE_DEFINITION"
    else:
        action = "NOT_REQUIRED_BY_CURRENT_RA72_DTS"
    resolution_rows.append(
        f"{label}\t{'YES' if referenced else 'NO'}"
        f"\t{'YES' if defined_native else 'NO'}\t{action}"
    )

(review / "q6-resolution.tsv").write_text(
    "\n".join(resolution_rows) + "\n", encoding="utf-8"
)
if unresolved:
    raise SystemExit(
        "Current RA72 DTS has unresolved Q6 references: "
        + ", ".join(unresolved)
    )

board.write_text(board_text, encoding="utf-8")
(review / "ipq5018-xiaomi-ra72.review.dts").write_text(
    board_text, encoding="utf-8"
)
PY
if [[ "$adapt_status" -ne 0 ]]; then
  printf 'BLOCKED_CURRENT_RA72_DTS_HAS_UNRESOLVED_DEPENDENCIES\n' \
    > "$STATUS_FILE"
  exit 1
fi

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

echo "Resolving only the include closure used by the RA72 board DTS..."
BINDING_LOG="$REVIEW_DIR/binding-resolution.log"
REQUIRED_INCLUDES="$REVIEW_DIR/required-include-closure.txt"
MISSING_BINDINGS="$REVIEW_DIR/missing-binding-includes.txt"
MATERIALIZED_SYMLINKS="$REVIEW_DIR/materialized-binding-symlinks.txt"
: > "$BINDING_LOG"
: > "$MATERIALIZED_SYMLINKS"

binding_resolution_complete=0
for pass in 1 2 3 4 5 6 7 8; do
  echo "Dependency-closure pass $pass" | tee -a "$BINDING_LOG"
  closure_status=0
  python3 - "$BOARD_STAGE" "$QCOM_STAGE" "$BINDINGS_DIR" \
    "$REQUIRED_INCLUDES" "$MISSING_BINDINGS" \
    "$REVIEW_DIR/unresolved-source-includes.txt" \
    <<'PY' || closure_status=$?
from __future__ import annotations

import pathlib
import re
import sys

board = pathlib.Path(sys.argv[1])
qcom_root = pathlib.Path(sys.argv[2])
bindings_root = pathlib.Path(sys.argv[3])
required_output = pathlib.Path(sys.argv[4])
missing_output = pathlib.Path(sys.argv[5])
unresolved_output = pathlib.Path(sys.argv[6])

include_re = re.compile(
    r'(?m)^[ \t]*#[ \t]*include[ \t]+[<"]([^">]+)[">]'
)
queue = [board]
visited: set[pathlib.Path] = set()
required: set[str] = set()
missing_bindings: set[str] = set()
unresolved_sources: set[str] = set()

while queue:
    current = queue.pop()
    current_key = current.absolute()
    if current_key in visited:
        continue
    if not current.is_file():
        unresolved_sources.add(str(current))
        continue
    visited.add(current_key)
    try:
        relative = current.relative_to(qcom_root)
        required.add(f"qcom/{relative.as_posix()}")
    except ValueError:
        try:
            relative = current.relative_to(bindings_root)
            required.add(f"dt-bindings/{relative.as_posix()}")
        except ValueError:
            required.add(str(current))

    text = current.read_text(encoding="utf-8", errors="ignore")
    for include in include_re.findall(text):
        if include.startswith("dt-bindings/"):
            relative = pathlib.Path(include.removeprefix("dt-bindings/"))
            target = bindings_root / relative
            if target.is_file():
                queue.append(target)
            else:
                missing_bindings.add(include)
            continue

        # Quoted includes are resolved relative to their current file first,
        # then from the Qualcomm DTS root.
        candidates = (current.parent / include, qcom_root / include)
        target = next((item for item in candidates if item.is_file()), None)
        if target is not None:
            queue.append(target)
        elif include.endswith((".dts", ".dtsi", ".h")):
            # Binding headers can include sibling headers with quotes, for
            # example input.h -> linux-event-codes.h. Classify those as
            # missing dt-bindings so the scoped fetcher can retrieve them.
            sibling = current.parent / include
            try:
                relative = sibling.relative_to(bindings_root)
            except ValueError:
                unresolved_sources.add(f"{current}: {include}")
            else:
                missing_bindings.add(
                    f"dt-bindings/{relative.as_posix()}"
                )

required_output.write_text(
    "\n".join(sorted(required)) + "\n", encoding="utf-8"
)
missing_output.write_text(
    "\n".join(sorted(missing_bindings))
    + ("\n" if missing_bindings else ""),
    encoding="utf-8",
)
unresolved_output.write_text(
    "\n".join(sorted(unresolved_sources))
    + ("\n" if unresolved_sources else ""),
    encoding="utf-8",
)

if unresolved_sources:
    print("Unresolved source includes:")
    for item in sorted(unresolved_sources):
        print(item)
    raise SystemExit(2)
PY

  if [[ "$closure_status" -ne 0 ]]; then
    printf 'BLOCKED_RA72_SOURCE_INCLUDE_UNRESOLVED\n' > "$STATUS_FILE"
    exit 1
  fi

  if [[ ! -s "$MISSING_BINDINGS" ]]; then
    binding_resolution_complete=1
    break
  fi

  fetch_failed=0
  while IFS= read -r include; do
    [[ -n "$include" ]] || continue
    relative="${include#dt-bindings/}"
    target="$BINDINGS_DIR/$relative"
    if [[ -L "$target" ]]; then
      rm -f "$target"
    fi
    if [[ ! -f "$target" ]]; then
      mkdir -p "$(dirname "$target")"
      echo "FETCH $include" | tee -a "$BINDING_LOG"
      if ! curl --fail --location --silent --show-error \
          "$LINUX_DT_BINDINGS_URL/$relative" --output "$target" \
          >>"$BINDING_LOG" 2>&1; then
        echo "FAILED $include" | tee -a "$BINDING_LOG"
        fetch_failed=1
        break
      fi

      # Git stores some dt-binding headers as symbolic links. Raw content
      # services return the link target path as a one-line blob instead of
      # returning the target header. Materialize such links into the original
      # dt-bindings location so cpp sees real C preprocessor definitions.
      logical_path="dt-bindings/$relative"
      for link_depth in 1 2 3 4 5 6 7 8; do
        resolved_target="$(
          python3 - "$target" "$logical_path" <<'PY'
import pathlib
import posixpath
import re
import sys

file_path = pathlib.Path(sys.argv[1])
logical_path = sys.argv[2]
text = file_path.read_text(encoding="utf-8", errors="strict").strip()

if "\n" in text or "\r" in text:
    raise SystemExit(0)
if not re.fullmatch(r"(?:\.\.?/)*[A-Za-z0-9_.+/-]+\.(?:h|dts|dtsi)", text):
    raise SystemExit(0)

resolved = posixpath.normpath(
    posixpath.join(posixpath.dirname(logical_path), text)
)
if resolved == ".." or resolved.startswith("../") or resolved.startswith("/"):
    raise SystemExit("Unsafe Linux include symlink target")
print(resolved)
PY
        )"

        if [[ -z "$resolved_target" ]]; then
          break
        fi

        echo "MATERIALIZE $logical_path -> $resolved_target" \
          | tee -a "$BINDING_LOG" "$MATERIALIZED_SYMLINKS"
        if ! curl --fail --location --silent --show-error \
            "$LINUX_INCLUDE_URL/$resolved_target" \
            --output "$target.materialized" \
            >>"$BINDING_LOG" 2>&1; then
          echo "FAILED symlink target $resolved_target" \
            | tee -a "$BINDING_LOG"
          rm -f "$target.materialized"
          fetch_failed=1
          break
        fi
        mv "$target.materialized" "$target"
        logical_path="$resolved_target"
      done

      if [[ "$fetch_failed" -ne 0 ]]; then
        break
      fi
    fi
  done < "$MISSING_BINDINGS"

  if [[ "$fetch_failed" -ne 0 ]]; then
    printf 'BLOCKED_REQUIRED_RA72_BINDING_FETCH_FAILED\n' > "$STATUS_FILE"
    exit 1
  fi
done

if [[ "$binding_resolution_complete" -ne 1 ]]; then
  printf 'BLOCKED_RA72_BINDING_CLOSURE_DID_NOT_CONVERGE\n' > "$STATUS_FILE"
  exit 1
fi
echo "RA72 dependency closure resolved." | tee -a "$BINDING_LOG"

CPP_LOG="$REVIEW_DIR/cpp.log"
DTC_LOG="$REVIEW_DIR/dtc-compile.log"
ROUNDTRIP_LOG="$REVIEW_DIR/dtc-roundtrip.log"

cpp_status=0
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
  -I "$QCOM_STAGE" -I "$WORK_DIR" \
  "$BOARD_STAGE" "$REVIEW_DIR/ra72.preprocessed.dts" \
  >"$CPP_LOG" 2>&1 || cpp_status=$?

if [[ "$cpp_status" -eq 0 ]]; then
  dtc_status=0
  dtc -@ -I dts -O dtb -o "$REVIEW_DIR/ipq5018-xiaomi-ra72.review.dtb" \
    "$REVIEW_DIR/ra72.preprocessed.dts" >"$DTC_LOG" 2>&1 \
    || dtc_status=$?
else
  dtc_status=99
fi

if [[ "$dtc_status" -eq 0 ]]; then
  decompile_status=0
  dtc -I dtb -O dts -o "$REVIEW_DIR/ra72.decompiled.dts" \
    "$REVIEW_DIR/ipq5018-xiaomi-ra72.review.dtb" >>"$DTC_LOG" 2>&1 \
    || decompile_status=$?
else
  decompile_status=99
fi

if [[ "$decompile_status" -eq 0 ]]; then
  roundtrip_status=0
  dtc -I dts -O dtb -o "$REVIEW_DIR/ra72.roundtrip.dtb" \
    "$REVIEW_DIR/ra72.decompiled.dts" >"$ROUNDTRIP_LOG" 2>&1 \
    || roundtrip_status=$?
else
  roundtrip_status=99
fi

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
  "$QCOM_ORIGINAL/ipq5018.dtsi" "$QCOM_STAGE/ipq5018.dtsi" \
  "$BOARD_STAGE" "$ROUTER_MAKEFILE_ORIGINAL" "$ROUTER_MAKEFILE_STAGE" \
  "$PATCH_FILE" "$DDWRT_KERNEL_REL" <<'PY'
from __future__ import annotations

import difflib
import pathlib
import sys

qcom_old = pathlib.Path(sys.argv[1])
qcom_new = pathlib.Path(sys.argv[2])
base_old = pathlib.Path(sys.argv[3])
base_new = pathlib.Path(sys.argv[4])
board = pathlib.Path(sys.argv[5])
router_old = pathlib.Path(sys.argv[6])
router_new = pathlib.Path(sys.argv[7])
patch_path = pathlib.Path(sys.argv[8])
kernel_rel = sys.argv[9]
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
    lines(base_old),
    lines(base_new),
    fromfile=f"a/{qcom_rel}/ipq5018.dtsi",
    tofile=f"b/{qcom_rel}/ipq5018.dtsi",
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
cp "$QCOM_ORIGINAL/ipq5018.dtsi" "$QCOM_CHECK/ipq5018.dtsi"
cp "$ROUTER_MAKEFILE_ORIGINAL" \
  "$PATCH_CHECK_ROOT/src/router/Makefile.ipq60xx"
patch --dry-run --batch -p1 -d "$PATCH_CHECK_ROOT" < "$PATCH_FILE" \
  > "$REVIEW_DIR/patch-dry-run.log" 2>&1
patch --batch -p1 -d "$PATCH_CHECK_ROOT" < "$PATCH_FILE" \
  > "$REVIEW_DIR/patch-apply.log" 2>&1
cmp "$QCOM_CHECK/Makefile" "$QCOM_STAGE/Makefile"
cmp "$QCOM_CHECK/ipq5018.dtsi" "$QCOM_STAGE/ipq5018.dtsi"
cmp "$QCOM_CHECK/ipq5018-xiaomi-ra72.dts" "$BOARD_STAGE"
cmp "$PATCH_CHECK_ROOT/src/router/Makefile.ipq60xx" \
  "$ROUTER_MAKEFILE_STAGE"

echo "Running Phase 27 integration checks..."
python3 - "$BOARD_STAGE" "$REVIEW_DIR/ra72.decompiled.dts" \
  "$QCOM_STAGE/Makefile" "$ROUTER_MAKEFILE_STAGE" "$PATCH_FILE" \
  "$REVIEW_DIR/q6-resolution.tsv" \
  "$REVIEW_DIR/required-include-closure.txt" \
  "$REVIEW_DIR/binding-resolution.log" \
  "$REVIEW_DIR/materialized-binding-symlinks.txt" \
  "$QCOM_STAGE/ipq5018.dtsi" \
  "$REVIEW_DIR/ge-phy-resolution.txt" \
  "$REVIEW_DIR/phase27-integration-checks.txt" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

board = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
decompiled = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
qcom_makefile = pathlib.Path(sys.argv[3]).read_text(encoding="utf-8")
router_makefile = pathlib.Path(sys.argv[4]).read_text(encoding="utf-8")
patch = pathlib.Path(sys.argv[5]).read_text(encoding="utf-8")
q6_resolution = pathlib.Path(sys.argv[6]).read_text(encoding="utf-8")
required_includes = pathlib.Path(sys.argv[7]).read_text(encoding="utf-8")
binding_log = pathlib.Path(sys.argv[8]).read_text(encoding="utf-8")
materialized_symlinks = pathlib.Path(sys.argv[9]).read_text(encoding="utf-8")
native_base = pathlib.Path(sys.argv[10]).read_text(encoding="utf-8")
ge_phy_resolution = pathlib.Path(sys.argv[11]).read_text(encoding="utf-8")
output = pathlib.Path(sys.argv[12])

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
    "q6_dependencies_resolved_dynamically":
        "BLOCKED_UNRESOLVED_REFERENCE" not in q6_resolution,
    "scoped_binding_closure_resolved":
        "RA72 dependency closure resolved." in binding_log,
    "linux_event_codes_symlink_materialized":
        "dt-bindings/input/linux-event-codes.h -> "
        "uapi/linux/input-event-codes.h" in materialized_symlinks,
    "native_ge_phy_label_targets_address_7":
        bool(re.search(
            r"(?m)^[ \t]*ge_phy\s*:\s*ethernet-phy@7[ \t]*\{",
            native_base,
        )),
    "native_ge_phy_matches_ipq5018_internal_phy":
        'compatible = "ethernet-phy-id004d.d0c0"' in native_base
        and bool(re.search(
            r"(?ms)ge_phy\s*:\s*ethernet-phy@7[ \t]*\{.*?"
            r"reg[ \t]*=[ \t]*<7>[ \t]*;",
            native_base,
        )),
    "ge_phy_existing_node_was_labeled":
        "action=LABEL_EXISTING_INTERNAL_PHY_AND_NORMALIZE_UNIT_ADDRESS"
        in ge_phy_resolution
        or "action=USE_NATIVE_LABELED_NODE" in ge_phy_resolution,
    "ra72_include_closure_recorded": bool(required_includes.strip()),
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
    "unified_patch_contains_native_ge_phy_label":
        "ipq5018.dtsi" in patch and "ge_phy: ethernet-phy@7" in patch,
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
    print("Failed Phase 27 checks:", ", ".join(failed))
    raise SystemExit(1)
print(f"Phase 27 integration checks passed: {len(checks)}/{len(checks)}")
PY

printf 'RA72_GE_PHY_LABEL_INTEGRATION_PATCH_COMPILES_REVIEW_ONLY\n' > "$STATUS_FILE"

CHECK_COUNT="$(grep -c '=PASS$' "$REVIEW_DIR/phase27-integration-checks.txt")"
cat <<EOF

Phase 27 result
---------------
STATUS: RA72_GE_PHY_LABEL_INTEGRATION_PATCH_COMPILES_REVIEW_ONLY

Verified:
- Native DD-WRT kernel tree: $DDWRT_KERNEL_REL
- Exact RA72 DTS preprocess and compile: PASS
- Native IPQ5018 GE PHY label and unit address: PASS
- RA72-only include/binding closure: PASS
- Linux dt-binding symlink materialization: PASS
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
echo "Phase 27 completed: $(cat "$STATUS_FILE")"
