# DD-WRT RA72 Phase 29

Phase 29 takes the successful source-only Phase 28 patch and asks the real
DD-WRT kernel build system to build the exact RA72 DTB.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## What this phase builds

Only:

`qcom/ipq5018-xiaomi-ra72.dtb`

It uses the complete selected public DD-WRT kernel tree and the native
`.config_ipq6018` baseline.

It does **not** build:

- a DD-WRT firmware;
- a kernel `Image`;
- UBI, BIN, ITB, TRX, or IMG files;
- anything approved for booting or flashing.

Nothing connects to the router. GitHub's Ubuntu runner performs all work.

## Run

In GitHub **Actions**, select:

`Phase 29: Build RA72 DTB through native DD-WRT kernel`

Press **Run workflow** and leave the three default fields unchanged.

The complete kernel export is much larger than earlier phases. The workflow
prints progress every 30 seconds and may take considerably longer.

Download:

`ddwrt-ra72-phase29-native-kernel-dtb-build`

Send back:

- `REPORT-PHASE29.txt`
- `review/phase29-status.txt`
- `review/build-status.txt`
- `review/phase29-integration-checks.txt`
- `review/olddefconfig.log`
- `review/native-kbuild.log`
- `review/warning-summary.txt`
- `review/native-dtb-decompile.log`

Do not boot or flash the generated review DTB.
