# DD-WRT RA72 Phase 25

Phase 25 fixes nested binding-header resolution for the exact
**Xiaomi Mi AIoT AX6000, model RA72**.

## Exact device

- Xiaomi Mi AIoT AX6000
- Model: RA72
- Qualcomm IPQ5018 / MP03.1

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000 (MediaTek).

## Why Phase 24 stopped

The RA72-only dependency closure correctly reached:

`dt-bindings/input/input.h`

That header uses a quoted sibling include:

`linux-event-codes.h`

Phase 24 treated the missing sibling as an ordinary DTS source include.
Phase 25 correctly classifies it as:

`dt-bindings/input/linux-event-codes.h`

and allows the scoped binding fetcher to resolve it.

## Additional reliability correction

Expected compiler or resolver failures are now captured explicitly without
triggering the generic `BLOCKED_UNEXPECTED_ERROR` handler. The artifact will
therefore retain the precise blocked status and diagnostic logs if another
real dependency is missing.

## Safety

No firmware is built, and no router is contacted. Nothing from this phase is
flashable.

## Run

In GitHub **Actions**, select:

`Phase 25: Resolve nested RA72 bindings and compile patch`

Run with default inputs and download:

`ddwrt-ra72-phase25-nested-binding-resolution`

Send back:

- `REPORT-PHASE25.txt`
- `review/phase25-status.txt`
- `review/phase25-integration-checks.txt`
- `review/binding-resolution.log`
- `review/required-include-closure.txt`
- `review/missing-binding-includes.txt`
- `review/compile-status.txt`
- `review/cpp.log`
- `review/dtc-compile.log`
