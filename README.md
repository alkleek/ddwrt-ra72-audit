# DD-WRT RA72 Phase 52

Phase 52 corrects the first confirmed failure from Phase 51: the native
`util-linux` install tried to run `chown root:root` and `chgrp tty` inside
the unprivileged GitHub Actions runner.

This is still a review-only userspace/rootfs build. It does not create
approved firmware and must not be flashed.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Verified Phase 51 result

Phase 51 proved that:

- the host `gtkdocize` contract passed;
- DD-WRT's native `ncurses-configure` target passed;
- DD-WRT's native `util-linux-configure` target passed;
- `src/router/util-linux/Makefile` was generated;
- the full configure advanced into the `util-linux` install.

The terminal failure was:

```text
chgrp tty .../usr/bin/wall
chgrp: ... Operation not permitted
chown root:root .../bin/mount
chown: ... Operation not permitted
```

The Phase 51 classifier's `MISSING_HOST_GTKDOCIZE` result was a false
positive caused by a harmless `gtk-doc ... not found` warning. Phase 52
narrows that classifier to exact missing-executable messages.

## Phase 52 correction

The workflow:

1. saves the original `src/router/rules/util-linux.mk`;
2. adds exactly once:
   - `--disable-makeinstall-chown`
   - `--disable-use-tty-group`
3. saves a unified patch and SHA-256 contract;
4. runs DD-WRT's native `util-linux-configure` target;
5. confirms the generated Makefile has no active `chgrp tty` or
   `chown root:root` recipes;
6. performs a focused staged `util-linux` install without `sudo`;
7. requires staged files and absence of ownership-operation failures;
8. only then resumes the native DD-WRT configure/rootfs path.

The two options are supported by upstream `util-linux`; this is not a
source-code workaround or a privileged install.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Preserve all folder paths, including `.github`.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 52: Disable util-linux ownership hooks and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged and run it.

Download this artifact after the run stops:

`ddwrt-ra72-phase52-util-linux-unprivileged-install-rootfs-build`

Send back the complete downloaded artifact ZIP.

## Most useful review files

- `REPORT-PHASE52.txt`
- `review/phase52-status.txt`
- `review/util-linux-rule.original.mk`
- `review/util-linux-rule.patched.mk`
- `review/util-linux-unprivileged-install.patch`
- `review/util-linux-unprivileged-install-patch-contract.txt`
- `review/util-linux-preconfigure-contract.txt`
- `review/util-linux-preconfigure.log`
- `review/util-linux-config.log` if present
- `review/util-linux-install-contract.txt`
- `review/util-linux-install-test.log`
- `review/util-linux-install-test-tail.txt`
- `review/util-linux-install-test-files.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/phase52-integration-checks.txt` if produced

## Safety

- No router, SSH, UART, NAND partition, or boot variable is accessed.
- Qualcomm UBI and all flash/deployment paths remain disabled.
- A generated SquashFS file is only a review component.
- Do not boot, load, install, deploy, or flash any Phase 52 file.
