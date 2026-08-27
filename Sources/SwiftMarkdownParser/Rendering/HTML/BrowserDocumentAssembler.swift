/// Owns browser enrichment, asset assembly, bootstrap behavior, and the
/// complete HTML document shell behind the `HTMLRenderer` interface.
struct BrowserDocumentAssembler: Sendable {
    let options: HTMLRenderOptions
    let assetLoader: any BrowserAssetLoading

    func renderFragment(
        body: String,
        requirements: BrowserRequirements
    ) throws -> String {
        guard !requirements.features.isEmpty else {
            return body
        }

        let assets = try BrowserAssetAssembler(
            options: options,
            loader: assetLoader
        ).assemble(requirements: requirements)
        return assets.head + body + assets.bootstrap
    }

    func renderDocument(
        body: String,
        requirements: BrowserRequirements,
        assembly: HTMLDocumentAssembly
    ) throws -> String {
        let host = try HTMLDocumentHostAssembler(assembly: assembly).assemble(body: body)
        let assets = try BrowserAssetAssembler(
            options: options,
            loader: assetLoader
        ).assemble(requirements: requirements)
        return """
        <!DOCTYPE html>
        <html lang="\(host.language)">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(host.title)</title>
            \(options.includeDefaultStyles ? Self.markdownCSS() : "")
            \(assets.head)
            \(host.styles)
        </head>
        <body>
            <div class="markdown-content">
                \(host.body)
            </div>
            \(assets.bootstrap)
            \(host.scripts)
        </body>
        </html>
        """
    }

    private static func markdownCSS() -> String {
        return """
        <style>
        /* Base styling */
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #fff;
            margin: 0;
            padding: 0;
        }

        .markdown-content {
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
        }

        /* Headings */
        h1, h2, h3, h4, h5, h6 {
            margin-top: 1.5em;
            margin-bottom: 0.5em;
            font-weight: 600;
            line-height: 1.25;
        }

        h1 {
            font-size: 2em;
            border-bottom: 1px solid #eaecef;
            padding-bottom: 0.3em;
        }

        h2 {
            font-size: 1.5em;
            border-bottom: 1px solid #eaecef;
            padding-bottom: 0.3em;
        }

        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; color: #6a737d; }

        /* Paragraphs */
        p {
            margin-top: 0;
            margin-bottom: 16px;
        }

        /* Lists */
        ul, ol {
            padding-left: 2em;
            margin-top: 0;
            margin-bottom: 16px;
        }

        ul ul, ul ol, ol ol, ol ul {
            margin-top: 0;
            margin-bottom: 0;
        }

        li {
            margin: 0.25em 0;
        }

        li > p {
            margin-top: 16px;
        }

        li + li {
            margin-top: 0.25em;
        }

        /* Task Lists */
        ul.task-list {
            list-style: none;
            padding-left: 0;
        }

        .task-list-item {
            display: flex;
            align-items: flex-start;
            margin: 8px 0;
            padding: 4px 8px;
            border-radius: 6px;
        }

        .task-list-item-checked {
            background-color: rgba(33, 136, 33, 0.08);
        }

        .task-list-checkbox {
            margin-right: 8px;
            margin-top: 2px;
            transform: scale(1.2);
            flex-shrink: 0;
        }

        .task-list-checkbox-checked {
            accent-color: #218838;
        }

        .task-list-content-checked {
            opacity: 0.8;
            text-decoration: line-through;
            text-decoration-color: #218838;
        }

        /* Code */
        code {
            background-color: rgba(175, 184, 193, 0.2);
            border-radius: 6px;
            font-size: 85%;
            margin: 0;
            padding: 0.2em 0.4em;
            font-family: 'SF Mono', Monaco, Inconsolata, 'Roboto Mono', 'Source Code Pro', monospace;
        }

        pre {
            background-color: #f6f8fa;
            border-radius: 6px;
            font-size: 85%;
            line-height: 1.45;
            overflow: auto;
            padding: 16px;
            margin-bottom: 16px;
        }

        pre code {
            background-color: transparent;
            border: 0;
            display: inline;
            line-height: inherit;
            margin: 0;
            max-width: auto;
            overflow: visible;
            padding: 0;
            word-wrap: normal;
        }

        /* Blockquotes */
        blockquote {
            border-left: 0.25em solid #dfe2e5;
            color: #6a737d;
            margin: 0;
            padding: 0 1em;
            margin-bottom: 16px;
        }

        blockquote > :first-child {
            margin-top: 0;
        }

        blockquote > :last-child {
            margin-bottom: 0;
        }

        /* Tables */
        table {
            border-spacing: 0;
            border-collapse: collapse;
            margin-bottom: 16px;
            width: 100%;
        }

        table th {
            font-weight: 600;
            background-color: #f6f8fa;
        }

        table th, table td {
            padding: 6px 13px;
            border: 1px solid #dfe2e5;
        }

        table tr {
            background-color: #fff;
            border-top: 1px solid #c6cbd1;
        }

        table tr:nth-child(2n) {
            background-color: #f6f8fa;
        }

        /* Links */
        a {
            color: #0366d6;
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        /* Images */
        img {
            max-width: 100%;
            height: auto;
            border-style: none;
            box-sizing: content-box;
        }

        /* Horizontal Rules */
        hr {
            height: 0.25em;
            padding: 0;
            margin: 24px 0;
            background-color: #e1e4e8;
            border: 0;
        }

        /* Emphasis */
        em {
            font-style: italic;
        }

        strong {
            font-weight: 600;
        }

        del {
            text-decoration: line-through;
        }

        /* Footnotes */
        .footnote {
            font-size: 0.9em;
            color: #0366d6;
            text-decoration: none;
            vertical-align: super;
        }

        .footnote:hover {
            text-decoration: underline;
        }

        .footnotes {
            border-top: 1px solid #eaecef;
            margin-top: 2em;
            padding-top: 1em;
            font-size: 0.9em;
        }

        .footnotes ol {
            padding-left: 1.5em;
        }

        .footnotes li {
            margin: 0.5em 0;
        }

        /* Math */
        .math {
            font-family: 'Latin Modern Math', 'Times New Roman', serif;
        }

        .math-display {
            text-align: center;
            margin: 1em 0;
        }

        /* Syntax highlighting */
        .language-swift .keyword { color: #a626a4; }
        .language-swift .string { color: #50a14f; }
        .language-swift .comment { color: #a0a1a7; font-style: italic; }
        .language-swift .number { color: #986801; }
        .language-swift .type { color: #0184bc; }

        .language-javascript .keyword { color: #d73a49; }
        .language-javascript .string { color: #032f62; }
        .language-javascript .comment { color: #6a737d; font-style: italic; }
        .language-javascript .number { color: #005cc5; }

        .language-python .keyword { color: #d73a49; }
        .language-python .string { color: #032f62; }
        .language-python .comment { color: #6a737d; font-style: italic; }
        .language-python .number { color: #005cc5; }

        /* Dark mode support */
        @media (prefers-color-scheme: dark) {
            body {
                background-color: #0d1117;
                color: #c9d1d9;
            }

            h1, h2 {
                border-bottom-color: #21262d;
            }

            h6 {
                color: #8b949e;
            }

            code {
                background-color: rgba(110, 118, 129, 0.4);
            }

            pre {
                background-color: #161b22;
            }

            blockquote {
                border-left-color: #30363d;
                color: #8b949e;
            }

            table th {
                background-color: #161b22;
            }

            table th, table td {
                border-color: #30363d;
            }

            table tr {
                background-color: #0d1117;
                border-top-color: #21262d;
            }

            table tr:nth-child(2n) {
                background-color: #161b22;
            }

            a {
                color: #58a6ff;
            }

            hr {
                background-color: #21262d;
            }

            .footnotes {
                border-top-color: #21262d;
            }

            .task-list-item-checked {
                background-color: rgba(46, 160, 67, 0.15);
            }
        }
        </style>
        """
    }

}
