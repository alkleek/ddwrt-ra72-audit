# DD-WRT RA72 Phase 17 — IPQ5018 foundation classification

This project audits public DD-WRT source for the **Xiaomi Mi AIoT AX6000,
model RA72** only.

- SoC: Qualcomm IPQ5018
- Board: MP03.1
- Not the Xiaomi Mi Router AX6000 (IPQ8072A)
- Not the Redmi AX6000

## Result carried forward from Phase 16

Phase 16 confirmed that the public DD-WRT tree is reachable through:

`svn://svn.dd-wrt.com/DD-WRT`

It found 123 IPQ5018/IPQ50xx/RA72-related path signals. That count did **not**
prove that DD-WRT contains a buildable RA72 target.

## What Phase 17 does

Phase 17 classifies those source signals into exact device, build/profile,
kernel/Device Tree, and driver candidate groups. It generates a text report so
we can decide whether a genuine DD-WRT platform foundation exists.

This is a source audit only:

- no firmware is built;
- no router is contacted;
- no flash image is created;
- nothing in the artifact is safe or intended to flash.

## Run Phase 17

1. Upload this update over the files in the existing GitHub repository.
2. Open **Actions**.
3. Select:
   **Phase 17: Classify DD-WRT IPQ5018 build foundation for Xiaomi Mi AIoT AX6000 RA72**
4. Select **Run workflow**.
5. Keep the default source URL:
   `svn://svn.dd-wrt.com/DD-WRT`
6. When it finishes, download:
   `ddwrt-ra72-phase17-ipq5018-foundation-classification`
7. Send these two files for analysis:
   - `REPORT-PHASE17.txt`
   - `review/phase17-status.txt`

Older workflows and scripts remain in the repository as an audit history. Run
only the workflow whose title starts with **Phase 17**.

