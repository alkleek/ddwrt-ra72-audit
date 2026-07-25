# DD-WRT RA72 Phase 28

Phase 28 integrates the missing native Q6 memory nodes before compiling the
DD-WRT source patch for the exact **Xiaomi Mi AIoT AX6000, model RA72**.

## Exact device

- Xiaomi Mi AIoT AX6000
- Model: RA72
- Qualcomm IPQ5018 / MP03.1

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000 (MediaTek).

## Why Phase 27 stopped

Phase 27 successfully found and labeled the existing internal GE PHY. DTC
then reported missing `q6_region` and `q6_etr_region` labels referenced by
the active native DD-WRT `ipq5018.dtsi`.

## Phase 28 correction

Phase 28 detects references across the real RA72 include closure and imports
only the missing balanced memory nodes from DD-WRT's direct MR5500/MX5500
IPQ5018 image templates. Both template definitions must agree before use.

Expected ranges:

```text
q6_region      0x4b000000  size 0x01700000
q6_etr_region  0x4c800000  size 0x00100000
```

Source files and SHA-256 values are recorded in:

`review/q6-node-provenance.tsv`

## Safety

No firmware is built, and no router is contacted. Nothing from this phase is
flashable.

## Run

In GitHub **Actions**, select:

`Phase 28: Integrate native RA72 Q6 memory nodes and compile patch`

Run with default inputs and download:

`ddwrt-ra72-phase28-native-q6-memory-integration`

Send back:

- `REPORT-PHASE28.txt`
- `review/phase28-status.txt`
- `review/phase28-integration-checks.txt`
- `review/q6-resolution.tsv`
- `review/q6-node-provenance.tsv`
- `review/compile-status.txt`
- `review/dtc-compile.log`
- `review/ra72.decompiled.dts`
