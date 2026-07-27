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
    libltdl_contract_path,
    ncurses_contract_path,
    gtkdocize_contract_path,
    meson_contract_path,
    util_linux_contract_path,
    util_linux_patch_contract_path,
    util_linux_install_contract_path,
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
libltdl_contract = read(libltdl_contract_path)
ncurses_contract = read(ncurses_contract_path)
gtkdocize_contract = read(gtkdocize_contract_path)
meson_contract = read(meson_contract_path)
util_linux_contract = read(util_linux_contract_path)
util_linux_patch_contract = read(util_linux_patch_contract_path)
util_linux_install_contract = read(util_linux_install_contract_path)


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
    "host_libltdl_macro_is_present":
        "ltdl_m4_present=PASS" in libltdl_contract,
    "host_libltdl_macro_is_readable":
        "ltdl_m4_readable=PASS" in libltdl_contract,
    "ncurses_native_rule_is_present":
        "ncurses_rule_present=PASS" in ncurses_contract,
    "ncurses_preconfigure_target_is_present":
        "ncurses_configure_target_present=PASS" in ncurses_contract,
    "ncurses_preconfigure_completed":
        "ncurses_preconfigure_status=0" in ncurses_contract,
    "ncurses_makefile_was_generated":
        "ncurses_makefile_present=PASS" in ncurses_contract,
    "host_gtkdocize_is_present":
        "gtkdocize_present=PASS" in gtkdocize_contract,
    "host_gtkdocize_is_executable":
        "gtkdocize_executable=PASS" in gtkdocize_contract,
    "host_meson_venv_was_created":
        "meson_venv_created=PASS" in meson_contract,
    "host_meson_is_executable":
        "meson_executable=PASS" in meson_contract,
    "host_meson_is_pinned_to_1_4_2":
        "meson_version_pinned=1.4.2" in meson_contract
        and "meson_version_actual=1.4.2" in meson_contract,
    "host_meson_meets_glib_requirement":
        "meson_version_required=1.4.0" in meson_contract
        and "meson_version_compatible=PASS" in meson_contract,
    "isolated_host_meson_is_active":
        "meson_active_path=PASS" in meson_contract,
    "isolated_host_meson_remains_active_with_cross_toolchain":
        "meson_build_path=PASS" in meson_contract,
    "util_linux_native_rule_is_present":
        "util_linux_rule_present=PASS" in util_linux_contract,
    "util_linux_preconfigure_target_is_present":
        "util_linux_configure_target_present=PASS" in util_linux_contract,
    "util_linux_preconfigure_completed":
        "util_linux_preconfigure_status=0" in util_linux_contract,
    "util_linux_makefile_was_generated":
        "util_linux_makefile_present=PASS" in util_linux_contract,
    "phase50_gtkdocize_failure_is_absent":
        "phase50_gtkdocize_failure_absent=PASS" in util_linux_contract,
    "util_linux_rule_was_patched_once":
        "util_linux_rule_patch=PASS" in util_linux_patch_contract
        and "changed_recipe_count=1" in util_linux_patch_contract,
    "util_linux_makeinstall_chown_is_disabled_once":
        "disable_makeinstall_chown_count=1" in util_linux_patch_contract,
    "util_linux_tty_group_is_disabled_once":
        "disable_use_tty_group_count=1" in util_linux_patch_contract,
    "util_linux_unprivileged_install_completed":
        "util_linux_install_test_status=0" in util_linux_install_contract,
    "util_linux_ownership_failure_is_absent":
        "ownership_operation_failure_absent=PASS"
        in util_linux_install_contract,
    "util_linux_generated_makefile_has_no_active_chgrp_tty":
        "generated_makefile_chgrp_tty_count=0"
        in util_linux_install_contract,
    "util_linux_generated_makefile_has_no_active_chown_root":
        "generated_makefile_chown_root_count=0"
        in util_linux_install_contract,
    "util_linux_install_stage_has_files":
        "staged_files_present=PASS" in util_linux_install_contract,
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
    print("Failed Phase 53 checks:", ", ".join(failed))
    raise SystemExit(1)

print(
    "Phase 53 DD-WRT RA72 userspace/rootfs checks passed: "
    f"{len(checks)}/{len(checks)}"
)
