import Foundation

/// One row of the JSON / property-list tree preview.
struct StructuredNode: Identifiable, Equatable {
    enum Kind: String {
        case dictionary, array, string, number, boolean, date, data, null
    }

    /// Path from the root (e.g. `/items/0/name`). Stable across re-parses so
    /// the tree keeps its expansion state while the source is edited.
    let id: String
    let key: String
    let kind: Kind
    let value: String
    let children: [StructuredNode]?

    var typeLabel: String { L("tree.type.\(kind.rawValue)") }
}

enum StructuredFormat {
    case json, propertyList

    /// Parses `text` into a tree. Dictionary keys are sorted: neither
    /// JSONSerialization nor PropertyListSerialization preserves key order.
    func parse(_ text: String) throws -> StructuredNode {
        let data = Data(text.utf8)
        let object: Any
        switch self {
        case .json:
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        case .propertyList:
            object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        }
        return Self.node(for: object, key: L("tree.root"), path: "")
    }

    private static let dateFormatter = ISO8601DateFormatter()

    private static func node(for object: Any, key: String, path: String) -> StructuredNode {
        let id = path.isEmpty ? "/" : path
        switch object {
        case let dictionary as [String: Any]:
            let children = dictionary.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map {
                node(for: dictionary[$0]!, key: $0, path: path + "/" + escape($0))
            }
            return StructuredNode(id: id, key: key, kind: .dictionary,
                                  value: L("tree.count.items", children.count), children: children)
        case let array as [Any]:
            let children = array.enumerated().map { index, element in
                node(for: element, key: "[\(index)]", path: path + "/\(index)")
            }
            return StructuredNode(id: id, key: key, kind: .array,
                                  value: L("tree.count.items", children.count), children: children)
        case let string as String:
            return StructuredNode(id: id, key: key, kind: .string, value: string, children: nil)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return StructuredNode(id: id, key: key, kind: .boolean, value: number.boolValue ? "true" : "false", children: nil)
            }
            return StructuredNode(id: id, key: key, kind: .number, value: number.stringValue, children: nil)
        case let date as Date:
            return StructuredNode(id: id, key: key, kind: .date, value: dateFormatter.string(from: date), children: nil)
        case let data as Data:
            return StructuredNode(id: id, key: key, kind: .data,
                                  value: ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .binary),
                                  children: nil)
        default:
            return StructuredNode(id: id, key: key, kind: .null, value: "null", children: nil)
        }
    }

    /// JSON Pointer–style escaping so keys containing "/" stay unique.
    private static func escape(_ key: String) -> String {
        key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
    }
}
