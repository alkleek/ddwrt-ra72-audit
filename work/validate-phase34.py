from __future__ import annotations

import pathlib
import re
import sys


def read(path: str) -> str:
    return pathlib.Path(path).read_text(encoding="utf-8", errors="replace")


(
    phase33_status_path,
    fit_status_path,
    fit_list_path,
    fit_dts_path,
    comparison_path,
    mkits_path,
    fit_path,
    unexpected_path,
    output_path,
) = sys.argv[1:]

phase33_status = read(phase33_status_path)
fit_status = read(fit_status_path)
fit_list = read(fit_list_path)
fit_dts = read(fit_dts_path)
comparison = read(comparison_path)
mkits = read(mkits_path)
unexpected = read(unexpected_path).strip()
fit_file = pathlib.Path(fit_path)

checks = {
    "phase33_regeneration_passed":
        "RA72_NATIVE_DDWRT_KERNEL_MODULES_BUILD_PASS_REVIEW_ONLY"
        in phase33_status,
    "fit_generation_passed":
        "fit_generation_status=0" in fit_status,
    "fit_listing_passed":
        "fit_listing_status=0" in fit_status,
    "fit_decompile_passed":
        "fit_decompile_status=0" in fit_status,
    "kernel_extraction_passed":
        "kernel_extraction_status=0" in fit_status,
    "dtb_extraction_passed":
        "dtb_extraction_status=0" in fit_status,
    "kernel_payload_matches":
        "kernel_payload_match=PASS" in comparison,
    "dtb_payload_matches":
        "dtb_payload_match=PASS" in comparison,
    "gzip_payload_valid":
        "kernel_gzip_test=PASS" in comparison,
    "fit_file_exists":
        fit_file.is_file(),
    "fit_file_is_nontrivial":
        fit_file.is_file() and fit_file.stat().st_size > 1024 * 1024,
    "fit_identifies_arm64_architecture":
        bool(re.search(r"Architecture:\s+(?:AArch64|ARM64)", fit_list,
                       re.IGNORECASE)),
    "fit_identifies_linux_os":
        bool(re.search(r"OS:\s+Linux", fit_list, re.IGNORECASE)),
    "fit_identifies_gzip_compression":
        bool(re.search(r"Compression:\s+gzip", fit_list, re.IGNORECASE)),
    "fit_load_address_is_41000000":
        bool(re.search(r"Load Address:\s+0x41000000", fit_list,
                       re.IGNORECASE)),
    "fit_entry_point_is_41000000":
        bool(re.search(r"Entry Point:\s+0x41000000", fit_list,
                       re.IGNORECASE)),
    "fit_has_kernel_image_node":
        bool(re.search(r"\bkernel(?:@|[-_])", fit_dts, re.IGNORECASE)),
    "fit_has_fdt_image_node":
        bool(re.search(r"\bfdt(?:@|[-_])", fit_dts, re.IGNORECASE)),
    "fit_has_configuration_node":
        "configurations" in fit_dts,
    "fit_mentions_exact_ra72_identity":
        "xiaomi_mi_aiot_ax6000_ra72" in fit_dts
        or "Xiaomi Mi AIoT AX6000 RA72" in fit_dts,
    "fit_arch_property_is_arm64":
        bool(re.search(r'arch\s*=\s*"arm64"', fit_dts)),
    "fit_compression_property_is_gzip":
        bool(re.search(r'compression\s*=\s*"gzip"', fit_dts)),
    "fit_load_property_is_41000000":
        bool(re.search(r"load\s*=\s*<0x41000000>", fit_dts)),
    "fit_entry_property_is_41000000":
        bool(re.search(r"entry\s*=\s*<0x41000000>", fit_dts)),
    "native_ddwrt_mkits_supports_required_options":
        all(token in mkits for token in ("getopts", "-k", "-d", "-a", "-e")),
    "no_rootfs_or_flashable_image_built":
        not unexpected,
}

output = pathlib.Path(output_path)
output.write_text(
    "\n".join(
        f"{name}={'PASS' if value else 'FAIL'}"
        for name, value in sorted(checks.items())
    )
    + "\n",
    encoding="utf-8",
)

failed = [name for name, value in checks.items() if not value]
if failed:
    print("Failed Phase 34 checks:", ", ".join(failed))
    raise SystemExit(1)

print(
    "Phase 34 DD-WRT RA72 FIT kernel-container checks passed: "
    f"{len(checks)}/{len(checks)}"
)
