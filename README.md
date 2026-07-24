# DD-WRT source audit for Xiaomi Mi AIoT AX6000 RA72

This private project investigates whether the public DD-WRT source tree has a
usable foundation for a future port to the exact Xiaomi **Mi AIoT AX6000**,
model **RA72**, based on Qualcomm **IPQ5018 / MP03.1**.

It is not for the Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 18

Phase 18 corrects false positives in the Phase 17 source classification.
Broad substring searches can treat unrelated names such as `DRA72`, `cora72`,
or `jump03` as device evidence. Phase 18 uses strict path-token matching and
separates:

- exact RA72, Mi AIoT AX6000, and MP03.1 identity signals;
- identity signals located in build/profile paths;
- generic IPQ5018/IPQ50xx components;
- rejected substring false positives.

## Run Phase 18

1. Upload this update to the existing private GitHub repository.
2. Open **Actions**.
3. Select:
   **Phase 18: Strictly classify DD-WRT support for Xiaomi Mi AIoT AX6000 RA72**
4. Select **Run workflow**.
5. Keep the default source URL and select the green **Run workflow** button.
6. When the run succeeds, download:
   `ddwrt-ra72-phase18-strict-classification`
7. Extract it and review:
   - `REPORT-PHASE18.txt`
   - `review/phase18-status.txt`
   - `review/phase18-counts.txt`

## Safety

Phase 18:

- does not build DD-WRT firmware;
- does not produce a bootable or flashable image;
- does not connect to the router;
- does not use SSH or UART;
- does not write NAND or change boot variables.
