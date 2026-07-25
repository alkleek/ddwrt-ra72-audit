# DD-WRT RA72 Phase 30

Phase 29 proved that the native DD-WRT kernel can build the RA72 Device Tree.
Its only failed validation was the generic human-readable model string.

Phase 30 corrects that property to:

`Xiaomi Mi AIoT AX6000 RA72`

and repeats the native Kbuild, decompile, and round-trip validation.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Safety

This phase builds one review DTB only. It does not build DD-WRT firmware,
a kernel image, UBI, BIN, ITB, TRX, or IMG. It does not contact the router.
Do not boot or flash the review DTB.

## Run

In GitHub **Actions**, select:

`Phase 30: Build exact-model RA72 DTB through native DD-WRT kernel`

Press **Run workflow** and leave all three fields unchanged.

The complete kernel export is approximately 1.7 GB, so this workflow may
take longer than the earlier source-only phases. Progress is printed every
30 seconds.

Download:

`ddwrt-ra72-phase30-exact-model-native-dtb-build`

Send back:

- `REPORT-PHASE30.txt`
- `review/phase30-status.txt`
- `review/build-status.txt`
- `review/phase30-integration-checks.txt`
- `review/model-identity-resolution.txt`
- `review/native-kbuild.log`
- `review/native-dtb-decompile.log`
- `review/warning-summary.txt`
