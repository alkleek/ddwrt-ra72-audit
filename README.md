# DD-WRT RA72 Phase 31

Phase 30 proved that the exact-model RA72 Device Tree builds successfully
through the native DD-WRT Linux 6.12 NSS kernel tree with 22/22 checks.

Phase 31 takes the next controlled step: it builds the native raw ARM64 Linux
`Image` together with the exact RA72 DTB. It also audits the resolved kernel
configuration required for NAND/UBI, Ethernet, MDIO/PHY, PCIe, and Qualcomm
Q6 foundations.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Safety

This phase builds a raw kernel Image and one review DTB only. The Image is
not complete DD-WRT firmware and is not approved for booting. It does not
build a root filesystem, module package, FIT, UBI, BIN, ITB, TRX, or IMG.
It does not contact the router. Do not boot or flash any Phase 31 file.

## Run

In GitHub **Actions**, select:

`Phase 31: Build native DD-WRT ARM64 kernel for exact RA72`

Press **Run workflow** and leave all three fields unchanged.

The complete kernel export is approximately 1.7 GB, so this workflow may
take longer than the earlier source-only phases. Progress is printed every
30 seconds.

Download:

`ddwrt-ra72-phase31-native-kernel-image-build`

Send back:

- `REPORT-PHASE31.txt`
- `review/phase31-status.txt`
- `review/build-status.txt`
- `review/phase31-integration-checks.txt`
- `review/model-identity-resolution.txt`
- `review/native-kernel-kbuild.log`
- `review/native-kernel-image-file.txt`
- `review/native-kernel-image-size.txt`
- `review/ra72-kernel-config-inventory.txt`
- `review/native-dtb-decompile.log`
- `review/warning-summary.txt`
