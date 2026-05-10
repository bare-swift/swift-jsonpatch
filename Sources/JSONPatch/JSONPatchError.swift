// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// Errors thrown by `JSONPatch.parse(_:)` and ``JSONPatch/apply(to:)``.
public enum JSONPatchError: Error, Equatable, Sendable {
    /// Patch document was not a valid JSON array, or the JSON-text input
    /// to the `String`-taking parser was syntactically malformed.
    case malformedPatch(String)

    /// An operation object was missing a required field (`op`, `path`,
    /// `value`, or `from`).
    case missingField(String, opIndex: Int)

    /// `op` field carried a value that isn't one of the six RFC 6902 ops.
    case unknownOperation(String, opIndex: Int)

    /// A path or `from` was a JSON Pointer that didn't parse.
    case invalidPath(String, opIndex: Int)

    /// Operation requires the path's target to exist (`remove`, `replace`,
    /// `move`-source, `copy`-source) but it doesn't.
    case pathNotFound(String, opIndex: Int)

    /// `test` operation found a value that didn't match.
    case testFailed(opIndex: Int)

    /// Array index out of bounds, or `-` used in a non-array context.
    case invalidIndex(String, opIndex: Int)

    /// Path traversed *into* a leaf (e.g. trying to add `/foo/bar` where
    /// `/foo` is a string).
    case targetIsNotContainer(opIndex: Int)
}
