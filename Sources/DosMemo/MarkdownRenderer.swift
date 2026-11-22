import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Converts GitHub Flavored Markdown to HTML with cmark-gfm.
enum MarkdownRenderer {
    /// GFM extensions, as enabled on github.com. `tagfilter` neutralizes
    /// tags such as `<script>`, `<iframe>` and `<style>` in raw HTML.
    private static let extensionNames = ["table", "strikethrough", "autolink", "tagfilter", "tasklist"]

    /// Raw HTML is passed through (like GitHub) because the preview runs
    /// with page JavaScript disabled and blocks in-page navigation.
    private static let options = CMARK_OPT_UNSAFE | CMARK_OPT_FOOTNOTES | CMARK_OPT_GITHUB_PRE_LANG

    static func html(from markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()
        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }

        for name in extensionNames {
            if let syntaxExtension = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, syntaxExtension)
            }
        }

        var source = markdown
        source.withUTF8 { buffer in
            buffer.withMemoryRebound(to: CChar.self) { chars in
                cmark_parser_feed(parser, chars.baseAddress, chars.count)
            }
        }
        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }

        guard let rendered = cmark_render_html(document, options, cmark_parser_get_syntax_extensions(parser)) else {
            return ""
        }
        defer { free(rendered) }
        return String(cString: rendered)
    }
}
