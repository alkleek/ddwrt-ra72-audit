# Xiaomi Mi AIoT AX6000 RA72 DD-WRT port draft contract

This contract applies only to the Xiaomi **Mi AIoT AX6000**, model **RA72**,
based on Qualcomm IPQ5018 and board configuration MP03.1.

It does not apply to the Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 9 purpose

Phase 9 creates the first reviewable DD-WRT source-port draft. It imports the
working, GPL-licensed OpenWrt RA72 device-tree source into a staging directory,
compares its include dependencies with DD-WRT's IPQ5018 kernel tree, and emits
a patch draft for review.

## Required properties

- Device identity remains `xiaomi,ax6000` plus `qcom,ipq5018`.
- Three QCA8337 LAN ports and the QCA8081 WAN PHY remain defined.
- ART is read-only and supplies calibration/MAC data.
- Trusted-firmware and WCSS reserved-memory regions remain unchanged.
- No installer, NAND writer, sysupgrade hook, or boot-environment mutation is
  introduced.
- Raw device-specific DTB files and secrets are never included.

## Output classification

Every Phase 9 output is source text or a report. Nothing produced by this phase
is a kernel, initramfs, firmware image, or file approved for booting/flashing.

The next phase may attempt to compile the staged DTS inside a DD-WRT kernel
tree. A RAM-only prototype remains a later, separately reviewed milestone.
