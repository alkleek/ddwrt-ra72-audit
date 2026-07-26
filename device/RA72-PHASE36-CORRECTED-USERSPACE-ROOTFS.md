# RA72 Phase 36 corrected userspace/rootfs build

## Exact device

- Xiaomi **Mi AIoT AX6000**
- Model **RA72**
- Qualcomm **IPQ5018 / MP03.1**

This is not Xiaomi Mi Router AX6000 (IPQ8072A) and not Redmi AX6000.

## Correction from Phase 35

Phase 35 successfully pinned DD-WRT SVN revision `65774`, exported the
complete router source, and selected the native `all` target. It then
stopped before the real build because the diagnostic dry run returned a
non-zero status and the inherited error trap treated that expected result
as fatal.

Phase 36:

1. captures the dry-run status without invoking the fatal trap;
2. isolates the real background build from the diagnostic error trap;
3. captures failed build exit codes normally so they can be classified;
4. omits the separate 1.7 GiB kernel export because Phase 36 builds only
   userspace/rootfs, leaving more runner disk space;
5. continues automatically into the actual native DD-WRT build;
6. validates `root.ipq5018` if produced;
7. otherwise records the first real toolchain/source/build blocker.

## Safety

No router is contacted. Qualcomm UBI packaging remains disabled. Any
rootfs produced is review-only and must not be booted or flashed.
