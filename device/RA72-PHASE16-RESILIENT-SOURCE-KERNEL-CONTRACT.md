# Phase 16 resilient source and kernel contract

This phase applies only to the Xiaomi Mi AIoT AX6000, model RA72, with
Qualcomm IPQ5018 and board configuration MP03.1.

Phase 15 was inconclusive because the public DD-WRT source endpoint was not
available during that workflow run. That result does not prove that DD-WRT
lacks an IPQ5018 or IPQ50xx platform foundation.

Phase 16:

- retries source discovery through the supported HTTPS and SVN addresses;
- accepts an optional source URL override;
- records every attempt and its error output;
- inventories kernel, build-system, ARM64 Device Tree, and IPQ5018 signals;
- records the exact OpenWrt comparison commit.

Phase 16 does not:

- build firmware;
- create a boot image;
- change or contact a router;
- prove DD-WRT compatibility;
- produce anything safe to flash.
