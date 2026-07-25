#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="phase21-output"
REVIEW_DIR="$OUT_DIR/review"
SOURCE_DIR="$REVIEW_DIR/source"
ATTEMPTS="$REVIEW_DIR/source-attempts.txt"
FETCH_LOG="$REVIEW_DIR/source-fetch.log"
SOURCE_URL="${DDWRT_SOURCE_URL:-svn://svn.dd-wrt.com/DD-WRT}"

rm -rf "$OUT_DIR"
mkdir -p "$REVIEW_DIR" "$SOURCE_DIR"
: > "$ATTEMPTS"
: > "$FETCH_LOG"

echo "DD-WRT RA72 Phase 21 build-contract reconstruction"
echo "Exact device: Xiaomi Mi AIoT AX6000, model RA72"
echo "SoC/board: Qualcomm IPQ5018 / MP03.1"
echo "SAFETY: source audit only; no firmware is built and no router is accessed."

declare -a REQUIRED_FILES=(
  "src/router/Makefile.ipq60xx"
  "src/router/tools/qcom/mkits.sh"
  "src/router/tools/qcom/ubinize-image.sh"
)

declare -a OPTIONAL_FILES=(
  "src/router/tools/qcom/ubinize-image.sh.buf"
  "src/linux/universal/linux-6.12-nss/.config_ipq6018"
  "src/linux/universal/linux-6.6-nss/.config_ipq6018"
  "src/linux/universal/linux-6.12-nss/arch/arm64/boot/dts/qcom/ipq5018-mr5500.dts"
  "src/linux/universal/linux-6.12-nss/arch/arm64/boot/dts/qcom/ipq5018-mx5500.dts"
  "src/linux/universal/linux-6.12/arch/arm64/boot/dts/qcom/ipq5018-spnmx56.dts"
)

select_source() {
  local candidate
  local test_file="${REQUIRED_FILES[0]}"
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
    if timeout 10m svn cat "${candidate%/}/$test_file" \
      > /dev/null 2>> "$ATTEMPTS"; then
      printf '%s\n' "${candidate%/}" > "$REVIEW_DIR/selected-source-url.txt"
      return 0
    fi
  done

  return 1
}

write_blocked_report() {
  local status="$1"
  printf '%s\n' "$status" > "$REVIEW_DIR/phase21-status.txt"
  cat > "$OUT_DIR/REPORT-PHASE21.txt" <<EOF
DD-WRT RA72 Phase 21 build-contract reconstruction

Exact device: Xiaomi Mi AIoT AX6000, model RA72
SoC/board: Qualcomm IPQ5018 / MP03.1

STATUS: $status

The required public DD-WRT source material was unavailable or incomplete.
No RA72 build-contract draft was approved by this audit.

SAFETY:
- No firmware was built.
- Nothing in this artifact is flashable.
- No router was accessed or modified.
EOF
}

if ! select_source; then
  write_blocked_report "SOURCE_UNAVAILABLE"
  exit 1
fi

SELECTED_URL="$(cat "$REVIEW_DIR/selected-source-url.txt")"

fetch_file() {
  local relative_path="$1"
  local destination="$SOURCE_DIR/$relative_path"
  mkdir -p "$(dirname "$destination")"

  echo "Fetching $relative_path" >> "$FETCH_LOG"
  if timeout 10m svn cat "$SELECTED_URL/$relative_path" \
    > "$destination.tmp" 2>> "$FETCH_LOG"; then
    mv "$destination.tmp" "$destination"
    return 0
  fi

  rm -f "$destination.tmp"
  echo "FAILED $relative_path" >> "$FETCH_LOG"
  return 1
}

missing_required=0
for relative_path in "${REQUIRED_FILES[@]}"; do
  if ! fetch_file "$relative_path"; then
    missing_required=1
  fi
done

for relative_path in "${OPTIONAL_FILES[@]}"; do
  fetch_file "$relative_path" || true
done

if [[ "$missing_required" -ne 0 ]]; then
  write_blocked_report "REQUIRED_BUILD_SOURCE_INCOMPLETE"
  exit 1
fi

python3 - "$SOURCE_DIR" "$REVIEW_DIR" \
  "$OUT_DIR/REPORT-PHASE21.txt" "$SELECTED_URL" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1])
review = pathlib.Path(sys.argv[2])
report_path = pathlib.Path(sys.argv[3])
source_url = sys.argv[4]

makefile_path = source / "src/router/Makefile.ipq60xx"
mkits_path = source / "src/router/tools/qcom/mkits.sh"
ubinize_path = source / "src/router/tools/qcom/ubinize-image.sh"

makefile = makefile_path.read_text(encoding="utf-8", errors="replace")
mkits = mkits_path.read_text(encoding="utf-8", errors="replace")
ubinize = ubinize_path.read_text(encoding="utf-8", errors="replace")


def extract_make_section(label: str) -> str:
    pattern = re.compile(
        rf"(?mi)^#{re.escape(label)}[ \t]*\r?\n"
        rf"(.*?)(?=^#[A-Za-z0-9][^\r\n]*\r?$|\Z)",
        re.DOTALL,
    )
    match = pattern.search(makefile)
    if not match:
        return ""
    return f"#{label}\n{match.group(1).rstrip()}\n"


def context_for(pattern: str, before: int = 5, after: int = 8) -> list[str]:
    lines = makefile.splitlines()
    regex = re.compile(pattern, re.IGNORECASE)
    blocks: list[str] = []
    for index, line in enumerate(lines):
        if regex.search(line):
            start = max(0, index - before)
            end = min(len(lines), index + after + 1)
            blocks.append("\n".join(lines[start:end]))
    return blocks


mr5500_block = extract_make_section("mr5500")
mx5500_block = extract_make_section("mx5500")
rootfs_blocks = context_for(r"root\.ipq5018", before=3, after=4)
ubi_kernel_blocks = context_for(
    r"ubinize-image\.sh[^\n]*--kernel",
    before=4,
    after=5,
)

(review / "reference-mr5500-block.mk").write_text(
    mr5500_block, encoding="utf-8"
)
(review / "reference-mx5500-block.mk").write_text(
    mx5500_block, encoding="utf-8"
)
(review / "reference-ipq5018-rootfs-blocks.txt").write_text(
    "\n\n---\n\n".join(rootfs_blocks) + ("\n" if rootfs_blocks else ""),
    encoding="utf-8",
)
(review / "reference-ubi-kernel-blocks.txt").write_text(
    "\n\n---\n\n".join(ubi_kernel_blocks)
    + ("\n" if ubi_kernel_blocks else ""),
    encoding="utf-8",
)

checks = {
    "makefile_has_root_ipq5018": "root.ipq5018" in makefile,
    "mr5500_recipe_found": bool(mr5500_block),
    "mr5500_uses_ipq5018_rootfs": "root.ipq5018" in mr5500_block,
    "mx5500_recipe_found": bool(mx5500_block),
    "mx5500_uses_ipq5018_rootfs": "root.ipq5018" in mx5500_block,
    "reference_uses_128k_peb": bool(
        re.search(r"-p[ \t]+128KiB", mr5500_block + mx5500_block)
    ),
    "reference_uses_2048_min_io": bool(
        re.search(r"-m[ \t]+2048", mr5500_block + mx5500_block)
    ),
    "mkits_supports_device_name": bool(
        re.search(r"(?:getopts|case).*D|[- ]D[ )]", mkits, re.DOTALL)
    ),
    "mkits_supports_dtb": bool(
        re.search(r"(?:getopts|case).*d|[- ]d[ )]", mkits, re.DOTALL)
    ),
    "ubinize_supports_kernel": "--kernel" in ubinize,
    "ubinize_supports_rootfs": "--rootfs" in ubinize,
    "existing_kernel_rootfs_ubi_reference": bool(ubi_kernel_blocks),
}

draft = r"""# REVIEW-ONLY DD-WRT RA72 image-recipe fragment
# Exact device: Xiaomi Mi AIoT AX6000, model RA72, IPQ5018 / MP03.1.
# This fragment is not integrated, executed, boot-tested, or flash-approved.
# Required future DTS: ipq5018-xiaomi-ra72.dts

#ra72-review
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

forbidden_patterns = {
    "linksys_header": r"(?i)\.LINKSYS",
    "linksys_model": r"(?i)\b(?:MR5500|MX5500)\b",
    "trx_wrapper": r"(?i)\btrx_n\b",
    "flash_writer": r"(?i)\b(?:ubiformat|sysupgrade|fw_setenv)\b",
    "mtd_writer": r"(?i)\bmtd[ \t]+(?:write|erase)\b",
    "router_access": r"(?i)\b(?:ssh|scp)[ \t]+root@",
}
for name, pattern in forbidden_patterns.items():
    checks[f"draft_excludes_{name}"] = not bool(re.search(pattern, draft))

checks["draft_uses_ra72_identity"] = (
    "xiaomi_mi_aiot_ax6000_ra72" in draft
    and "ipq5018-xiaomi-ra72.dtb" in draft
)
checks["draft_uses_ipq5018_rootfs"] = "root.ipq5018" in draft
checks["draft_uses_kernel_rootfs_ubi"] = (
    "--kernel" in draft and "--rootfs" in draft
)
checks["draft_uses_verified_nand_geometry"] = (
    "-p 128KiB" in draft and "-m 2048" in draft
)

required_checks = [
    "makefile_has_root_ipq5018",
    "mr5500_recipe_found",
    "mr5500_uses_ipq5018_rootfs",
    "mx5500_recipe_found",
    "mx5500_uses_ipq5018_rootfs",
    "reference_uses_128k_peb",
    "reference_uses_2048_min_io",
    "mkits_supports_device_name",
    "mkits_supports_dtb",
    "ubinize_supports_kernel",
    "ubinize_supports_rootfs",
    "existing_kernel_rootfs_ubi_reference",
    "draft_excludes_linksys_header",
    "draft_excludes_linksys_model",
    "draft_excludes_trx_wrapper",
    "draft_excludes_flash_writer",
    "draft_excludes_mtd_writer",
    "draft_excludes_router_access",
    "draft_uses_ra72_identity",
    "draft_uses_ipq5018_rootfs",
    "draft_uses_kernel_rootfs_ubi",
    "draft_uses_verified_nand_geometry",
]

failed = [name for name in required_checks if not checks.get(name, False)]

(review / "phase21-contract-checks.txt").write_text(
    "\n".join(
        f"{name}={'PASS' if value else 'FAIL'}"
        for name, value in sorted(checks.items())
    )
    + "\n",
    encoding="utf-8",
)

if failed:
    status = "BLOCKED_BUILD_CONTRACT_INCOMPLETE"
    (review / "phase21-failed-checks.txt").write_text(
        "\n".join(failed) + "\n",
        encoding="utf-8",
    )
else:
    status = "RA72_BUILD_CONTRACT_RECONSTRUCTED_REVIEW_ONLY"
    (review / "ra72-image-recipe-review.mk").write_text(
        draft, encoding="utf-8"
    )

(review / "phase21-status.txt").write_text(status + "\n", encoding="utf-8")

report = [
    "DD-WRT RA72 Phase 21 build-contract reconstruction",
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
    "Established public DD-WRT foundation",
    "------------------------------------",
    "- Platform integration: src/router/Makefile.ipq60xx",
    "- Root filesystem family: root.ipq5018",
    "- Direct IPQ5018 recipe references: MR5500 and MX5500",
    "- FIT/ITB load and entry address: 0x41000000",
    "- NAND geometry: 128 KiB PEB, 2048-byte minimum I/O",
    "- Kernel+rootfs UBI capability: ubinize-image.sh",
    "",
    "RA72-specific decision",
    "----------------------",
    "The Linksys footer, checksum structure, fixed padding, and TRX wrapper",
    "are vendor-specific and are excluded from the RA72 review draft.",
    "The draft instead uses a single review UBI containing kernel and rootfs.",
    "",
    f"Required checks passed: {len(required_checks) - len(failed)}/{len(required_checks)}",
]

if failed:
    report.extend([
        "Failed checks:",
        *[f"- {name}" for name in failed],
    ])
else:
    report.extend([
        "",
        "Review draft",
        "------------",
        "review/ra72-image-recipe-review.mk",
        "",
        "The draft is source text only. It has not been inserted into DD-WRT,",
        "executed, compiled, booted, or tested on hardware.",
    ])

report.extend([
    "",
    "Safety",
    "------",
    "No firmware was built. Nothing in this artifact is flashable.",
    "No router, NAND partition, boot flag, SSH session, or UART was used.",
])

report_path.write_text("\n".join(report) + "\n", encoding="utf-8")
PY

echo
echo "Phase 21 status: $(cat "$REVIEW_DIR/phase21-status.txt")"
