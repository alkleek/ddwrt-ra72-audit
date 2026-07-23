# RA72 Device Tree compile-fix contract

This phase is exclusively for the Xiaomi Mi AIoT AX6000, model RA72,
Qualcomm IPQ5018 / MP03.1.

Phase 10 proved that preprocessing stopped because
`dt-bindings/input/input.h` requires the adjacent
`dt-bindings/input/linux-event-codes.h` header. Phase 11 adds that exact
upstream Linux 6.12 compatibility header and repeats preprocessing, Device
Tree compilation, decompilation, and hardware-identity checks.

The generated DTB is a compiler test object only. It is not DD-WRT firmware,
is not boot-tested, and must not be flashed, booted, installed, or deployed.
