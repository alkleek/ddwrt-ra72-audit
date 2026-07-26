# DD-WRT RA72 Phase 45

Phase 45 generates the verified DD-WRT SVN revision metadata that was
missing in Phase 44, then resumes the native configure, bootstrap,
compile, install, and rootfs-discovery stages.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Phase 44 result

The exact RA72 profile enabled `CONFIG_ATH11K=y` and disabled the
incompatible legacy MADWIFI, ATH9K, ATH10K, registration, superchannel,
and QCA98xx selections. The former `register_check.o` dependency
disappeared, and the native configure build progressed through Jansson,
wireless-tools, and into `libutils`.

The first real blocker was then:

`libutils/utils.c:1536:10: fatal error: revision.h: No such file or directory`

This is generated DD-WRT build metadata, not device-specific source.
The public SVN export does not contain working-copy metadata from which
the normal build procedure can derive the header automatically.

## Phase 45 correction

- Preserves every verified Phase 44 source, toolchain, header, and RA72
  wireless-profile correction.
- Obtains the exact pinned source revision with `svn info`.
- Generates the native one-line DD-WRT revision header:

  `#define SVN_REVISION "<verified revision>"`

- Installs that same verified header in the four native consumers:
  `libutils`, `shared`, `httpd`, and `httpd/visuals`.
- Verifies every generated copy byte-for-byte before compilation.
- Records the revision value, consumers, paths, and SHA-256 hashes in
  the review artifact.
- Adds a dedicated missing-revision-header failure classifier.
- Never guesses a revision number and never substitutes unrelated code.
- Keeps every Qualcomm UBI/flash packaging path disabled.

## Upload and run

1. Upload this update over the existing `ddwrt-ra72-audit` repository.
2. Keep `.github` and every folder path unchanged.
3. Commit the changes.
4. Open **Actions**.
5. Select:

   `Phase 45: Generate verified revision metadata and build rootfs`

6. Press **Run workflow**.
7. Leave all three fields unchanged.

Download this artifact when the run stops:

`ddwrt-ra72-phase45-revision-metadata-rootfs-build`

Send back the complete downloaded artifact ZIP. The most useful files
inside it are:

- `REPORT-PHASE45.txt`
- `review/phase45-status.txt`
- `review/revision-header-contract.txt`
- `review/revision-header-paths.txt`
- `review/revision-header-consumers.txt`
- `review/revision-header-sha256.txt`
- `review/base-ipq60xx.config`
- `review/selected-ipq60xx.config`
- `review/ra72-wireless-profile.patch`
- `review/ra72-wireless-profile-contract.txt`
- `review/configure-failure-classification.txt`
- `review/first-configure-errors.txt`
- `review/ddwrt-configure-tail.txt`
- `review/bootstrap-stage-status.txt`
- `review/ddwrt-bootstrap-build-tail.txt`
- `review/userspace-build-status.txt`
- `review/build-failure-classification.txt`
- `review/first-build-errors.txt`
- `review/userspace-build-tail.txt`
- `review/phase45-integration-checks.txt` if present

## Safety

This workflow never contacts the router. It does not produce an
approved firmware image. Any rootfs is a review-only component and must
not be booted or flashed.
