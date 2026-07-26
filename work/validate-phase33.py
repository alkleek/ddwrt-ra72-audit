from __future__ import annotations

import pathlib
import re
import sys


def read(path: str) -> str:
    return pathlib.Path(path).read_text(encoding="utf-8", errors="replace")


def config_enabled(config: str, symbol: str) -> bool:
    return bool(re.search(rf"^{re.escape(symbol)}=(?:y|m)$", config, re.MULTILINE))


(
    phase28_status_path,
    build_status_path,
    config_path,
    decompiled_path,
    patch_path,
    build_log_path,
    install_log_path,
    unexpected_path,
    kernel_image_path,
    kernel_file_report_path,
    module_list_path,
    module_file_types_path,
    module_dependencies_path,
    critical_modules_path,
    output_path,
) = sys.argv[1:]

phase28_status = read(phase28_status_path)
build_status = read(build_status_path)
config = read(config_path)
decompiled = read(decompiled_path)
patch = read(patch_path)
build_log = read(build_log_path)
install_log = read(install_log_path)
unexpected = read(unexpected_path).strip()
kernel_file_report = read(kernel_file_report_path)
module_list = read(module_list_path)
module_file_types = read(module_file_types_path)
module_dependencies = read(module_dependencies_path)
critical_modules = read(critical_modules_path)
kernel_image = pathlib.Path(kernel_image_path)

required_config = (
    "CONFIG_ARM64",
    "CONFIG_ARCH_QCOM",
    "CONFIG_OF",
    "CONFIG_MODULES",
    "CONFIG_MTD",
    "CONFIG_MTD_RAW_NAND",
    "CONFIG_MTD_NAND_QCOM",
    "CONFIG_MTD_UBI",
    "CONFIG_MTD_UBI_BLOCK",
    "CONFIG_UBIFS_FS",
    "CONFIG_NET",
    "CONFIG_NET_DSA",
    "CONFIG_NET_DSA_QCA8K",
    "CONFIG_MDIO_IPQ4019",
    "CONFIG_AT803X_PHY",
    "CONFIG_QCA808X_PHY",
    "CONFIG_PHY_QCOM_ETH_UNIPHY",
    "CONFIG_PCIE_QCOM",
    "CONFIG_QCOM_Q6V5_COMMON",
    "CONFIG_QCOM_Q6V5_MPD",
    "CONFIG_QCOM_Q6V5_WCSS",
    "CONFIG_QCOM_SMEM",
    "CONFIG_QCOM_SMP2P",
)

module_paths = [
    line.strip()
    for line in module_list.splitlines()
    if line.strip() and not line.startswith("#")
]
module_count_match = re.search(r"^module_count=(\d+)$", build_status, re.MULTILINE)
module_count = int(module_count_match.group(1)) if module_count_match else 0

checks = {
    "phase28_patch_regeneration_passed":
        "RA72_NATIVE_Q6_MEMORY_INTEGRATION_PATCH_COMPILES_REVIEW_ONLY"
        in phase28_status,
    "build_status_records_in_tree_mode":
        "build_mode=in-tree" in build_status,
    "olddefconfig_passed":
        "olddefconfig_status=0" in build_status,
    "native_kernel_image_build_passed":
        "kernel_image_build_status=0" in build_status,
    "native_dtb_build_passed":
        "dtb_build_status=0" in build_status,
    "native_modules_build_passed":
        "modules_build_status=0" in build_status,
    "native_modules_install_passed":
        "modules_install_status=0" in build_status,
    "native_dtb_decompile_passed":
        "decompile_status=0" in build_status,
    "native_dtb_roundtrip_passed":
        "roundtrip_status=0" in build_status,
    "all_required_kernel_config_foundations_enabled":
        all(config_enabled(config, symbol) for symbol in required_config),
    "qca8337_driver_is_configured_as_module":
        bool(re.search(r"^CONFIG_NET_DSA_QCA8K=m$", config, re.MULTILINE)),
    "qcom_ppe_is_configured_as_module":
        bool(re.search(r"^CONFIG_QCOM_PPE=m$", config, re.MULTILINE)),
    "exact_ra72_model_present":
        bool(re.search(
            r'model\s*=\s*"Xiaomi Mi AIoT AX6000 RA72"',
            decompiled,
        )),
    "exact_xiaomi_ax6000_compatible_present":
        "xiaomi,ax6000" in decompiled,
    "ipq5018_compatible_present":
        "qcom,ipq5018" in decompiled,
    "qca8337_switch_address_11_present":
        "ethernet-switch@11" in decompiled,
    "qca8081_wan_phy_address_8_present":
        "ethernet-phy@8" in decompiled,
    "internal_ge_phy_address_7_present":
        "ethernet-phy@7" in decompiled,
    "lan1_present":
        bool(re.search(r'label\s*=\s*"lan1"', decompiled)),
    "lan2_present":
        bool(re.search(r'label\s*=\s*"lan2"', decompiled)),
    "lan3_present":
        bool(re.search(r'label\s*=\s*"lan3"', decompiled)),
    "wan_present":
        bool(re.search(r'label\s*=\s*"wan"', decompiled)),
    "q6_region_address_present":
        "wcnss@4b000000" in decompiled,
    "q6_etr_region_address_present":
        "q6_etr_dump@4c800000" in decompiled,
    "patch_registers_exact_ra72_dtb":
        "ipq5018-xiaomi-ra72.dtb" in patch,
    "kernel_build_log_is_nonempty":
        bool(build_log.strip()),
    "modules_install_log_is_nonempty":
        bool(install_log.strip()),
    "phase31_types_header_error_is_absent":
        "fatal error: types.h: No such file or directory" not in build_log,
    "phase31_stddef_header_error_is_absent":
        "fatal error: stddef.h: No such file or directory" not in build_log,
    "no_modpost_undefined_symbols":
        "undefined!" not in build_log.lower()
        and "undefined symbol" not in build_log.lower(),
    "kernel_image_exists":
        kernel_image.is_file(),
    "kernel_image_has_substantial_size":
        kernel_image.is_file() and kernel_image.stat().st_size > 4 * 1024 * 1024,
    "kernel_image_is_identified_as_arm64_linux":
        "linux kernel arm64 boot executable image" in kernel_file_report.lower(),
    "module_count_recorded":
        module_count > 0,
    "module_list_matches_recorded_count":
        module_count == len(module_paths),
    "qca8k_module_built_and_staged":
        bool(re.search(r"(?:^|/)qca8k(?:[-_][^/]*)?\.ko$", module_list,
                       re.MULTILINE)),
    "qcom_ppe_module_resolution_recorded":
        "qcom_ppe_module_count=" in critical_modules,
    "all_staged_modules_are_arm64":
        bool(module_file_types.strip())
        and "arm aarch64" in module_file_types.lower()
        and "x86-64" not in module_file_types.lower(),
    "module_dependency_metadata_present":
        "modules.dep" in module_dependencies
        and "modules.alias" in module_dependencies,
    "no_firmware_or_rootfs_built":
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
    print("Failed Phase 33 checks:", ", ".join(failed))
    raise SystemExit(1)

print(
    "Phase 33 native DD-WRT kernel-module checks passed: "
    f"{len(checks)}/{len(checks)}"
)
