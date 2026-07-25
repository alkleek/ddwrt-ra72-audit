# DD-WRT RA72 Phase 27

Phase 27 integrates the missing native GE PHY label before compiling the
DD-WRT source patch for the exact **Xiaomi Mi AIoT AX6000, model RA72**.

## Exact device

- Xiaomi Mi AIoT AX6000
- Model: RA72
- Qualcomm IPQ5018 / MP03.1

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000 (MediaTek).

## Why Phase 26 stopped

Phase 26 successfully materialized the Linux input-event-codes binding,
resolved the RA72 dependency closure, and completed preprocessing. DTC then
reported:

`Label or path ge_phy not found`

The native DD-WRT `ipq5018.dtsi` already contains the correct internal PHY
with compatible `ethernet-phy-id004d.d0c0` and `reg = <7>`, but its node is
named `ethernet-phy@0` and has no `ge_phy` label.

## Phase 27 correction

Phase 27 finds that exact existing node, labels it, and corrects only its
unit address:

`ge_phy: ethernet-phy@7`

It does not add or duplicate a PHY. The resulting `ipq5018.dtsi` change is
included in the unified DD-WRT review patch.

## Safety

No firmware is built, and no router is contacted. Nothing from this phase is
flashable.

## Run

In GitHub **Actions**, select:

`Phase 27: Integrate RA72 GE PHY label and compile patch`

Run with default inputs and download:

`ddwrt-ra72-phase27-ge-phy-label-integration`

Send back:

- `REPORT-PHASE27.txt`
- `review/phase27-status.txt`
- `review/phase27-integration-checks.txt`
- `review/ge-phy-resolution.txt`
- `review/compile-status.txt`
- `review/cpp.log`
- `review/dtc-compile.log`
- `review/ra72.decompiled.dts`
