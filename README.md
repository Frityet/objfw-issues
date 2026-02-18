# ObjFW Audit Repros

Minimal repro harnesses for the confirmed and likely findings from the deep audit.

## Requirements
- ObjFW installed at `/workspaces/ObjFW/install` (override with `OBJFW_PREFIX`)
- `valgrind`
- `python3`

## Usage
Run from repo root:

```sh
./repros/run.sh c1   # one repro
./repros/run.sh l3   # one likely repro
./repros/run.sh all  # everything
```

## Repro Index
- `c1` confirmed: `readStringWithLength:SIZE_MAX` overflow crash (`src/OFStream.m`)
- `c2` confirmed: ZIP `mutableCopy` copies wrong field (`src/OFZIPArchiveEntry.m`)
- `c3` confirmed: SOCKS5 hostname length wraps/truncates at 256 (`src/OFTCPSocketSOCKS5Connector.m`)
- `c4` confirmed: HTTP long-line buffering drives memory growth (`src/OFHTTPServer.m` + `src/OFStream.m`)
- `c5` confirmed: runtime dynamic method-list leak on `objc_deinit` (`src/runtime/class.m`)
- `c6` confirmed: leak on out-of-range `removeObjectsAtIndexes:` path (`src/OFConcreteMutableArray.m`)
- `c7` confirmed (test infra): `CustomData`/`CustomMutableData` leak via `OFDataTests`
- `l1` likely: weak-reference race stress (`src/runtime/arc.m`)
- `l2` likely: run-loop pool lifecycle probe (`src/OFRunLoop.m`)
- `l3` likely: huge chunk size accepted (no practical cap) (`src/OFHTTPServer.m`)
- `l4` likely: unchecked `_readBufferLength + bufferLength` wrap path (`src/OFStream.m`)

Notes:
- `l1` is nondeterministic by nature; script runs multiple attempts.
- `l2` is a probe to validate behavior around callback-to-callback autorelease draining.
- `l4` uses injected internal stream state to hit the wrap path without allocating near-`SIZE_MAX` memory.
