#!/usr/bin/env bash
set -Eeuo pipefail

OUT="$PWD/phase13-output"
OPENWRT_DIR="$OUT/openwrt"
DDWRT_DIR="$OUT/ddwrt"
STAGE="$OUT/compile-stage"
REVIEW="$OUT/review"
REPORT="$OUT/REPORT-PHASE13.txt"

rm -rf "$OUT"
mkdir -p "$OPENWRT_DIR" "$DDWRT_DIR" "$STAGE" "$REVIEW"

cleanup_source_trees() {
  rm -rf "$OPENWRT_DIR" "$DDWRT_DIR"
}
trap cleanup_source_trees EXIT

exec > >(tee "$REPORT") 2>&1

echo "DD-WRT RA72 Phase 13 Q6 reserved-memory compiler audit"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: compiler audit only; no firmware is built and nothing is flashable."
echo

OPENWRT_REF="${OPENWRT_REF:-openwrt-25.12}"
OPENWRT_REPOSITORY="${OPENWRT_REPOSITORY:-https://github.com/openwrt/openwrt.git}"
DDWRT_SVN_URL="${DDWRT_SVN_URL:-https://svn.dd-wrt.com/DD-WRT}"
LINUX_DT_BINDINGS_URL="${LINUX_DT_BINDINGS_URL:-https://raw.githubusercontent.com/torvalds/linux/master/include/dt-bindings}"

git clone --filter=blob:none --no-checkout "$OPENWRT_REPOSITORY" "$OPENWRT_DIR"
git -C "$OPENWRT_DIR" fetch --depth=1 origin "$OPENWRT_REF"
git -C "$OPENWRT_DIR" checkout --detach FETCH_HEAD
git -C "$OPENWRT_DIR" rev-parse HEAD | tee "$REVIEW/openwrt-commit.txt"

BOARD_DTS="$(find "$OPENWRT_DIR/target/linux/qualcommax" -type f \
  \( -name 'ipq5018-ax6000.dts' -o -name '*ax6000*.dts' \) \
  -print | head -n 1)"

if [[ -z "$BOARD_DTS" ]] || ! grep -Eqi 'ax6000|ra72' "$BOARD_DTS"; then
  echo "BLOCKED: verified OpenWrt reference does not contain the RA72/AX6000 board DTS."
  printf 'BLOCKED: RA72 board DTS not found\n' > "$REVIEW/phase13-status.txt"
  exit 0
fi

printf '%s\n' "${BOARD_DTS#"$OPENWRT_DIR/"}" | tee "$REVIEW/openwrt-board-dts-path.txt"

svn export --force "$DDWRT_SVN_URL/src/linux/universal/linux-6.1/arch/arm64/boot/dts/qcom" \
  "$DDWRT_DIR/qcom" >/dev/null
svn export --force "$DDWRT_SVN_URL/src/linux/universal/linux-6.1/include/dt-bindings" \
  "$DDWRT_DIR/dt-bindings" >/dev/null

cp -a "$DDWRT_DIR/qcom/." "$STAGE/"
cp "$BOARD_DTS" "$STAGE/ra72-review.dts"

# The OpenWrt GE-PHY overlay is not part of the native DD-WRT IPQ5018 base.
# Remove that one overlay from the temporary review source only.
python3 - "$STAGE/ra72-review.dts" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
m = re.search(r'(?m)^[ \t]*&ge_phy[ \t]*\{', s)
if m:
    start = m.start()
    brace = s.find("{", m.start())
    depth = 0
    end = None
    for i in range(brace, len(s)):
        if s[i] == "{":
            depth += 1
        elif s[i] == "}":
            depth -= 1
            if depth == 0:
                semi = s.find(";", i)
                end = semi + 1
                break
    if end is None:
        raise SystemExit("Unable to isolate &ge_phy overlay safely")
    s = s[:start] + "/* Phase 13: OpenWrt-only &ge_phy overlay omitted for DD-WRT native-base audit. */\n" + s[end:]
p.write_text(s)
PY

# Locate exact Q6 reserved-memory definitions in the verified OpenWrt tree,
# preserve their source provenance, and inject them into the temporary native
# DD-WRT ipq5018.dtsi. No address or size is ever invented.
set +e
python3 - "$OPENWRT_DIR/target/linux/qualcommax" "$STAGE/ipq5018.dtsi" "$REVIEW" <<'PY'
import hashlib, pathlib, re, sys

root = pathlib.Path(sys.argv[1])
base = pathlib.Path(sys.argv[2])
review = pathlib.Path(sys.argv[3])
labels = ("q6_region", "q6_etr_region")

def balanced_node(text, label):
    pat = re.compile(rf'(?m)^[ \t]*{re.escape(label)}\s*:\s*[-A-Za-z0-9,._+@]+\s*\{{')
    m = pat.search(text)
    if not m:
        return None
    brace = text.find("{", m.start())
    depth = 0
    in_string = False
    escaped = False
    for i in range(brace, len(text)):
        c = text[i]
        if in_string:
            if escaped:
                escaped = False
            elif c == "\\":
                escaped = True
            elif c == '"':
                in_string = False
            continue
        if c == '"':
            in_string = True
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                semi = text.find(";", i)
                if semi < 0:
                    return None
                return text[m.start():semi + 1]
    return None

files = sorted(
    [p for p in root.rglob("*") if p.suffix in (".dts", ".dtsi")],
    key=lambda p: (0 if "ipq5018" in p.name.lower() else 1, str(p))
)
found = {}
for label in labels:
    for p in files:
        text = p.read_text(errors="ignore")
        node = balanced_node(text, label)
        if node:
            found[label] = (p, node)
            break

if len(found) != len(labels):
    missing = [x for x in labels if x not in found]
    (review / "phase13-status.txt").write_text(
        "BLOCKED: exact OpenWrt node definitions not found: " + ", ".join(missing) + "\n"
    )
    print("BLOCKED: exact node definitions missing:", ", ".join(missing))
    raise SystemExit(2)

rows = ["label\tsource\tsha256"]
bundle = []
for label in labels:
    p, node = found[label]
    rel = p.relative_to(root)
    digest = hashlib.sha256(node.encode()).hexdigest()
    rows.append(f"{label}\t{rel}\t{digest}")
    bundle.append(f"/* Exact source: {rel}; sha256: {digest} */\n{node}")
(review / "q6-node-provenance.tsv").write_text("\n".join(rows) + "\n")
(review / "q6-reserved-memory-nodes.dtsi").write_text("\n\n".join(bundle) + "\n")

text = base.read_text(errors="strict")
needed = [node for label, (_, node) in found.items()
          if not re.search(rf'(?m)^[ \t]*{re.escape(label)}\s*:', text)]
if needed:
    m = re.search(r'(?m)^[ \t]*reserved-memory\s*\{', text)
    if not m:
        (review / "phase13-status.txt").write_text(
            "BLOCKED: native DD-WRT ipq5018.dtsi has no reserved-memory node\n"
        )
        print("BLOCKED: reserved-memory node not found in native DD-WRT base")
        raise SystemExit(3)
    brace = text.find("{", m.start())
    depth = 0
    close = None
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                close = i
                break
    if close is None:
        raise SystemExit("Malformed reserved-memory node")
    insertion = "\n\n\t\t/* Phase 13: exact verified OpenWrt Q6 reserved-memory nodes. */\n"
    insertion += "\n\n".join("\n".join("\t\t" + line for line in n.splitlines()) for n in needed)
    insertion += "\n"
    text = text[:close] + insertion + text[close:]
    base.write_text(text)

(review / "phase13-status.txt").write_text(
    "RESOLVED: exact Q6 reserved-memory nodes found and injected without guessed addresses\n"
)
print("Resolved exact Q6 reserved-memory nodes with recorded provenance.")
PY
resolver_status=$?
set -e

if [[ "$resolver_status" -ne 0 ]]; then
  echo "Phase 13 stopped safely before compilation; see phase13-status.txt."
  exit 0
fi

# Resolve binding includes. DD-WRT's exported headers are preferred; missing
# public Linux binding headers are fetched only into this temporary audit tree.
while IFS= read -r include; do
  rel="${include#dt-bindings/}"
  target="$DDWRT_DIR/dt-bindings/$rel"
  if [[ -L "$target" ]]; then
    rm -f "$target"
  fi
  if [[ ! -f "$target" ]]; then
    mkdir -p "$(dirname "$target")"
    curl --fail --location --silent --show-error \
      "$LINUX_DT_BINDINGS_URL/$rel" --output "$target"
  fi
done < <(grep -RhoE '<dt-bindings/[^>]+>' "$STAGE" | tr -d '<>' | sort -u)

CPP_LOG="$REVIEW/cpp.log"
DTC_LOG="$REVIEW/dtc-compile.log"
ROUNDTRIP_LOG="$REVIEW/dtc-roundtrip.log"

set +e
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
  -I "$STAGE" -I "$DDWRT_DIR" \
  "$STAGE/ra72-review.dts" "$REVIEW/ra72-review.preprocessed.dts" \
  >"$CPP_LOG" 2>&1
cpp_status=$?

if [[ "$cpp_status" -eq 0 ]]; then
  dtc -@ -I dts -O dtb -o "$REVIEW/ra72-review.dtb" \
    "$REVIEW/ra72-review.preprocessed.dts" >"$DTC_LOG" 2>&1
  dtc_status=$?
else
  dtc_status=99
fi

if [[ "$dtc_status" -eq 0 ]]; then
  dtc -I dtb -O dts -o "$REVIEW/ra72-review.decompiled.dts" \
    "$REVIEW/ra72-review.dtb" >>"$DTC_LOG" 2>&1
  dtc -I dts -O dtb -o "$REVIEW/ra72-review.roundtrip.dtb" \
    "$REVIEW/ra72-review.decompiled.dts" >"$ROUNDTRIP_LOG" 2>&1
  roundtrip_status=$?
else
  roundtrip_status=99
fi
set -e

{
  echo "cpp_status=$cpp_status"
  echo "dtc_status=$dtc_status"
  echo "roundtrip_status=$roundtrip_status"
} | tee "$REVIEW/compile-status.txt"

if [[ "$cpp_status" -eq 0 && "$dtc_status" -eq 0 && "$roundtrip_status" -eq 0 ]]; then
  grep -q 'q6_region:' "$STAGE/ipq5018.dtsi"
  grep -q 'q6_etr_region:' "$STAGE/ipq5018.dtsi"
  sha256sum "$REVIEW/ra72-review.dtb" "$REVIEW/ra72-review.roundtrip.dtb" \
    | tee "$REVIEW/dtb-sha256.txt"
  echo "PASS: preprocessing, DTB compilation, decompilation, and round-trip compilation succeeded."
else
  echo "BLOCKED: review the compiler logs. No firmware was produced."
fi

cat > "$OUT/DO-NOT-FLASH.txt" <<'EOF'
PHASE 13 OUTPUT IS A SOURCE/DEVICE-TREE COMPILER AUDIT ONLY.
IT IS NOT DD-WRT FIRMWARE AND MUST NOT BE FLASHED TO ANY ROUTER.
Exact device under study: Xiaomi Mi AIoT AX6000, model RA72 only.
EOF

exit 0
