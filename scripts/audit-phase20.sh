#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="phase20-output"
REVIEW_DIR="$OUT_DIR/review"
SNAPSHOT_DIR="$REVIEW_DIR/source-snapshot"
INVENTORY="$REVIEW_DIR/ddwrt-source-inventory.txt"
ATTEMPTS="$REVIEW_DIR/source-attempts.txt"
FETCH_LOG="$REVIEW_DIR/source-fetch.log"
SOURCE_URL="${DDWRT_SOURCE_URL:-svn://svn.dd-wrt.com/DD-WRT}"

rm -rf "$OUT_DIR"
mkdir -p "$REVIEW_DIR" "$SNAPSHOT_DIR"
: > "$ATTEMPTS"
: > "$FETCH_LOG"

echo "DD-WRT RA72 Phase 20 platform integration map"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: source audit only; no firmware is built and no router is accessed."

fetch_inventory() {
  local candidate
  local -a candidates=(
    "$SOURCE_URL"
    "svn://svn.dd-wrt.com/DD-WRT"
    "https://svn.dd-wrt.com/DD-WRT"
  )

  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    if grep -Fxq "$candidate" "$ATTEMPTS" 2>/dev/null; then
      continue
    fi

    printf '%s\n' "$candidate" >> "$ATTEMPTS"
    echo "Trying public DD-WRT source: $candidate"
    rm -f "$INVENTORY.tmp"

    if timeout 50m svn list --recursive "$candidate" \
      > "$INVENTORY.tmp" 2>> "$ATTEMPTS"; then
      if [[ -s "$INVENTORY.tmp" ]]; then
        mv "$INVENTORY.tmp" "$INVENTORY"
        printf '%s\n' "$candidate" > "$REVIEW_DIR/selected-source-url.txt"
        return 0
      fi
    fi
  done

  rm -f "$INVENTORY.tmp"
  return 1
}

write_unavailable_report() {
  local status="$1"
  printf '%s\n' "$status" > "$REVIEW_DIR/phase20-status.txt"
  cat > "$OUT_DIR/REPORT-PHASE20.txt" <<EOF
DD-WRT RA72 Phase 20 platform integration map

Exact device: Xiaomi Mi AIoT AX6000, model RA72
SoC/board: Qualcomm IPQ5018 / MP03.1

STATUS: $status

The required public DD-WRT source material was unavailable. No platform
integration conclusion was produced.

SAFETY:
- No firmware was built.
- Nothing in this artifact is flashable.
- No router was accessed or modified.
EOF
}

if ! fetch_inventory; then
  write_unavailable_report "SOURCE_INVENTORY_UNAVAILABLE"
  exit 1
fi

python3 - "$INVENTORY" "$REVIEW_DIR/selected-source-files.txt" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

inventory_path = pathlib.Path(sys.argv[1])
selection_path = pathlib.Path(sys.argv[2])

paths = [
    line.strip().replace("\\", "/")
    for line in inventory_path.read_text(
        encoding="utf-8", errors="replace"
    ).splitlines()
    if line.strip() and not line.rstrip().endswith("/")
]

exact_files = {
    "src/router/Makefile",
    "src/router/Makefile.ipq60xx",
    "src/router/Makefile.ipq806x",
}

selected: set[str] = set()
for path in paths:
    low = path.lower()
    name = low.rsplit("/", 1)[-1]

    if path in exact_files:
        selected.add(path)
        continue

    if low.startswith("src/router/configs/ipq60xx/"):
        selected.add(path)
        continue

    if (
        low.startswith("src/router/configs/buildscripts/")
        and ("ipq" in name or "qualcomm" in name)
    ):
        selected.add(path)
        continue

    if re.fullmatch(
        r"src/linux/universal/linux-(?:6\.6|6\.12)-nss/"
        r"\.config_(?:ipq6018|ipq95xx)(?:\.[^/]+)?",
        low,
    ):
        selected.add(path)
        continue

    if re.fullmatch(
        r"src/linux/universal/linux-(?:6\.6-nss|6\.12(?:-nss)?)/"
        r"arch/arm64/boot/dts/qcom/ipq5018[^/]*\.(?:dts|dtsi)",
        low,
    ):
        selected.add(path)

selection_path.write_text(
    "\n".join(sorted(selected)) + ("\n" if selected else ""),
    encoding="utf-8",
)
PY

SELECTED_URL="$(cat "$REVIEW_DIR/selected-source-url.txt")"
SELECTED_URL="${SELECTED_URL%/}"

while IFS= read -r relative_path; do
  [[ -n "$relative_path" ]] || continue
  destination="$SNAPSHOT_DIR/$relative_path"
  mkdir -p "$(dirname "$destination")"

  echo "Fetching $relative_path" >> "$FETCH_LOG"
  if timeout 5m svn cat "$SELECTED_URL/$relative_path" \
    > "$destination.tmp" 2>> "$FETCH_LOG"; then
    mv "$destination.tmp" "$destination"
  else
    rm -f "$destination.tmp"
    echo "FAILED $relative_path" >> "$FETCH_LOG"
  fi
done < "$REVIEW_DIR/selected-source-files.txt"

python3 - "$INVENTORY" "$SNAPSHOT_DIR" "$REVIEW_DIR" \
  "$OUT_DIR/REPORT-PHASE20.txt" "$SELECTED_URL" <<'PY'
from __future__ import annotations

import collections
import pathlib
import re
import sys

inventory_path = pathlib.Path(sys.argv[1])
snapshot = pathlib.Path(sys.argv[2])
review = pathlib.Path(sys.argv[3])
report_path = pathlib.Path(sys.argv[4])
source_url = sys.argv[5]

inventory = [
    line.strip().replace("\\", "/")
    for line in inventory_path.read_text(
        encoding="utf-8", errors="replace"
    ).splitlines()
    if line.strip()
]

files: dict[str, str] = {}
for path in snapshot.rglob("*"):
    if not path.is_file():
        continue
    relative = path.relative_to(snapshot).as_posix()
    files[relative] = path.read_text(encoding="utf-8", errors="replace")

reference_devices = {
    "gl-b3000": ("gl-b3000",),
    "mr5500": ("mr5500",),
    "mx2000": ("mx2000",),
    "mx5500": ("mx5500",),
    "rdp432-c2": ("rdp432-c2", "rdp432"),
    "spnmx56": ("spnmx56",),
    "tplink-archer-ax55-v1": ("archer-ax55", "ax55-v1"),
    "wrc-x3000gs2": ("wrc-x3000gs2", "x3000gs2"),
}

anchor_patterns = {
    "ipq5018": re.compile(r"(?i)\bipq5018\b"),
    "ipq6018": re.compile(r"(?i)\bipq6018\b"),
    "ipq60xx": re.compile(r"(?i)\bipq60xx\b"),
    "ipq95xx": re.compile(r"(?i)\bipq95xx\b"),
    "device_tree": re.compile(r"(?i)(?:\bdtb\b|\bdts\b|device.?tree)"),
    "nand": re.compile(r"(?i)(?:\bnand\b|qpic)"),
    "ubi": re.compile(r"(?i)(?:\bubi\b|ubifs|ubinize)"),
    "squashfs": re.compile(r"(?i)squashfs"),
    "fit_or_uimage": re.compile(r"(?i)(?:fitimage|mkimage|uimage|\bitb\b)"),
    "ath11k": re.compile(r"(?i)ath11k"),
    "nss": re.compile(r"(?i)(?:qca-nss|\bnss\b)"),
    "qca8337": re.compile(r"(?i)(?:qca8337|qca8k|ar8337)"),
    "qca8081": re.compile(r"(?i)qca8081"),
    "mdio": re.compile(r"(?i)\bmdio\b"),
    "pcie": re.compile(r"(?i)\bpcie\b"),
}

def is_dts_path(path: str) -> bool:
    low = path.lower()
    return "/arch/arm64/boot/dts/" in low and low.endswith((".dts", ".dtsi"))

reference_paths: dict[str, list[str]] = {}
reference_build_links: list[str] = []
for device, tokens in reference_devices.items():
    matched_paths = sorted(
        path for path in inventory
        if any(token in path.lower() for token in tokens)
    )
    reference_paths[device] = matched_paths

    for path, text in files.items():
        path_low = path.lower()
        content_low = text.lower()
        if any(token in path_low or token in content_low for token in tokens):
            if not is_dts_path(path):
                reference_build_links.append(
                    f"device={device}\tfile={path}"
                )

anchor_hits: list[str] = []
anchor_counts: collections.Counter[str] = collections.Counter()
for path, text in sorted(files.items()):
    hits = [
        name for name, pattern in anchor_patterns.items()
        if pattern.search(text)
    ]
    for hit in hits:
        anchor_counts[hit] += 1
    if hits:
        anchor_hits.append(
            f"file={path}\tanchors={','.join(hits)}"
        )

platform_makefile = "src/router/Makefile.ipq60xx"
platform_configs = sorted(
    path for path in files
    if path.startswith("src/router/configs/ipq60xx/")
)
ipq5018_dts = sorted(
    path for path in files
    if re.search(r"/ipq5018[^/]*\.dtsi?$", path, re.IGNORECASE)
)
kernel_configs = sorted(
    path for path in files
    if re.search(r"/\.config_(?:ipq6018|ipq95xx)", path, re.IGNORECASE)
)

foundation_rows: list[tuple[int, str, str]] = []
if platform_makefile in files:
    text = files[platform_makefile]
    present = sorted(
        name for name, pattern in anchor_patterns.items()
        if pattern.search(text)
    )
    score = 40 + len(present)
    foundation_rows.append(
        (score, platform_makefile, ",".join(present) or "none")
    )

for path in platform_configs:
    text = files[path]
    present = sorted(
        name for name, pattern in anchor_patterns.items()
        if pattern.search(text)
    )
    score = 20 + len(present)
    foundation_rows.append(
        (score, path, ",".join(present) or "none")
    )

device_rows: list[tuple[int, str, str]] = []
device_weights = {
    "qca8337": 12,
    "qca8081": 12,
    "nand": 6,
    "ubi": 5,
    "ath11k": 4,
    "mdio": 3,
    "pcie": 2,
    "nss": 2,
}
for path in ipq5018_dts:
    text = files[path]
    present = sorted(
        name for name, pattern in anchor_patterns.items()
        if pattern.search(text)
    )
    score = sum(device_weights.get(name, 0) for name in present)
    if path.endswith(".dts"):
        score += 3
    device_rows.append(
        (score, path, ",".join(present) or "none")
    )

foundation_rows.sort(key=lambda item: (-item[0], item[1]))
device_rows.sort(key=lambda item: (-item[0], item[1]))
reference_build_links = sorted(set(reference_build_links))

if reference_build_links:
    status = "IPQ5018_REFERENCE_DEVICE_BUILD_LINK_FOUND"
elif (
    platform_makefile in files
    and platform_configs
    and ipq5018_dts
):
    status = "IPQ60XX_PLATFORM_BASE_WITH_IPQ5018_DTS_NO_DEVICE_LINK"
elif platform_makefile in files or platform_configs or ipq5018_dts:
    status = "PARTIAL_PLATFORM_BASE_FOUND"
else:
    status = "PLATFORM_BASE_UNAVAILABLE"

def write_lines(name: str, values: list[str]) -> None:
    (review / name).write_text(
        "\n".join(values) + ("\n" if values else ""),
        encoding="utf-8",
    )

write_lines(
    "reference-device-paths.txt",
    [
        f"device={device}\tpath={path}"
        for device, paths in reference_paths.items()
        for path in paths
    ],
)
write_lines("reference-device-build-links.txt", reference_build_links)
write_lines("build-anchor-hits.txt", anchor_hits)
write_lines(
    "platform-foundation-ranking.txt",
    [
        f"score={score}\tfile={path}\tanchors={anchors}"
        for score, path, anchors in foundation_rows
    ],
)
write_lines(
    "reference-device-ranking.txt",
    [
        f"score={score}\tfile={path}\tfeatures={features}"
        for score, path, features in device_rows
    ],
)
write_lines("fetched-source-files.txt", sorted(files))
write_lines("phase20-status.txt", [status])

counts = {
    "inventory_paths": len(inventory),
    "selected_source_files": len(
        (review / "selected-source-files.txt").read_text(
            encoding="utf-8", errors="replace"
        ).splitlines()
    ),
    "fetched_source_files": len(files),
    "platform_config_files": len(platform_configs),
    "kernel_config_files": len(kernel_configs),
    "ipq5018_dts_files": len(ipq5018_dts),
    "reference_device_build_links": len(reference_build_links),
}
for name in sorted(anchor_patterns):
    counts[f"anchor_{name}_files"] = anchor_counts[name]

write_lines(
    "phase20-counts.txt",
    [f"{key}={value}" for key, value in counts.items()],
)

if status == "IPQ5018_REFERENCE_DEVICE_BUILD_LINK_FOUND":
    interpretation = [
        "At least one known IPQ5018 reference device is linked from a",
        "non-DTS build or packaging file. The linked files can be studied",
        "as the direct template for RA72 build integration.",
    ]
elif status == "IPQ60XX_PLATFORM_BASE_WITH_IPQ5018_DTS_NO_DEVICE_LINK":
    interpretation = [
        "The public tree contains an IPQ60xx platform build base, platform",
        "configurations, and IPQ5018 Device Trees, but the known IPQ5018",
        "devices are not linked from a retrieved non-DTS build definition.",
        "The RA72 target will require explicit build and packaging wiring.",
    ]
elif status == "PARTIAL_PLATFORM_BASE_FOUND":
    interpretation = [
        "Only part of the expected public platform foundation was fetched.",
        "The missing integration layer must be located before drafting a",
        "DD-WRT target.",
    ]
else:
    interpretation = [
        "No usable public platform foundation was available from this run.",
    ]

top_foundation = (
    foundation_rows[0][1] if foundation_rows else "none"
)
top_reference = device_rows[0][1] if device_rows else "none"

report = [
    "DD-WRT RA72 Phase 20 platform integration map",
    "",
    "Exact device: Xiaomi Mi AIoT AX6000, model RA72",
    "SoC/board: Qualcomm IPQ5018 / MP03.1",
    "",
    f"STATUS: {status}",
    "",
    "Selected public source",
    "----------------------",
    source_url,
    "",
    "Result",
    "------",
    f"Selected source files: {counts['selected_source_files']}",
    f"Fetched source files: {counts['fetched_source_files']}",
    f"IPQ60xx platform configs: {len(platform_configs)}",
    f"IPQ5018 DTS/DTSI files: {len(ipq5018_dts)}",
    f"Reference-device build links: {len(reference_build_links)}",
    f"Top platform foundation: {top_foundation}",
    f"Top reference Device Tree: {top_reference}",
    "",
    "Interpretation",
    "--------------",
    *interpretation,
    "",
    "Safety",
    "------",
    "This is a source-content audit. No DD-WRT firmware was built.",
    "No file in this artifact is safe to flash.",
    "The router, its NAND, boot flags, SSH, and UART were not touched.",
    "",
    "Review files",
    "------------",
    "review/phase20-status.txt",
    "review/phase20-counts.txt",
    "review/platform-foundation-ranking.txt",
    "review/reference-device-ranking.txt",
    "review/reference-device-build-links.txt",
    "review/build-anchor-hits.txt",
]

report_path.write_text("\n".join(report) + "\n", encoding="utf-8")
PY

gzip -9 -f "$INVENTORY"

echo
echo "Phase 20 status: $(cat "$REVIEW_DIR/phase20-status.txt")"
