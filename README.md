# DD-WRT source audit for Xiaomi Mi AIoT AX6000 RA72

## Phase 20 - platform integration map

This repository is a private, audit-only investigation for the:

- **Xiaomi Mi AIoT AX6000**
- model **RA72**
- Qualcomm **IPQ5018**
- board configuration **MP03.1**

It is not for the Xiaomi Mi Router AX6000 (IPQ8072A) or Redmi AX6000.

Phase 19 proved that the public DD-WRT source contains IPQ5018 components
and Device Trees, but no complete IPQ5018 build template was identified by
path-only classification.

Phase 20 retrieves the contents of the closest public integration files and
maps the relationship between:

- `src/router/Makefile.ipq60xx`;
- the `src/router/configs/ipq60xx` configurations;
- IPQ5018 kernel configurations and Device Trees;
- the known IPQ5018 reference devices in the public tree.

This phase answers which existing DD-WRT platform family is the safest
foundation for a future RA72 build target. It does not create that target yet.

## Run

1. Upload this update to the existing GitHub repository.
2. Open **Actions**.
3. Select:

   `Phase 20: Map DD-WRT IPQ5018 platform integration for RA72`

4. Select **Run workflow**.
5. Keep the default DD-WRT source URL.
6. Download the artifact:

   `ddwrt-ra72-phase20-platform-integration-map`

## Send back for analysis

- `REPORT-PHASE20.txt`
- `review/phase20-status.txt`
- `review/phase20-counts.txt`
- `review/platform-foundation-ranking.txt`
- `review/reference-device-build-links.txt`

## Safety

This phase only reads public DD-WRT source. It does not build firmware,
does not access the router, and produces nothing flashable.
