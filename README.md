# DD-WRT private port audit - Xiaomi Mi AIoT AX6000 RA72

## Phase 14

Phase 14 audits the platform gap between the public DD-WRT source inventory and
the verified OpenWrt implementation for this exact device:

- Product: **Xiaomi Mi AIoT AX6000**
- Model: **RA72**
- SoC: **Qualcomm IPQ5018**
- Board: **MP03.1**

It is **not** for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

The audit inventories the IPQ5018 platform pieces needed for a real DD-WRT port
and creates an ordered source-import plan. It does not treat isolated driver
matches as proof of device support.

## Run Phase 14

In GitHub:

1. Open **Actions**.
2. Select **Phase 14: Audit IPQ5018 platform gap and source-import plan for RA72**.
3. Select **Run workflow**.
4. Keep `openwrt-25.12` unless intentionally auditing another reviewed ref.
5. Download the artifact named `ddwrt-ra72-phase14-platform-gap`.

Important output:

- `REPORT-PHASE14.txt`
- `review/phase14-status.txt`
- `review/missing-platform-components.txt`
- `review/source-import-plan.txt`
- `review/openwrt-ipq5018-components.txt`
- `review/ddwrt-ipq5018-matches.txt`

## Safety

Phase 14 is analysis-only. It builds no firmware, creates no boot image, does
not access the router, and produces nothing flashable.

Previous audit workflows remain in the repository for traceability. Each new
stage uses its own phase number; Phase 14 does not replace or reuse Phase 11.
