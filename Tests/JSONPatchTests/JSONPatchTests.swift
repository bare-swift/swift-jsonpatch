// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import JSONPatch
import JSON
import JSONPointer

private func parse(_ s: String) throws -> JSONValue { try JSON.parse(s) }
private func patch(_ s: String) throws -> JSONPatch { try JSONPatch.parse(s) }

private func apply(_ patchString: String, to docString: String) throws -> JSONValue {
    var doc = try parse(docString)
    let p = try patch(patchString)
    try p.apply(to: &doc)
    return doc
}

@Suite("Patch document parser")
struct PatchParserTests {
    @Test("empty patch is an empty array")
    func empty() throws {
        let p = try patch("[]")
        #expect(p.operations.isEmpty)
    }

    @Test("add operation parses")
    func addOp() throws {
        let p = try patch(#"[{"op":"add","path":"/foo","value":"bar"}]"#)
        #expect(p.operations.count == 1)
        if case .add(let path, let value) = p.operations[0] {
            #expect(path.description == "/foo")
            #expect(value == .string("bar"))
        } else { Issue.record() }
    }

    @Test("all six operation types parse")
    func sixOps() throws {
        let p = try patch(#"""
        [
          {"op":"add","path":"/a","value":1},
          {"op":"remove","path":"/b"},
          {"op":"replace","path":"/c","value":2},
          {"op":"move","from":"/d","path":"/e"},
          {"op":"copy","from":"/f","path":"/g"},
          {"op":"test","path":"/h","value":3}
        ]
        """#)
        #expect(p.operations.count == 6)
    }

    @Test("missing op field throws")
    func missingOp() {
        #expect(throws: JSONPatchError.missingField("op", opIndex: 0)) {
            try patch(#"[{"path":"/foo"}]"#)
        }
    }

    @Test("missing path throws")
    func missingPath() {
        #expect(throws: JSONPatchError.missingField("path", opIndex: 0)) {
            try patch(#"[{"op":"add","value":1}]"#)
        }
    }

    @Test("unknown op throws")
    func unknownOp() {
        #expect(throws: JSONPatchError.unknownOperation("delete", opIndex: 0)) {
            try patch(#"[{"op":"delete","path":"/foo"}]"#)
        }
    }

    @Test("missing value for add throws")
    func missingValue() {
        #expect(throws: JSONPatchError.missingField("value", opIndex: 0)) {
            try patch(#"[{"op":"add","path":"/foo"}]"#)
        }
    }

    @Test("missing from for move throws")
    func missingFrom() {
        #expect(throws: JSONPatchError.missingField("from", opIndex: 0)) {
            try patch(#"[{"op":"move","path":"/foo"}]"#)
        }
    }

    @Test("non-array document throws")
    func nonArray() {
        #expect(throws: (any Error).self) {
            try patch(#"{"op":"add","path":"/foo","value":1}"#)
        }
    }

    @Test("invalid pointer throws")
    func invalidPointer() {
        #expect(throws: (any Error).self) {
            // Path missing leading slash.
            try patch(#"[{"op":"add","path":"foo","value":1}]"#)
        }
    }
}

@Suite("Add")
struct AddOpTests {
    @Test("add new object member")
    func addNewMember() throws {
        let result = try apply(#"[{"op":"add","path":"/email","value":"a@b"}]"#,
                                to: #"{"name":"alice"}"#)
        if case .object(let m) = result {
            #expect(m.contains { $0.key == "email" && $0.value == .string("a@b") })
        } else { Issue.record() }
    }

    @Test("add overwrites existing object member")
    func addOverwrites() throws {
        let result = try apply(#"[{"op":"add","path":"/age","value":31}]"#,
                                to: #"{"name":"alice","age":30}"#)
        if case .object(let m) = result {
            let age = m.first(where: { $0.key == "age" })?.value
            #expect(age == .integer(31))
        } else { Issue.record() }
    }

    @Test("add inserts into array at index")
    func addInsertsArray() throws {
        let result = try apply(#"[{"op":"add","path":"/1","value":99}]"#,
                                to: "[10, 20, 30]")
        #expect(result == .array([.integer(10), .integer(99), .integer(20), .integer(30)]))
    }

    @Test("add appends with `-` token")
    func addAppendsDash() throws {
        let result = try apply(#"[{"op":"add","path":"/-","value":40}]"#,
                                to: "[10, 20, 30]")
        #expect(result == .array([.integer(10), .integer(20), .integer(30), .integer(40)]))
    }

    @Test("add to nested path")
    func addNested() throws {
        let result = try apply(#"[{"op":"add","path":"/a/b","value":2}]"#,
                                to: #"{"a":{}}"#)
        if case .object(let outer) = result,
           case .object(let inner) = outer[0].value {
            #expect(inner == [.init(key: "b", value: .integer(2))])
        } else { Issue.record() }
    }

    @Test("add to root replaces document")
    func addToRoot() throws {
        let result = try apply(#"[{"op":"add","path":"","value":[1,2,3]}]"#,
                                to: #"{"old":"value"}"#)
        #expect(result == .array([.integer(1), .integer(2), .integer(3)]))
    }

    @Test("add to non-existent parent throws pathNotFound")
    func addParentMissing() {
        #expect(throws: (any Error).self) {
            try apply(#"[{"op":"add","path":"/missing/foo","value":1}]"#,
                       to: #"{"a":1}"#)
        }
    }

    @Test("add at out-of-bounds array index throws")
    func addOutOfBounds() {
        #expect(throws: (any Error).self) {
            try apply(#"[{"op":"add","path":"/5","value":1}]"#, to: "[10]")
        }
    }
}

@Suite("Remove")
struct RemoveOpTests {
    @Test("remove object member")
    func removeMember() throws {
        let result = try apply(#"[{"op":"remove","path":"/age"}]"#,
                                to: #"{"name":"alice","age":30}"#)
        if case .object(let m) = result {
            #expect(m.count == 1 && m[0].key == "name")
        } else { Issue.record() }
    }

    @Test("remove array element")
    func removeArrayElement() throws {
        let result = try apply(#"[{"op":"remove","path":"/1"}]"#,
                                to: "[10, 20, 30]")
        #expect(result == .array([.integer(10), .integer(30)]))
    }

    @Test("remove nested path")
    func removeNested() throws {
        let result = try apply(#"[{"op":"remove","path":"/a/b"}]"#,
                                to: #"{"a":{"b":1,"c":2}}"#)
        if case .object(let outer) = result,
           case .object(let inner) = outer[0].value {
            #expect(inner.count == 1 && inner[0].key == "c")
        } else { Issue.record() }
    }

    @Test("remove of missing member throws")
    func removeMissing() {
        #expect(throws: (any Error).self) {
            try apply(#"[{"op":"remove","path":"/missing"}]"#, to: #"{"a":1}"#)
        }
    }
}

@Suite("Replace")
struct ReplaceOpTests {
    @Test("replace existing member")
    func replaceExisting() throws {
        let result = try apply(#"[{"op":"replace","path":"/x","value":42}]"#,
                                to: #"{"x":1}"#)
        if case .object(let m) = result {
            #expect(m[0].value == .integer(42))
        } else { Issue.record() }
    }

    @Test("replace requires path to exist (RFC 6902 § 4.3)")
    func replaceMissing() {
        #expect(throws: (any Error).self) {
            try apply(#"[{"op":"replace","path":"/missing","value":1}]"#,
                       to: #"{"a":1}"#)
        }
    }

    @Test("replace array element")
    func replaceArray() throws {
        let result = try apply(#"[{"op":"replace","path":"/1","value":99}]"#,
                                to: "[10, 20, 30]")
        #expect(result == .array([.integer(10), .integer(99), .integer(30)]))
    }
}

@Suite("Move")
struct MoveOpTests {
    @Test("move within object")
    func moveWithinObject() throws {
        let result = try apply(#"[{"op":"move","from":"/a","path":"/b"}]"#,
                                to: #"{"a":1}"#)
        if case .object(let m) = result {
            #expect(m.first(where: { $0.key == "b" })?.value == .integer(1))
            #expect(m.first(where: { $0.key == "a" }) == nil)
        } else { Issue.record() }
    }

    @Test("move from missing source throws")
    func moveSourceMissing() {
        #expect(throws: (any Error).self) {
            try apply(#"[{"op":"move","from":"/x","path":"/y"}]"#, to: #"{"a":1}"#)
        }
    }

    @Test("move array element")
    func moveArrayElement() throws {
        let result = try apply(#"[{"op":"move","from":"/0","path":"/-"}]"#,
                                to: "[10, 20, 30]")
        #expect(result == .array([.integer(20), .integer(30), .integer(10)]))
    }
}

@Suite("Copy")
struct CopyOpTests {
    @Test("copy preserves source")
    func copyPreserves() throws {
        let result = try apply(#"[{"op":"copy","from":"/a","path":"/b"}]"#,
                                to: #"{"a":42}"#)
        if case .object(let m) = result {
            #expect(m.first(where: { $0.key == "a" })?.value == .integer(42))
            #expect(m.first(where: { $0.key == "b" })?.value == .integer(42))
        } else { Issue.record() }
    }

    @Test("copy from missing source throws")
    func copyMissing() {
        #expect(throws: (any Error).self) {
            try apply(#"[{"op":"copy","from":"/x","path":"/y"}]"#, to: "{}")
        }
    }
}

@Suite("Test")
struct TestOpTests {
    @Test("test passes when values match")
    func testPasses() throws {
        let result = try apply(#"[{"op":"test","path":"/x","value":42}]"#,
                                to: #"{"x":42}"#)
        // Original unchanged.
        if case .object(let m) = result {
            #expect(m[0].value == .integer(42))
        } else { Issue.record() }
    }

    @Test("test fails when values differ")
    func testFails() {
        #expect(throws: JSONPatchError.testFailed(opIndex: 0)) {
            try apply(#"[{"op":"test","path":"/x","value":99}]"#,
                       to: #"{"x":42}"#)
        }
    }

    @Test("test fails when path missing")
    func testMissingPath() {
        #expect(throws: JSONPatchError.testFailed(opIndex: 0)) {
            try apply(#"[{"op":"test","path":"/missing","value":1}]"#,
                       to: "{}")
        }
    }
}

@Suite("Atomicity")
struct AtomicityTests {
    @Test("failure mid-patch leaves input unchanged")
    func atomicFailure() throws {
        var doc = try parse(#"{"a":1,"b":2}"#)
        let original = doc
        let p = try patch(#"""
        [
          {"op":"add","path":"/c","value":3},
          {"op":"test","path":"/a","value":99}
        ]
        """#)
        #expect(throws: JSONPatchError.testFailed(opIndex: 1)) {
            try p.apply(to: &doc)
        }
        #expect(doc == original)  // unchanged
    }

    @Test("successful sequence applies all operations")
    func successfulSequence() throws {
        let result = try apply(#"""
        [
          {"op":"add","path":"/c","value":3},
          {"op":"replace","path":"/a","value":99},
          {"op":"remove","path":"/b"}
        ]
        """#, to: #"{"a":1,"b":2}"#)
        if case .object(let m) = result {
            #expect(m.count == 2)
        } else { Issue.record() }
    }
}

@Suite("Round-trip serialize")
struct RoundTripTests {
    @Test("parse → serialize → parse")
    func roundTrip() throws {
        let original = try patch(#"""
        [
          {"op":"add","path":"/a","value":1},
          {"op":"remove","path":"/b"},
          {"op":"replace","path":"/c","value":"x"},
          {"op":"move","from":"/d","path":"/e"},
          {"op":"copy","from":"/f","path":"/g"},
          {"op":"test","path":"/h","value":true}
        ]
        """#)
        let serialized = original.serialized()
        let reparsed = try JSONPatch.parse(serialized)
        #expect(original == reparsed)
    }
}

@Suite("End-to-end — RFC 6902 examples")
struct EndToEndTests {
    /// Adapted from RFC 6902 § A.1.
    @Test("A.1: add member to object")
    func a1() throws {
        let result = try apply(#"[{"op":"add","path":"/baz","value":"qux"}]"#,
                                to: #"{"foo":"bar"}"#)
        if case .object(let m) = result {
            #expect(m.contains { $0.key == "baz" && $0.value == .string("qux") })
        } else { Issue.record() }
    }

    /// RFC 6902 § A.2.
    @Test("A.2: add array element")
    func a2() throws {
        let result = try apply(#"[{"op":"add","path":"/foo/1","value":"qux"}]"#,
                                to: #"{"foo":["bar","baz"]}"#)
        if case .object(let outer) = result,
           case .array(let inner) = outer[0].value {
            #expect(inner == [.string("bar"), .string("qux"), .string("baz")])
        } else { Issue.record() }
    }

    /// RFC 6902 § A.3.
    @Test("A.3: remove object member")
    func a3() throws {
        let result = try apply(#"[{"op":"remove","path":"/baz"}]"#,
                                to: #"{"baz":"qux","foo":"bar"}"#)
        if case .object(let m) = result {
            #expect(m.count == 1 && m[0].key == "foo")
        } else { Issue.record() }
    }

    /// RFC 6902 § A.6.
    @Test("A.6: move value from one location to another")
    func a6() throws {
        let result = try apply(#"[{"op":"move","from":"/foo/waldo","path":"/qux/thud"}]"#,
                                to: #"{"foo":{"bar":"baz","waldo":"fred"},"qux":{"corge":"grault"}}"#)
        // Verify /foo no longer has waldo, and /qux has thud
        if case .object(let outer) = result,
           case .object(let foo) = outer.first(where: { $0.key == "foo" })!.value,
           case .object(let qux) = outer.first(where: { $0.key == "qux" })!.value {
            #expect(foo.first(where: { $0.key == "waldo" }) == nil)
            #expect(qux.first(where: { $0.key == "thud" })?.value == .string("fred"))
        } else { Issue.record() }
    }
}
