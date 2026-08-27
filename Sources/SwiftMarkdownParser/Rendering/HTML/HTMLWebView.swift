/// SwiftUI adapter for presenting HTML-rendered Markdown in WebKit.
///
/// This file provides WebView integration for displaying Mermaid diagrams
/// in SwiftUI and UIKit/AppKit applications.

#if canImport(SwiftUI) && canImport(WebKit)
import Foundation
public import SwiftUI
import WebKit

enum BrowserRuntimeError: Error, LocalizedError {
    case failed(String)
    case invalidReport

    var errorDescription: String? {
        switch self {
        case .failed(let detail):
            return "Browser runtime failed: \(detail)"
        case .invalidReport:
            return "Browser runtime returned an invalid readiness report."
        }
    }
}

enum BrowserRuntimeReport: Equatable {
    static let currentVersion = 1

    case ready(requiredFeatures: Set<BrowserFeature>)
    case failed(
        requiredFeatures: Set<BrowserFeature>,
        failedFeatures: Set<BrowserFeature>,
        detail: String
    )

    init(messageBody: Any) throws {
        guard
            let payload = messageBody as? [String: Any],
            let status = payload["status"] as? String
        else {
            throw BrowserRuntimeError.invalidReport
        }

        let requiredFeatures: Set<BrowserFeature>
        let failedFeatures: Set<BrowserFeature>
        if let version = payload["version"] as? Int {
            guard version == Self.currentVersion else {
                throw BrowserRuntimeError.invalidReport
            }
            requiredFeatures = try Self.features(in: payload, key: "requiredFeatures")
            failedFeatures = try Self.features(in: payload, key: "failedFeatures")
            guard failedFeatures.isSubset(of: requiredFeatures) else {
                throw BrowserRuntimeError.invalidReport
            }
        } else if payload["version"] == nil {
            requiredFeatures = []
            failedFeatures = []
        } else {
            throw BrowserRuntimeError.invalidReport
        }

        switch status {
        case "ready":
            guard failedFeatures.isEmpty else {
                throw BrowserRuntimeError.invalidReport
            }
            self = .ready(requiredFeatures: requiredFeatures)
        case "failed":
            self = .failed(
                requiredFeatures: requiredFeatures,
                failedFeatures: failedFeatures,
                detail: payload["detail"] as? String ?? "Unknown browser runtime failure"
            )
        default:
            throw BrowserRuntimeError.invalidReport
        }
    }

    private static func features(in payload: [String: Any], key: String) throws -> Set<BrowserFeature> {
        guard let rawFeatures = payload[key] as? [String] else {
            throw BrowserRuntimeError.invalidReport
        }
        let features = rawFeatures.compactMap(BrowserFeature.init(rawValue:))
        guard features.count == rawFeatures.count, Set(rawFeatures).count == rawFeatures.count else {
            throw BrowserRuntimeError.invalidReport
        }
        return Set(features)
    }
}

// MARK: - WebView Support for SwiftUI

#if os(macOS)

/// SwiftUI view for displaying general markdown content in a WebView
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public struct MarkdownWebView: View {
    /// Renderer-independent document to present.
    public let document: AST.DocumentNode

    /// HTML behavior used by the presentation adapter.
    public let options: HTMLRenderOptions

    /// Metadata for the complete HTML document loaded by WebKit.
    public let metadata: HTMLDocumentMetadata

    /// Optional callback when content is rendered
    public let onRender: ((Result<Void, Error>) -> Void)?

    /// State for the WebView
    @State private var isLoading = true
    @State private var error: Error?

    public init(
        document: AST.DocumentNode,
        options: HTMLRenderOptions = .init(),
        metadata: HTMLDocumentMetadata = .init(),
        onRender: ((Result<Void, Error>) -> Void)? = nil
    ) {
        self.document = document
        self.options = options
        self.metadata = metadata
        self.onRender = onRender
    }

    public var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            MarkdownWebViewRepresentable(
                document: document,
                options: options,
                metadata: metadata,
                isLoading: $isLoading,
                error: $error,
                onRender: onRender
            )
            .opacity(isLoading ? 0 : 1)

            if let error = error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.red)

                    Text("Failed to render markdown")
                        .font(.headline)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// SwiftUI view for displaying Mermaid diagrams in a WebView
@available(iOS 17.0, macOS 14.0, *)
@MainActor
struct MermaidWebView: View {

    /// The Mermaid diagram node to render
    let diagramNode: AST.MermaidDiagramNode

    /// Configuration for Mermaid rendering
    let configuration: MermaidConfiguration

    /// Optional callback when diagram is rendered
    let onRender: ((Result<Void, Error>) -> Void)?

    /// State for the WebView
    @State private var isLoading = true
    @State private var error: Error?

    init(
        diagramNode: AST.MermaidDiagramNode,
        configuration: MermaidConfiguration = .default,
        onRender: ((Result<Void, Error>) -> Void)? = nil
    ) {
        self.diagramNode = diagramNode
        self.configuration = configuration
        self.onRender = onRender
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            MermaidWebViewRepresentable(
                diagramNode: diagramNode,
                configuration: configuration,
                isLoading: $isLoading,
                error: $error,
                onRender: onRender
            )
            .opacity(isLoading ? 0 : 1)

            if let error = error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.red)

                    Text("Failed to render diagram")
                        .font(.headline)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - WebView Representable

@available(iOS 17.0, macOS 14.0, *)
struct MarkdownWebViewRepresentable: NSViewRepresentable {
    let document: AST.DocumentNode
    let options: HTMLRenderOptions
    let metadata: HTMLDocumentMetadata
    @Binding var isLoading: Bool
    @Binding var error: Error?
    let onRender: ((Result<Void, Error>) -> Void)?

    @MainActor
    func makeNSView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()

        webConfiguration.userContentController.add(
            context.coordinator,
            name: "markdownRuntime"
        )

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = context.coordinator

        return webView
    }

    @MainActor
    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.loadTask?.cancel()
        context.coordinator.loadTask = Task {
            await loadMarkdownContent(in: webView)
        }
    }

    @MainActor
    func makeCoordinator() -> MarkdownCoordinator {
        MarkdownCoordinator(parent: self)
    }

    @MainActor
    private func loadMarkdownContent(in webView: WKWebView) async {
        do {
            let html = try await HTMLRenderer(options: options).renderDocument(
                document,
                metadata: metadata
            )

            webView.loadHTMLString(html, baseURL: nil)
        } catch {
            self.isLoading = false
            self.error = error
            self.onRender?(.failure(error))
        }
    }

    @MainActor
    class MarkdownCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: MarkdownWebViewRepresentable
        var loadTask: Task<Void, Never>?

        init(parent: MarkdownWebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finish(with: .failure(error))
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            finish(with: .failure(error))
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "markdownRuntime" else { return }

            do {
                switch try BrowserRuntimeReport(messageBody: message.body) {
                case .ready:
                    finish(with: .success(()))
                case .failed(_, _, let detail):
                    finish(with: .failure(BrowserRuntimeError.failed(detail)))
                }
            } catch {
                finish(with: .failure(error))
            }
        }

        private func finish(with result: Result<Void, Error>) {
            parent.isLoading = false
            if case .failure(let error) = result {
                parent.error = error
            }
            parent.onRender?(result)
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct MermaidWebViewRepresentable: NSViewRepresentable {
    let diagramNode: AST.MermaidDiagramNode
    let configuration: MermaidConfiguration
    @Binding var isLoading: Bool
    @Binding var error: Error?
    let onRender: ((Result<Void, Error>) -> Void)?

    @MainActor
    func makeNSView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController.add(
            context.coordinator,
            name: "markdownRuntime"
        )

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = context.coordinator

        return webView
    }

    @MainActor
    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.loadTask?.cancel()
        context.coordinator.loadTask = Task {
            await loadMermaidContent(in: webView)
        }
    }

    @MainActor
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    private func loadMermaidContent(in webView: WKWebView) async {
        do {
            let options = HTMLRenderOptions(mermaidConfiguration: configuration)
            let document = AST.DocumentNode(children: [diagramNode])
            let html = try await HTMLRenderer(options: options).renderDocument(
                document,
                metadata: HTMLDocumentMetadata(title: "Mermaid Diagram")
            )
            webView.loadHTMLString(html, baseURL: nil)
        } catch {
            isLoading = false
            self.error = error
            onRender?(.failure(error))
        }
    }

    @MainActor
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: MermaidWebViewRepresentable
        var loadTask: Task<Void, Never>?

        init(parent: MermaidWebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finish(with: .failure(error))
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            finish(with: .failure(error))
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "markdownRuntime" else { return }

            do {
                switch try BrowserRuntimeReport(messageBody: message.body) {
                case .ready:
                    finish(with: .success(()))
                case .failed(_, _, let detail):
                    finish(with: .failure(BrowserRuntimeError.failed(detail)))
                }
            } catch {
                finish(with: .failure(error))
            }
        }

        private func finish(with result: Result<Void, Error>) {
            parent.isLoading = false
            if case .failure(let error) = result {
                parent.error = error
            }
            parent.onRender?(result)
        }
    }
}

#endif // os(macOS)

#endif // canImport(SwiftUI) && canImport(WebKit)
