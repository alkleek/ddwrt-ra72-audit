# Phase 19 — DD-WRT IPQ5018 build-template selection

This phase is only for the **Xiaomi Mi AIoT AX6000**, model **RA72**:

- Qualcomm IPQ5018
- board configuration MP03.1
- 128 MiB NAND

It is not for the Xiaomi Mi Router AX6000 or Redmi AX6000.

Phase 18 proved that the public DD-WRT source inventory contains generic
IPQ5018 components and build fragments, but no direct RA72, Mi AIoT AX6000,
or MP03.1 target.

Phase 19 ranks the generic IPQ5018/IPQ50xx source locations and looks for
the closest complete build template. It checks for:

- build definitions;
- target/profile selection;
- image packaging;
- kernel configuration;
- Device Tree integration.

The result is an audit report only. No firmware is built and nothing in the
artifact is safe to flash.
