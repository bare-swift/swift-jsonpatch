# ``JSONPatch``

RFC 6902 JSON Patch operations on swift-json — Sendable, Foundation-free, atomic apply.

## Overview

`JSONPatch` parses, serializes, and applies [RFC 6902](https://www.rfc-editor.org/rfc/rfc6902.html)
JSON Patch documents against `JSONValue` documents. The six standard
operations are supported: `add`, `remove`, `replace`, `move`, `copy`,
`test`. Path resolution uses `JSONPointer` (RFC 6901) from
swift-jsonpointer.

Apply is **atomic**: the patch operates on a copy of the input and only
assigns it back when every operation succeeds. If any operation fails
(invalid path, missing target, failing test), the patch throws and the
caller's `JSONValue` is left unchanged.

```swift
import JSON
import JSONPatch

var doc = try JSON.parse(#"{"name": "alice", "age": 30}"#)
let patch = try JSONPatch.parse(#"""
[
  {"op": "replace", "path": "/age", "value": 31},
  {"op": "add", "path": "/email", "value": "a@example.com"},
  {"op": "test", "path": "/name", "value": "alice"}
]
"""#)
try patch.apply(to: &doc)
// doc → {"name":"alice","age":31,"email":"a@example.com"}
```

## Topics

### Essentials

- ``JSONPatch/Operation``
- ``JSONPatchError``
