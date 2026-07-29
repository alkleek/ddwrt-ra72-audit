# RA72 Phase 70 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 69 evidence

The isolated Python 3.12 virtual environment now imports `distutils`,
`distutils.core`, and `distutils.sysconfig` from pinned `setuptools 70.3.0`.
The previous `libtalloc` failure is absent. The build advanced into bundled
`libusb` under `usb_modeswitch`, which uses:

```text
-I.../src/router/kernel_headers/include
```

That constrained header tree lacked `linux/netlink.h`, so configure stopped
with `Linux netlink header not found`.

## Phase 70 contract

The phase requires:

- the exact header source to be the pinned DD-WRT Linux 6.12 NSS UAPI tree;
- the destination to be DD-WRT's userspace `kernel_headers/include` tree;
- source and destination to be byte-for-byte identical;
- a focused AArch64 uClibc compile using that destination to pass;
- the bundled `usb_modeswitch/libusb` configure segment to detect
  `linux/netlink.h`;
- the exact Phase 69 missing-netlink failure to be absent;
- all earlier Phase 69 distutils and target OpenSSL contracts to remain valid.

If the build stops later, Phase 70 records the first new blocker instead of
claiming rootfs completion.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging remains blocked,
no router is contacted, and no output is boot-approved or flashable.
