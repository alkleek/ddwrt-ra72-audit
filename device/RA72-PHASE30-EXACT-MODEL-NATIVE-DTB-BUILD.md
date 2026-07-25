# Phase 30 exact-model native DD-WRT DTB-build contract

Exact device: **Xiaomi Mi AIoT AX6000, model RA72**  
SoC/board: **Qualcomm IPQ5018 / MP03.1**

This is not the Xiaomi Mi Router AX6000 (IPQ8072A), Redmi AX6000, or any
device whose label does not state RA72.

## Phase 29 finding

The native DD-WRT kernel build succeeded:

- `olddefconfig_status=0`
- `dtb_build_status=0`
- `decompile_status=0`
- `roundtrip_status=0`
- 21 of 22 validation checks passed

The sole failed check was the root `model` display property. The verified
GPL source used the generic text `Xiaomi AX6000`, even though the binding
identity and hardware topology were correct.

## Phase 30 correction

Phase 30 changes only the human-readable root model property to:

`Xiaomi Mi AIoT AX6000 RA72`

It preserves:

- `compatible = "xiaomi,ax6000", "qcom,ipq5018";`
- all Ethernet, Wi-Fi, PCIe, NAND, Q6, and reserved-memory definitions;
- the native DD-WRT IPQ6018 configuration;
- the Phase 28 patch provenance and integration checks.

The complete source patch is then rebuilt through DD-WRT's native kernel
Kbuild target and subjected to decompile and round-trip checks.

## Safety boundary

Only a review DTB is built on GitHub. No firmware, kernel image, UBI, BIN,
ITB, TRX, or IMG is produced. No router is accessed, and nothing is approved
for booting or flashing.
