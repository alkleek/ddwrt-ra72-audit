#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="phase19-output"
REVIEW_DIR="$OUT_DIR/review"
INVENTORY="$REVIEW_DIR/ddwrt-source-inventory.txt"
SOURCE_URL="${DDWRT_SOURCE_URL:-svn://svn.dd-wrt.com/DD-WRT}"

mkdir -p "$REVIEW_DIR"

echo "DD-WRT RA72 Phase 19 build-template selection"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: audit only; no firmware is built and nothing is flashable."

fetch_inventory() {
  local candidate
  local -a candidates=(
    "$SOURCE_URL"
    "https://svn.dd-wrt.com/DD-WRT"
    "svn://svn.dd-wrt.com/DD-WRT"
  )

  : > "$REVIEW_DIR/source-attempts.txt"
  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    echo "Trying $candidate" | tee -a "$REVIEW_DIR/source-attempts.txt"
    if timeout 35m svn list --recursive "$candidate" > "$INVENTORY.tmp" 2>> "$REVIEW_DIR/source-attempts.txt"; then
      mv "$INVENTORY.tmp" "$INVENTORY"
      printf '%s\n' "$candidate" > "$REVIEW_DIR/selected-source-url.txt"
      return 0
    fi
    rm -f "$INVENTORY.tmp"
  done
  return 1
}

if ! fetch_inventory; then
  printf '%s\n' "SOURCE_INVENTORY_UNAVAILABLE" > "$REVIEW_DIR/phase19-status.txt"
  cat > "$OUT_DIR/REPORT-PHASE19.txt" <<'EOF'
DD-WRT RA72 Phase 19 build-template selection

STATUS: SOURCE_INVENTORY_UNAVAILABLE

The public DD-WRT source inventory could not be retrieved. No template
classification was performed. No firmware was built.
EOF
  exit 1
fi

gzip -c "$INVENTORY" > "$REVIEW_DIR/ddwrt-source-inventory.txt.gz"

python3 - "$INVENTORY" "$REVIEW_DIR" "$OUT_DIR/REPORT-PHASE19.txt" <<'PY'
from __future__ import annotations

import collections
import pathlib
import re
import sys

inventory_path = pathlib.Path(sys.argv[1])
review = pathlib.Path(sys.argv[2])
report_path = pathlib.Path(sys.argv[3])

paths = [
    line.strip().replace("\\", "/")
    for line in inventory_path.read_text(encoding="utf-8", errors="replace").splitlines()
    if line.strip()
]

ipq_re = re.compile(r"(?i)(?:ipq5018|ipq50xx)")
ra72_re = re.compile(r"(?i)(?:^|[/_.-])ra72(?:$|[/_.-])")
miot_re = re.compile(r"(?i)(?:mi.?aiot.?ax6000|aiot.?ax6000)")
mp03_re = re.compile(r"(?i)(?:mp03(?:\.1)?|ap-mp03(?:\.1)?)")

def categories(path: str) -> set[str]:
    low = path.lower()
    name = low.rsplit("/", 1)[-1]
    result: set[str] = set()

    if (
        name in {"makefile", "kconfig", "config.in", "rules.mk"}
        or name.endswith((".mk", ".mak"))
        or any(token in low for token in (
            "/build/", "/tools/", "/toolchains/", "/configs/",
            "/targets/", "/target/", "/profiles/", "/boards/"
        ))
    ):
        result.add("build_definition")

    if (
        any(token in low for token in (
            "target", "profile", "board", "device", "defconfig",
            "config_", "/configs/", "/profiles/", "/boards/"
        ))
        and not low.endswith((".c", ".h"))
    ):
        result.add("target_selection")

    if any(token in low for token in (
        "image", "firmware", "rootfs", "squashfs", "ubifs",
        ".ubi", "uimage", "fitimage", "/bin/"
    )):
        result.add("image_packaging")

    if (
        "defconfig" in low
        or "kernel_config" in low
        or re.search(r"(?:^|/)config(?:[._-]|$)", low)
        or "/configs/" in low
    ):
        result.add("kernel_config")

    if (
        name.endswith((".dts", ".dtsi", ".dtb"))
        or "/boot/dts/" in low
        or "/devicetree/" in low
        or "/device-tree/" in low
    ):
        result.add("device_tree")

    if not result:
        result.add("source_component")
    return result

def candidate_root(path: str) -> str:
    parts = [part for part in path.split("/") if part]
    if not parts:
        return "."
    for index, part in enumerate(parts):
        if ipq_re.search(part):
            if index == len(parts) - 1:
                return "/".join(parts[:index]) or "."
            return "/".join(parts[: index + 1])
    return "/".join(parts[:-1]) or "."

ipq_paths = sorted(path for path in paths if ipq_re.search(path))
strict_identity = sorted(
    path for path in paths
    if ra72_re.search(path) or miot_re.search(path) or mp03_re.search(path)
)

classified: dict[str, set[str]] = {}
root_files: dict[str, list[str]] = collections.defaultdict(list)
root_categories: dict[str, set[str]] = collections.defaultdict(set)

for path in ipq_paths:
    cats = categories(path)
    classified[path] = cats
    root = candidate_root(path)
    root_files[root].append(path)
    root_categories[root].update(cats)

weights = {
    "build_definition": 6,
    "target_selection": 5,
    "image_packaging": 5,
    "kernel_config": 4,
    "device_tree": 3,
    "source_component": 1,
}

ranked: list[tuple[int, str, list[str], set[str]]] = []
for root, files in root_files.items():
    cats = root_categories[root]
    score = sum(weights[cat] for cat in cats) + min(len(files), 25)
    ranked.append((score, root, sorted(files), cats))
ranked.sort(key=lambda item: (-item[0], item[1]))

def is_viable(files: list[str], cats: set[str]) -> bool:
    return (
        len(files) >= 5
        and len(cats) >= 3
        and bool(cats & {"build_definition", "target_selection"})
        and bool(cats & {"image_packaging", "kernel_config", "device_tree"})
    )

viable = [item for item in ranked if is_viable(item[2], item[3])]

if viable:
    status = "CLOSEST_BUILDABLE_IPQ5018_TEMPLATE_CANDIDATE_FOUND"
elif any(
    cats & {"build_definition", "target_selection"}
    for _, _, _, cats in ranked
):
    status = "IPQ5018_BUILD_FRAGMENTS_WITHOUT_COMPLETE_TEMPLATE"
else:
    status = "NO_IPQ5018_BUILD_TEMPLATE_FOUND"

def write_lines(name: str, values: list[str]) -> None:
    (review / name).write_text(
        "\n".join(values) + ("\n" if values else ""),
        encoding="utf-8",
    )

write_lines("ipq5018-all-paths.txt", ipq_paths)
write_lines("strict-ra72-identity-paths.txt", strict_identity)
write_lines(
    "ipq5018-build-paths.txt",
    [p for p in ipq_paths if "build_definition" in classified[p]],
)
write_lines(
    "target-selection-paths.txt",
    [p for p in ipq_paths if "target_selection" in classified[p]],
)
write_lines(
    "image-packaging-paths.txt",
    [p for p in ipq_paths if "image_packaging" in classified[p]],
)
write_lines(
    "kernel-config-paths.txt",
    [p for p in ipq_paths if "kernel_config" in classified[p]],
)
write_lines(
    "device-tree-paths.txt",
    [p for p in ipq_paths if "device_tree" in classified[p]],
)

root_lines: list[str] = []
candidate_file_lines: list[str] = []
for score, root, files, cats in ranked[:50]:
    root_lines.append(
        f"score={score}\tfiles={len(files)}\t"
        f"categories={','.join(sorted(cats))}\troot={root}"
    )
    candidate_file_lines.append(f"### {root}")
    candidate_file_lines.extend(files)
    candidate_file_lines.append("")

write_lines("candidate-template-roots.txt", root_lines)
write_lines("candidate-template-files.txt", candidate_file_lines)

missing_contract = [
    "Exact device identity: Xiaomi Mi AIoT AX6000, model RA72",
    "SoC and board identity: Qualcomm IPQ5018 / MP03.1",
    "RA72 Device Tree integrated into a DD-WRT kernel build",
    "RA72 NAND partition and A/B boot layout",
    "RA72 image packaging compatible with Xiaomi UBI boot",
    "Ethernet: QCA8337 switch plus QCA8081 2.5GbE PHY",
    "Wi-Fi: IPQ5018 internal radio plus both PCIe radios",
    "ART/calibration preservation and extraction contract",
    "Boot-only recovery image and tested rollback path",
]
write_lines("ra72-missing-contract.txt", missing_contract)

category_counts = collections.Counter()
for cats in classified.values():
    category_counts.update(cats)

counts = [
    f"inventory_paths={len(paths)}",
    f"ipq5018_paths={len(ipq_paths)}",
    f"strict_ra72_identity_paths={len(strict_identity)}",
    f"candidate_roots={len(ranked)}",
    f"viable_candidate_roots={len(viable)}",
]
for key in sorted(weights):
    counts.append(f"{key}_paths={category_counts[key]}")
write_lines("phase19-counts.txt", counts)
write_lines("phase19-status.txt", [status])

top = ranked[0] if ranked else None
report = [
    "DD-WRT RA72 Phase 19 build-template selection",
    "",
    "Exact device: Xiaomi Mi AIoT AX6000, model RA72",
    "SoC/board: Qualcomm IPQ5018 / MP03.1",
    "",
    f"STATUS: {status}",
    "",
    "Purpose",
    "-------",
    "This audit ranks public DD-WRT IPQ5018/IPQ50xx source locations to",
    "identify the closest real build template that could be studied for a",
    "new RA72 port. It does not build firmware and creates nothing flashable.",
    "",
    "Result",
    "------",
    f"IPQ5018/IPQ50xx paths: {len(ipq_paths)}",
    f"Candidate roots: {len(ranked)}",
    f"Viable template candidates: {len(viable)}",
]
if top:
    report.extend([
        f"Top ranked root: {top[1]}",
        f"Top score: {top[0]}",
        f"Top categories: {', '.join(sorted(top[3]))}",
        f"Top files: {len(top[2])}",
    ])
else:
    report.append("Top ranked root: none")

report.extend([
    "",
    "Interpretation",
    "--------------",
])
if status == "CLOSEST_BUILDABLE_IPQ5018_TEMPLATE_CANDIDATE_FOUND":
    report.extend([
        "At least one source location has enough build, target, packaging,",
        "kernel-config, or Device Tree evidence to serve as a candidate",
        "template. This is not evidence that RA72 is supported.",
    ])
elif status == "IPQ5018_BUILD_FRAGMENTS_WITHOUT_COMPLETE_TEMPLATE":
    report.extend([
        "The public tree contains IPQ5018 build fragments, but this audit",
        "did not find a sufficiently complete template root. A new DD-WRT",
        "target would require reconstructing the missing build integration.",
    ])
else:
    report.extend([
        "No usable public IPQ5018 build-template evidence was found.",
        "A private or unavailable DD-WRT platform tree may be required.",
    ])

report.extend([
    "",
    "Safety",
    "------",
    "Audit only. No firmware was built. Do not flash any file from this",
    "artifact. UART remains emergency recovery only; this phase does not",
    "touch the router.",
    "",
    "Review files",
    "------------",
    "review/candidate-template-roots.txt",
    "review/candidate-template-files.txt",
    "review/phase19-counts.txt",
    "review/phase19-status.txt",
    "review/ra72-missing-contract.txt",
])

report_path.write_text("\n".join(report) + "\n", encoding="utf-8")
PY

echo "Phase 19 status: $(cat "$REVIEW_DIR/phase19-status.txt")"
