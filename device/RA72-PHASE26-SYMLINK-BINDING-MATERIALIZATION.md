# Phase 26 binding-symlink materialization contract

Exact device: **Xiaomi Mi AIoT AX6000, model RA72**  
SoC/board: **Qualcomm IPQ5018 / MP03.1**

## Phase 25 finding

The RA72-only dependency closure completed and the C preprocessor succeeded.
The first real DTC invocation then stopped at:

`dt-bindings/input/linux-event-codes.h:1.1-3 syntax error`

The downloaded file contained only this Git symbolic-link target:

`../../uapi/linux/input-event-codes.h`

That path is repository metadata, not valid C preprocessor input.

## Phase 26 correction

After fetching a required Linux binding, inspect a one-line file that contains
only a safe relative header path. Resolve that target relative to its logical
Linux include location, fetch the actual target below `include/`, and place
its contents at the original binding location.

The process is restricted to relative `.h`, `.dts`, or `.dtsi` targets,
rejects traversal outside `include/`, records every materialization, and
limits nested links to eight levels.

Expected first record:

`dt-bindings/input/linux-event-codes.h -> uapi/linux/input-event-codes.h`

## Acceptance criteria

- The expected Linux input-event-codes symlink is materialized.
- The RA72 dependency closure converges.
- DTS preprocess, compile, decompile, and round-trip compile succeed.
- The unified DD-WRT patch applies cleanly.
- All Phase 26 integration and safety checks pass.

## Safety boundary

This remains source-only. It produces no firmware and accesses no router.
