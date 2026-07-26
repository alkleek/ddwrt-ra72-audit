from __future__ import annotations

import pathlib
import re
import sys


def read(path: str) -> str:
    target = pathlib.Path(path)
    if not target.exists():
        return ""
    return target.read_text(encoding="utf-8", errors="replace")


(
    rootfs_path,
    stage_path,
    validation_status_path,
    busybox_type_path,
    unexpected_flashable_path,
    revision_contract_path,
    pcre_contract_path,
    sodium_contract_path,
    output_path,
) = sys.argv[1:]

rootfs = pathlib.Path(rootfs_path)
stage = pathlib.Path(stage_path)
validation_status = read(validation_status_path)
busybox_type = read(busybox_type_path)
unexpected_flashable = read(unexpected_flashable_path).strip()
revision_contract = read(revision_contract_path)
pcre_contract = read(pcre_contract_path)
sodium_contract = read(sodium_contract_path)


def any_exists(*names: str) -> bool:
    return any((stage / name).exists() for name in names)


checks = {
    "rootfs_file_exists": rootfs.is_file(),
    "rootfs_file_is_nontrivial":
        rootfs.is_file() and rootfs.stat().st_size > 1024 * 1024,
    "rootfs_fits_single_ra72_rootfs_partition":
        rootfs.is_file() and rootfs.stat().st_size < 36 * 1024 * 1024,
    "squashfs_superblock_valid":
        "superblock_status=0" in validation_status,
    "rootfs_extraction_passed":
        "extraction_status=0" in validation_status,
    "rootfs_stage_exists": stage.is_dir(),
    "rootfs_has_init":
        any_exists("sbin/init", "etc/preinit", "init"),
    "rootfs_has_shell":
        any_exists("bin/sh", "bin/ash"),
    "rootfs_has_busybox":
        any_exists("bin/busybox", "sbin/busybox"),
    "rootfs_has_etc": (stage / "etc").is_dir(),
    "rootfs_has_sbin": (stage / "sbin").is_dir(),
    "rootfs_has_ddwrt_web_files":
        any_exists("www", "www/index.asp", "www/index.html"),
    "busybox_is_arm64":
        bool(re.search(r"(?:ARM aarch64|ARM64|AArch64)", busybox_type,
                       re.IGNORECASE)),
    "verified_revision_headers_generated":
        "revision_headers_exact=PASS" in revision_contract,
    "pcre_rule_was_patched_once":
        "pcre_rule_patch=PASS" in pcre_contract,
    "pcre_c_library_built":
        "libpcre_shared=PASS" in pcre_contract,
    "pcre_posix_library_built":
        "libpcreposix_shared=PASS" in pcre_contract,
    "pcre_cpp_library_built":
        "libpcrecpp_shared=PASS" in pcre_contract,
    "pcre_cross_unit_tests_excluded":
        all(
            f"{name}_excluded=PASS" in pcre_contract
            for name in (
                "pcrecpp_unittest",
                "pcre_scanner_unittest",
                "pcre_stringpiece_unittest",
            )
        ),
    "libsodium_rule_was_patched_once":
        "sodium_rule_patch=PASS" in sodium_contract,
    "libsodium_system_config_helpers_found":
        "system_config_guess=PASS" in sodium_contract
        and "system_config_sub=PASS" in sodium_contract,
    "libsodium_config_helpers_are_executable":
        "libsodium_config_guess_executable=PASS" in sodium_contract
        and "libsodium_config_sub_executable=PASS" in sodium_contract,
    "libsodium_config_helpers_run":
        "libsodium_config_guess_runs=PASS" in sodium_contract
        and "libsodium_config_sub_aarch64_uclibc=PASS" in sodium_contract,
    "phase46_libsodium_failure_is_absent":
        "phase46_config_sub_failure_absent=PASS" in sodium_contract,
    "no_flashable_container_was_built": not unexpected_flashable,
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
    print("Failed Phase 48 checks:", ", ".join(failed))
    raise SystemExit(1)

print(
    "Phase 48 DD-WRT RA72 userspace/rootfs checks passed: "
    f"{len(checks)}/{len(checks)}"
)
