# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-05-10

### Added
- `JSONPatch` value type — Sendable, Equatable; carries an ordered array of `Operation`s.
- `JSONPatch.Operation` enum — six cases covering the full RFC 6902 operation set: `add`, `remove`, `replace`, `move`, `copy`, `test`.
- `JSONPatch.parse(_ source: String) throws(JSONPatchError) -> JSONPatch` and `JSONPatch.parse(_ document: JSONValue) throws(JSONPatchError) -> JSONPatch` — patch-document parsing.
- `JSONPatch.serialized() -> JSONValue` — round-trip back to the patch document form.
- `JSONPatch.apply(to: inout JSONValue) throws(JSONPatchError)` — **atomic** application: works on a copy, only assigns back on full success. Partial application never happens.
- Per-operation semantics:
  - `add` supports the `-` token for array append; insert vs. replace on object members per RFC 6902 § 4.1.
  - `remove`, `replace` require the path to exist.
  - `move`/`copy` resolve `from`, then operate on `path`.
  - `test` uses `JSONValue` structural equality (numeric integers and doubles compare equal when they hold the same number).
- `JSONPatchError` typed-throws enum with operation-index metadata for surfacing failures inside long patches.
- 40 tests across 10 suites covering: patch document parsing (six op types, missing fields, unknown ops, invalid pointers); per-op apply (8 add cases, 4 remove, 3 replace, 3 move, 2 copy, 3 test); atomicity (failure leaves input unchanged); round-trip serialize; and four canonical RFC 6902 Appendix-A examples.

### Dependencies
- `swift-json` 0.1.0 — `JSONValue` representation.
- `swift-jsonpointer` 0.1.0 — RFC 6901 path tokens.

### Limitations (out of scope for v0.1)
- JSON Merge Patch (RFC 7396) — different format; ship as separate package if asked.
- Streaming application against a delta source.
- `Codable` bridging — same Foundation-free / non-Codable differentiator as the rest of the format tier.
