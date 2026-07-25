# DD-WRT RA72 Phase 22

This repository update performs a temporary, review-only source integration
for the exact **Xiaomi Mi AIoT AX6000, model RA72**.

## Exact device

- Xiaomi Mi AIoT AX6000
- Model: RA72
- SoC: Qualcomm IPQ5018
- Board family: MP03.1

It is **not** for the Xiaomi Mi Router AX6000 (IPQ8072A), and it is not for the
Redmi AX6000 (MediaTek). The DD-WRT project may use the upstream compatible
string `xiaomi,ax6000`; in this project that compatible refers only to RA72.

## What Phase 22 does

Phase 22:

1. obtains the public DD-WRT IPQ5018 kernel/device-tree source;
2. imports the verified GPL RA72 board DTS as a reference;
3. supplies the exact Q6 reserved-memory nodes required by the DD-WRT base;
4. registers `ipq5018-xiaomi-ra72.dtb` in the DD-WRT Qualcomm DTS Makefile;
5. inserts the Phase 21 review recipe into a temporary
   `src/router/Makefile.ipq60xx`;
6. preprocesses, compiles, decompiles, and round-trip compiles the RA72 DTS;
7. generates a unified source patch and validates that it applies cleanly.

## Safety boundary

This phase does **not** build DD-WRT firmware.

- No UBI, BIN, ITB firmware, or sysupgrade file is produced.
- No router is contacted.
- No SSH, UART, NAND, boot flag, or flash command is used.
- The generated patch remains review-only and is not hardware-approved.

## Run

In GitHub, open **Actions** and select:

`Phase 22: Integrate and compile DD-WRT RA72 source patch`

Press **Run workflow**, then download:

`ddwrt-ra72-phase22-source-integration-compile`

Send back these files:

- `REPORT-PHASE22.txt`
- `review/phase22-status.txt`
- `review/phase22-integration-checks.txt`
- `review/compile-status.txt`
- `review/dtc-compile.log`
- `patches/0001-ddwrt-add-xiaomi-mi-aiot-ax6000-ra72-review.patch`

Do not flash anything produced by Phase 22.
