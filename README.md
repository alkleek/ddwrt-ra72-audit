# DD-WRT source audit for Xiaomi Mi AIoT AX6000 RA72

## Phase 21 - build-contract reconstruction

This repository is a private, source-only investigation for the:

- **Xiaomi Mi AIoT AX6000**
- model **RA72**
- Qualcomm **IPQ5018**
- board configuration **MP03.1**

It is not for the Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

Phase 20 established that the public DD-WRT tree already builds IPQ5018
root filesystems and contains real MR5500/MX5500 image recipes in:

`src/router/Makefile.ipq60xx`

Phase 21 extracts the reusable parts of that integration and reconstructs a
review-only RA72 build contract. It verifies:

- the `root.ipq5018` root filesystem path;
- the IPQ5018 FIT/ITB construction pattern;
- UBI generation with 128 KiB eraseblocks and 2048-byte minimum I/O;
- support for a UBI image containing both kernel and rootfs;
- separation from Linksys headers, checksums, and TRX wrapping.

The generated RA72 recipe is source text for review. It is not inserted into
DD-WRT and is not executed.

## Run

1. Upload this update to the existing GitHub repository.
2. Open **Actions**.
3. Select:

   `Phase 21: Reconstruct DD-WRT build contract for RA72`

4. Select **Run workflow**.
5. Keep the default DD-WRT source URL.
6. Download the artifact:

   `ddwrt-ra72-phase21-build-contract-reconstruction`

## Send back for analysis

- `REPORT-PHASE21.txt`
- `review/phase21-status.txt`
- `review/phase21-contract-checks.txt`
- `review/ra72-image-recipe-review.mk`
- `review/reference-ubi-kernel-blocks.txt`

## Safety

This phase only reads public DD-WRT source and writes a non-executed recipe
draft into the artifact. It builds no firmware and accesses no router.
