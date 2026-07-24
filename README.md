# DD-WRT private port audit - Xiaomi Mi AIoT AX6000 RA72

## Phase 13

This phase resolves the two missing Q6 reserved-memory labels discovered by
Phase 12:

- `q6_region`
- `q6_etr_region`

It searches the selected, verified OpenWrt source for the exact node
definitions, records their source paths and SHA-256 hashes, and injects those
exact definitions into a temporary DD-WRT native `ipq5018.dtsi`.

No address or size is guessed. If either definition cannot be found, the job
stops safely and reports `BLOCKED`.

## Exact device

Only:

- Product: **Xiaomi Mi AIoT AX6000**
- Model: **RA72**
- SoC: **Qualcomm IPQ5018**
- Board: **MP03.1**

It is not for Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

## Run

In GitHub, open **Actions** and select:

**Phase 13: Resolve Q6 reserved-memory labels and compile review-only DD-WRT RA72 Device Tree**

Press **Run workflow** and keep the default OpenWrt reference unless a different
reviewed reference is intentionally required.

Download the artifact:

`ddwrt-ra72-phase13-q6-dts-compile`

The important files are:

- `REPORT-PHASE13.txt`
- `review/phase13-status.txt`
- `review/q6-node-provenance.tsv`
- `review/q6-reserved-memory-nodes.dtsi`
- `review/compile-status.txt`
- `review/dtc-compile.log`

## Safety

Phase 13 is a compiler audit only. It does not build DD-WRT firmware and does
not modify a router. Nothing in the artifact is flashable.
