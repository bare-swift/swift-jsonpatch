// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import JSON
import JSONPointer

/// JSON Patch application. The five primitive helpers (``get``, ``add``,
/// ``remove``, ``replace``, equality test) are composed into the six
/// RFC 6902 operations by ``apply(_:to:opIndex:)``.
///
/// Mutation walks the `JSONValue` tree by reconstructing the path from
/// leaf upward — Swift's value semantics make in-place mutation through
/// nested enum-of-arrays awkward, so each helper operates on the parent
/// directly and the outer recursion threads the change back up.
enum Apply {
    static func apply(_ op: JSONPatch.Operation, to root: inout JSONValue, opIndex: Int) throws(JSONPatchError) {
        switch op {
        case .add(let path, let value):
            try add(value: value, at: path, in: &root, opIndex: opIndex)
        case .remove(let path):
            _ = try remove(at: path, in: &root, opIndex: opIndex)
        case .replace(let path, let value):
            try replace(value: value, at: path, in: &root, opIndex: opIndex)
        case .move(let from, let path):
            let v = try remove(at: from, in: &root, opIndex: opIndex)
            try add(value: v, at: path, in: &root, opIndex: opIndex)
        case .copy(let from, let path):
            guard let v = get(at: from, in: root) else {
                throw .pathNotFound(from.description, opIndex: opIndex)
            }
            try add(value: v, at: path, in: &root, opIndex: opIndex)
        case .test(let path, let expected):
            guard let actual = get(at: path, in: root) else {
                throw .testFailed(opIndex: opIndex)
            }
            if actual != expected {
                throw .testFailed(opIndex: opIndex)
            }
        }
    }

    // MARK: - Read

    /// Resolve a pointer to the value it targets, or `nil` if any segment
    /// is missing or traverses into a non-container.
    static func get(at path: JSONPointer, in root: JSONValue) -> JSONValue? {
        var current = root
        for token in path.tokens {
            switch current {
            case .object(let members):
                guard let m = members.first(where: { $0.key == token.value }) else {
                    return nil
                }
                current = m.value
            case .array(let items):
                guard let idx = token.arrayIndex, idx >= 0, idx < items.count else {
                    return nil
                }
                current = items[idx]
            default:
                return nil
            }
        }
        return current
    }

    // MARK: - Add

    static func add(value: JSONValue, at path: JSONPointer, in root: inout JSONValue, opIndex: Int) throws(JSONPatchError) {
        let tokens = path.tokens
        if tokens.isEmpty {
            // RFC 6902 § 4.1: `add` to root replaces the whole document.
            root = value
            return
        }
        try mutateContainer(at: tokens, in: &root, opIndex: opIndex) { parent, lastToken in
            switch parent {
            case .object(var members):
                if let idx = members.firstIndex(where: { $0.key == lastToken.value }) {
                    members[idx] = .init(key: lastToken.value, value: value)
                } else {
                    members.append(.init(key: lastToken.value, value: value))
                }
                parent = .object(members)
            case .array(var items):
                if lastToken.isNextElement {
                    items.append(value)
                } else if let idx = lastToken.arrayIndex, idx >= 0, idx <= items.count {
                    items.insert(value, at: idx)
                } else {
                    throw JSONPatchError.invalidIndex(lastToken.value, opIndex: opIndex)
                }
                parent = .array(items)
            default:
                throw JSONPatchError.targetIsNotContainer(opIndex: opIndex)
            }
        }
    }

    // MARK: - Remove

    @discardableResult
    static func remove(at path: JSONPointer, in root: inout JSONValue, opIndex: Int) throws(JSONPatchError) -> JSONValue {
        let tokens = path.tokens
        if tokens.isEmpty {
            // RFC 6902 doesn't define `remove` on the root explicitly;
            // most implementations treat it as an error.
            throw .invalidPath("", opIndex: opIndex)
        }
        var removed: JSONValue = .null
        try mutateContainer(at: tokens, in: &root, opIndex: opIndex) { parent, lastToken in
            switch parent {
            case .object(var members):
                guard let idx = members.firstIndex(where: { $0.key == lastToken.value }) else {
                    throw JSONPatchError.pathNotFound(path.description, opIndex: opIndex)
                }
                removed = members[idx].value
                members.remove(at: idx)
                parent = .object(members)
            case .array(var items):
                guard let idx = lastToken.arrayIndex, idx >= 0, idx < items.count else {
                    throw JSONPatchError.invalidIndex(lastToken.value, opIndex: opIndex)
                }
                removed = items[idx]
                items.remove(at: idx)
                parent = .array(items)
            default:
                throw JSONPatchError.targetIsNotContainer(opIndex: opIndex)
            }
        }
        return removed
    }

    // MARK: - Replace

    static func replace(value: JSONValue, at path: JSONPointer, in root: inout JSONValue, opIndex: Int) throws(JSONPatchError) {
        let tokens = path.tokens
        if tokens.isEmpty {
            root = value
            return
        }
        try mutateContainer(at: tokens, in: &root, opIndex: opIndex) { parent, lastToken in
            switch parent {
            case .object(var members):
                guard let idx = members.firstIndex(where: { $0.key == lastToken.value }) else {
                    throw JSONPatchError.pathNotFound(path.description, opIndex: opIndex)
                }
                members[idx] = .init(key: lastToken.value, value: value)
                parent = .object(members)
            case .array(var items):
                guard let idx = lastToken.arrayIndex, idx >= 0, idx < items.count else {
                    throw JSONPatchError.invalidIndex(lastToken.value, opIndex: opIndex)
                }
                items[idx] = value
                parent = .array(items)
            default:
                throw JSONPatchError.targetIsNotContainer(opIndex: opIndex)
            }
        }
    }

    // MARK: - Recursive container mutation

    /// Walk `tokens` (all but the last) into `root`, hand the resulting
    /// parent and the last token to `mutate`, then thread the modified
    /// parent back up the spine.
    static func mutateContainer(
        at tokens: [JSONPointer.Token],
        in root: inout JSONValue,
        opIndex: Int,
        _ mutate: (inout JSONValue, JSONPointer.Token) throws -> Void
    ) throws(JSONPatchError) {
        // Caller checks emptiness; this helper expects at least one token.
        do {
            try walk(tokens: tokens, depth: 0, in: &root, opIndex: opIndex, mutate)
        } catch let e as JSONPatchError {
            throw e
        } catch {
            throw .malformedPatch("\(error)")
        }
    }

    private static func walk(
        tokens: [JSONPointer.Token],
        depth: Int,
        in node: inout JSONValue,
        opIndex: Int,
        _ mutate: (inout JSONValue, JSONPointer.Token) throws -> Void
    ) throws {
        let token = tokens[depth]
        if depth == tokens.count - 1 {
            // Terminal — hand the parent (this node) and the final token to the mutator.
            try mutate(&node, token)
            return
        }
        // Non-terminal — descend into the child indicated by `token`, then
        // re-attach after recursion.
        switch node {
        case .object(var members):
            guard let idx = members.firstIndex(where: { $0.key == token.value }) else {
                throw JSONPatchError.pathNotFound(formatPath(tokens, upTo: depth + 1), opIndex: opIndex)
            }
            var child = members[idx].value
            try walk(tokens: tokens, depth: depth + 1, in: &child, opIndex: opIndex, mutate)
            members[idx] = .init(key: token.value, value: child)
            node = .object(members)
        case .array(var items):
            guard let idx = token.arrayIndex, idx >= 0, idx < items.count else {
                throw JSONPatchError.invalidIndex(token.value, opIndex: opIndex)
            }
            var child = items[idx]
            try walk(tokens: tokens, depth: depth + 1, in: &child, opIndex: opIndex, mutate)
            items[idx] = child
            node = .array(items)
        default:
            throw JSONPatchError.targetIsNotContainer(opIndex: opIndex)
        }
    }

    static func formatPath(_ tokens: [JSONPointer.Token], upTo: Int) -> String {
        var s = ""
        for i in 0..<upTo {
            s.append("/")
            s.append(tokens[i].value)
        }
        return s
    }
}
