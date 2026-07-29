# RA72 Phase 69 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 68 evidence

All curl target-OpenSSL3 checks passed. The build then entered the native
`libtalloc` Waf configure and selected:

```text
.../host-meson-venv/bin/python3
```

That interpreter is Python 3.12. Its standard library no longer includes
`distutils`, so Waf stopped with:

```text
The distutils module is unusable: install "python-devel"?
```

The runner already had the Ubuntu `python3-setuptools` package, but a normal
virtual environment does not inherit global site packages. The missing
module must therefore be provided inside the selected environment.

## Phase 69 contract

The phase requires:

- isolated Meson `1.4.2` to remain unchanged;
- `setuptools 70.3.0` installed into the same virtual environment;
- `SETUPTOOLS_USE_DISTUTILS=local`;
- direct imports of `distutils`, `distutils.core`, and
  `distutils.sysconfig` to pass;
- the resolved provider path to be inside the environment's
  `setuptools/_distutils` tree;
- the import contract to remain valid after the cross-toolchain path is
  activated;
- the exact Phase 68 `libtalloc` error to be absent;
- curl's previously verified target OpenSSL contract to remain valid.

If the build stops later, Phase 69 records the first new blocker instead of
claiming rootfs completion.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging remains blocked,
no router is contacted, and no output is boot-approved or flashable.
