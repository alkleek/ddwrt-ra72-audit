# DD-WRT RA72 Phase 24

Phase 24 corrects the dependency collection step for the exact
**Xiaomi Mi AIoT AX6000, model RA72**.

## Exact device

- Xiaomi Mi AIoT AX6000
- Model: RA72
- Qualcomm IPQ5018 / MP03.1

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000 (MediaTek).

## Why Phase 23 stopped

Phase 23 passed the corrected Q6 dependency decision, then stopped while
resolving `dt-bindings`. It scanned every Qualcomm DTS exported from DD-WRT,
including unrelated devices. An include used only by another board could
therefore stop the RA72 audit.

## Phase 24 correction

Phase 24 constructs a recursive dependency closure beginning only with:

`ipq5018-xiaomi-ra72.dts`

It follows the DTS/DTSI files included by RA72 and resolves only the
`dt-bindings` reached through that chain. It records:

- every required source/header in `required-include-closure.txt`;
- each required download in `binding-resolution.log`;
- unresolved source includes in a dedicated file;
- explicit blocked statuses instead of a generic error.

It then compiles and round-trip checks the DTS and validates the unified
DD-WRT source patch.

## Safety

No firmware is built, and no router is contacted. Nothing in this phase is
flashable.

## Run

In GitHub **Actions**, select:

`Phase 24: Resolve RA72 bindings and compile DD-WRT patch`

Run with default inputs and download:

`ddwrt-ra72-phase24-scoped-binding-closure`

Send back:

- `REPORT-PHASE24.txt`
- `review/phase24-status.txt`
- `review/phase24-integration-checks.txt`
- `review/binding-resolution.log`
- `review/required-include-closure.txt`
- `review/missing-binding-includes.txt`
- `review/compile-status.txt`
- `review/cpp.log`
- `review/dtc-compile.log`
