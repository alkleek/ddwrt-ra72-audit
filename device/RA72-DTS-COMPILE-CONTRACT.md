# Xiaomi Mi AIoT AX6000 RA72 Device Tree compile contract

This contract applies only to the Xiaomi **Mi AIoT AX6000**, model **RA72**,
based on Qualcomm IPQ5018 and board configuration MP03.1.

It does not apply to the Xiaomi Mi Router AX6000 (IPQ8072A), Redmi AX6000, or
any other device whose bottom label does not state RA72.

## Phase 10 purpose

Phase 10 tests whether the Phase 9 RA72 Device Tree source can be
preprocessed and compiled while using DD-WRT's public IPQ5018 kernel Device
Tree as its primary include environment.

The three generic Linux binding headers found missing or different in Phase 9
are placed in a temporary compatibility overlay. Their source and checksums
are recorded in the artifact. No DD-WRT source file is silently overwritten.

## Required checks

- The source retains `xiaomi,ax6000` and `qcom,ipq5018`.
- QCA8337 remains at MDIO address 17 (`ethernet-switch@11`).
- QCA8081 remains at MDIO address 8 (`ethernet-phy@8`).
- LAN labels remain `lan1`, `lan2`, and `lan3`; WAN remains `wan`.
- The compiled tree retains the RA72 NAND, ART, reserved-memory, Ethernet,
  Wi-Fi calibration, LED, and button descriptions supplied by the reviewed
  source.

## Output classification

A DTB emitted by this phase is a **compiler test object only**. It is not
combined with a DD-WRT kernel, has not passed boot validation, and is not a
firmware image.

Do not boot, flash, install, TFTP, write, or deploy any Phase 10 output.
