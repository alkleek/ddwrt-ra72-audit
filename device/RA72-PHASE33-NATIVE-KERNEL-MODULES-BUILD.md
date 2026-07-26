# RA72 Phase 33 native kernel-modules build contract

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not Xiaomi Mi Router AX6000 (IPQ8072A) and not Redmi AX6000.

## Purpose

Phase 33 extends the successful Phase 32 in-tree native kernel build. It:

1. regenerates and applies the verified Phase 28 RA72 source patch;
2. exports the complete selected DD-WRT IPQ5018 kernel tree;
3. uses the native DD-WRT `.config_ipq6018`;
4. builds `Image`, the exact-model RA72 DTB, and all configured kernel modules;
5. stages the modules with native `modules_install`;
6. inventories module names, hashes, architecture, dependencies, and aliases;
7. requires the QCA8337/QCA8K DSA module used by RA72 LAN ports;
8. records QCOM PPE and IPQ9574 PCS module resolution without falsely treating
   either as proof of a complete router firmware.

## Safety boundary

This phase does not build a root filesystem, FIT image, UBI image, TRX, BIN,
ITB, IMG, factory image, or upgrade image. It does not contact a router and
does not use SSH, UART, U-Boot, NAND, or boot variables.

The raw kernel Image, DTB, and `.ko` files are review components only. They
are not a bootable or flashable DD-WRT firmware and must not be loaded on the
router.

## Exit states

- `RA72_NATIVE_DDWRT_KERNEL_MODULES_BUILD_PASS_REVIEW_ONLY`
- `BLOCKED_PHASE28_PATCH_REGENERATION_FAILED`
- `BLOCKED_COMPLETE_DDWRT_KERNEL_EXPORT_FAILED`
- `BLOCKED_NATIVE_DDWRT_OLDDEFCONFIG_FAILED`
- `BLOCKED_NATIVE_DDWRT_KERNEL_MODULES_BUILD_FAILED`
- `BLOCKED_NATIVE_DDWRT_MODULES_INSTALL_FAILED`
- `BLOCKED_NATIVE_DDWRT_DTB_ROUNDTRIP_FAILED`
- `BLOCKED_NATIVE_DDWRT_KERNEL_MODULES_VALIDATION_FAILED`
- `BLOCKED_UNEXPECTED_ERROR`
