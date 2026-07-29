# RA72 Phase 68 engineering note

## Scope

Exact board only:

- Xiaomi Mi AIoT AX6000
- model RA72
- Qualcomm IPQ5018 / MP03.1

This note does not apply to Xiaomi Mi Router AX6000 or Redmi AX6000.

## Phase 67 evidence

The OpenSSL3 dependency redirect and narrow recursive `MAKE=make` override
both passed. Curl then invoked its configure script with explicit target
OpenSSL3 paths, but `/usr/bin/pkg-config` supplied the GitHub runner's host
OpenSSL paths:

```text
SSL_LDFLAGS="-L/usr/lib/x86_64-linux-gnu"
SSL_CPPFLAGS="-I/usr/include"
checking for openssl/x509.h... no
```

This is a host/target metadata collision, not a recurrence of the Phase 66
recursive-make failure.

## Phase 68 contract

The phase requires:

- the verified Phase 67 curl/OpenSSL3 rule state;
- exactly one main `curl/build` configure block;
- exactly one separate `curl/build_static` configure block;
- target OpenSSL include, library, and `--with-openssl` arguments already
  present in the main block;
- no pre-existing `PKG_CONFIG="/tmp"` override;
- exactly one override inserted in the main block;
- no override and no content change in the static block;
- the runtime command to contain the override and target OpenSSL paths;
- host OpenSSL pkg-config paths and the Phase 67 header failure to be absent;
- curl's main configure output to be created before full validation can pass.

The `/tmp` value follows an existing DD-WRT pattern for disabling an unwanted
host pkg-config lookup. It is local to curl's main configure command and does
not change global package discovery.

## Safety boundary

This phase builds no approved RA72 firmware. Image packaging remains blocked,
no router is contacted, and no output is boot-approved or flashable.
