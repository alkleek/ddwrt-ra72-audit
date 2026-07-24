# RA72 Phase 12 Device Tree compile contract

This phase is exclusively for the Xiaomi Mi AIoT AX6000, model RA72,
Qualcomm IPQ5018 / MP03.1.

Phase 10 identified a missing input binding header. Historical Phase 11
iterations resolved that header, symlink, and Device Tree composition issues.
Phase 12 consolidates those corrections: it retains DD-WRT's native
`ipq5018.dtsi` and `ipq5018-ess.dtsi`, imports only the RA72 board DTS,
excludes the OpenWrt-only `&ge_phy` overlay from this compiler test, supplies
the required Linux 6.12 input binding header, and repeats preprocessing,
Device Tree compilation, decompilation, and hardware-identity checks.

The generated DTB is a compiler test object only. It is not DD-WRT firmware,
is not boot-tested, and must not be flashed, booted, installed, or deployed.
