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
