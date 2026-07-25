from __future__ import annotations

import pathlib
import re
import sys


def read(path: str) -> str:
    return pathlib.Path(path).read_text(encoding="utf-8", errors="replace")


(
    phase28_status_path,
    build_status_path,
    config_path,
    decompiled_path,
    patch_path,
    build_log_path,
    unexpected_path,
    output_path,
) = sys.argv[1:]

phase28_status = read(phase28_status_path)
build_status = read(build_status_path)
config = read(config_path)
decompiled = read(decompiled_path)
patch = read(patch_path)
build_log = read(build_log_path)
unexpected = read(unexpected_path).strip()

checks = {
    "phase28_patch_regeneration_passed":
        "RA72_NATIVE_Q6_MEMORY_INTEGRATION_PATCH_COMPILES_REVIEW_ONLY"
        in phase28_status,
    "olddefconfig_passed": "olddefconfig_status=0" in build_status,
    "native_dtb_build_passed": "dtb_build_status=0" in build_status,
    "native_dtb_decompile_passed": "decompile_status=0" in build_status,
    "native_dtb_roundtrip_passed": "roundtrip_status=0" in build_status,
    "native_config_enables_arm64": "CONFIG_ARM64=y" in config,
    "native_config_enables_qcom": "CONFIG_ARCH_QCOM=y" in config,
    "exact_ra72_model_present":
        bool(re.search(
            r'model\s*=\s*"Xiaomi Mi AIoT AX6000 RA72"',
            decompiled,
        )),
    "exact_xiaomi_ax6000_compatible_present":
        "xiaomi,ax6000" in decompiled,
    "ipq5018_compatible_present": "qcom,ipq5018" in decompiled,
    "qca8337_switch_address_11_present":
        "ethernet-switch@11" in decompiled,
    "qca8081_wan_phy_address_8_present":
        "ethernet-phy@8" in decompiled,
    "internal_ge_phy_address_7_present":
        "ethernet-phy@7" in decompiled,
    "lan1_present": bool(re.search(r'label\s*=\s*"lan1"', decompiled)),
    "lan2_present": bool(re.search(r'label\s*=\s*"lan2"', decompiled)),
    "lan3_present": bool(re.search(r'label\s*=\s*"lan3"', decompiled)),
    "wan_present": bool(re.search(r'label\s*=\s*"wan"', decompiled)),
    "q6_region_address_present": "wcnss@4b000000" in decompiled,
    "q6_etr_region_address_present":
        "q6_etr_dump@4c800000" in decompiled,
    "patch_registers_exact_ra72_dtb":
        "ipq5018-xiaomi-ra72.dtb" in patch,
    "kernel_kbuild_invoked_exact_ra72_target":
        "qcom/ipq5018-xiaomi-ra72.dtb" in build_log,
    "no_firmware_or_kernel_image_built": not unexpected,
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
    print("Failed Phase 30 checks:", ", ".join(failed))
    raise SystemExit(1)

print(f"Phase 30 exact-model native-kernel checks passed: {len(checks)}/{len(checks)}")
