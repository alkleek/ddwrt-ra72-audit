# DD-WRT source audit for Xiaomi Mi AIoT AX6000 RA72

## Phase 19 - closest IPQ5018 build-template selection

This repository is a private, audit-only investigation for the:

- **Xiaomi Mi AIoT AX6000**
- model **RA72**
- Qualcomm **IPQ5018**
- board configuration **MP03.1**

It is not for the Xiaomi Mi Router AX6000 or Redmi AX6000.

Phase 18 established that the public DD-WRT inventory has generic IPQ5018
components and build fragments, but no direct RA72 target or profile.

Phase 19 ranks the IPQ5018/IPQ50xx source locations to determine whether
the public tree contains a sufficiently complete build template that could
serve as the starting point for a new RA72 port.

## Run

1. Upload this update to the existing GitHub repository.
2. Open **Actions**.
3. Select:

   `Phase 19: Select closest DD-WRT IPQ5018 build template for RA72`

4. Select **Run workflow**.
5. Keep the default DD-WRT source URL.
6. Download the artifact:

   `ddwrt-ra72-phase19-build-template-selection`

## Send back for analysis

- `REPORT-PHASE19.txt`
- `review/phase19-status.txt`
- `review/phase19-counts.txt`
- `review/candidate-template-roots.txt`

## Safety

This phase does not build firmware and does not modify the router. Nothing
inside the artifact is flashable.
