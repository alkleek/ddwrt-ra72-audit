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
    nfnetlink_compat_contract_path,
    autoconf_archive_contract_path,
    powertop_autoconf_contract_path,
    e2fsprogs_blkid_const_contract_path,
    e2fsprogs_private_link_contract_path,
    e2fsprogs_private_link_generated_contract_path,
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
nfnetlink_compat_contract = read(nfnetlink_compat_contract_path)
autoconf_archive_contract = read(autoconf_archive_contract_path)
powertop_autoconf_contract = read(powertop_autoconf_contract_path)
e2fsprogs_blkid_const_contract = read(
    e2fsprogs_blkid_const_contract_path
)
e2fsprogs_private_link_contract = read(
    e2fsprogs_private_link_contract_path
)
e2fsprogs_private_link_generated_contract = read(
    e2fsprogs_private_link_generated_contract_path
)
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
    "nfnetlink_compat_source_is_present":
        "source_present=PASS" in nfnetlink_compat_contract,
    "nfnetlink_compat_destination_is_present":
        "destination_present=PASS" in nfnetlink_compat_contract,
    "nfnetlink_compat_header_is_from_pinned_linux_tree":
        "source_path=src/linux/universal/linux-6.12-nss/"
        "include/uapi/linux/netfilter/nfnetlink_compat.h"
        in nfnetlink_compat_contract,
    "nfnetlink_compat_header_is_materialized_in_userspace_tree":
        "destination_path=src/router/kernel_headers/include/linux/"
        "netfilter/nfnetlink_compat.h"
        in nfnetlink_compat_contract,
    "nfnetlink_compat_source_and_destination_are_identical":
        "source_destination_identical=PASS"
        in nfnetlink_compat_contract,
    "nfnetlink_compat_include_guard_is_present":
        "nfnetlink_compat_guard_present=PASS"
        in nfnetlink_compat_contract,
    "autoconf_archive_package_is_installed":
        "package_installed=PASS" in autoconf_archive_contract,
    "autoconf_archive_aclocal_directory_is_present":
        "aclocal_directory_present=PASS" in autoconf_archive_contract,
    "all_required_powertop_ax_macros_are_present":
        "all_required_ax_macros=PASS" in autoconf_archive_contract
        and all(
            f"macro_{macro}_present=PASS" in autoconf_archive_contract
            for macro in (
                "AX_REQUIRE_DEFINED",
                "AX_ADD_FORTIFY_SOURCE",
                "AX_CXX_COMPILE_STDCXX",
                "AX_PTHREAD",
            )
        ),
    "powertop_configure_ac_is_present":
        "configure_ac_present=PASS" in powertop_autoconf_contract,
    "powertop_references_all_required_ax_macros":
        all(
            f"configure_ref_{macro}=PASS" in powertop_autoconf_contract
            for macro in (
                "AX_REQUIRE_DEFINED",
                "AX_ADD_FORTIFY_SOURCE",
                "AX_CXX_COMPILE_STDCXX",
                "AX_PTHREAD",
            )
        ),
    "powertop_autoconf_archive_contract_passed":
        "autoconf_archive_contract_passed=PASS"
        in powertop_autoconf_contract,
    "powertop_focused_autoconf_preflight_passed":
        "focused_autoconf_preflight_status=0"
        in powertop_autoconf_contract
        and "focused_autoconf_preflight_passed=PASS"
        in powertop_autoconf_contract,
    "powertop_generated_aclocal_m4_is_present":
        "generated_aclocal_m4_present=PASS"
        in powertop_autoconf_contract,
    "powertop_generated_configure_is_present":
        "generated_configure_present=PASS"
        in powertop_autoconf_contract,
    "powertop_ax_pthread_definition_is_materialized":
        "ax_pthread_definition_materialized=PASS"
        in powertop_autoconf_contract,
    "phase54_powertop_undefined_macro_failure_is_absent":
        "phase54_undefined_ac_msg_error_absent=PASS"
        in powertop_autoconf_contract,
    "e2fsprogs_blkid_source_is_present":
        "source_present=PASS" in e2fsprogs_blkid_const_contract,
    "util_linux_blkid_public_header_is_present":
        "public_header_present=PASS" in e2fsprogs_blkid_const_contract,
    "util_linux_blkid_discovery_root_is_present":
        "public_header_discovery_root_present=PASS"
        in e2fsprogs_blkid_const_contract,
    "util_linux_blkid_public_header_was_selected":
        "public_header_selected=PASS"
        in e2fsprogs_blkid_const_contract,
    "util_linux_blkid_template_selection_was_recorded":
        "public_header_selection_method="
        in e2fsprogs_blkid_const_contract,
    "util_linux_blkid_public_prototype_is_const_correct":
        "public_header_const_signature=PASS"
        in e2fsprogs_blkid_const_contract,
    "legacy_e2fsprogs_blkid_signature_was_unique":
        "legacy_function_signature_exactly_once=PASS"
        in e2fsprogs_blkid_const_contract
        and "legacy_search_type_exactly_once=PASS"
        in e2fsprogs_blkid_const_contract
        and "legacy_search_value_exactly_once=PASS"
        in e2fsprogs_blkid_const_contract,
    "e2fsprogs_blkid_const_patch_was_applied_once":
        "signature_replacements=1" in e2fsprogs_blkid_const_contract
        and "patched_const_signature_exactly_once=PASS"
        in e2fsprogs_blkid_const_contract,
    "legacy_e2fsprogs_blkid_nonconst_signature_is_absent":
        "legacy_nonconst_signature_absent=PASS"
        in e2fsprogs_blkid_const_contract,
    "e2fsprogs_blkid_patch_evidence_is_present":
        "patch_is_nonempty=PASS" in e2fsprogs_blkid_const_contract,
    "e2fsprogs_private_blkid_source_contract_passed":
        "source_root_present=PASS" in e2fsprogs_private_link_contract
        and "authoritative_sources_present=PASS"
        in e2fsprogs_private_link_contract,
    "e2fsprogs_private_blkid_legacy_reference_was_bounded":
        "legacy_reference_count_is_bounded=PASS"
        in e2fsprogs_private_link_contract,
    "e2fsprogs_private_blkid_source_reference_was_corrected":
        "all_legacy_references_replaced=PASS"
        in e2fsprogs_private_link_contract
        and "corrected_reference_count_matches=PASS"
        in e2fsprogs_private_link_contract,
    "e2fsprogs_private_blkid_source_patch_is_recorded":
        "patch_is_nonempty=PASS" in e2fsprogs_private_link_contract,
    "e2fsprogs_private_blkid_fallback_symlink_was_not_created":
        "no_fallback_symlink_created=PASS"
        in e2fsprogs_private_link_contract
        and "fallback_symlink_not_used=PASS"
        in e2fsprogs_private_link_generated_contract,
    "e2fsprogs_generated_mconfig_uses_private_blkid_name":
        "generated_mconfig_present=PASS"
        in e2fsprogs_private_link_generated_contract
        and "generated_libblkid_uses_private_name=PASS"
        in e2fsprogs_private_link_generated_contract,
    "e2fsprogs_generated_legacy_blkid_link_name_is_absent":
        "generated_legacy_libblkid_name_absent=PASS"
        in e2fsprogs_private_link_generated_contract,
    "e2fsprogs_private_blkid_shared_library_was_built":
        "private_shared_library_was_built=PASS"
        in e2fsprogs_private_link_generated_contract,
    "phase57_missing_private_blkid_target_is_absent":
        "phase57_missing_libblkid_target_absent=PASS"
        in e2fsprogs_private_link_generated_contract,
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
    print("Failed Phase 58 checks:", ", ".join(failed))
    raise SystemExit(1)

print(
    "Phase 58 DD-WRT RA72 userspace/rootfs checks passed: "
    f"{len(checks)}/{len(checks)}"
)
