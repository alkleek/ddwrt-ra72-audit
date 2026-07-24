#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="phase18-output"
REVIEW_DIR="$OUT_DIR/review"
INVENTORY="$REVIEW_DIR/ddwrt-source-inventory.txt"
ATTEMPTS="$REVIEW_DIR/ddwrt-source-attempts.txt"
SOURCE_INFO="$REVIEW_DIR/ddwrt-source-info.txt"

rm -rf "$OUT_DIR"
mkdir -p "$REVIEW_DIR"
: > "$ATTEMPTS"
: > "$SOURCE_INFO"

echo "DD-WRT RA72 Phase 18 strict source classification"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: source inventory audit only; no firmware is built and no router is modified."
echo

declare -a SOURCE_URLS=()
if [[ -n "${DDWRT_SOURCE_URL:-}" ]]; then
  SOURCE_URLS+=("$DDWRT_SOURCE_URL")
fi
SOURCE_URLS+=(
  "svn://svn.dd-wrt.com/DD-WRT"
  "https://svn.dd-wrt.com/DD-WRT"
)

SUCCESS_URL=""
for url in "${SOURCE_URLS[@]}"; do
  if [[ -n "$SUCCESS_URL" ]]; then
    break
  fi

  if grep -Fxq "$url" "$ATTEMPTS" 2>/dev/null; then
    continue
  fi
  printf '%s\n' "$url" >> "$ATTEMPTS"

  echo "Trying public source inventory: $url"
  rm -f "$INVENTORY"
  if timeout 50m svn list --recursive "$url" > "$INVENTORY" 2>"$REVIEW_DIR/svn-last-error.txt"; then
    if [[ -s "$INVENTORY" ]]; then
      SUCCESS_URL="$url"
      {
        echo "selected_url=$url"
        svn info "$url" 2>/dev/null || true
      } > "$SOURCE_INFO"
    fi
  fi
done

if [[ -z "$SUCCESS_URL" || ! -s "$INVENTORY" ]]; then
  cat > "$OUT_DIR/REPORT-PHASE18.txt" <<'EOF'
DD-WRT RA72 PHASE 18 STRICT CLASSIFICATION

RESULT: SOURCE_INVENTORY_UNAVAILABLE

The public DD-WRT SVN inventory could not be retrieved from the attempted
endpoints. No classification was performed.

SAFETY:
- No firmware was built.
- No image was produced.
- No router was accessed or modified.
EOF
  echo "SOURCE_INVENTORY_UNAVAILABLE" > "$REVIEW_DIR/phase18-status.txt"
  exit 1
fi

python3 - "$INVENTORY" "$OUT_DIR" "$SUCCESS_URL" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

inventory_path = pathlib.Path(sys.argv[1])
out_dir = pathlib.Path(sys.argv[2])
source_url = sys.argv[3]
review = out_dir / "review"

paths = [
    line.strip().replace("\\", "/")
    for line in inventory_path.read_text(encoding="utf-8", errors="replace").splitlines()
    if line.strip()
]

strict_ra72 = re.compile(r"(?i)(?:^|[/_.+\-])ra72(?:$|[/_.+\-])")
strict_mi_aiot = re.compile(
    r"(?i)(?:^|[/_.+\-\s])mi(?:[/_.+\-\s]+)aiot"
    r"(?:[/_.+\-\s]+)ax6000(?:$|[/_.+\-\s])"
)
strict_mp03 = re.compile(r"(?i)(?:^|[/_.+\-])mp03(?:[._-]?1)?(?:$|[/_.+\-])")
ambiguous_ax6000 = re.compile(
    r"(?i)(?:^|[/_.+\-])xiaomi[_\-]?ax6000(?:$|[/_.+\-\s])"
)
generic_component = re.compile(
    r"(?i)(ipq5018|ipq50xx|qca8337|qca8081|ath11k|qca8k|qca-ssdk|ssdk|nss-dp)"
)
ra72_substring = re.compile(r"(?i)ra72")
mp03_substring = re.compile(r"(?i)mp03")

build_parts = {
    "target", "targets", "profile", "profiles", "platform", "platforms",
    "board", "boards", "config", "configs", "rules", "mach", "machine",
    "machines", "image", "images",
}
build_files = {"makefile", "kconfig", "config.in"}


def is_build_context(path: str) -> bool:
    components = [part.lower() for part in path.split("/") if part]
    if any(part in build_parts for part in components):
        return True
    name = components[-1] if components else ""
    return name in build_files or name.endswith((".mk", ".config", "_defconfig", "-defconfig"))


strict_ra72_paths = sorted({p for p in paths if strict_ra72.search(p)})
strict_mi_aiot_paths = sorted({p for p in paths if strict_mi_aiot.search(p)})
strict_mp03_paths = sorted({p for p in paths if strict_mp03.search(p)})
ambiguous_ax6000_paths = sorted({p for p in paths if ambiguous_ax6000.search(p)})
generic_component_paths = sorted({p for p in paths if generic_component.search(p)})

direct_identity_paths = sorted(
    set(strict_ra72_paths) | set(strict_mi_aiot_paths) | set(strict_mp03_paths)
)
direct_build_paths = sorted(p for p in direct_identity_paths if is_build_context(p))
generic_build_paths = sorted(p for p in generic_component_paths if is_build_context(p))

rejected_ra72 = sorted(
    {p for p in paths if ra72_substring.search(p) and not strict_ra72.search(p)}
)
rejected_mp03 = sorted(
    {p for p in paths if mp03_substring.search(p) and not strict_mp03.search(p)}
)


def write_list(name: str, values: list[str]) -> None:
    path = review / name
    text = "\n".join(values)
    path.write_text(text + ("\n" if text else ""), encoding="utf-8")


write_list("strict-ra72-identity-paths.txt", strict_ra72_paths)
write_list("strict-mi-aiot-ax6000-paths.txt", strict_mi_aiot_paths)
write_list("strict-mp03-board-paths.txt", strict_mp03_paths)
write_list("direct-ra72-build-profile-paths.txt", direct_build_paths)
write_list("generic-ipq5018-component-paths.txt", generic_component_paths)
write_list("generic-ipq5018-build-paths.txt", generic_build_paths)
write_list("ambiguous-xiaomi-ax6000-alias-paths.txt", ambiguous_ax6000_paths)
write_list("rejected-ra72-substring-false-positives.txt", rejected_ra72)
write_list("rejected-mp03-substring-false-positives.txt", rejected_mp03)

if direct_build_paths:
    status = "DIRECT_RA72_BUILD_PROFILE_SIGNAL_FOUND"
elif direct_identity_paths:
    status = "STRICT_RA72_IDENTITY_SIGNAL_WITHOUT_BUILD_PROFILE"
elif generic_build_paths:
    status = "GENERIC_IPQ5018_BUILD_COMPONENTS_ONLY_NO_RA72_TARGET"
elif generic_component_paths:
    status = "GENERIC_IPQ5018_COMPONENTS_ONLY_NO_RA72_TARGET"
else:
    status = "NO_ACTIONABLE_IPQ5018_OR_RA72_FOUNDATION"

counts = {
    "inventory_paths": len(paths),
    "strict_ra72_identity_paths": len(strict_ra72_paths),
    "strict_mi_aiot_ax6000_paths": len(strict_mi_aiot_paths),
    "strict_mp03_board_paths": len(strict_mp03_paths),
    "direct_ra72_build_profile_paths": len(direct_build_paths),
    "generic_ipq5018_component_paths": len(generic_component_paths),
    "generic_ipq5018_build_paths": len(generic_build_paths),
    "ambiguous_xiaomi_ax6000_alias_paths": len(ambiguous_ax6000_paths),
    "rejected_ra72_substring_false_positives": len(rejected_ra72),
    "rejected_mp03_substring_false_positives": len(rejected_mp03),
}

(review / "phase18-status.txt").write_text(status + "\n", encoding="utf-8")
(review / "phase18-counts.txt").write_text(
    "\n".join(f"{key}={value}" for key, value in counts.items()) + "\n",
    encoding="utf-8",
)

report = f"""DD-WRT RA72 PHASE 18 STRICT CLASSIFICATION

Exact device:
- Product: Xiaomi Mi AIoT AX6000
- Model: RA72
- SoC/board: Qualcomm IPQ5018 / MP03.1
- Not Xiaomi Mi Router AX6000 (IPQ8072A)
- Not Redmi AX6000

RESULT: {status}

Why Phase 18 exists:
Phase 17 used broad substring matching. That can incorrectly count unrelated
names such as DRA72 or cora72 as RA72, and jump03 as MP03. Phase 18 requires
token boundaries and separates identity signals from actual build/profile
locations.

Selected public source:
{source_url}

Counts:
{chr(10).join(f"- {key}: {value}" for key, value in counts.items())}

Interpretation:
- DIRECT_RA72_BUILD_PROFILE_SIGNAL_FOUND means a strict RA72/Mi-AIoT/MP03.1
  identity occurred in a build/profile context. It is still not proof that a
  complete or working port exists.
- STRICT_RA72_IDENTITY_SIGNAL_WITHOUT_BUILD_PROFILE means the identity exists
  somewhere, but no corresponding build target/profile was found.
- GENERIC_IPQ5018_BUILD_COMPONENTS_ONLY_NO_RA72_TARGET means the tree contains
  generic IPQ5018/IPQ50xx-related build material but no strict RA72 target.
- GENERIC_IPQ5018_COMPONENTS_ONLY_NO_RA72_TARGET means only generic component
  references were found.
- NO_ACTIONABLE_IPQ5018_OR_RA72_FOUNDATION means no useful public foundation
  was identified by this inventory audit.

Important:
An internal or proprietary DD-WRT tree may differ from the public SVN tree.
This report classifies only the public inventory retrieved by this run.

SAFETY:
- No firmware was built.
- No bootable image was produced.
- Nothing in this artifact is flashable.
- No router, SSH session, NAND partition, boot flag, or UART interface was used.
"""
(out_dir / "REPORT-PHASE18.txt").write_text(report, encoding="utf-8")
PY

gzip -9 -f "$INVENTORY"

echo
echo "Phase 18 classification complete."
cat "$REVIEW_DIR/phase18-status.txt"
