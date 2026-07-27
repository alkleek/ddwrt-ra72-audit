# DD-WRT RA72 Phase 53

Phase 53 corrects the exact failure found by Phase 52:

```text
meson.build:4:18: ERROR: Meson version is 1.3.2 but project requires >= 1.4.0
make: *** [rules/glib.mk:140: glib20-configure] Error 1
```

Phase 52 itself was successful in its intended correction: the
`util-linux` unprivileged install completed, produced 349 staged files,
and contained no active `chown root:root` or `chgrp tty` operations.

This remains a review-only userspace/rootfs build. It does not create
approved firmware and must not be flashed.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 53 correction

The workflow:

1. installs Python virtual-environment support on the GitHub runner;
2. creates a private Meson environment inside the temporary build area;
3. installs exactly Meson `1.4.2`;
4. verifies the executable, exact version, active path, SHA-256, and pip
   provider before downloading the large DD-WRT source or toolchain;
5. keeps the isolated Meson first in the effective build path;
6. retains every correction and safety boundary from Phase 52;
7. classifies an old-Meson failure explicitly if it ever reappears;
8. continues the native DD-WRT RA72 userspace/rootfs build.

Version `1.4.2` is the nearest stable Meson release selected above GLib's
minimum `1.4.0`, reducing avoidable behavior drift from much newer
versions.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Preserve all folder paths, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 53: Pin compatible Meson and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and run it.

Download this artifact after the run stops:

`ddwrt-ra72-phase53-pinned-host-meson-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE53.txt`
- `review/phase53-status.txt`
- `review/host-meson-contract.txt`
- `review/host-meson-install.log`
- `review/host-meson-install-tail.txt`
- `review/userspace-build-environment.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/build-failure-classification.txt`
- `review/userspace-build-tail.txt`
- `review/phase53-integration-checks.txt` if produced

The Phase 52 util-linux patch and focused-install evidence remain included
in the artifact as well.

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 53 file.
