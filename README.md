# swift-jsonpatch

RFC 6902 JSON Patch operations on swift-json — Sendable, Foundation-free, atomic apply.

Part of the [bare-swift](https://github.com/bare-swift) ecosystem.

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/bare-swift/swift-jsonpatch.git", from: "0.1.0")
```

Then depend on the `JSONPatch` product:

```swift
.product(name: "JSONPatch", package: "swift-jsonpatch")
```

## Usage

```swift
import JSON
import JSONPatch

var doc = try JSON.parse(#"{"name": "alice", "age": 30}"#)

let patch = try JSONPatch.parse(#"""
[
  {"op": "test",    "path": "/name",  "value": "alice"},
  {"op": "replace", "path": "/age",   "value": 31},
  {"op": "add",     "path": "/email", "value": "a@example.com"}
]
"""#)

try patch.apply(to: &doc)
// doc → {"name":"alice","age":31,"email":"a@example.com"}
```

## Scope

`swift-jsonpatch` v0.1 implements the full [RFC 6902](https://www.rfc-editor.org/rfc/rfc6902.html) operation set:

- **`add`** — insert at object/array; supports `-` token for array append; replaces existing object members.
- **`remove`** — delete at path; throws if path missing.
- **`replace`** — set at existing path; throws if path missing (RFC 6902 § 4.3).
- **`move`** — `remove(from)` + `add(path, value)`.
- **`copy`** — read at `from`, insert at `path`. Source unchanged.
- **`test`** — succeed iff value at path equals expected. Equality follows `JSONValue`'s structural equality (numeric integers and doubles compare equal when they hold the same number).

Apply is **atomic**: operates on a copy, only assigns back on full success. Partial application never happens.

Public API:

- `JSONPatch.parse(_:)` — accepts a JSON `String` or a parsed `JSONValue`.
- `JSONPatch.apply(to: inout JSONValue) throws(JSONPatchError)` — atomic in-place mutation.
- `JSONPatch.serialized() -> JSONValue` — round-trip back to the patch document form.
- `JSONPatchError` typed-throws enum (8 cases including `missingField(String, opIndex:)` and `testFailed(opIndex:)` with operation-index metadata for surfacing failures in long patches).

Out of scope for v0.1:

- JSON Merge Patch (RFC 7396). Different format; could ship as a separate package if asked.
- Streaming application against a delta source.
- `Codable` bridging — same Foundation-free / non-Codable differentiator.

## Dependencies

- `swift-json` 0.1.0 — `JSONValue` representation.
- `swift-jsonpointer` 0.1.0 — RFC 6901 path resolution.

## Documentation

Full DocC documentation: <https://bare-swift.github.io/swift-jsonpatch/>

## Source

No upstream Rust crate; this is a native bare-swift package implementing RFC 6902 directly.

## License

Apache 2.0 with LLVM exception. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
