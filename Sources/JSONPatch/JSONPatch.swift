// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import JSON
import JSONPointer

/// Sendable, Foundation-free [RFC 6902](https://www.rfc-editor.org/rfc/rfc6902.html)
/// JSON Patch operations against `JSONValue`.
///
/// A `JSONPatch` is an ordered sequence of ``Operation`` values. Each
/// operation targets a path resolved as an RFC 6901 JSON Pointer. The
/// six operations defined by the spec are `add`, `remove`, `replace`,
/// `move`, `copy`, and `test`.
///
/// Application is **atomic**: ``apply(to:)`` works on a copy of the
/// input and only assigns it back when every operation succeeds. If
/// any operation fails — invalid path, missing target, failing test —
/// the patch throws and the caller's `JSONValue` is left unchanged.
///
/// ```swift
/// import JSON
/// import JSONPatch
///
/// var doc = try JSON.parse(#"{"name": "alice", "age": 30}"#)
/// let patch = try JSONPatch.parse(#"""
/// [
///   {"op": "replace", "path": "/age", "value": 31},
///   {"op": "add", "path": "/email", "value": "a@example.com"}
/// ]
/// """#)
/// try patch.apply(to: &doc)
/// // doc → {"name":"alice","age":31,"email":"a@example.com"}
/// ```
public struct JSONPatch: Sendable, Equatable {
    public let operations: [Operation]

    public init(operations: [Operation]) {
        self.operations = operations
    }

    /// Parse an RFC 6902 patch document from a JSON `String`.
    public static func parse(_ source: String) throws(JSONPatchError) -> JSONPatch {
        let value: JSONValue
        do {
            value = try JSON.parse(source)
        } catch {
            throw .malformedPatch("\(error)")
        }
        return try parse(value)
    }

    /// Parse an RFC 6902 patch document from a parsed `JSONValue` (must
    /// be a top-level array of operation objects).
    public static func parse(_ document: JSONValue) throws(JSONPatchError) -> JSONPatch {
        try ParseSerialize.parse(document)
    }

    /// Serialize this patch to a `JSONValue` array per RFC 6902.
    public func serialized() -> JSONValue {
        ParseSerialize.serialize(self)
    }

    /// Apply this patch atomically to the given `JSONValue`. On any
    /// operation failure, the input is left unchanged.
    public func apply(to value: inout JSONValue) throws(JSONPatchError) {
        var working = value
        for (index, op) in operations.enumerated() {
            try Apply.apply(op, to: &working, opIndex: index)
        }
        value = working
    }
}
