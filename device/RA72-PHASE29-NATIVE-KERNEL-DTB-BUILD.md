# Phase 29 native DD-WRT kernel DTB-build contract

Exact device: **Xiaomi Mi AIoT AX6000, model RA72**  
SoC/board: **Qualcomm IPQ5018 / MP03.1**

This contract does not apply to Xiaomi Mi Router AX6000 (IPQ8072A), Redmi
AX6000, or any device whose label does not state RA72.

## Phase 28 result

Phase 28 produced a source-only RA72 patch that:

- compiles through direct CPP/DTC validation;
- decompiles and round-trip compiles;
- labels the native IPQ5018 internal GE PHY at address 7;
- imports the native DD-WRT Q6 reserved-memory definitions;
- registers `ipq5018-xiaomi-ra72.dtb`;
- passes all source-integration checks.

## Phase 29 purpose

Phase 29 validates that same generated patch through the selected DD-WRT
kernel tree's own Kbuild path. It:

1. reproduces the successful Phase 28 patch;
2. exports the complete selected public DD-WRT kernel tree;
3. applies the patch to an untouched source layout;
4. uses the native `.config_ipq6018` baseline;
5. runs `olddefconfig`;
6. asks the kernel build system to build only
   `qcom/ipq5018-xiaomi-ra72.dtb`;
7. decompiles and round-trip checks the resulting DTB;
8. records hashes, build logs, source revision, config provenance, and
   integration checks.

## Acceptance criteria

- Phase 28 regeneration succeeds.
- The generated patch applies cleanly to the full kernel tree.
- Native IPQ5018 configuration completes successfully.
- The native kernel Kbuild target produces the exact RA72 DTB.
- The DTB contains the RA72 identity, Ethernet topology, GE PHY, WAN PHY,
  and Q6 memory ranges.
- DTB decompile and round-trip compile succeed.
- No kernel image, UBI, BIN, ITB, TRX, or firmware image is produced.

## Safety boundary

Phase 29 builds **one review DTB only** on GitHub's Ubuntu runner. It does
not build firmware, access a router, use SSH or UART, write NAND, or change
boot variables. The DTB is not approved for booting or flashing.
