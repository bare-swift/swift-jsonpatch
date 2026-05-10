// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import JSON
import JSONPointer

extension JSONPatch {
    /// One RFC 6902 operation. Each carries its target path (always an RFC
    /// 6901 JSON Pointer) and operation-specific payload (`value`, `from`).
    public enum Operation: Sendable, Equatable {
        /// `add` — insert into an array (or replace into an object). The
        /// final token may be `-` to mean "append" when the parent is an
        /// array.
        case add(path: JSONPointer, value: JSONValue)

        /// `remove` — delete the value at `path`. Path must exist.
        case remove(path: JSONPointer)

        /// `replace` — set the value at `path`. Path must exist (RFC 6902
        /// § 4.3 forbids `replace` on a missing path).
        case replace(path: JSONPointer, value: JSONValue)

        /// `move` — remove from `from`, insert at `path`. Atomic per the
        /// spec; not equivalent to `remove` followed by `add` if the two
        /// could race.
        case move(from: JSONPointer, path: JSONPointer)

        /// `copy` — read from `from`, insert at `path`. Source unchanged.
        case copy(from: JSONPointer, path: JSONPointer)

        /// `test` — succeed iff the value at `path` equals `value`. RFC
        /// 6902 defines equality structurally; numeric integers and
        /// doubles are compared as the same value when they hold the
        /// same number (matches swift-json's `JSONValue` equality).
        case test(path: JSONPointer, value: JSONValue)
    }
}
