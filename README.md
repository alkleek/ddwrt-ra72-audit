# DD-WRT RA72 Phase 34

Phase 33 successfully built and staged 322 native ARM64 kernel modules,
including the QCA8337/QCA8K switch, QCOM PPE, and IPQ9574 PCS modules.

Phase 34 verifies the next packaging layer: a review-only FIT/ITB container
holding the native RA72 kernel and exact-model Device Tree. The workflow
extracts both payloads again and byte-compares them with their inputs.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Safety

The ITB produced by this phase is not complete DD-WRT firmware. It contains
no rootfs, DD-WRT userspace, module package, UBI, factory image, or upgrade
image. It is not boot-approved or flash-approved. Do not load it into
U-Boot and do not transfer it to the router.

## Upload

Upload the contents of this update over the existing GitHub project. Keep
the folders exactly as provided, including `.github`.

## Run

In GitHub **Actions**, select:

`Phase 34: Build review-only RA72 FIT kernel container`

Press **Run workflow** and leave all three fields unchanged.

Phase 34 reproduces Phase 33 first, so a run can take approximately as long
as Phase 33 plus a few minutes.

Download the artifact:

`ddwrt-ra72-phase34-fit-kernel-container-build`

Send back:

- `REPORT-PHASE34.txt`
- `review/phase34-status.txt`
- `review/fit-build-status.txt`
- `review/phase34-integration-checks.txt`
- `review/fit-image-list.txt`
- `review/fit-payload-comparison.txt`
- `review/fit-structure.txt`
- `review/fit-build.log`
- `review/fit-extraction.log`

Do not boot, load, or flash any Phase 34 output.
