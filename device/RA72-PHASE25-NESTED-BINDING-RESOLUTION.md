# Phase 25 nested-binding contract

Exact device: **Xiaomi Mi AIoT AX6000, model RA72**  
SoC/board: **Qualcomm IPQ5018 / MP03.1**

## Corrected nested-header rule

When a file already inside `dt-bindings` includes a missing sibling header
with quotes, resolve the sibling relative to that binding file and classify it
as another required `dt-bindings` dependency.

Example verified by Phase 24:

`dt-bindings/input/input.h` -> `dt-bindings/input/linux-event-codes.h`

The dependency-closure loop repeats after each scoped fetch so nested
dependencies are discovered transitively.

## Error-status rule

Commands whose failure is being measured must be guarded explicitly. Expected
non-zero results are recorded in dedicated status files and logs; only truly
unexpected failures use the generic error handler.

## Acceptance criteria

- Nested sibling binding headers resolve.
- The RA72 dependency closure converges.
- No RA72 source include remains unresolved.
- DTS compile, decompile, and round-trip compile succeed.
- The unified DD-WRT patch applies cleanly.
- All Phase 25 integration and safety checks pass.

## Safety boundary

This remains source-only. It produces no firmware and accesses no router.
