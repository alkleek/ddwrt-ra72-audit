# DD-WRT RA72 Phase 23

Phase 23 corrects the failed Phase 22 dependency rule for the exact
**Xiaomi Mi AIoT AX6000, model RA72**.

## Exact device

- Xiaomi Mi AIoT AX6000
- Model: RA72
- SoC: Qualcomm IPQ5018
- Board family: MP03.1

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000 (MediaTek).
The source compatible `xiaomi,ax6000` refers to RA72 in this project.

## Why Phase 22 failed

Phase 22 always demanded historical labels named `q6_region` and
`q6_etr_region`. The current verified RA72 DTS does not reference those labels,
so requiring their definitions was incorrect.

## What Phase 23 changes

Phase 23 evaluates Q6 dependencies dynamically:

- if the current RA72 DTS does not reference a label, the label is not needed;
- if it references a label already defined by the native DD-WRT base, that
  native definition is used;
- if a referenced label is unresolved, the phase stops safely.

It then performs the same temporary DD-WRT source integration, DTS compile,
decompile, round-trip compile, unified-patch generation, and clean patch-apply
test.

## Safety

No firmware is built. No router is contacted. Nothing from this phase is
flashable.

## Run

Open GitHub **Actions** and select:

`Phase 23: Integrate current DD-WRT RA72 DTS patch`

Run it with the default inputs and download:

`ddwrt-ra72-phase23-current-dts-integration`

Send back:

- `REPORT-PHASE23.txt`
- `review/phase23-status.txt`
- `review/phase23-integration-checks.txt`
- `review/q6-resolution.tsv`
- `review/compile-status.txt`
- `review/dtc-compile.log`
- `patches/0001-ddwrt-add-xiaomi-mi-aiot-ax6000-ra72-review.patch`
