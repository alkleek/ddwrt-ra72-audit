# DD-WRT source audit for Xiaomi Mi AIoT AX6000 RA72

This is **phase 1 only** of a private DD-WRT port investigation.

It runs manually on a GitHub-hosted Ubuntu runner and checks the public DD-WRT
source inventory for an existing Qualcomm IPQ5018/IPQ50xx platform foundation.

It does not:

- build firmware;
- modify a router;
- claim DD-WRT compatibility;
- produce anything safe to flash.

## Exact device

Only the Xiaomi **Mi AIoT AX6000**, model **RA72**, based on Qualcomm IPQ5018
and board configuration MP03.1 is in scope.

It is not for the Xiaomi Mi Router AX6000 or Redmi AX6000.

## Run

1. Upload this project to a new GitHub repository.
2. Open **Actions**.
3. Select **Audit DD-WRT source for Xiaomi Mi AIoT AX6000 RA72**.
4. Select **Run workflow**.
5. Download the artifact named `ddwrt-ra72-source-audit`.

Do not perform any operation on a router during this phase.

## Phase 2

Phase 2 checks whether the public tree contains a real DD-WRT IPQ5018
build/profile foundation rather than kernel drivers alone. Run:

`Audit DD-WRT IPQ5018 build foundation for RA72`

Its artifact is named `ddwrt-ra72-phase2-audit`. It is text-only and is not
firmware.

## Phase 3

Phase 3 inspects DD-WRT configuration, rules, and device initialization files
to locate the closest Qualcomm ARM64 build template for a new RA72 target. Run:

`Audit DD-WRT build system for a new RA72 target`

Its artifact is named `ddwrt-ra72-phase3-audit`. It contains reports and public
source excerpts only; it is not firmware.

## Phase 4

Phase 4 inspects the concrete IPQ5018 templates found in phase 3, especially
the Linksys MR5500 and MX5500. Run:

`Audit DD-WRT IPQ5018 templates for RA72`

Its artifact is named `ddwrt-ra72-phase4-audit`. It collects the relevant
public source excerpts needed to compare image construction, board detection,
flash layout, networking, Wi-Fi calibration, and MAC handling with RA72. It
does not build firmware.
