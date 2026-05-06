# Fix Kubernetes Watch Stream Chunk Parser

## Background

The Kubernetes Python client streams watch events over persistent HTTP connections.
The server transmits newline-delimited JSON (NDJSON) — one JSON object per line — and
the transport layer delivers that stream as arbitrary byte chunks. A chunk may contain
zero, one, or more complete events, and a single event may span multiple chunks.

The current implementation in `kubernetes/watch/watch.py` processes each transport
chunk in isolation. It decodes each chunk independently and splits on newline characters
without maintaining any cross-chunk state. This works only when the server happens to
align JSON event boundaries with chunk boundaries, which the transport layer does not
guarantee.

## Problem

The `iter_resp_lines` function in `kubernetes/watch/watch.py` must be made robust to
arbitrary chunk boundaries in the transport stream.

Specifically, the function must correctly handle all of the following:

1. **Split events**: A JSON event that is delivered across two or more chunks must
   be reassembled and yielded as a single complete line.

2. **Multiple events per chunk**: A chunk that contains several complete newline-
   terminated events must yield each event as a separate line, in order.

3. **Empty and zero-byte chunks**: The stream may deliver empty chunks between
   events (common with chunked-transfer encoding keepalives). These must not
   corrupt the parser state or cause spurious yields.

4. **UTF-8 multibyte characters split across chunk boundaries**: The server may
   split a UTF-8 multibyte sequence (e.g., a 2- or 3-byte Unicode character) across
   a chunk boundary. Decoding each chunk independently will produce a
   `UnicodeDecodeError` or silently corrupt the character. The implementation must
   accumulate raw bytes and decode only at confirmed newline boundaries.

5. **Mixed bytes and str chunks**: The transport layer may yield either `bytes` or
   `str` objects. Both must be handled without data loss or encoding errors.

6. **Ordering**: Events must be yielded in the exact order they appear in the stream,
   regardless of how the transport layer chunks the data.

## Expected Behavior

After the fix, `iter_resp_lines(resp)` must:

- Buffer incoming bytes across chunk boundaries until a `\n` is found.
- Decode each complete line as UTF-8 (replacing invalid byte sequences with the
  Unicode replacement character `\ufffd` rather than raising).
- Yield complete, correctly decoded lines only — never partial JSON fragments.
- Yield an empty string for lines that contain only a newline (keepalive lines), so
  that callers can observe them without being required to act on them.
- Not yield anything for zero-byte chunks.

## Constraints

- The public API of `Watch` must remain unchanged. Do not modify `Watch.__init__`,
  `Watch.stop`, `Watch.stream`, `Watch.unmarshal_event`, or any other method
  signature or return contract.
- The `iter_resp_lines` function signature `iter_resp_lines(resp)` must remain
  unchanged.
- The fix must not break any existing tests in `kubernetes/watch/watch_test.py`.
- The implementation must stay within `kubernetes/watch/watch.py`. Do not add new
  modules or packages.

## Scope

Only `kubernetes/watch/watch.py` requires changes. No other files should be modified.

## Acceptance Criteria

All tests in `kubernetes/watch/watch_stream_test.py` must pass. All pre-existing
tests in `kubernetes/watch/watch_test.py` must continue to pass.
