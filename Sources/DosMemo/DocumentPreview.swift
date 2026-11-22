import SwiftUI
import UniformTypeIdentifiers

/// How a document is shown: editable source, source beside a preview, or
/// the preview alone.
enum EditorLayout: String, CaseIterable {
    case source, split, preview

    var titleKey: String { "layout.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .source:  return "doc.plaintext"
        case .split:   return "rectangle.split.2x1"
        case .preview: return "eye"
        }
    }
}

/// Formats with a formatted preview.
enum PreviewKind: Equatable {
    case markdown
    case tree(StructuredFormat)

    /// Determined by the file's type; untitled documents have none until
    /// they are saved with a previewable extension.
    init?(fileURL: URL?, isBinaryPropertyList: Bool) {
        if isBinaryPropertyList {
            self = .tree(.propertyList)
            return
        }
        guard let ext = fileURL?.pathExtension, let type = UTType(filenameExtension: ext) else { return nil }
        if type.conforms(to: TextFormat.markdown) {
            self = .markdown
        } else if type.conforms(to: .json) {
            self = .tree(.json)
        } else if type.conforms(to: .propertyList) {
            self = .tree(.propertyList)
        } else {
            return nil
        }
    }
}

/// Renders the preview for `text`, re-rendering shortly after edits stop
/// so typing in split view stays responsive.
struct DocumentPreview: View {
    let kind: PreviewKind
    let text: String
    let fileURL: URL?
    let fontSize: CGFloat

    @State private var html = ""
    @State private var tree: Result<StructuredNode, Error>?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .task(id: RenderKey(kind: kind, text: text)) {
                await render(isInitial: html.isEmpty && tree == nil)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .markdown:
            MarkdownPreviewView(html: html, baseURL: fileURL?.deletingLastPathComponent(),
                                zoom: fontSize / AppSettings.baseFontSize)
        case .tree:
            switch tree {
            case .success(let root)?:
                StructuredTreeView(root: root, fontSize: fontSize)
            case .failure(let error)?:
                ParseErrorView(error: error)
            case nil:
                ProgressView().controlSize(.small)
            }
        }
    }

    private struct RenderKey: Equatable {
        let kind: PreviewKind
        let text: String
    }

    private func render(isInitial: Bool) async {
        if !isInitial {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
        }
        let text = self.text
        switch kind {
        case .markdown:
            let rendered = await Task.detached(priority: .userInitiated) { MarkdownRenderer.html(from: text) }.value
            if !Task.isCancelled { html = rendered }
        case .tree(let format):
            let parsed = await Task.detached(priority: .userInitiated) {
                Result { try format.parse(text) }
            }.value
            if !Task.isCancelled { tree = parsed }
        }
    }
}

/// Key / type / value outline. Visible rows are laid out flat, with the
/// indentation taken out of the key column, so the type and value columns
/// stay aligned at every depth (an outline `Table` would need macOS 14).
private struct StructuredTreeView: View {
    let root: StructuredNode
    let fontSize: CGFloat

    /// Expanded node ids. Ids are paths, so expansion survives re-parsing
    /// while the source is edited.
    @State private var expanded: Set<String> = ["/"]

    private var indent: CGFloat { fontSize }
    private var keyWidth: CGFloat { fontSize * 16 }
    private var typeWidth: CGFloat { fontSize * 6 }

    private struct Row: Identifiable {
        let node: StructuredNode
        let depth: Int
        var id: String { node.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(L("tree.column.key")).frame(width: indent + keyWidth, alignment: .leading)
                Text(L("tree.column.type")).frame(width: typeWidth, alignment: .leading)
                Text(L("tree.column.value"))
                Spacer(minLength: 0)
            }
            .font(.system(size: max(11, fontSize - 2), weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, row in
                        rowView(row)
                            .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.04))
                    }
                }
            }
        }
    }

    private var visibleRows: [Row] {
        var rows: [Row] = []
        func append(_ node: StructuredNode, depth: Int) {
            rows.append(Row(node: node, depth: depth))
            guard expanded.contains(node.id), let children = node.children else { return }
            for child in children { append(child, depth: depth + 1) }
        }
        append(root, depth: 0)
        return rows
    }

    private func rowView(_ row: Row) -> some View {
        let node = row.node
        let offset = CGFloat(row.depth) * indent
        return HStack(spacing: 8) {
            HStack(spacing: 2) {
                Color.clear.frame(width: offset, height: 1)
                if node.children?.isEmpty == false {
                    Button { toggle(node) } label: {
                        Image(systemName: expanded.contains(node.id) ? "chevron.down" : "chevron.right")
                            .font(.system(size: fontSize * 0.7, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: indent - 2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: indent - 2, height: 1)
                }
                Text(node.key).lineLimit(1)
                Spacer(minLength: 0)
            }
            // Deeper rows give up key width instead of pushing columns right.
            .frame(width: indent + keyWidth, alignment: .leading)
            .clipped()
            Text(node.typeLabel)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: typeWidth, alignment: .leading)
            Text(node.value)
                .lineLimit(1)
                .foregroundColor(node.children == nil ? .primary : .secondary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.system(size: fontSize))
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    /// Option-click expands or collapses the whole subtree, as in Finder.
    private func toggle(_ node: StructuredNode) {
        let expand = !expanded.contains(node.id)
        let ids = NSEvent.modifierFlags.contains(.option) ? Self.subtreeIDs(node) : [node.id]
        if expand { expanded.formUnion(ids) } else { expanded.subtract(ids) }
    }

    private static func subtreeIDs(_ node: StructuredNode) -> [String] {
        guard let children = node.children else { return [] }
        return [node.id] + children.flatMap(subtreeIDs)
    }
}

private struct ParseErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            Text(L("tree.error.title")).font(.headline)
            Text(detail)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .padding(24)
    }

    /// Foundation's parse errors put the position ("around line 3,
    /// column 5") in the debug description, not the localized one.
    private var detail: String {
        let nsError = error as NSError
        return (nsError.userInfo[NSDebugDescriptionErrorKey] as? String) ?? nsError.localizedDescription
    }
}
