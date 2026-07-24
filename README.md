# DD-WRT private port audit - Xiaomi Mi AIoT AX6000 RA72

## Phase 15

Phase 15 identifies the closest public DD-WRT kernel baseline and Qualcomm
ARM64 Device Tree foundation for this exact device:

- Product: **Xiaomi Mi AIoT AX6000**
- Model: **RA72**
- SoC: **Qualcomm IPQ5018**
- Board: **MP03.1**

It is **not** for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

It compares the verified OpenWrt reference with DD-WRT's public source
inventory. It records kernel candidates, Qualcomm ARM64 Device Tree roots, and
explicit IPQ5018/IPQ50xx signals. It does not treat isolated source matches as
proof of device support.

## Run Phase 15

In GitHub:

1. Open **Actions**.
2. Select **Phase 15: Audit DD-WRT kernel baseline and ARM64 DTS foundation for RA72**.
3. Select **Run workflow**.
4. Keep `openwrt-25.12` unless intentionally auditing another reviewed ref.
5. Download the artifact named `ddwrt-ra72-phase15-kernel-baseline`.

Important output:

- `REPORT-PHASE15.txt`
- `review/phase15-status.txt`
- `review/ddwrt-kernel-candidates.txt`
- `review/ddwrt-arm64-dts-roots.txt`
- `review/ddwrt-ipq5018-signals.txt`
- `review/openwrt-kernel-baseline.txt`

## Safety

Phase 15 is analysis-only. It builds no firmware, creates no boot image, does
not access the router, and produces nothing flashable.

Previous audit workflows remain in the repository for traceability. Each new
stage uses its own phase number; Phase 15 does not replace any earlier phase.
