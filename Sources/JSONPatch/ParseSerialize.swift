// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import JSON
import JSONPointer

/// Parse and serialize the JSON Patch document itself per RFC 6902:
/// the document is a top-level JSON array; each element is an object
/// with `op`, `path`, and (depending on the op) `value` and/or `from`.
enum ParseSerialize {
    static func parse(_ document: JSONValue) throws(JSONPatchError) -> JSONPatch {
        guard case .array(let items) = document else {
            throw .malformedPatch("patch document must be a JSON array")
        }
        var ops: [JSONPatch.Operation] = []
        for (index, item) in items.enumerated() {
            ops.append(try parseOp(item, opIndex: index))
        }
        return JSONPatch(operations: ops)
    }

    private static func parseOp(_ item: JSONValue, opIndex: Int) throws(JSONPatchError) -> JSONPatch.Operation {
        guard case .object(let members) = item else {
            throw .malformedPatch("operation #\(opIndex) is not a JSON object")
        }
        let opName = try requireString(members, key: "op", opIndex: opIndex)
        let pathString = try requireString(members, key: "path", opIndex: opIndex)
        let path: JSONPointer
        do {
            path = try JSONPointer(pathString)
        } catch {
            throw .invalidPath(pathString, opIndex: opIndex)
        }

        switch opName {
        case "add":
            let v = try requireValue(members, key: "value", opIndex: opIndex)
            return .add(path: path, value: v)
        case "remove":
            return .remove(path: path)
        case "replace":
            let v = try requireValue(members, key: "value", opIndex: opIndex)
            return .replace(path: path, value: v)
        case "move":
            let from = try parsePointer(try requireString(members, key: "from", opIndex: opIndex), opIndex: opIndex)
            return .move(from: from, path: path)
        case "copy":
            let from = try parsePointer(try requireString(members, key: "from", opIndex: opIndex), opIndex: opIndex)
            return .copy(from: from, path: path)
        case "test":
            let v = try requireValue(members, key: "value", opIndex: opIndex)
            return .test(path: path, value: v)
        default:
            throw .unknownOperation(opName, opIndex: opIndex)
        }
    }

    private static func requireString(
        _ members: [JSONValue.Member],
        key: String,
        opIndex: Int
    ) throws(JSONPatchError) -> String {
        guard let m = members.first(where: { $0.key == key }) else {
            throw .missingField(key, opIndex: opIndex)
        }
        guard case .string(let s) = m.value else {
            throw .missingField(key, opIndex: opIndex)
        }
        return s
    }

    private static func requireValue(
        _ members: [JSONValue.Member],
        key: String,
        opIndex: Int
    ) throws(JSONPatchError) -> JSONValue {
        guard let m = members.first(where: { $0.key == key }) else {
            throw .missingField(key, opIndex: opIndex)
        }
        return m.value
    }

    private static func parsePointer(_ s: String, opIndex: Int) throws(JSONPatchError) -> JSONPointer {
        do {
            return try JSONPointer(s)
        } catch {
            throw .invalidPath(s, opIndex: opIndex)
        }
    }

    // MARK: - Serialize

    static func serialize(_ patch: JSONPatch) -> JSONValue {
        let items: [JSONValue] = patch.operations.map { op -> JSONValue in
            switch op {
            case .add(let path, let value):
                return .object([
                    .init(key: "op", value: .string("add")),
                    .init(key: "path", value: .string(path.description)),
                    .init(key: "value", value: value),
                ])
            case .remove(let path):
                return .object([
                    .init(key: "op", value: .string("remove")),
                    .init(key: "path", value: .string(path.description)),
                ])
            case .replace(let path, let value):
                return .object([
                    .init(key: "op", value: .string("replace")),
                    .init(key: "path", value: .string(path.description)),
                    .init(key: "value", value: value),
                ])
            case .move(let from, let path):
                return .object([
                    .init(key: "op", value: .string("move")),
                    .init(key: "from", value: .string(from.description)),
                    .init(key: "path", value: .string(path.description)),
                ])
            case .copy(let from, let path):
                return .object([
                    .init(key: "op", value: .string("copy")),
                    .init(key: "from", value: .string(from.description)),
                    .init(key: "path", value: .string(path.description)),
                ])
            case .test(let path, let value):
                return .object([
                    .init(key: "op", value: .string("test")),
                    .init(key: "path", value: .string(path.description)),
                    .init(key: "value", value: value),
                ])
            }
        }
        return .array(items)
    }
}
