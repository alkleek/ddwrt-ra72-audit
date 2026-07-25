# DD-WRT RA72 Phase 26

Phase 26 materializes Linux binding headers stored as Git symbolic links
before compiling the DD-WRT source patch for the exact
**Xiaomi Mi AIoT AX6000, model RA72**.

## Exact device

- Xiaomi Mi AIoT AX6000
- Model: RA72
- Qualcomm IPQ5018 / MP03.1

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000 (MediaTek).

## Why Phase 25 stopped

Phase 25 resolved the complete RA72 binding closure and successfully
preprocessed the DTS. DTC then read this as the complete contents of
`dt-bindings/input/linux-event-codes.h`:

`../../uapi/linux/input-event-codes.h`

This is the target of a Git symbolic link. A raw-file download returned the
link target path instead of the target header contents, so DTC reported a
syntax error on line 1.

## Phase 26 correction

The resolver now recognizes safe one-line relative Linux include links and
materializes the actual target header. Every replacement is recorded in:

`review/materialized-binding-symlinks.txt`

This phase then repeats the exact preprocess, DTC compile, decompile,
round-trip compile, patch-generation, and patch-application checks.

## Safety

No firmware is built, and no router is contacted. Nothing from this phase is
flashable.

## Run

In GitHub **Actions**, select:

`Phase 26: Materialize RA72 binding symlinks and compile patch`

Run with default inputs and download:

`ddwrt-ra72-phase26-symlink-binding-materialization`

Send back:

- `REPORT-PHASE26.txt`
- `review/phase26-status.txt`
- `review/phase26-integration-checks.txt`
- `review/materialized-binding-symlinks.txt`
- `review/binding-resolution.log`
- `review/required-include-closure.txt`
- `review/compile-status.txt`
- `review/cpp.log`
- `review/dtc-compile.log`
