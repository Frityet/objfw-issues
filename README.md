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


## Additional comments

### Confirmed Findings

High | confidence: high OFStream.m (line 538)
Issue: integer overflow in length + 1 in readStringWithLength:encoding:.
Impact: SIZE_MAX input causes invalid write / segfault (memory-safety bug).
Evidence: stream_size_max_objfw repro exits 139; Valgrind shows invalid write in _i_OFStream__readStringWithLength_encoding_.
Fix direction: guard length == SIZE_MAX (or checked add) before allocation.
High | confidence: high OFHTTPServer.m (line 968), OFHTTPServer.m (line 362), OFStream.m (line 551), OFStream.m (line 688)
Issue: unbounded request-line/header-line buffering via asyncReadLine/tryReadLine.
Impact: remote memory DoS by streaming long unterminated lines.
Evidence: local HTTP probe showed RSS growth tracking attacker payload (~10–16 MB deltas during long-line send).
Fix direction: add configurable max line/header sizes and close on overflow.
Medium | confidence: high OFTCPSocketSOCKS5Connector.m (line 164)
Issue: hostname length cast to uint8_t without bounds check.
Impact: >255 UTF-8 host silently truncates/wraps; malformed SOCKS5 destination.
Evidence: SOCKS fixture shows len=255 -> host_len=255, len=256 -> host_len=0.
Fix direction: reject UTF8StringLength > 255 with explicit exception.
Medium | confidence: high OFZIPArchiveEntry.m (line 317)
Issue: mutableCopy copies _extraField into _fileComment.
Impact: metadata corruption/type mismatch in copied entry.
Evidence: repro shows copy.fileComment class is OFConcreteData instead of string.
Fix direction: copy _fileComment into _fileComment.
Medium | confidence: high class.m (line 827), class.m (line 1007)
Issue: method-list allocations from class_addMethod/missing-selector class_replaceMethod are not reclaimed on runtime deinit path.
Impact: leak during objc_deinit / dynamic-class lifecycle; growth with dynamic method injection.
Evidence: dedicated objc_deinit Valgrind repro shows indirect leaks from class_addMethod/class_replaceMethod.
Fix direction: track and free dynamically allocated method lists during unregister/deinit.
Low | confidence: high OFConcreteMutableArray.m (line 305), OFConcreteMutableArray.m (line 308)
Issue: allocates copy before out-of-range validation in removeObjectsAtIndexes:.
Impact: exception path leaks (OFOutOfRangeException case).
Evidence: targeted Valgrind harness: 1000 OOB calls -> 8000 bytes definitely lost.
Fix direction: validate ranges before allocation or wrap pre-check in @try/@finally.
Low (test infra) | confidence: high OFDataTests.m (line 303), OFMutableDataTests.m (line 170)
Issue: CustomData / CustomMutableData wrappers miss dealloc cleanup of _data.
Impact: test-only leak noise; can mask framework leak checks.
Evidence: Valgrind definite leaks in OFDataTests and OFMutableDataTests stack to these classes.
Fix direction: add -dealloc releasing _data.

### Likely Findings (need targeted validation)

High | confidence: medium arc.m (line 303), arc.m (line 316)
objc_loadWeakRetained appears to unlock before class/retain checks, enabling potential weak-race UAF window.
Validation: dedicated multi-thread weak-load/dealloc stress harness under ASan/TSan.
Medium-High | confidence: medium OFRunLoop.m (line 1884), OFRunLoop.m (line 2041)
run-loop autorelease-pool lifecycle looks inconsistent across loop iterations.
Validation: pool-depth instrumentation across repeated run-loop cycles.
High | confidence: medium OFHTTPServer.m (line 745), OFHTTPServer.m (line 775)
chunked-body size accepts very large declared chunk lengths (bounded only by LLONG_MAX).
Validation: send oversized chunk size line and observe resource hold/behavior under limits.
Low-Medium | confidence: medium OFStream.m (line 688), OFStream.m (line 1005), OFStream.m (line 1179)
several _readBufferLength + bufferLength additions are unchecked; theoretical wrap risk near SIZE_MAX.
Validation: synthetic large-length fault-injection/unit tests for checked-add behavior.
