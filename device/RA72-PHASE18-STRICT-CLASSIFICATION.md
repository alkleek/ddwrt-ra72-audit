# Phase 18 strict classification contract

This phase audits only the public DD-WRT source inventory for the exact device:

- Xiaomi **Mi AIoT AX6000**
- model **RA72**
- Qualcomm **IPQ5018**
- board **MP03.1**

It is not for Xiaomi Mi Router AX6000 or Redmi AX6000.

Phase 18 corrects the broad substring matching used in Phase 17. A strict
identity token must be separated by a path or filename boundary. Therefore:

- `ra72` can match;
- `DRA72` and `cora72` are rejected;
- `mp03` or `mp03.1` can match;
- `jump03` is rejected.

The audit also distinguishes generic IPQ5018 components from an actual RA72
build/profile target.

This phase does not build firmware and does not access or modify a router.
