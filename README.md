# DD-WRT private port audit - Xiaomi Mi AIoT AX6000 RA72

## Phase 16

Phase 16 repeats the DD-WRT source and kernel-baseline audit with resilient
source discovery for this exact device:

- Product: **Xiaomi Mi AIoT AX6000**
- Model: **RA72**
- SoC: **Qualcomm IPQ5018**
- Board: **MP03.1**

It is **not** for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

Phase 15 ended with:

`AUDIT_INCOMPLETE_DDWRT_SOURCE_UNAVAILABLE`

That means the public DD-WRT source endpoint was unavailable during the run.
It is not evidence that an IPQ5018 platform foundation is absent.

Phase 16 tries the public HTTPS and SVN endpoints up to three times each,
records every failure, and permits an optional source URL override. If the
source becomes available, it inventories kernel/build paths, Qualcomm ARM64
Device Tree roots, and IPQ5018/IPQ50xx signals.

## Run Phase 16

In GitHub:

1. Upload this update to the repository and commit it.
2. Open **Actions**.
3. Select **Phase 16: Audit DD-WRT kernel baseline with resilient source discovery for RA72**.
4. Select **Run workflow**.
5. Keep `openwrt-25.12`.
6. Leave the optional DD-WRT source URL empty.
7. Download `ddwrt-ra72-phase16-resilient-kernel-baseline`.

Send back:

- `REPORT-PHASE16.txt`
- `review/phase16-status.txt`

## Safety

Phase 16 is analysis-only. It builds no firmware, creates no boot image, does
not access the router, and produces nothing flashable.

Previous workflows remain in the repository for traceability. This stage uses
the unique Phase 16 name and does not replace an earlier phase.
