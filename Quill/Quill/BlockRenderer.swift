import SwiftUI
import WebKit

#if os(iOS) || os(visionOS)
import UIKit
typealias PlatformImage = UIImage
typealias PlatformViewRepresentable = UIViewRepresentable
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

// MARK: - Main Block Renderer

struct BlockRenderer: View {
    @ObservedObject var document: BlockDocument
    let block: GutenbergBlock
    @State private var isEditing = false
    @State private var editingContent = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Render block based on type
            if block.isNativeSupported {
                NativeBlockRenderer(
                    document: document,
                    block: block,
                    isEditing: $isEditing,
                    editingContent: $editingContent
                )
            } else {
                HTMLBlockRenderer(block: block)
            }
        }
        .padding(.vertical, 8)
        .onTapGesture {
            if !isEditing {
                document.selectedBlockID = block.id
                if block.isNativeSupported {
                    startEditing()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(document.selectedBlockID == block.id ? Color.accentColor.opacity(0.1) : Color.clear)
                .stroke(document.selectedBlockID == block.id ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                .animation(.easeInOut(duration: 0.2), value: document.selectedBlockID)
        )
        .scaleEffect(document.selectedBlockID == block.id ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: document.selectedBlockID)
    }
    
    private func startEditing() {
        editingContent = block.content
        isEditing = true
    }
    
    private func finishEditing() {
        document.updateBlock(id: block.id, content: editingContent)
        isEditing = false
    }
}

// MARK: - Native Block Renderer

struct NativeBlockRenderer: View {
    @ObservedObject var document: BlockDocument
    let block: GutenbergBlock
    @Binding var isEditing: Bool
    @Binding var editingContent: String
    
    var body: some View {
        switch block.type {
        case .paragraph:
            ParagraphBlockRenderer(
                block: block,
                isEditing: $isEditing,
                editingContent: $editingContent,
                onFinishEditing: { content in
                    document.updateBlock(id: block.id, content: content)
                    isEditing = false
                }
            )
            
        case .heading:
            HeadingBlockRenderer(
                block: block,
                isEditing: $isEditing,
                editingContent: $editingContent,
                onFinishEditing: { content in
                    document.updateBlock(id: block.id, content: content)
                    isEditing = false
                }
            )
            
        case .list:
            ListBlockRenderer(block: block)
            
        case .quote:
            QuoteBlockRenderer(block: block)
            
        case .code:
            CodeBlockRenderer(block: block)
            
        case .image:
            ImageBlockRenderer(block: block)
            
        case .separator:
            SeparatorBlockRenderer(block: block)
            
        case .buttons:
            ButtonsBlockRenderer(block: block)
            
        case .button:
            ButtonBlockRenderer(block: block)
            
        case .columns:
            ColumnsBlockRenderer(block: block)
            
        case .column:
            ColumnBlockRenderer(block: block)
            
        case .gallery:
            GalleryBlockRenderer(block: block)
            
        case .video:
            VideoBlockRenderer(block: block)
            
        case .audio:
            AudioBlockRenderer(block: block)
            
        case .table:
            TableBlockRenderer(block: block)
            
        case .spacer:
            SpacerBlockRenderer(block: block)
            
        case .group:
            GroupBlockRenderer(block: block)
            
        case .cover:
            CoverBlockRenderer(block: block)
            
        case .embed:
            EmbedBlockRenderer(block: block)
            
        case .pullquote:
            PullquoteBlockRenderer(block: block)
            
        case .unknown:
            UnknownBlockRenderer(block: block)
        }
    }
}

// MARK: - HTML Fallback Renderer

struct HTMLBlockRenderer: View {
    let block: GutenbergBlock
    @State private var webViewHeight: CGFloat = 100
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Block type indicator
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
                Text(block.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            
            // Web view for complex block
            WebView(
                htmlContent: generateHTMLContent(),
                dynamicHeight: $webViewHeight
            )
            .frame(height: webViewHeight)
            .background(backgroundColorView)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(separatorColorView, lineWidth: 1)
            )
        }
    }
    
    private var backgroundColorView: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    private var separatorColorView: Color {
        #if os(macOS)
        return Color(NSColor.separatorColor)
        #else
        return Color(.separator)
        #endif
    }
    
    private func generateHTMLContent() -> String {
        let css = """
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                font-size: 16px;
                line-height: 1.6;
                margin: 16px;
                background-color: transparent;
            }
            * {
                max-width: 100%;
            }
            img {
                height: auto;
                border-radius: 8px;
            }
            pre {
                background-color: #f6f8fa;
                padding: 16px;
                border-radius: 8px;
                overflow-x: auto;
            }
            blockquote {
                border-left: 4px solid #007AFF;
                padding-left: 16px;
                margin-left: 0;
                font-style: italic;
            }
            table {
                width: 100%;
                border-collapse: collapse;
            }
            td, th {
                border: 1px solid #ddd;
                padding: 8px;
                text-align: left;
            }
            th {
                background-color: #f6f8fa;
                font-weight: bold;
            }
        </style>
        """
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \(css)
        </head>
        <body>
            \(block.content)
        </body>
        </html>
        """
    }
}

// MARK: - WebView Component

#if os(iOS) || os(visionOS)
struct WebView: UIViewRepresentable {
    let htmlContent: String
    @Binding var dynamicHeight: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        // Inject JavaScript to get content height
        let script = WKUserScript(
            source: """
                function updateHeight() {
                    window.webkit.messageHandlers.heightUpdate.postMessage(document.body.scrollHeight);
                }
                window.addEventListener('load', updateHeight);
                window.addEventListener('resize', updateHeight);
                new MutationObserver(updateHeight).observe(document.body, {childList: true, subtree: true});
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        
        webView.configuration.userContentController.add(context.coordinator, name: "heightUpdate")
        webView.configuration.userContentController.addUserScript(script)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightUpdate", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = max(height, 50)
                }
            }
        }
    }
}

#elseif os(macOS)
struct WebView: NSViewRepresentable {
    let htmlContent: String
    @Binding var dynamicHeight: CGFloat
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        
        let script = WKUserScript(
            source: """
                function updateHeight() {
                    window.webkit.messageHandlers.heightUpdate.postMessage(document.body.scrollHeight);
                }
                window.addEventListener('load', updateHeight);
                window.addEventListener('resize', updateHeight);
                new MutationObserver(updateHeight).observe(document.body, {childList: true, subtree: true});
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        
        webView.configuration.userContentController.add(context.coordinator, name: "heightUpdate")
        webView.configuration.userContentController.addUserScript(script)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightUpdate", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = max(height, 50)
                }
            }
        }
    }
}
#endif

// MARK: - Placeholder Block Renderers for New Types
// These are placeholder implementations that use the HTML fallback renderer

struct ButtonsBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct ButtonBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct ColumnsBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct ColumnBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct GalleryBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct VideoBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct AudioBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct TableBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct SpacerBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct GroupBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct CoverBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct EmbedBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

struct PullquoteBlockRenderer: View {
    let block: GutenbergBlock
    var body: some View { HTMLBlockRenderer(block: block) }
}

// MARK: - Block Support Detection

extension GutenbergBlock {
    var isNativeSupported: Bool {
        switch type {
        case .paragraph, .heading, .list, .quote, .code, .image, .separator:
            return true
        case .buttons, .button, .columns, .column, .gallery, .video, .audio, .table, .spacer, .group, .cover, .embed, .pullquote:
            return false // Use HTML renderer for advanced blocks for now
        case .unknown:
            return false
        }
    }
}