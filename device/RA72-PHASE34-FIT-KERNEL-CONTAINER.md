# RA72 Phase 34 FIT kernel-container contract

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not Xiaomi Mi Router AX6000 (IPQ8072A) and not Redmi AX6000.

## Purpose

Phase 34 extends the successful Phase 33 native kernel and module build. It:

1. regenerates the verified Phase 33 components;
2. fetches DD-WRT's public Qualcomm `mkits.sh`;
3. compresses the native ARM64 kernel deterministically with gzip;
4. creates a single-configuration RA72 FIT/ITB kernel container;
5. uses the reconstructed load and entry address `0x41000000`;
6. embeds the exact-model `ipq5018-xiaomi-ra72` DTB;
7. lists and decompiles the FIT;
8. extracts the kernel and DTB from the FIT;
9. byte-compares both extracted payloads against their verified inputs.

## Safety boundary

The resulting ITB contains only a review kernel and DTB. It has no root
filesystem, DD-WRT userspace, kernel-module package, UBI volume, vendor
header, Xiaomi install wrapper, factory image, or upgrade image.

The ITB is not boot-approved and must not be loaded through U-Boot, SSH, or
UART. No Phase 34 file may be flashed.

The workflow never contacts the router and never accesses NAND or boot
variables.

## Exit states

- `RA72_DDWRT_FIT_KERNEL_CONTAINER_BUILD_PASS_REVIEW_ONLY`
- `BLOCKED_PHASE33_REGENERATION_FAILED`
- `BLOCKED_DDWRT_MKITS_FETCH_FAILED`
- `BLOCKED_RA72_FIT_GENERATION_FAILED`
- `BLOCKED_RA72_FIT_EXTRACTION_FAILED`
- `BLOCKED_RA72_FIT_PAYLOAD_MISMATCH`
- `BLOCKED_RA72_FIT_VALIDATION_FAILED`
- `BLOCKED_UNEXPECTED_ERROR`
