# DD-WRT RA72 Phase 33

Phase 32 successfully built the raw ARM64 Linux kernel Image and exact-model
RA72 DTB inside the native DD-WRT kernel tree.

Phase 33 performs the next controlled step: it builds and stages all kernel
modules selected by DD-WRT's native `.config_ipq6018`, then validates the
module architecture, dependency metadata, and the QCA8337/QCA8K LAN-switch
module required by this board.

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Safety

This is a source-build and component-review phase. It does not create a
rootfs or any flashable DD-WRT firmware. The raw Image, DTB, and kernel
modules in the artifact are not approved for booting, loading, or flashing.
The workflow never contacts the router.

## Upload

Upload the contents of this update over the existing project. Keep the
folders exactly as provided, including `.github`.

## Run

In GitHub **Actions**, select:

`Phase 33: Build native DD-WRT RA72 kernel modules`

Press **Run workflow** and leave all three fields unchanged.

The workflow exports the complete DD-WRT kernel source and builds hundreds
of configured modules, so it can take noticeably longer than Phase 32.
Progress is printed every 30 seconds during source export and every five
minutes during the module build.

Download the artifact:

`ddwrt-ra72-phase33-native-kernel-modules-build`

Send back:

- `REPORT-PHASE33.txt`
- `review/phase33-status.txt`
- `review/build-status.txt`
- `review/phase33-integration-checks.txt`
- `review/module-summary.txt`
- `review/critical-module-resolution.txt`
- `review/module-dependency-audit.txt`
- `review/native-kernel-modules-kbuild.log`
- `review/modules-install.log`
- `review/first-build-errors.txt` if present

Do not run, load, boot, or flash any file from the downloaded artifact.
