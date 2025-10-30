//
//  GutenbergWebView.swift
//  Quill
//
//  Created by Claude on 7/4/25.
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - Gutenberg WebView Editor

struct GutenbergWebView: View {
    @Bindable var post: Post
    let typeface: String
    let fontSize: Int
    let siteConfig: SiteConfiguration?
    @State private var webViewHeight: CGFloat = 600
    @State private var isLoading = false
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var webViewRef: WKWebView?
    @Environment(\.colorScheme) private var colorScheme

    private var editorBackgroundColor: Color {
        // Match the editor's background color exactly and respond to theme changes
        if colorScheme == .dark {
            return Color(red: 0x1e/255.0, green: 0x1e/255.0, blue: 0x1e/255.0) // #1e1e1e
        } else {
            return Color.white // #ffffff
        }
    }

    var body: some View {
        ZStack {
            GutenbergWebViewRepresentable(
                post: post,
                typeface: typeface,
                fontSize: fontSize,
                siteConfig: siteConfig,
                dynamicHeight: $webViewHeight,
                isLoading: $isLoading,
                hasError: $hasError,
                errorMessage: $errorMessage,
                webViewRef: $webViewRef
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isLoading ? 0 : 1)

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    Text("Loading editor...")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(editorBackgroundColor)
            }
        }
        .background(editorBackgroundColor)
        .onDisappear {
            // Save any pending changes when view disappears
            #if os(macOS)
            if let webView = webViewRef as? GutenbergWKWebView,
               let coordinator = webView.coordinator {
                coordinator.savePendingChanges()
            }
            #elseif os(iOS)
            // iOS doesn't have direct access to coordinator through webView
            // The coordinator will handle cleanup in its deinit
            #endif
        }
        .onChange(of: post.id) { _, newPostID in
            // When post selection changes, trigger a refresh to decode HTML entities
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Small delay to ensure WebView is ready and content is loaded
                refreshWebViewContent()
            }
        }
    }
    
    private func refreshWebViewContent() {
        guard let webView = webViewRef else { return }
        
        // Trigger a refresh of the WebView content with decoded HTML entities
        let decodedContent = HTMLHandler.shared.decodeHTMLEntitiesManually(post.content)
        let script = """
            if (window.gutenbergEditor) {
                window.gutenbergEditor.setContent(`\(decodedContent.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`);
            }
        """
        
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                DebugLogger.shared.log("Failed to refresh WebView content: \(error)", level: .error, source: "WebView")
            } else {
                DebugLogger.shared.log("Successfully refreshed WebView content with decoded entities", level: .info, source: "WebView")
            }
        }
    }
}

// MARK: - WebView Representable

#if os(iOS) || os(visionOS)
struct GutenbergWebViewRepresentable: UIViewRepresentable {
    @Bindable var post: Post
    let typeface: String
    let fontSize: Int
    let siteConfig: SiteConfiguration?
    @Binding var dynamicHeight: CGFloat
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var errorMessage: String
    @Binding var webViewRef: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        let coordinator = context.coordinator
        
        // Configure web view
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(coordinator, name: "contentUpdate")
        configuration.userContentController.add(coordinator, name: "heightUpdate")
        configuration.userContentController.add(coordinator, name: "editorReady")
        configuration.userContentController.add(coordinator, name: "editorError")
        configuration.userContentController.add(coordinator, name: "imageUpload")
        configuration.userContentController.add(coordinator, name: "requestImagePicker")
        configuration.userContentController.add(coordinator, name: "consoleLog")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        
        // Store webView reference for parent
        DispatchQueue.main.async {
            webViewRef = webView
        }
        
        // Load the Gutenberg editor
        loadGutenbergEditor(in: webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update content if post has changed
        context.coordinator.updateContent(post.content)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func loadGutenbergEditor(in webView: WKWebView) {
        let htmlContent = generateGutenbergHTML()
        webView.loadHTMLString(htmlContent, baseURL: Bundle.main.bundleURL)
    }
    
    private func generateGutenbergHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>Gutenberg Editor</title>
            <!-- Cache bust: v5.0 Professional blue link colors -->
            <style>
                :root {
                    --editor-font-family: \({
                        switch typeface {
                        case "system": return "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
                        case "sf-mono": return "'SF Mono', Monaco, 'Courier New', monospace"
                        case "georgia": return "Georgia, 'Times New Roman', serif"
                        case "verdana": return "Verdana, Geneva, sans-serif"
                        case "arial": return "Arial, Helvetica, sans-serif"
                        default: return "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
                        }
                    }());
                    --editor-font-size: \(fontSize)px;
                    
                    /* Light mode colors */
                    --bg-color: #ffffff;
                    --text-color: #000000;
                    --secondary-text: #666666;
                    --placeholder-color: #999999;
                    --link-color: #0066CC;
                    --code-bg: #f5f5f5;
                    --quote-border: #ddd;
                    --pullquote-border: #666;
                    --popover-bg: rgba(255, 255, 255, 0.95);
                    --popover-border: #0066CC;
                    --popover-shadow: rgba(0, 0, 0, 0.3);
                    --button-secondary-bg: rgba(0, 0, 0, 0.05);
                    --button-secondary-text: #333;
                    --input-border: rgba(0, 0, 0, 0.1);
                    --slash-menu-bg: rgba(255, 255, 255, 0.95);
                    --slash-menu-border: rgba(0, 0, 0, 0.1);
                    --slash-menu-shadow: rgba(0, 0, 0, 0.12);
                    --slash-menu-hover: rgba(0, 102, 204, 0.08);
                    --slash-menu-text: #1d1d1f;
                    --image-error-bg: #ffebee;
                    --image-error-text: #c62828;
                }
                
                @media (prefers-color-scheme: dark) {
                    :root {
                        /* Dark mode colors */
                        --bg-color: #1e1e1e;
                        --text-color: #ffffff;
                        --secondary-text: #999999;
                        --placeholder-color: #666666;
                        --link-color: #66B3FF;
                        --code-bg: #2d2d2d;
                        --quote-border: #555;
                        --pullquote-border: #999;
                        --popover-bg: rgba(40, 40, 40, 0.95);
                        --popover-border: #66B3FF;
                        --popover-shadow: rgba(0, 0, 0, 0.5);
                        --button-secondary-bg: rgba(255, 255, 255, 0.1);
                        --button-secondary-text: #ddd;
                        --input-border: rgba(255, 255, 255, 0.2);
                        --slash-menu-bg: rgba(40, 40, 40, 0.95);
                        --slash-menu-border: rgba(255, 255, 255, 0.2);
                        --slash-menu-shadow: rgba(0, 0, 0, 0.3);
                        --slash-menu-hover: rgba(102, 179, 255, 0.15);
                        --slash-menu-text: #ffffff;
                        --image-error-bg: #5c2828;
                        --image-error-text: #ff9999;
                    }
                }
                
                body {
                    margin: 0;
                    padding: 20px;
                    font-family: var(--editor-font-family);
                    font-size: var(--editor-font-size);
                    background-color: var(--bg-color);
                    color: var(--text-color);
                    overflow-x: hidden;
                }
                
                .editor-container {
                    max-width: 100%;
                    margin: 0 auto;
                    overflow-x: hidden;
                }
                
                .wp-block-editor__container {
                    background: var(--bg-color);
                    max-width: 100%;
                    overflow-x: hidden;
                }
                
                .block-editor-writing-flow {
                    height: auto !important;
                    max-width: 100%;
                    overflow-x: hidden;
                }
                
                /* Native-looking blocks without backgrounds */
                .wp-block {
                    margin: 0.25em 0;
                    position: relative;
                    padding: 2px;
                    border-radius: 4px;
                    transition: background-color 0.15s ease;
                    max-width: 100%;
                    box-sizing: border-box;
                }
                
                /* Remove hover background for more native feel */
                .wp-block:hover {
                    background-color: transparent;
                }
                
                .wp-block-content {
                    min-height: 1.5em;
                    font-family: var(--editor-font-family);
                    font-size: var(--editor-font-size);
                    line-height: 1.75;
                }
                
                .wp-block.is-focused .wp-block-content:empty:before {
                    content: "Type / for commands";
                    color: var(--placeholder-color);
                    font-style: italic;
                }
                
                /* Paragraph blocks with minimal spacing */
                .wp-block[data-type="core/paragraph"] {
                    margin: 0.2em 0;
                }
                
                .wp-block-content p {
                    margin: 0;
                    line-height: 1.75;
                }
                
                /* Heading blocks with reduced spacing */
                .wp-block[data-type="core/heading"] h1,
                .wp-block[data-type="core/heading"] h2,
                .wp-block[data-type="core/heading"] h3,
                .wp-block[data-type="core/heading"] h4,
                .wp-block[data-type="core/heading"] h5,
                .wp-block[data-type="core/heading"] h6 {
                    margin: 0.3em 0 0.2em 0;
                    font-family: var(--editor-font-family);
                    line-height: 1.35;
                }
                
                /* List blocks with improved line spacing */
                .wp-block-content ul,
                .wp-block-content ol {
                    margin: 0.2em 0;
                    line-height: 1.75;
                }
                
                .wp-block-content li {
                    line-height: 1.75;
                    margin: 0.1em 0;
                }
                
                /* Code blocks with line spacing */
                .wp-block-content pre {
                    line-height: 1.6;
                    margin: 0.3em 0;
                }
                
                /* Quote blocks with line spacing */
                .wp-block-content blockquote {
                    line-height: 1.75;
                    margin: 0.3em 0;
                }
                
                /* Link styles - v5.0 - Professional blue colors for visibility */
                a, 
                .wp-block-content a,
                .wp-block a,
                p a,
                div a,
                span a,
                [contenteditable] a {
                    color: #0066FF !important;
                    text-decoration: underline !important;
                    text-decoration-color: #0066FF !important;
                    border-bottom: none !important;
                    font-weight: 500 !important;
                    transition: color 0.2s ease !important;
                }
                
                @media (prefers-color-scheme: dark) {
                    a, 
                    .wp-block-content a,
                    .wp-block a,
                    p a,
                    div a,
                    span a,
                    [contenteditable] a {
                        color: #4DA6FF !important;
                        text-decoration-color: #4DA6FF !important;
                    }
                }
                
                a:hover, 
                .wp-block-content a:hover,
                .wp-block a:hover,
                p a:hover,
                div a:hover,
                span a:hover,
                [contenteditable] a:hover {
                    color: #0052CC !important;
                    text-decoration-color: #0052CC !important;
                }
                
                @media (prefers-color-scheme: dark) {
                    a:hover, 
                    .wp-block-content a:hover,
                    .wp-block a:hover,
                    p a:hover,
                    div a:hover,
                    span a:hover,
                    [contenteditable] a:hover {
                        color: #66B3FF !important;
                        text-decoration-color: #66B3FF !important;
                    }
                }
                
                /* Link popover styles */
                .link-popover {
                    position: fixed;
                    background: var(--popover-bg);
                    border: 2px solid var(--popover-border);
                    border-radius: 8px;
                    box-shadow: 0 8px 32px var(--popover-shadow);
                    padding: 12px;
                    z-index: 999999;
                    min-width: 300px;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
                    display: block !important;
                    visibility: visible !important;
                    opacity: 1 !important;
                }
                
                .link-popover input {
                    width: 100%;
                    padding: 8px 12px;
                    border: 1px solid var(--input-border);
                    border-radius: 6px;
                    font-size: 14px;
                    outline: none;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
                    background: var(--bg-color);
                    color: var(--text-color);
                }
                
                .link-popover input:focus {
                    border-color: var(--link-color);
                    box-shadow: 0 0 0 3px rgba(74, 158, 255, 0.1);
                }
                
                .link-popover-buttons {
                    display: flex;
                    gap: 8px;
                    margin-top: 8px;
                    justify-content: flex-end;
                }
                
                .link-popover button {
                    padding: 6px 12px;
                    border: none;
                    border-radius: 6px;
                    font-size: 13px;
                    cursor: pointer;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
                }
                
                .link-popover button.primary {
                    background: var(--link-color);
                    color: white;
                }
                
                .link-popover button.secondary {
                    background: var(--button-secondary-bg);
                    color: var(--button-secondary-text);
                }
                
                .link-popover button:hover {
                    opacity: 0.9;
                }
                
                /* Image blocks with reduced spacing */
                .wp-block[data-type="image"] figure {
                    margin: 0.4em 0;
                    text-align: center;
                }
                
                .wp-block[data-type="image"] img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 4px;
                }
                
                /* WordPress-style image blocks */
                .wp-block-image {
                    margin: 0.4em 0;
                    max-width: 100%;
                    box-sizing: border-box;
                    overflow: hidden;
                }
                
                .wp-block-image figure {
                    margin: 0;
                    max-width: 100%;
                    width: 100%;
                    box-sizing: border-box;
                }
                
                .wp-block-image img {
                    max-width: 100%;
                    width: auto;
                    height: auto;
                    display: block;
                    border-radius: 4px;
                    box-sizing: border-box;
                }
                
                /* Ensure all figure elements are constrained */
                figure {
                    max-width: 100%;
                    margin: 0;
                    box-sizing: border-box;
                }
                
                /* Ensure all images in the editor are constrained */
                .block-editor-writing-flow img {
                    max-width: 100% !important;
                    height: auto !important;
                }
                
                .image-loading {
                    position: relative;
                    padding: 40px;
                    text-align: center;
                    color: #666;
                    background: #f5f5f5;
                    border-radius: 4px;
                    font-style: italic;
                    min-height: 200px;
                }
                
                /* Remove focus outlines */
                .wp-block.is-focused {
                    outline: none;
                }
                
                /* Native macOS-style slash command menu */
                .slash-command-menu {
                    position: fixed;
                    background: rgba(255, 255, 255, 0.95);
                    backdrop-filter: blur(20px);
                    border: 1px solid rgba(0, 0, 0, 0.1);
                    border-radius: 8px;
                    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
                    padding: 4px 0;
                    z-index: 1000;
                    min-width: 240px;
                    max-height: none;
                    overflow: visible;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
                }
                
                .slash-command-item {
                    padding: 8px 16px;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    font-size: 13px;
                    color: #1d1d1f;
                    transition: background-color 0.1s ease;
                }
                
                .slash-command-item:hover {
                    background-color: rgba(0, 122, 255, 0.08);
                }
                
                .slash-command-item:first-child {
                    margin-top: 4px;
                }
                
                .slash-command-item:last-child {
                    margin-bottom: 4px;
                }
                
                .loading {
                    text-align: center;
                    padding: 40px;
                    color: #666;
                }
                
                .error {
                    text-align: center;
                    padding: 40px;
                    color: #d32f2f;
                    background-color: #ffebee;
                    border-radius: 8px;
                    margin: 20px;
                }
            </style>
        </head>
        <body>
            <div class="editor-container">
                <div id="gutenberg-editor" class="loading">
                    Loading Gutenberg Editor...
                </div>
            </div>
            
            <script>
                // Gutenberg Editor Implementation
                class GutenbergEditor {
                    constructor() {
                        console.log('GutenbergEditor: Constructor called');
                        this.content = `\(HTMLHandler.shared.decodeHTMLEntitiesManually(post.content).replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`;
                        this.blocks = [];
                        this.shouldAutoFocus = false; // Don't auto-focus on initial load
                        this.hasUserInteracted = false;
                        console.log('GutenbergEditor: About to call init()');
                        this.init();
                    }
                    
                    init() {
                        console.log('GutenbergEditor: init() called');
                        try {
                            console.log('GutenbergEditor: calling setupEditor()');
                            this.setupEditor();
                            console.log('GutenbergEditor: calling parseContent()');
                            this.parseContent();
                            console.log('GutenbergEditor: calling render()');
                            this.render();
                            console.log('GutenbergEditor: calling notifyReady()');
                            this.notifyReady();
                            console.log('GutenbergEditor: Initialization complete');
                        } catch (error) {
                            console.error('GutenbergEditor: Initialization error:', error);
                            this.handleError(error);
                        }
                    }
                    
                    setupEditor() {
                        this.container = document.getElementById('gutenberg-editor');
                        this.container.className = 'wp-block-editor__container';
                        this.container.innerHTML = '';
                        
                        // Create blocks container
                        this.blocksContainer = document.createElement('div');
                        this.blocksContainer.className = 'block-editor-writing-flow';
                        this.blocksContainer.style.minHeight = '200px';
                        this.blocksContainer.contentEditable = true;
                        this.blocksContainer.style.outline = 'none';
                        
                        this.container.appendChild(this.blocksContainer);
                        
                        // Setup slash command state
                        this.showingSlashCommands = false;
                        this.slashCommandMenu = null;
                        this.currentBlock = null;
                        this.handlingBackspace = false;
                        this.justHidSlashCommands = false;
                        
                        // Add unified event listeners to blocks container
                        this.setupContainerEventListeners();
                        
                        // Setup mutation observer for height changes
                        this.setupHeightObserver();
                    }
                    
                    setupContainerEventListeners() {
                        // Handle input events at container level
                        this.blocksContainer.addEventListener('input', (e) => {
                            // First check if the DOM structure has been altered (multi-block edit)
                            if (this.needsBlockStructureSync()) {
                                this.syncBlocksFromDOM();
                                return; // Let the sync handle the update
                            }
                            
                            const blockElement = this.findBlockElementFromEvent(e);
                            if (blockElement) {
                                const blockId = blockElement.getAttribute('data-block-id');
                                const block = this.blocks.find(b => b.id === blockId);
                                if (block) {
                                    window.webkit.messageHandlers.editorError.postMessage(`INPUT event: blockId="${blockId}", target="${e.target.className}", showingSlash=${this.showingSlashCommands}`);
                                    this.handleBlockInput(e, block);
                                } else {
                                    window.webkit.messageHandlers.editorError.postMessage(`INPUT event: No block found for blockId="${blockId}"`);
                                }
                            } else {
                                window.webkit.messageHandlers.editorError.postMessage(`INPUT event: No block element found from target "${e.target.className}"`);
                            }
                        });
                        
                        // Handle keydown events at container level
                        this.blocksContainer.addEventListener('keydown', (e) => {
                            const blockElement = this.findBlockElementFromEvent(e);
                            if (blockElement) {
                                const blockIndex = parseInt(blockElement.getAttribute('data-block-index'));
                                window.webkit.messageHandlers.editorError.postMessage(`KEYDOWN event: key="${e.key}", text="${e.target.innerText}", showingSlash=${this.showingSlashCommands}`);
                                this.handleKeyDown(e, blockIndex);
                            }
                        });
                        
                        // Handle selection changes to update current block
                        document.addEventListener('selectionchange', () => {
                            const selection = window.getSelection();
                            if (selection.rangeCount > 0) {
                                const range = selection.getRangeAt(0);
                                const blockElement = this.findBlockElementFromNode(range.startContainer);
                                if (blockElement) {
                                    const blockId = blockElement.getAttribute('data-block-id');
                                    this.setCurrentBlock(blockId);
                                }
                            }
                        });
                        
                        // Handle clicks to update current block
                        this.blocksContainer.addEventListener('click', (e) => {
                            // Mark that user has interacted with the editor
                            if (!this.hasUserInteracted) {
                                this.hasUserInteracted = true;
                                this.shouldAutoFocus = true;
                            }
                            
                            const blockElement = this.findBlockElementFromEvent(e);
                            if (blockElement) {
                                const blockId = blockElement.getAttribute('data-block-id');
                                this.setCurrentBlock(blockId);
                                
                                // Don't call focusBlock here - let the browser handle natural cursor placement
                                // focusBlock always moves cursor to end, which interferes with clicking at specific positions
                            }
                        });
                        
                        // Handle focus events to detect user interaction
                        this.blocksContainer.addEventListener('focus', (e) => {
                            if (!this.hasUserInteracted) {
                                this.hasUserInteracted = true;
                                this.shouldAutoFocus = true;
                            }
                        }, true);
                    }
                    
                    findBlockElementFromEvent(event) {
                        let element = event.target;
                        
                        // If the target is the container itself, try to find the focused block
                        if (element === this.blocksContainer) {
                            const selection = window.getSelection();
                            if (selection.rangeCount > 0) {
                                const range = selection.getRangeAt(0);
                                element = range.startContainer.nodeType === Node.TEXT_NODE 
                                    ? range.startContainer.parentElement 
                                    : range.startContainer;
                            }
                        }
                        
                        while (element && element !== this.blocksContainer && !element.classList.contains('wp-block')) {
                            element = element.parentElement;
                        }
                        
                        return element && element.classList.contains('wp-block') ? element : null;
                    }
                    
                    findBlockElementFromNode(node) {
                        let element = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
                        while (element && !element.classList.contains('wp-block')) {
                            element = element.parentElement;
                        }
                        return element;
                    }
                    
                    needsBlockStructureSync() {
                        // Check if the number of block elements in DOM matches our internal blocks array
                        const domBlocks = this.blocksContainer.querySelectorAll('.wp-block');
                        return domBlocks.length !== this.blocks.length;
                    }
                    
                    syncBlocksFromDOM() {
                        window.webkit.messageHandlers.editorError.postMessage('Syncing blocks from DOM due to structure change');
                        
                        // Save current selection/cursor position
                        const selection = window.getSelection();
                        let cursorInfo = null;
                        
                        if (selection.rangeCount > 0) {
                            const range = selection.getRangeAt(0);
                            const blockElement = this.findBlockElementFromNode(range.startContainer);
                            
                            if (blockElement) {
                                const blockIndex = Array.from(this.blocksContainer.children).indexOf(blockElement);
                                const contentElement = blockElement.querySelector('.wp-block-content');
                                
                                if (contentElement) {
                                    // Calculate offset within the block
                                    const preCaretRange = range.cloneRange();
                                    preCaretRange.selectNodeContents(contentElement);
                                    preCaretRange.setEnd(range.endContainer, range.endOffset);
                                    const offset = preCaretRange.toString().length;
                                    
                                    cursorInfo = {
                                        blockIndex: blockIndex,
                                        offset: offset,
                                        collapsed: range.collapsed
                                    };
                                }
                            }
                        }
                        
                        const domBlocks = this.blocksContainer.querySelectorAll('.wp-block');
                        const newBlocks = [];
                        
                        domBlocks.forEach((blockElement, index) => {
                            const contentElement = blockElement.querySelector('.wp-block-content');
                            if (contentElement) {
                                const blockId = blockElement.getAttribute('data-block-id');
                                const existingBlock = this.blocks.find(b => b.id === blockId);
                                
                                if (existingBlock) {
                                    // Update existing block with current content
                                    existingBlock.content = contentElement.innerHTML;
                                    newBlocks.push(existingBlock);
                                } else {
                                    // Create new block from DOM element
                                    const tagName = contentElement.tagName.toLowerCase();
                                    let blockType = 'paragraph';
                                    
                                    // Determine block type from tag
                                    switch (tagName) {
                                        case 'h1': blockType = 'heading-1'; break;
                                        case 'h2': blockType = 'heading-2'; break;
                                        case 'h3': blockType = 'heading-3'; break;
                                        case 'pre': blockType = 'code'; break;
                                        case 'blockquote': blockType = 'quote'; break;
                                        case 'ul': blockType = 'list'; break;
                                        case 'ol': blockType = 'ordered-list'; break;
                                    }
                                    
                                    newBlocks.push({
                                        id: this.generateBlockId(),
                                        type: blockType,
                                        content: contentElement.innerHTML,
                                        attributes: {}
                                    });
                                }
                            }
                        });
                        
                        // Update internal blocks array
                        this.blocks = newBlocks;
                        
                        // Instead of full re-render, just update block attributes
                        this.updateBlockAttributes();
                        
                        // Restore cursor position if we had one
                        if (cursorInfo && cursorInfo.blockIndex < this.blocksContainer.children.length) {
                            const blockElement = this.blocksContainer.children[cursorInfo.blockIndex];
                            const contentElement = blockElement.querySelector('.wp-block-content');
                            
                            if (contentElement) {
                                // Focus the container first
                                this.blocksContainer.focus();
                                
                                // Set cursor at the saved position
                                const textNode = this.getTextNodeAtOffset(contentElement, cursorInfo.offset);
                                if (textNode.node) {
                                    const range = document.createRange();
                                    range.setStart(textNode.node, textNode.offset);
                                    range.collapse(true);
                                    
                                    const sel = window.getSelection();
                                    sel.removeAllRanges();
                                    sel.addRange(range);
                                }
                                
                                // Check if we need to show slash commands after sync
                                const text = contentElement.innerText.trim();
                                if (text === '/') {
                                    const block = this.blocks[cursorInfo.blockIndex];
                                    if (block) {
                                        window.webkit.messageHandlers.editorError.postMessage(`Showing slash commands after sync for block ${cursorInfo.blockIndex}`);
                                        this.showSlashCommands(cursorInfo.blockIndex);
                                    }
                                }
                            }
                        }
                        
                        // Notify of content change
                        this.handleContentChange();
                    }
                    
                    getTextNodeAtOffset(element, offset) {
                        let currentOffset = 0;
                        let targetNode = null;
                        let targetOffset = 0;
                        
                        const walk = (node) => {
                            if (node.nodeType === Node.TEXT_NODE) {
                                const length = node.textContent.length;
                                if (currentOffset + length >= offset) {
                                    targetNode = node;
                                    targetOffset = offset - currentOffset;
                                    return true;
                                }
                                currentOffset += length;
                            } else if (node.nodeType === Node.ELEMENT_NODE) {
                                for (let child of node.childNodes) {
                                    if (walk(child)) return true;
                                }
                            }
                            return false;
                        };
                        
                        walk(element);
                        
                        // If we didn't find a text node, try to use the last available position
                        if (!targetNode && element.lastChild) {
                            if (element.lastChild.nodeType === Node.TEXT_NODE) {
                                targetNode = element.lastChild;
                                targetOffset = element.lastChild.textContent.length;
                            } else {
                                // Create a text node if needed
                                targetNode = document.createTextNode('');
                                element.appendChild(targetNode);
                                targetOffset = 0;
                            }
                        }
                        
                        return { node: targetNode, offset: targetOffset };
                    }
                    
                    updateBlockAttributes() {
                        // Update block attributes without re-rendering
                        const domBlocks = this.blocksContainer.querySelectorAll('.wp-block');
                        
                        domBlocks.forEach((blockElement, index) => {
                            if (index < this.blocks.length) {
                                const block = this.blocks[index];
                                blockElement.setAttribute('data-block-id', block.id);
                                blockElement.setAttribute('data-block-index', index);
                                blockElement.setAttribute('data-block-type', block.type);
                            }
                        });
                    }
                    
                    parseContent() {
                        if (!this.content || this.content.trim() === '') {
                            this.blocks = [{
                                id: this.generateBlockId(),
                                type: 'paragraph',
                                content: '',
                                attributes: {}
                            }];
                            return;
                        }
                        
                        // Parse HTML content into blocks
                        this.blocks = this.parseHTMLToBlocks(this.content);
                        
                        if (this.blocks.length === 0) {
                            this.blocks = [{
                                id: this.generateBlockId(),
                                type: 'paragraph',
                                content: '',
                                attributes: {}
                            }];
                        }
                    }
                    
                    render() {
                        // Save current block before clearing
                        const previousCurrentBlock = this.currentBlock;
                        
                        this.blocksContainer.innerHTML = '';
                        
                        this.blocks.forEach((block, index) => {
                            const blockElement = this.createBlockElement(block, index);
                            this.blocksContainer.appendChild(blockElement);
                        });
                        
                        // Only restore focus if user has interacted with the editor
                        if (this.hasUserInteracted) {
                            if (previousCurrentBlock) {
                                const blockIndex = this.blocks.findIndex(b => b.id === previousCurrentBlock);
                                if (blockIndex >= 0) {
                                    this.focusBlock(blockIndex);
                                } else if (this.blocks.length > 0 && this.shouldAutoFocus) {
                                    this.focusBlock(0);
                                }
                            } else if (this.blocks.length > 0 && this.shouldAutoFocus) {
                                this.focusBlock(0);
                            }
                        }
                    }
                    
                    handleContentChange() {
                        // Serialize blocks to WordPress format with block comments
                        const wpContent = this.serializeBlocksToWordPress();
                        
                        const text = this.blocks.map(block => {
                            const tempDiv = document.createElement('div');
                            tempDiv.innerHTML = block.content;
                            return tempDiv.textContent || tempDiv.innerText || '';
                        }).join('\\n\\n');
                        
                        // Update content with WordPress formatted blocks
                        this.content = wpContent;
                        
                        // Notify native app with WordPress formatted content
                        this.notifyContentUpdate(wpContent);
                        this.updateHeight();
                    }
                    
                    serializeBlocksToWordPress() {
                        return this.blocks.map(block => {
                            let blockName = '';
                            let attrs = '';
                            
                            // Map block types to WordPress block names
                            switch (block.type) {
                                case 'paragraph':
                                    blockName = 'paragraph';
                                    break;
                                case 'heading-1':
                                    blockName = 'heading';
                                    attrs = ' {"level":1}';
                                    break;
                                case 'heading-2':
                                    blockName = 'heading';
                                    attrs = ' {"level":2}';
                                    break;
                                case 'heading-3':
                                    blockName = 'heading';
                                    attrs = ' {"level":3}';
                                    break;
                                case 'heading-4':
                                    blockName = 'heading';
                                    attrs = ' {"level":4}';
                                    break;
                                case 'heading-5':
                                    blockName = 'heading';
                                    attrs = ' {"level":5}';
                                    break;
                                case 'heading-6':
                                    blockName = 'heading';
                                    attrs = ' {"level":6}';
                                    break;
                                case 'list':
                                    blockName = 'list';
                                    break;
                                case 'ordered-list':
                                    blockName = 'list';
                                    attrs = ' {"ordered":true}';
                                    break;
                                case 'quote':
                                    blockName = 'quote';
                                    break;
                                case 'pullquote':
                                    blockName = 'pullquote';
                                    break;
                                case 'code':
                                    blockName = 'code';
                                    break;
                                case 'image':
                                    blockName = 'image';
                                    if (block.attributes && block.attributes.id) {
                                        attrs = ` {"id":${block.attributes.id}}`;
                                    }
                                    break;
                                default:
                                    blockName = 'paragraph';
                            }
                            
                            // Get appropriate HTML tag for content
                            const tagName = this.getBlockTagName(block.type);
                            const content = `<${tagName}>${block.content}</${tagName}>`;
                            
                            // Return WordPress block format with comments
                            return `<!-- wp:${blockName}${attrs} -->\n${content}\n<!-- /wp:${blockName} -->`;
                        }).join('\\n\\n');
                    }
                    
                    handleKeyDown(event, blockIndex) {
                        window.webkit.messageHandlers.editorError.postMessage(`KeyDown event: key="${event.key}", metaKey=${event.metaKey}, ctrlKey=${event.ctrlKey}, showingSlashCommands: ${this.showingSlashCommands}`);
                        
                        // Handle Cmd+K for links before other key handling
                        if (event.key === 'k' && (event.metaKey || event.ctrlKey) && !event.shiftKey) {
                            event.preventDefault();
                            event.stopPropagation();
                            window.webkit.messageHandlers.editorError.postMessage(`Cmd+K detected, showing link popover for block ${blockIndex}`);
                            this.showLinkPopover(blockIndex);
                            return;
                        }
                        
                        // Handle text formatting shortcuts (Cmd+B, Cmd+I, Cmd+U)
                        if ((event.metaKey || event.ctrlKey) && !event.shiftKey && !event.altKey) {
                            let handled = false;
                            switch (event.key.toLowerCase()) {
                                case 'b':
                                    event.preventDefault();
                                    document.execCommand('bold', false, null);
                                    handled = true;
                                    break;
                                case 'i':
                                    event.preventDefault();
                                    document.execCommand('italic', false, null);
                                    handled = true;
                                    break;
                                case 'u':
                                    event.preventDefault();
                                    document.execCommand('underline', false, null);
                                    handled = true;
                                    break;
                            }
                            
                            if (handled) {
                                // Trigger content update after formatting
                                this.handleContentChange();
                                return;
                            }
                        }
                        
                        if (this.showingSlashCommands) {
                            this.handleSlashCommandKeydown(event);
                            return;
                        }
                        
                        const block = this.blocks[blockIndex];
                        
                        switch (event.key) {
                            case 'Enter':
                                if (!event.shiftKey) {
                                    event.preventDefault();
                                    this.handleEnterKey(blockIndex);
                                } else {
                                    // Shift+Enter always creates a new block, even in lists
                                    event.preventDefault();
                                    const newBlock = {
                                        id: this.generateBlockId(),
                                        type: 'paragraph',
                                        content: '',
                                        attributes: {}
                                    };
                                    
                                    this.blocks.splice(blockIndex + 1, 0, newBlock);
                                    this.render();
                                    this.focusBlock(blockIndex + 1);
                                }
                                break;
                            case 'Backspace':
                                // Handle slash menu hiding FIRST before any other processing
                                if (this.showingSlashCommands) {
                                    const element = event.target;
                                    const text = element.innerText;
                                    window.webkit.messageHandlers.editorError.postMessage(`Backspace with slash menu visible. Text: "${text}"`);
                                    
                                    // Prevent default AND stop propagation to prevent input event
                                    event.preventDefault();
                                    event.stopPropagation();
                                    event.stopImmediatePropagation();
                                    
                                    // Hide slash commands immediately
                                    this.hideSlashCommands();
                                    this.justHidSlashCommands = true;
                                    
                                    // Manually handle the backspace
                                    const selection = window.getSelection();
                                    const range = selection.getRangeAt(0);
                                    
                                    if (range.startOffset > 0) {
                                        // Delete the character before the cursor
                                        range.setStart(range.startContainer, range.startOffset - 1);
                                        range.deleteContents();
                                        
                                        // Update the block content
                                        const newContent = element.innerHTML;
                                        this.blocks[blockIndex].content = newContent;
                                        
                                        // Manually trigger content change without going through input handler
                                        this.handleContentChange();
                                    }
                                    
                                    window.webkit.messageHandlers.editorError.postMessage('Slash menu hidden and backspace handled manually');
                                    return;
                                }
                                
                                // Handle normal backspace behavior
                                this.handleBackspaceKey(event, blockIndex);
                                break;
                            case 'ArrowUp':
                                if (this.isAtBlockStart(blockIndex)) {
                                    this.focusBlock(blockIndex - 1);
                                    event.preventDefault();
                                }
                                break;
                            case 'ArrowDown':
                                if (this.isAtBlockEnd(blockIndex)) {
                                    this.focusBlock(blockIndex + 1);
                                    event.preventDefault();
                                }
                                break;
                            case '/':
                                // Slash command detection is handled in handleBlockInput
                                break;
                        }
                    }
                    
                    // Block Management Methods
                    generateBlockId() {
                        return 'block-' + Math.random().toString(36).substr(2, 9);
                    }
                    
                    createBlockElement(block, index) {
                        const blockElement = document.createElement('div');
                        blockElement.className = 'wp-block';
                        blockElement.setAttribute('data-block-id', block.id);
                        blockElement.setAttribute('data-block-type', block.type);
                        blockElement.setAttribute('data-block-index', index);
                        
                        const contentElement = this.createContentElement(block);
                        blockElement.appendChild(contentElement);
                        
                        // Add click handler for image blocks
                        if (block.type === 'image') {
                            blockElement.style.cursor = 'pointer';
                            blockElement.tabIndex = 0; // Make it focusable
                            blockElement.addEventListener('click', (e) => {
                                e.preventDefault();
                                e.stopPropagation();
                                
                                // Set this as the current block index
                                this.currentBlockIndex = index;
                                this.setCurrentBlock(block.id);
                                
                                // Focus the block element itself
                                blockElement.focus();
                                
                                window.webkit.messageHandlers.editorError.postMessage(`Image block clicked: ${block.id}, index: ${index}`);
                            });
                            
                            // Handle keyboard events on the image block
                            blockElement.addEventListener('keydown', (e) => {
                                if (e.key === 'Enter') {
                                    e.preventDefault();
                                    this.handleEnterKey(index);
                                }
                            });
                        }
                        
                        return blockElement;
                    }
                    
                    createContentElement(block) {
                        const element = document.createElement(this.getBlockTagName(block.type));
                        element.className = 'wp-block-content';
                        element.style.outline = 'none';
                        
                        // Special handling for different block types
                        if (block.type === 'image') {
                            // Image blocks are not editable
                            element.contentEditable = 'false';
                            if (block.attributes.uploading) {
                                element.innerHTML = block.content || '<div class="image-loading">Uploading image...</div>';
                            } else {
                                element.innerHTML = block.content || '';
                            }
                            // Add wp-block-image class for proper styling
                            element.className += ' wp-block-image';
                        } else if (block.type === 'list' || block.type === 'ordered-list') {
                            element.innerHTML = block.content || '<li></li>';
                            
                            // List-specific setup for first item focus
                            if (block.type === 'list' || block.type === 'ordered-list') {
                                // Focus handling is now managed at container level
                                this.setCurrentBlock(block.id);
                            }
                        } else {
                            element.innerHTML = block.content || '';
                            // Focus handling is now managed at container level
                        }
                        
                        // Apply block-specific attributes
                        this.applyBlockAttributes(element, block);
                        
                        // Individual block event listeners are now handled at container level
                        
                        return element;
                    }
                    
                    getBlockTagName(type) {
                        const tags = {
                            'paragraph': 'p',
                            'heading': 'h2',
                            'heading-1': 'h1',
                            'heading-2': 'h2', 
                            'heading-3': 'h3',
                            'heading-4': 'h4',
                            'heading-5': 'h5',
                            'heading-6': 'h6',
                            'code': 'pre',
                            'quote': 'blockquote',
                            'pullquote': 'blockquote',
                            'list': 'ul',
                            'ordered-list': 'ol',
                            'image': 'figure'
                        };
                        return tags[type] || 'p';
                    }
                    
                    applyBlockAttributes(element, block) {
                        switch (block.type) {
                            case 'code':
                                element.style.backgroundColor = 'var(--code-bg)';
                                element.style.padding = '1em';
                                element.style.fontFamily = 'monospace';
                                element.style.borderRadius = '4px';
                                break;
                            case 'pullquote':
                                element.style.fontSize = '1.5em';
                                element.style.fontStyle = 'italic';
                                element.style.textAlign = 'center';
                                element.style.padding = '1.5em 1em';
                                element.style.borderLeft = '4px solid var(--pullquote-border)';
                                break;
                            case 'quote':
                                element.style.borderLeft = '4px solid var(--quote-border)';
                                element.style.paddingLeft = '1em';
                                element.style.fontStyle = 'italic';
                                break;
                            case 'list':
                            case 'ordered-list':
                                element.style.paddingLeft = '1.5em';
                                element.style.margin = '0.2em 0';
                                break;
                        }
                    }
                    
                    handleBlockInput(event, block) {
                        const blockIndex = this.getBlockIndex(block.id);
                        
                        // Find the block content element
                        const blockElement = this.findBlockElementFromEvent(event);
                        const contentElement = blockElement ? blockElement.querySelector('.wp-block-content') : null;
                        
                        if (!contentElement) return;
                        
                        const content = contentElement.innerHTML;
                        
                        // Update block content
                        this.blocks[blockIndex].content = content;
                        
                        // Skip slash command processing if we just hid slash commands via backspace
                        if (this.justHidSlashCommands) {
                            this.justHidSlashCommands = false;
                            this.handleContentChange();
                            return;
                        }
                        
                        // Handle slash commands
                        const text = contentElement.innerText;
                        if (text.startsWith('/')) {
                            if (text.length === 1) {
                                // Show slash commands when text is exactly '/'
                                this.showSlashCommands(blockIndex);
                            } else {
                                // Filter slash commands when text is '/something'
                                this.filterSlashCommands(text.substring(1), blockIndex);
                            }
                        } else if (this.showingSlashCommands) {
                            // Hide slash commands when text doesn't start with '/'
                            this.hideSlashCommands();
                        }
                        
                        this.handleContentChange();
                    }
                    
                    getBlockIndex(blockId) {
                        return this.blocks.findIndex(block => block.id === blockId);
                    }
                    
                    setCurrentBlock(blockId) {
                        // Remove is-focused class from all blocks
                        const allBlocks = this.blocksContainer.querySelectorAll('.wp-block');
                        allBlocks.forEach(block => block.classList.remove('is-focused'));
                        
                        // Add is-focused class to the current block
                        if (blockId) {
                            const blockElement = this.blocksContainer.querySelector(`[data-block-id="${blockId}"]`);
                            if (blockElement) {
                                blockElement.classList.add('is-focused');
                                window.webkit.messageHandlers.editorError.postMessage(`Set focus to block: ${blockId}, has is-focused: ${blockElement.classList.contains('is-focused')}`);
                            }
                        }
                        
                        this.currentBlock = blockId;
                    }
                    
                    focusBlock(index) {
                        if (index >= 0 && index < this.blocks.length) {
                            const blockElement = this.blocksContainer.children[index];
                            const contentElement = blockElement.querySelector('.wp-block-content');
                            const block = this.blocks[index];
                            
                            if (contentElement) {
                                // Update current block
                                const blockId = blockElement.getAttribute('data-block-id');
                                this.setCurrentBlock(blockId);
                                
                                // Skip cursor placement for non-editable blocks
                                if (block.type === 'image') {
                                    // Just set focus to container, don't try to place cursor
                                    this.blocksContainer.focus();
                                } else {
                                    // Focus the container first
                                    this.blocksContainer.focus();
                                    // Place cursor at end of the block
                                    const range = document.createRange();
                                    const sel = window.getSelection();
                                    range.selectNodeContents(contentElement);
                                    range.collapse(false);
                                    sel.removeAllRanges();
                                    sel.addRange(range);
                                }
                            }
                        }
                    }
                    
                    handleEnterKey(blockIndex) {
                        const block = this.blocks[blockIndex];
                        
                        // Special handling for image blocks - always create new paragraph below
                        if (block.type === 'image') {
                            const newBlock = {
                                id: this.generateBlockId(),
                                type: 'paragraph',
                                content: '',
                                attributes: {}
                            };
                            
                            this.blocks.splice(blockIndex + 1, 0, newBlock);
                            this.render();
                            this.focusBlock(blockIndex + 1);
                            this.handleContentChange();
                            return;
                        }
                        
                        // Special handling for list blocks
                        if (block.type === 'list' || block.type === 'ordered-list') {
                            const selection = window.getSelection();
                            const anchorNode = selection.anchorNode;
                            
                            // Find the current list item
                            let currentLi = anchorNode;
                            while (currentLi && currentLi.tagName !== 'LI') {
                                currentLi = currentLi.parentNode;
                            }
                            
                            if (currentLi) {
                                const liContent = currentLi.textContent.trim();
                                
                                // If current list item is empty, exit the list
                                if (liContent === '') {
                                    // Remove the empty list item
                                    currentLi.remove();
                                    
                                    // Update block content
                                    const blockElement = this.blocksContainer.children[blockIndex].querySelector('.wp-block-content');
                                    block.content = blockElement.innerHTML;
                                    
                                    // Create new paragraph block
                                    const newBlock = {
                                        id: this.generateBlockId(),
                                        type: 'paragraph',
                                        content: '',
                                        attributes: {}
                                    };
                                    
                                    this.blocks.splice(blockIndex + 1, 0, newBlock);
                                    this.render();
                                    this.focusBlock(blockIndex + 1);
                                    return;
                                }
                                
                                // If current list item has content, create new list item
                                const newLi = document.createElement('li');
                                newLi.innerHTML = '';
                                
                                // Insert after current list item
                                currentLi.parentNode.insertBefore(newLi, currentLi.nextSibling);
                                
                                // Update block content
                                const blockElement = this.blocksContainer.children[blockIndex].querySelector('.wp-block-content');
                                block.content = blockElement.innerHTML;
                                
                                // Focus the new list item
                                const range = document.createRange();
                                const sel = window.getSelection();
                                range.setStart(newLi, 0);
                                range.collapse(true);
                                sel.removeAllRanges();
                                sel.addRange(range);
                                
                                // Update content
                                this.handleContentChange();
                                return;
                            }
                        }
                        
                        // Default behavior for non-list blocks
                        const newBlock = {
                            id: this.generateBlockId(),
                            type: 'paragraph',
                            content: '',
                            attributes: {}
                        };
                        
                        this.blocks.splice(blockIndex + 1, 0, newBlock);
                        this.render();
                        this.focusBlock(blockIndex + 1);
                    }
                    
                    handleBackspaceKey(event, blockIndex) {
                        const block = this.blocks[blockIndex];
                        const element = event.target;
                        
                        // Only handle block deletion if:
                        // 1. Block is empty 
                        // 2. Not the first block
                        // 3. Cursor is at the beginning of the block
                        const selection = window.getSelection();
                        const isAtStart = selection.anchorOffset === 0;
                        
                        if (this.isBlockEmpty(blockIndex) && blockIndex > 0 && isAtStart) {
                            event.preventDefault();
                            this.deleteBlock(blockIndex);
                            this.focusBlock(blockIndex - 1);
                        }
                    }
                    
                    isBlockEmpty(blockIndex) {
                        const block = this.blocks[blockIndex];
                        return !block.content || block.content.trim() === '';
                    }
                    
                    isAtBlockStart(blockIndex) {
                        const selection = window.getSelection();
                        return selection.anchorOffset === 0;
                    }
                    
                    isAtBlockEnd(blockIndex) {
                        const selection = window.getSelection();
                        const element = selection.anchorNode;
                        return selection.anchorOffset === element.textContent.length;
                    }
                    
                    deleteBlock(blockIndex) {
                        if (this.blocks.length > 1) {
                            this.blocks.splice(blockIndex, 1);
                            this.render();
                            this.handleContentChange();
                        }
                    }
                    
                    // Slash Commands System
                    showSlashCommands(blockIndex) {
                        window.webkit.messageHandlers.editorError.postMessage(`showSlashCommands called for block ${blockIndex}`);
                        this.showingSlashCommands = true;
                        this.currentBlockIndex = blockIndex;
                        this.createSlashCommandMenu(blockIndex);
                        window.webkit.messageHandlers.editorError.postMessage(`showSlashCommands completed, showingSlashCommands: ${this.showingSlashCommands}`);
                    }
                    
                    createSlashCommandMenu(blockIndex) {
                        // Remove existing menu if it exists, but don't reset showingSlashCommands flag
                        if (this.slashCommandMenu) {
                            document.body.removeChild(this.slashCommandMenu);
                            this.slashCommandMenu = null;
                        }
                        
                        const commands = [
                            { name: 'Paragraph', type: 'paragraph', icon: '¶' },
                            { name: 'Heading 1', type: 'heading-1', icon: 'H1' },
                            { name: 'Heading 2', type: 'heading-2', icon: 'H2' },
                            { name: 'Heading 3', type: 'heading-3', icon: 'H3' },
                            { name: 'Bulleted List', type: 'list', icon: '•' },
                            { name: 'Numbered List', type: 'ordered-list', icon: '1.' },
                            { name: 'Code', type: 'code', icon: '</>' },
                            { name: 'Quote', type: 'quote', icon: '"' },
                            { name: 'Pullquote', type: 'pullquote', icon: '❝' },
                            { name: 'Image', type: 'image', icon: '🖼' }
                        ];
                        
                        this.slashCommandMenu = document.createElement('div');
                        this.slashCommandMenu.className = 'slash-command-menu';
                        this.slashCommandMenu.style.cssText = `
                            position: absolute;
                            background: var(--slash-menu-bg);
                            backdrop-filter: blur(20px);
                            border: 1px solid var(--slash-menu-border);
                            border-radius: 8px;
                            box-shadow: 0 8px 32px var(--slash-menu-shadow);
                            padding: 4px 0;
                            z-index: 1000;
                            min-width: 240px;
                            max-height: none;
                            overflow: visible;
                            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
                        `;
                        
                        // Track selected index
                        this.selectedCommandIndex = 0;
                        
                        commands.forEach((command, index) => {
                            const item = document.createElement('div');
                            item.className = 'slash-command-item';
                            item.setAttribute('data-command-index', index);
                            item.setAttribute('data-command-type', command.type);
                            item.style.cssText = `
                                padding: 8px 16px;
                                cursor: pointer;
                                display: flex;
                                align-items: center;
                                gap: 12px;
                                font-size: 13px;
                                color: var(--slash-menu-text);
                                transition: background-color 0.1s ease;
                                margin: 2px 0;
                            `;
                            
                            // Auto-select first item
                            if (index === 0) {
                                item.style.backgroundColor = 'var(--slash-menu-hover)';
                                item.classList.add('selected');
                            }
                            
                            item.innerHTML = `
                                <span style="font-size: 14px;">${command.icon}</span>
                                <span>${command.name}</span>
                            `;
                            
                            item.addEventListener('click', () => {
                                this.executeSlashCommand(command.type, blockIndex);
                            });
                            
                            item.addEventListener('mouseover', () => {
                                this.selectCommandItem(index);
                            });
                            
                            this.slashCommandMenu.appendChild(item);
                        });
                        
                        // Position the menu
                        const blockElement = this.blocksContainer.children[blockIndex];
                        const rect = blockElement.getBoundingClientRect();
                        this.slashCommandMenu.style.left = rect.left + 'px';
                        this.slashCommandMenu.style.top = (rect.bottom + 5) + 'px';
                        
                        document.body.appendChild(this.slashCommandMenu);
                    }
                    
                    selectCommandItem(index) {
                        const items = this.slashCommandMenu.querySelectorAll('.slash-command-item');
                        
                        // Clear previous selection
                        items.forEach((item, i) => {
                            if (i === index) {
                                item.style.backgroundColor = 'var(--slash-menu-hover)';
                                item.classList.add('selected');
                            } else {
                                item.style.backgroundColor = 'transparent';
                                item.classList.remove('selected');
                            }
                        });
                        
                        this.selectedCommandIndex = index;
                    }
                    
                    hideSlashCommands() {
                        window.webkit.messageHandlers.editorError.postMessage(`hideSlashCommands called, menu exists: ${!!this.slashCommandMenu}`);
                        if (this.slashCommandMenu) {
                            document.body.removeChild(this.slashCommandMenu);
                            this.slashCommandMenu = null;
                        }
                        this.showingSlashCommands = false;
                        window.webkit.messageHandlers.editorError.postMessage(`hideSlashCommands completed, showingSlashCommands: ${this.showingSlashCommands}`);
                    }
                    
                    executeSlashCommand(blockType, blockIndex) {
                        // Clear the slash command text from the block
                        this.blocks[blockIndex].content = '';
                        
                        // Special handling for image blocks
                        if (blockType === 'image') {
                            this.hideSlashCommands();
                            this.showImagePicker(blockIndex);
                            return;
                        }
                        
                        this.blocks[blockIndex].type = blockType;
                        
                        // Set appropriate content for list types
                        if (blockType === 'list' || blockType === 'ordered-list') {
                            this.blocks[blockIndex].content = '<li></li>';
                        } else {
                            this.blocks[blockIndex].content = '';
                        }
                        
                        this.hideSlashCommands();
                        this.render();
                        this.focusBlock(blockIndex);
                    }
                    
                    showImagePicker(blockIndex) {
                        window.webkit.messageHandlers.editorError.postMessage('showImagePicker called for block ' + blockIndex);
                        
                        // Request native image picker
                        window.webkit.messageHandlers.requestImagePicker.postMessage({
                            blockIndex: blockIndex,
                            blockId: this.blocks[blockIndex].id
                        });
                        
                        // Update block to show placeholder while waiting
                        this.blocks[blockIndex].type = 'image';
                        this.blocks[blockIndex].content = '<div class="image-loading">Select an image...</div>';
                        this.blocks[blockIndex].attributes = {
                            selecting: true
                        };
                        this.render();
                    }
                    
                    handleImageFile(file, blockIndex) {
                        // First, create a placeholder image block with loading state
                        this.blocks[blockIndex].type = 'image';
                        this.blocks[blockIndex].content = '<div class="image-loading">Uploading image...</div>';
                        this.blocks[blockIndex].attributes = {
                            uploading: true
                        };
                        this.render();
                        
                        // Read the file as data URL for immediate preview
                        const reader = new FileReader();
                        reader.onload = (e) => {
                            const dataUrl = e.target.result;
                            
                            // Update block with preview
                            this.blocks[blockIndex].content = `<img src="${dataUrl}" alt="${file.name}" style="max-width: 100%; height: auto;" />`;
                            this.blocks[blockIndex].attributes = {
                                dataUrl: dataUrl,
                                fileName: file.name,
                                uploading: true
                            };
                            this.render();
                            
                            // Notify native app to handle the actual upload
                            window.webkit.messageHandlers.imageUpload.postMessage({
                                blockId: this.blocks[blockIndex].id,
                                blockIndex: blockIndex,
                                dataUrl: dataUrl,
                                fileName: file.name,
                                fileSize: file.size,
                                mimeType: file.type
                            });
                        };
                        
                        reader.readAsDataURL(file);
                    }
                    
                    // Called from native app after successful upload
                    updateImageBlock(blockId, imageUrl, imageId) {
                        const blockIndex = this.blocks.findIndex(b => b.id === blockId);
                        if (blockIndex >= 0) {
                            this.blocks[blockIndex].content = `<figure class="wp-block-image"><img src="${imageUrl}" alt="" /></figure>`;
                            this.blocks[blockIndex].attributes = {
                                id: imageId,
                                url: imageUrl,
                                uploading: false
                            };
                            this.render();
                            this.handleContentChange();
                        }
                    }
                    
                    handleSlashCommandKeydown(event) {
                        if (!this.slashCommandMenu) return;
                        
                        const visibleItems = Array.from(this.slashCommandMenu.querySelectorAll('.slash-command-item'))
                            .filter(item => item.style.display !== 'none');
                        
                        switch (event.key) {
                            case 'Escape':
                                event.preventDefault();
                                this.hideSlashCommands();
                                break;
                                
                            case 'Enter':
                                event.preventDefault();
                                // Execute selected command
                                const selectedItem = this.slashCommandMenu.querySelector('.slash-command-item.selected');
                                if (selectedItem) {
                                    selectedItem.click();
                                }
                                break;
                                
                            case 'ArrowUp':
                                event.preventDefault();
                                if (visibleItems.length > 0) {
                                    // Find current selected item in visible items
                                    let currentVisibleIndex = visibleItems.findIndex(item => item.classList.contains('selected'));
                                    if (currentVisibleIndex === -1) currentVisibleIndex = 0;
                                    
                                    let newVisibleIndex = currentVisibleIndex - 1;
                                    if (newVisibleIndex < 0) {
                                        newVisibleIndex = visibleItems.length - 1;
                                    }
                                    
                                    const itemIndex = parseInt(visibleItems[newVisibleIndex].getAttribute('data-command-index'));
                                    this.selectCommandItem(itemIndex);
                                }
                                break;
                                
                            case 'ArrowDown':
                                event.preventDefault();
                                if (visibleItems.length > 0) {
                                    // Find current selected item in visible items
                                    let currentVisibleIndex = visibleItems.findIndex(item => item.classList.contains('selected'));
                                    if (currentVisibleIndex === -1) currentVisibleIndex = -1;
                                    
                                    let newVisibleIndex = currentVisibleIndex + 1;
                                    if (newVisibleIndex >= visibleItems.length) {
                                        newVisibleIndex = 0;
                                    }
                                    
                                    const itemIndex = parseInt(visibleItems[newVisibleIndex].getAttribute('data-command-index'));
                                    this.selectCommandItem(itemIndex);
                                }
                                break;
                        }
                    }
                    
                    filterSlashCommands(query, blockIndex) {
                        if (!this.slashCommandMenu) {
                            this.createSlashCommandMenu(blockIndex);
                        }
                        
                        const items = this.slashCommandMenu.querySelectorAll('.slash-command-item');
                        let firstVisibleIndex = -1;
                        let hasVisibleItems = false;
                        
                        items.forEach((item, index) => {
                            const text = item.textContent.toLowerCase();
                            const visible = text.includes(query.toLowerCase());
                            item.style.display = visible ? 'flex' : 'none';
                            
                            if (visible && firstVisibleIndex === -1) {
                                firstVisibleIndex = index;
                                hasVisibleItems = true;
                            }
                        });
                        
                        // Auto-select first visible item after filtering
                        if (hasVisibleItems) {
                            this.selectCommandItem(firstVisibleIndex);
                        }
                    }
                    
                    
                    moveBlockUp(blockIndex) {
                        if (blockIndex > 0) {
                            const block = this.blocks.splice(blockIndex, 1)[0];
                            this.blocks.splice(blockIndex - 1, 0, block);
                            this.render();
                            this.focusBlock(blockIndex - 1);
                            this.handleContentChange();
                        }
                    }
                    
                    moveBlockDown(blockIndex) {
                        if (blockIndex < this.blocks.length - 1) {
                            const block = this.blocks.splice(blockIndex, 1)[0];
                            this.blocks.splice(blockIndex + 1, 0, block);
                            this.render();
                            this.focusBlock(blockIndex + 1);
                            this.handleContentChange();
                        }
                    }
                    
                    duplicateBlock(blockIndex) {
                        const originalBlock = this.blocks[blockIndex];
                        const duplicatedBlock = {
                            id: this.generateBlockId(),
                            type: originalBlock.type,
                            content: originalBlock.content,
                            attributes: { ...originalBlock.attributes }
                        };
                        this.blocks.splice(blockIndex + 1, 0, duplicatedBlock);
                        this.render();
                        this.focusBlock(blockIndex + 1);
                        this.handleContentChange();
                    }
                    
                    // HTML Parsing
                    parseHTMLToBlocks(html) {
                        const blocks = [];
                        
                        // Check if content has WordPress block comments
                        if (html.includes('<!-- wp:')) {
                            // Parse WordPress block format
                            const blockRegex = /<!-- wp:([a-z-]+)(?:\\s+(\\{[^}]*\\}))? -->\\n?([\\s\\S]*?)\\n?<!-- \\/wp:\\1 -->/g;
                            let match;
                            
                            while ((match = blockRegex.exec(html)) !== null) {
                                const [fullMatch, blockName, attrsJson, content] = match;
                                let type = 'paragraph';
                                let attributes = {};
                                
                                // Parse attributes if present
                                if (attrsJson) {
                                    try {
                                        attributes = JSON.parse(attrsJson);
                                    } catch (e) {
                                        console.error('Failed to parse block attributes:', e);
                                    }
                                }
                                
                                // Map WordPress block names to our types
                                switch (blockName) {
                                    case 'paragraph':
                                        type = 'paragraph';
                                        break;
                                    case 'heading':
                                        const level = attributes.level || 2;
                                        type = `heading-${level}`;
                                        break;
                                    case 'list':
                                        type = attributes.ordered ? 'ordered-list' : 'list';
                                        break;
                                    case 'quote':
                                        type = 'quote';
                                        break;
                                    case 'pullquote':
                                        type = 'pullquote';
                                        break;
                                    case 'code':
                                        type = 'code';
                                        break;
                                    case 'image':
                                        type = 'image';
                                        // Extract image URL from content
                                        const imgMatch = content.match(/<img[^>]+src=["']([^"']+)["']/);
                                        if (imgMatch) {
                                            attributes.url = imgMatch[1];
                                        }
                                        break;
                                }
                                
                                // Extract inner content from HTML tags
                                const tempDiv = document.createElement('div');
                                tempDiv.innerHTML = content;
                                const innerContent = tempDiv.querySelector('p, h1, h2, h3, h4, h5, h6, pre, blockquote, ul, ol, figure');
                                
                                blocks.push({
                                    id: this.generateBlockId(),
                                    type: type,
                                    content: innerContent ? innerContent.innerHTML : content,
                                    attributes: attributes
                                });
                            }
                        } else {
                            // Fallback to parsing regular HTML
                            const div = document.createElement('div');
                            div.innerHTML = html;
                            
                            Array.from(div.children).forEach(element => {
                                const block = this.elementToBlock(element);
                                if (block) {
                                    blocks.push(block);
                                }
                            });
                            
                            // If no blocks found, create paragraph blocks from text content
                            if (blocks.length === 0 && html.trim()) {
                                const paragraphs = html.split('\\n\\n').filter(p => p.trim());
                                paragraphs.forEach(p => {
                                    blocks.push({
                                        id: this.generateBlockId(),
                                        type: 'paragraph',
                                        content: p.trim(),
                                        attributes: {}
                                    });
                                });
                            }
                        }
                        
                        return blocks;
                    }
                    
                    elementToBlock(element) {
                        const tagName = element.tagName.toLowerCase();
                        const content = element.innerHTML;
                        
                        let type = 'paragraph';
                        let attributes = {};
                        
                        switch (tagName) {
                            case 'h1': type = 'heading-1'; break;
                            case 'h2': type = 'heading-2'; break;
                            case 'h3': type = 'heading-3'; break;
                            case 'h4': type = 'heading-4'; break;
                            case 'h5': type = 'heading-5'; break;
                            case 'h6': type = 'heading-6'; break;
                            case 'pre': type = 'code'; break;
                            case 'blockquote': 
                                type = element.className.includes('pullquote') ? 'pullquote' : 'quote';
                                break;
                            case 'ul': type = 'list'; break;
                            case 'ol': type = 'ordered-list'; break;
                            case 'figure':
                                // Check if it's an image block
                                if (element.className.includes('wp-block-image')) {
                                    type = 'image';
                                    const img = element.querySelector('img');
                                    if (img) {
                                        attributes.url = img.src;
                                        attributes.alt = img.alt || '';
                                    }
                                }
                                break;
                        }
                        
                        return {
                            id: this.generateBlockId(),
                            type: type,
                            content: content,
                            attributes: attributes
                        };
                    }
                    
                    setupHeightObserver() {
                        const observer = new MutationObserver(() => {
                            this.updateHeight();
                        });
                        
                        observer.observe(this.container, {
                            childList: true,
                            subtree: true,
                            attributes: true
                        });
                        
                        // Initial height update
                        setTimeout(() => this.updateHeight(), 100);
                    }
                    
                    updateHeight() {
                        const height = Math.max(this.container.scrollHeight + 40, 300);
                        window.webkit.messageHandlers.heightUpdate.postMessage(height);
                    }
                    
                    notifyContentUpdate(html) {
                        window.webkit.messageHandlers.contentUpdate.postMessage({
                            html: html,
                            text: this.content
                        });
                    }
                    
                    notifyReady() {
                        window.webkit.messageHandlers.editorReady.postMessage('ready');
                    }
                    
                    handleError(error) {
                        console.error('Gutenberg Editor Error:', error);
                        this.container.innerHTML = `
                            <div class="error">
                                <h3>Editor Error</h3>
                                <p>${error.message}</p>
                            </div>
                        `;
                        window.webkit.messageHandlers.editorError.postMessage(error.message);
                    }
                    
                    // Public methods for native app integration
                    setContent(content) {
                        this.content = content;
                        this.parseContent();
                        // Reset user interaction flag when new content is set
                        this.hasUserInteracted = false;
                        this.shouldAutoFocus = false;
                        this.render();
                    }
                    
                    getContent() {
                        return {
                            html: this.editableArea.innerHTML,
                            text: this.content
                        };
                    }
                    
                    // Link handling methods
                    showLinkPopover(blockIndex) {
                        window.webkit.messageHandlers.editorError.postMessage(`showLinkPopover called for block ${blockIndex}`);
                        
                        const selection = window.getSelection();
                        if (!selection.rangeCount) {
                            window.webkit.messageHandlers.editorError.postMessage('No selection range count');
                            return;
                        }
                        
                        const range = selection.getRangeAt(0);
                        const selectedText = range.toString();
                        
                        window.webkit.messageHandlers.editorError.postMessage(`Selection found: "${selectedText}", collapsed: ${range.collapsed}`);
                        
                        // If no text is selected, prompt user to select text first
                        if (!selectedText && range.collapsed) {
                            window.webkit.messageHandlers.editorError.postMessage('No text selected - prompting user');
                            alert('Please select some text first to create a link');
                            return;
                        }
                        
                        // Check if we're editing an existing link
                        let existingLink = null;
                        let linkNode = range.startContainer;
                        while (linkNode && linkNode !== this.blocksContainer) {
                            if (linkNode.tagName === 'A') {
                                existingLink = linkNode;
                                break;
                            }
                            linkNode = linkNode.parentElement;
                        }
                        
                        window.webkit.messageHandlers.editorError.postMessage(`About to call createLinkPopover with blockIndex=${blockIndex}, selectedText="${selectedText}"`);
                        
                        // Create popover
                        try {
                            this.createLinkPopover(blockIndex, selectedText, existingLink);
                        } catch (error) {
                            window.webkit.messageHandlers.editorError.postMessage(`Error in createLinkPopover: ${error.message}`);
                        }
                    }
                    
                    createLinkPopover(blockIndex, selectedText, existingLink) {
                        window.webkit.messageHandlers.editorError.postMessage(`Creating link popover: blockIndex=${blockIndex}, selectedText="${selectedText}", hasExistingLink=${!!existingLink}`);
                        
                        // Remove existing popover if any
                        this.hideLinkPopover();
                        
                        const popover = document.createElement('div');
                        popover.className = 'link-popover';
                        popover.innerHTML = `
                            <input type="url" 
                                   placeholder="https://example.com" 
                                   value="${existingLink ? existingLink.href : ''}"
                                   autocomplete="off"
                                   spellcheck="false">
                            <div class="link-popover-buttons">
                                ${existingLink ? '<button class="secondary remove">Remove</button>' : ''}
                                <button class="secondary cancel">Cancel</button>
                                <button class="primary apply">Apply</button>
                            </div>
                        `;
                        
                        this.linkPopover = popover;
                        this.linkBlockIndex = blockIndex;
                        this.linkSelectedText = selectedText;
                        this.linkExistingNode = existingLink;
                        
                        // Position popover
                        const selection = window.getSelection();
                        if (!selection.rangeCount) {
                            window.webkit.messageHandlers.editorError.postMessage('No selection range found when positioning popover');
                            return;
                        }
                        
                        const range = selection.getRangeAt(0);
                        const rect = range.getBoundingClientRect();
                        
                        // Position relative to viewport (since we're using position: fixed)
                        const left = Math.max(10, Math.min(rect.left, window.innerWidth - 320));
                        const top = Math.max(10, Math.min(rect.bottom + 5, window.innerHeight - 150));
                        
                        window.webkit.messageHandlers.editorError.postMessage(`Popover position: left=${left}, top=${top}, rect.left=${rect.left}, rect.bottom=${rect.bottom}, window dimensions: ${window.innerWidth}x${window.innerHeight}`);
                        
                        popover.style.left = left + 'px';
                        popover.style.top = top + 'px';
                        
                        // Also add inline styles to ensure visibility
                        popover.style.position = 'fixed';
                        popover.style.zIndex = '999999';
                        popover.style.backgroundColor = 'white';
                        popover.style.border = '2px solid #007AFF';
                        popover.style.boxShadow = '0 8px 32px rgba(0, 0, 0, 0.3)';
                        
                        // Append to container instead of body for better context
                        this.container.appendChild(popover);
                        window.webkit.messageHandlers.editorError.postMessage('Link popover added to editor container');
                        
                        // Focus input
                        const input = popover.querySelector('input');
                        input.focus();
                        input.select();
                        
                        window.webkit.messageHandlers.editorError.postMessage('Link popover input focused');
                        
                        // Event handlers
                        input.addEventListener('keydown', (e) => {
                            if (e.key === 'Enter') {
                                e.preventDefault();
                                this.applyLink(input.value);
                            } else if (e.key === 'Escape') {
                                e.preventDefault();
                                this.hideLinkPopover();
                            }
                        });
                        
                        popover.querySelector('.apply').addEventListener('click', () => {
                            this.applyLink(input.value);
                        });
                        
                        popover.querySelector('.cancel').addEventListener('click', () => {
                            this.hideLinkPopover();
                        });
                        
                        const removeBtn = popover.querySelector('.remove');
                        if (removeBtn) {
                            removeBtn.addEventListener('click', () => {
                                this.removeLink();
                            });
                        }
                    }
                    
                    applyLink(url) {
                        if (!url || this.linkBlockIndex === undefined) {
                            this.hideLinkPopover();
                            return;
                        }
                        
                        // Ensure URL has protocol
                        if (!url.match(/^https?:\\/\\//)) {
                            url = 'https://' + url;
                        }
                        
                        const block = this.blocks[this.linkBlockIndex];
                        const blockElement = this.blocksContainer.children[this.linkBlockIndex];
                        const contentElement = blockElement.querySelector('.wp-block-content');
                        
                        if (this.linkExistingNode) {
                            // Update existing link
                            this.linkExistingNode.href = url;
                        } else if (this.linkSelectedText) {
                            // Create new link
                            const selection = window.getSelection();
                            const range = selection.getRangeAt(0);
                            
                            // Create link element
                            const link = document.createElement('a');
                            link.href = url;
                            link.textContent = this.linkSelectedText;
                            
                            // Replace selection with link
                            range.deleteContents();
                            range.insertNode(link);
                            
                            // Update cursor position
                            range.setStartAfter(link);
                            range.collapse(true);
                            selection.removeAllRanges();
                            selection.addRange(range);
                        }
                        
                        // Update block content
                        block.content = contentElement.innerHTML;
                        this.handleContentChange();
                        this.hideLinkPopover();
                    }
                    
                    removeLink() {
                        if (!this.linkExistingNode || this.linkBlockIndex === undefined) {
                            this.hideLinkPopover();
                            return;
                        }
                        
                        const block = this.blocks[this.linkBlockIndex];
                        const blockElement = this.blocksContainer.children[this.linkBlockIndex];
                        const contentElement = blockElement.querySelector('.wp-block-content');
                        
                        // Replace link with its text content
                        const textNode = document.createTextNode(this.linkExistingNode.textContent);
                        this.linkExistingNode.parentNode.replaceChild(textNode, this.linkExistingNode);
                        
                        // Update block content
                        block.content = contentElement.innerHTML;
                        this.handleContentChange();
                        this.hideLinkPopover();
                    }
                    
                    hideLinkPopover() {
                        if (this.linkPopover && this.linkPopover.parentNode) {
                            this.linkPopover.parentNode.removeChild(this.linkPopover);
                            this.linkPopover = null;
                            this.linkBlockIndex = undefined;
                            this.linkSelectedText = null;
                            this.linkExistingNode = null;
                        }
                    }
                    
                    // Serialize blocks to WordPress format with block comments
                    handleContentChange() {
                        const wpContent = this.serializeBlocksToWordPress();
                        
                        // Debug logging
                        console.log('=== Content being sent to Swift ===');
                        console.log('Content length:', wpContent.length);
                        console.log('Content preview:', wpContent.substring(0, 500));
                        console.log('Contains actual newlines:', wpContent.includes('\\n'));
                        
                        window.webkit.messageHandlers.contentUpdate.postMessage({
                            html: wpContent,
                            text: this.content
                        });
                    }
                    
                    serializeBlocksToWordPress() {
                        return this.blocks.map(block => {
                            let blockName = '';
                            let attrs = '';
                            
                            // Map block types to WordPress block names
                            switch (block.type) {
                                case 'paragraph':
                                    blockName = 'paragraph';
                                    break;
                                case 'heading-1':
                                    blockName = 'heading';
                                    attrs = ' {"level":1}';
                                    break;
                                case 'heading-2':
                                    blockName = 'heading';
                                    attrs = ' {"level":2}';
                                    break;
                                case 'heading-3':
                                    blockName = 'heading';
                                    attrs = ' {"level":3}';
                                    break;
                                case 'heading-4':
                                    blockName = 'heading';
                                    attrs = ' {"level":4}';
                                    break;
                                case 'heading-5':
                                    blockName = 'heading';
                                    attrs = ' {"level":5}';
                                    break;
                                case 'heading-6':
                                    blockName = 'heading';
                                    attrs = ' {"level":6}';
                                    break;
                                case 'list':
                                    blockName = 'list';
                                    attrs = ' {"ordered":false}';
                                    break;
                                case 'ordered-list':
                                    blockName = 'list';
                                    attrs = ' {"ordered":true}';
                                    break;
                                case 'quote':
                                    blockName = 'quote';
                                    break;
                                case 'pullquote':
                                    blockName = 'pullquote';
                                    break;
                                case 'code':
                                    blockName = 'code';
                                    break;
                                case 'image':
                                    blockName = 'image';
                                    if (block.attributes.id) {
                                        attrs = ` {"id":${block.attributes.id}}`;
                                    }
                                    break;
                                default:
                                    blockName = 'paragraph';
                            }
                            
                            // Get the proper HTML tag for the block
                            const tagName = this.getBlockTagName(block.type);
                            let content = '';
                            
                            // Format content based on block type
                            if (block.type === 'image' && block.attributes.url) {
                                content = `<figure class="wp-block-image"><img src="${block.attributes.url}" alt="${block.attributes.alt || ''}" /></figure>`;
                            } else if (tagName) {
                                content = `<${tagName}>${block.content}</${tagName}>`;
                            } else {
                                content = block.content;
                            }
                            
                            // Wrap with WordPress block comments
                            return `<!-- wp:${blockName}${attrs} -->\n${content}\n<!-- /wp:${blockName} -->`;
                        }).join('\n\n');
                    }
                }
                
                // Initialize editor when DOM is ready
                console.log('Document ready state:', document.readyState);
                
                function initializeEditor() {
                    console.log('Initializing GutenbergEditor...');
                    window.webkit.messageHandlers.editorError.postMessage('JavaScript is running - attempting to initialize editor');
                    try {
                        window.gutenbergEditor = new GutenbergEditor();
                        console.log('GutenbergEditor initialized successfully');
                        window.webkit.messageHandlers.editorError.postMessage('GutenbergEditor initialized successfully');
                    } catch (error) {
                        console.error('Failed to initialize GutenbergEditor:', error);
                        window.webkit.messageHandlers.editorError.postMessage('Failed to initialize GutenbergEditor: ' + error.message);
                    }
                }
                
                if (document.readyState === 'loading') {
                    console.log('Document still loading, waiting for DOMContentLoaded...');
                    document.addEventListener('DOMContentLoaded', initializeEditor);
                } else {
                    console.log('Document already loaded, initializing immediately...');
                    initializeEditor();
                }
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
        var parent: GutenbergWebViewRepresentable
        private var contentUpdateTimer: Timer?
        private var lastPendingContent: String?
        
        init(_ parent: GutenbergWebViewRepresentable) {
            self.parent = parent
        }
        
        deinit {
            // Save any pending changes before deallocation
            savePendingChanges()
        }
        
        func savePendingChanges() {
            // Cancel timer and save immediately
            contentUpdateTimer?.invalidate()
            contentUpdateTimer = nil
            
            // If we have pending content, save it immediately
            if let pendingContent = lastPendingContent {
                DispatchQueue.main.async {
                    self.parent.post.content = pendingContent
                    self.parent.post.modifiedDate = Date()
                    self.lastPendingContent = nil
                    
                    // SwiftData automatically saves changes
                    DebugLogger.shared.log("Saved pending changes on cleanup", level: .debug, source: "WebView")
                }
            }
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            
            // Inject JavaScript to capture console.log messages
            let consoleLogScript = """
                if (!window.consoleLogInjected) {
                    window.consoleLogInjected = true;
                    const originalLog = console.log;
                    console.log = function(...args) {
                        originalLog.apply(console, args);
                        try {
                            window.webkit.messageHandlers.consoleLog.postMessage(args.map(arg => String(arg)).join(' '));
                        } catch (e) {
                            originalLog('Failed to send log to native:', e);
                        }
                    };
                }
            """
            
            webView.evaluateJavaScript(consoleLogScript) { _, error in
                if let error = error {
                    DebugLogger.shared.log("Failed to inject console log handler: \(error)", level: .error, source: "WebView")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
                self.parent.errorMessage = error.localizedDescription
            }
        }
        
        // MARK: - WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            DispatchQueue.main.async {
                switch message.name {
                case "contentUpdate":
                    self.handleContentUpdate(message.body)
                case "heightUpdate":
                    self.handleHeightUpdate(message.body)
                case "editorReady":
                    self.handleEditorReady()
                case "editorError":
                    self.handleEditorError(message.body)
                case "imageUpload":
                    self.handleImageUpload(message.body)
                case "requestImagePicker":
                    self.handleImagePickerRequest(message.body)
                case "consoleLog":
                    if let logMessage = message.body as? String {
                        DebugLogger.shared.log("[JS Console] \(logMessage)", level: .debug, source: "WebView")
                    }
                default:
                    break
                }
            }
        }
        
        private func handleContentUpdate(_ body: Any) {
            guard let data = body as? [String: Any],
                  let html = data["html"] as? String else { return }
            
            // Log the content being saved
            DebugLogger.shared.log("=== Content Update from Editor ===", level: .debug, source: "GutenbergWebView")
            DebugLogger.shared.log("HTML content: \(html)", level: .debug, source: "GutenbergWebView")
            
            // Check for specific patterns that might cause issues
            if html.contains("\\n") {
                DebugLogger.shared.log("Content contains escaped newlines (\\n)", level: .warning, source: "GutenbergWebView")
            }
            if html.contains("&#") || html.contains("&lt;") || html.contains("&gt;") {
                DebugLogger.shared.log("Content contains HTML entities", level: .warning, source: "GutenbergWebView")
            }
            
            // Store the pending content
            lastPendingContent = html
            
            // Debounce content updates
            contentUpdateTimer?.invalidate()
            contentUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.parent.post.content = html
                    self.parent.post.modifiedDate = Date()
                    self.lastPendingContent = nil
                    
                    DebugLogger.shared.log("Content saved to post model", level: .debug, source: "GutenbergWebView")
                }
            }
        }
        
        private func handleHeightUpdate(_ body: Any) {
            guard let height = body as? CGFloat else { return }
            parent.dynamicHeight = max(height, 300)
        }
        
        private func handleEditorReady() {
            parent.isLoading = false
            parent.hasError = false
            
            // Add additional keyboard shortcut handling after editor is ready
            if let webView = parent.webViewRef {
                let script = """
                    // Add additional Cmd+K listener after editor is ready
                    document.addEventListener('keydown', (e) => {
                        if (e.key === 'k' && (e.metaKey || e.ctrlKey) && !e.shiftKey && !e.altKey) {
                            e.preventDefault();
                            e.stopPropagation();
                            
                            window.webkit.messageHandlers.editorError.postMessage('Editor-ready Cmd+K detected - using simple prompt');
                            
                            const selection = window.getSelection();
                            if (!selection.rangeCount || selection.isCollapsed) {
                                alert('Please select some text first to create a link');
                                return false;
                            }
                            
                            const selectedText = selection.toString();
                            const url = prompt('Enter URL for "' + selectedText + '":', 'https://');
                            
                            if (url && url !== '' && url !== 'https://') {
                                try {
                                    const range = selection.getRangeAt(0);
                                    
                                    // Create link element
                                    const link = document.createElement('a');
                                    link.href = url;
                                    link.textContent = selectedText;
                                    
                                    // Replace selection with link
                                    range.deleteContents();
                                    range.insertNode(link);
                                    
                                    // Update content
                                    if (window.gutenbergEditor) {
                                        // Find which block was edited
                                        let blockElement = link.parentElement;
                                        while (blockElement && !blockElement.classList.contains('wp-block')) {
                                            blockElement = blockElement.parentElement;
                                        }
                                        
                                        if (blockElement) {
                                            const blockIndex = parseInt(blockElement.getAttribute('data-block-index'));
                                            const contentElement = blockElement.querySelector('.wp-block-content');
                                            if (window.gutenbergEditor.blocks[blockIndex] && contentElement) {
                                                window.gutenbergEditor.blocks[blockIndex].content = contentElement.innerHTML;
                                                window.gutenbergEditor.handleContentChange();
                                            }
                                        }
                                    }
                                    
                                    window.webkit.messageHandlers.editorError.postMessage(`Link created: ${url}`);
                                } catch (error) {
                                    window.webkit.messageHandlers.editorError.postMessage(`Error creating link: ${error.message}`);
                                }
                            }
                            
                            return false;
                        }
                    }, true);
                    
                    window.webkit.messageHandlers.editorError.postMessage('Added editor-ready Cmd+K listener');
                """
                
                webView.evaluateJavaScript(script) { _, error in
                    if let error = error {
                        DebugLogger.shared.log("Failed to add Cmd+K listener: \(error)", level: .error, source: "WebView")
                    }
                }
            }
        }
        
        private func handleEditorError(_ body: Any) {
            let message = body as? String ?? "Unknown error occurred"
            parent.isLoading = false
            parent.hasError = true
            parent.errorMessage = message
            
            // Send debug message to DebugLogger
            DebugLogger.shared.log(message, level: .error, source: "WebView")
        }
        
        private func handleImageUpload(_ body: Any) {
            guard let data = body as? [String: Any],
                  let blockId = data["blockId"] as? String,
                  let dataUrl = data["dataUrl"] as? String,
                  let fileName = data["fileName"] as? String else {
                DebugLogger.shared.log("Invalid image upload data", level: .error, source: "WebView")
                return
            }
            
            // For now, we'll just use the data URL directly
            // In a real implementation, you would upload to WordPress media library
            DebugLogger.shared.log("Image selected: \(fileName)", level: .info, source: "WebView")
            
            // Update the image block with the data URL
            // In production, this would be the uploaded image URL from WordPress
            if let webView = parent.webViewRef {
                let escapedUrl = dataUrl.replacingOccurrences(of: "'", with: "\\'")
                let script = """
                    if (window.gutenbergEditor && window.gutenbergEditor.updateImageBlock) {
                        window.gutenbergEditor.updateImageBlock('\(blockId)', '\(escapedUrl)', 'temp-id');
                    }
                """
                webView.evaluateJavaScript(script) { _, error in
                    if let error = error {
                        DebugLogger.shared.log("Error updating image block: \(error)", level: .error, source: "WebView")
                    }
                }
            }
        }
        
        private func handleImagePickerRequest(_ body: Any) {
            guard let data = body as? [String: Any],
                  let blockIndex = data["blockIndex"] as? Int,
                  let _ = data["blockId"] as? String else {
                DebugLogger.shared.log("Invalid image picker request data", level: .error, source: "WebView")
                return
            }
            
            #if os(macOS)
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [.image]
            panel.prompt = "Select Image"
            
            if panel.runModal() == .OK, let url = panel.url {
                    // Read the image file
                    if let imageData = try? Data(contentsOf: url) {
                        let mimeType = url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
                        let fileName = url.lastPathComponent
                        
                        // First, show a preview with data URL while uploading
                        let base64String = imageData.base64EncodedString()
                        let dataUrl = "data:\(mimeType);base64,\(base64String)"
                        
                        if let webView = self.parent.webViewRef {
                            // Show preview immediately
                            let escapedUrl = dataUrl.replacingOccurrences(of: "'", with: "\\'")
                            let previewScript = """
                                if (window.gutenbergEditor) {
                                    window.gutenbergEditor.blocks[\(blockIndex)].type = 'image';
                                    window.gutenbergEditor.blocks[\(blockIndex)].content = '<div class="image-loading" style="position: relative;"><img src="\(escapedUrl)" alt="\(fileName)" style="max-width: 100%; height: auto; opacity: 0.5;" /><div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); background: rgba(255,255,255,0.9); padding: 10px; border-radius: 4px;">Uploading to WordPress...</div></div>';
                                    window.gutenbergEditor.blocks[\(blockIndex)].attributes = {
                                        uploading: true,
                                        fileName: '\(fileName)'
                                    };
                                    window.gutenbergEditor.render();
                                }
                            """
                            webView.evaluateJavaScript(previewScript) { _, _ in }
                        }
                        
                        // Upload to WordPress if we have site configuration
                        if let siteConfig = self.parent.siteConfig {
                            DebugLogger.shared.log("Site configuration found. Site URL: \(siteConfig.siteURL), Username: \(siteConfig.username)", level: .info, source: "WebView")
                            Task {
                                do {
                                    DebugLogger.shared.log("Starting image upload to WordPress: \(fileName), Size: \(imageData.count) bytes, MIME: \(mimeType)", level: .info, source: "WebView")
                                    
                                    // Retrieve password from keychain
                                    guard let password = try? KeychainManager.shared.retrieve(for: siteConfig.keychainIdentifier),
                                          !password.isEmpty else {
                                        throw WordPressError.unauthorized
                                    }
                                    
                                    let media = try await WordPressAPI.shared.uploadImage(
                                        siteURL: siteConfig.siteURL,
                                        username: siteConfig.username,
                                        password: password,
                                        imageData: imageData,
                                        filename: fileName,
                                        mimeType: mimeType
                                    )
                                    
                                    DebugLogger.shared.log("Image uploaded successfully. URL: \(media.sourceUrl)", level: .info, source: "WebView")
                                    
                                    // Update the block with the real URL
                                    await MainActor.run {
                                        if let webView = self.parent.webViewRef {
                                            let escapedUrl = media.sourceUrl.replacingOccurrences(of: "'", with: "\\'")
                                            let altText = media.altText.isEmpty ? fileName : media.altText.replacingOccurrences(of: "'", with: "\\'")
                                            let updateScript = """
                                                if (window.gutenbergEditor) {
                                                    window.gutenbergEditor.blocks[\(blockIndex)].content = '<figure class="wp-block-image"><img src="\(escapedUrl)" alt="\(altText)" /></figure>';
                                                    window.gutenbergEditor.blocks[\(blockIndex)].attributes = {
                                                        id: \(media.id),
                                                        url: '\(escapedUrl)',
                                                        alt: '\(altText)',
                                                        uploading: false
                                                    };
                                                    window.gutenbergEditor.render();
                                                    window.gutenbergEditor.handleContentChange();
                                                }
                                            """
                                            webView.evaluateJavaScript(updateScript) { _, error in
                                                if let error = error {
                                                    DebugLogger.shared.log("Error updating image block after upload: \(error)", level: .error, source: "WebView")
                                                }
                                            }
                                        }
                                    }
                                } catch {
                                    DebugLogger.shared.log("Failed to upload image: \(error)", level: .error, source: "WebView")
                                    
                                    // Show error state
                                    await MainActor.run {
                                        if let webView = self.parent.webViewRef {
                                            let errorScript = """
                                                if (window.gutenbergEditor) {
                                                    window.gutenbergEditor.blocks[\(blockIndex)].content = '<div class="image-error" style="padding: 20px; background: var(--image-error-bg); color: var(--image-error-text); border-radius: 4px;">Failed to upload image: \(error.localizedDescription)</div>';
                                                    window.gutenbergEditor.blocks[\(blockIndex)].attributes = {
                                                        error: true,
                                                        uploading: false
                                                    };
                                                    window.gutenbergEditor.render();
                                                }
                                            """
                                            webView.evaluateJavaScript(errorScript) { _, _ in }
                                        }
                                    }
                                }
                            }
                        } else {
                            // No site configuration, just use the data URL
                            DebugLogger.shared.log("No site configuration available, using data URL", level: .warning, source: "WebView")
                            if let webView = self.parent.webViewRef {
                                let escapedUrl = dataUrl.replacingOccurrences(of: "'", with: "\\'")
                                let script = """
                                    if (window.gutenbergEditor) {
                                        window.gutenbergEditor.blocks[\(blockIndex)].content = '<img src="\(escapedUrl)" alt="\(fileName)" style="max-width: 100%; height: auto;" />';
                                        window.gutenbergEditor.blocks[\(blockIndex)].attributes = {
                                            dataUrl: '\(escapedUrl)',
                                            fileName: '\(fileName)',
                                            uploading: false
                                        };
                                        window.gutenbergEditor.render();
                                        window.gutenbergEditor.handleContentChange();
                                    }
                                """
                                webView.evaluateJavaScript(script) { _, _ in }
                            }
                        }
                    }
                }
            #endif
        }
        
        // MARK: - WKUIDelegate for macOS
        
        #if os(macOS)
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let alert = NSAlert()
            alert.messageText = "Add Link"
            alert.informativeText = prompt
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Add")
            alert.addButton(withTitle: "Cancel")
            
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            input.stringValue = defaultText ?? "https://"
            input.placeholderString = "https://example.com"
            alert.accessoryView = input
            
            // Focus the text field and select all text
            alert.window.initialFirstResponder = input
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                completionHandler(input.stringValue)
            } else {
                completionHandler(nil)
            }
        }
        #endif
        
        // MARK: - Content Management
        
        func updateContent(_ content: String) {
            // Save any pending changes first
            self.savePendingChanges()
            
            // Update editor content through JavaScript
            guard let webView = parent.webViewRef else { return }
            
            let decodedContent = HTMLHandler.shared.decodeHTMLEntitiesManually(content)
            let escapedContent = decodedContent
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            
            let script = """
                if (window.gutenbergEditor) {
                    window.gutenbergEditor.setContent(`\(escapedContent)`);
                }
            """
            
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    DebugLogger.shared.log("Failed to update content: \(error)", level: .error, source: "WebView")
                } else {
                    DebugLogger.shared.log("Successfully updated content for new post", level: .debug, source: "WebView")
                }
            }
        }
        
        // MARK: - WKUIDelegate for iOS
        
        #if os(iOS)
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler()
            })
            
            if let viewController = parent.webViewRef?.window?.rootViewController {
                viewController.present(alert, animated: true)
            } else {
                completionHandler()
            }
        }
        
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: "Add Link", message: prompt, preferredStyle: .alert)
            
            alert.addTextField { textField in
                textField.text = defaultText
                textField.placeholder = "https://example.com"
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(nil)
            })
            
            alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            
            if let viewController = parent.webViewRef?.window?.rootViewController {
                viewController.present(alert, animated: true)
            } else {
                completionHandler(nil)
            }
        }
        #endif
        
        // MARK: - Native Context Menu Support
        
        @available(iOS 13.0, *)
        func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
            // TODO: iOS doesn't have boundingRect on WKContextMenuElementInfo
            // For now, we'll disable context menus on iOS
            completionHandler(nil)
            return
            
            /*
            // Check if we're right-clicking on a block element
            // Note: boundingRect not available on iOS, using fallback approach
            webView.evaluateJavaScript("document.elementFromPoint(100, 100)?.closest('.wp-block')?.getAttribute('data-block-index')") { result, error in
                guard let blockIndexString = result as? String,
                      let blockIndex = Int(blockIndexString) else {
                    completionHandler(nil)
                    return
                }
                
                // Get total blocks count
                webView.evaluateJavaScript("window.gutenbergEditor?.blocks?.length || 0") { blocksCountResult, _ in
                    let blocksCount = blocksCountResult as? Int ?? 0
                    
                    DispatchQueue.main.async {
                        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
                            var actions: [UIAction] = []
                            
                            // Move Up
                            if blockIndex > 0 {
                                let moveUpAction = UIAction(title: "Move Up", image: UIImage(systemName: "arrow.up")) { _ in
                                    self.executeBlockAction("moveBlockUp", blockIndex: blockIndex)
                                }
                                actions.append(moveUpAction)
                            }
                            
                            // Move Down
                            if blockIndex < blocksCount - 1 {
                                let moveDownAction = UIAction(title: "Move Down", image: UIImage(systemName: "arrow.down")) { _ in
                                    self.executeBlockAction("moveBlockDown", blockIndex: blockIndex)
                                }
                                actions.append(moveDownAction)
                            }
                            
                            // Delete Block
                            if blocksCount > 1 {
                                let deleteAction = UIAction(title: "Delete Block", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                                    self.executeBlockAction("deleteBlock", blockIndex: blockIndex)
                                }
                                actions.append(deleteAction)
                            }
                            
                            // Duplicate
                            let duplicateAction = UIAction(title: "Duplicate", image: UIImage(systemName: "doc.on.doc")) { _ in
                                self.executeBlockAction("duplicateBlock", blockIndex: blockIndex)
                            }
                            actions.append(duplicateAction)
                            
                            return UIMenu(title: "", children: actions)
                        }
                        
                        completionHandler(configuration)
                    }
                }
            }
            */
        }
        
        private func executeBlockAction(_ action: String, blockIndex: Int) {
            // Get the webView from the parent's webViewRef
            guard let webView = parent.webViewRef else { return }
            
            let script = "window.gutenbergEditor?.\(action)(\(blockIndex))"
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    DebugLogger.shared.log("Failed to execute block action \(action): \(error)", level: .error, source: "WebView")
                }
            }
        }
    }
}

#elseif os(macOS)

// Custom WKWebView subclass to handle context menu
class GutenbergWKWebView: WKWebView {
    weak var coordinator: GutenbergWebViewRepresentable.Coordinator?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        DebugLogger.shared.log("WebView becoming first responder", level: .debug, source: "WebView")
        return super.becomeFirstResponder()
    }
    
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        super.willOpenMenu(menu, with: event)
        
        // Filter out unwanted menu items
        let itemsToRemove = menu.items.filter { item in
            let title = item.title.lowercased()
            let identifier = item.identifier?.rawValue ?? ""
            
            // Items to hide based on title or identifier
            return title.contains("transformation") ||
                   title.contains("paragraph direction") ||
                   title.contains("selection direction") ||
                   title.contains("share") ||
                   title.contains("auto-fill") ||
                   title.contains("autofill") ||
                   title.contains("services") ||
                   title.contains("look up") ||
                   title.contains("translate") ||
                   title.contains("search with") ||
                   identifier.contains("WKMenuItemIdentifierLookUp") ||
                   identifier.contains("WKMenuItemIdentifierTranslate") ||
                   identifier.contains("WKMenuItemIdentifierSearchWeb") ||
                   identifier.contains("WKMenuItemIdentifierShareMenu") ||
                   identifier.contains("WKMenuItemIdentifierServices")
        }
        
        // Remove the unwanted items
        for item in itemsToRemove {
            menu.removeItem(item)
        }
        
        guard let coordinator = coordinator else { return }
        
        // Get the click location
        let locationInView = convert(event.locationInWindow, from: nil)
        
        // Check if we're right-clicking on a block element
        evaluateJavaScript("document.elementFromPoint(\(locationInView.x), \(locationInView.y))?.closest('.wp-block')?.getAttribute('data-block-index')") { result, error in
            guard let blockIndexString = result as? String,
                  let blockIndex = Int(blockIndexString) else {
                return
            }
            
            // Get total blocks count
            self.evaluateJavaScript("window.gutenbergEditor?.blocks?.length || 0") { blocksCountResult, _ in
                let blocksCount = blocksCountResult as? Int ?? 0
                
                DispatchQueue.main.async {
                    // Add separator
                    menu.addItem(NSMenuItem.separator())
                    
                    // Move Up
                    let moveUpItem = NSMenuItem(title: "Move Up", action: #selector(coordinator.moveBlockUp), keyEquivalent: "")
                    moveUpItem.target = coordinator
                    moveUpItem.representedObject = blockIndex
                    moveUpItem.isEnabled = blockIndex > 0
                    menu.addItem(moveUpItem)
                    
                    // Move Down
                    let moveDownItem = NSMenuItem(title: "Move Down", action: #selector(coordinator.moveBlockDown), keyEquivalent: "")
                    moveDownItem.target = coordinator
                    moveDownItem.representedObject = blockIndex
                    moveDownItem.isEnabled = blockIndex < blocksCount - 1
                    menu.addItem(moveDownItem)
                    
                    // Delete Block
                    let deleteItem = NSMenuItem(title: "Delete Block", action: #selector(coordinator.deleteBlock), keyEquivalent: "")
                    deleteItem.target = coordinator
                    deleteItem.representedObject = blockIndex
                    deleteItem.isEnabled = blocksCount > 1
                    menu.addItem(deleteItem)
                    
                    // Duplicate
                    let duplicateItem = NSMenuItem(title: "Duplicate", action: #selector(coordinator.duplicateBlock), keyEquivalent: "")
                    duplicateItem.target = coordinator
                    duplicateItem.representedObject = blockIndex
                    menu.addItem(duplicateItem)
                }
            }
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        DebugLogger.shared.log("performKeyEquivalent called: \(event.charactersIgnoringModifiers ?? "nil"), modifiers: \(event.modifierFlags.rawValue)", level: .debug, source: "WebView")
        
        // Check for Cmd+K
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
            DebugLogger.shared.log("CMD+K detected in performKeyEquivalent", level: .info, source: "WebView")
            
            // Get selected text
            self.evaluateJavaScript("window.getSelection().toString()") { [weak self] result, error in
                if let error = error {
                    DebugLogger.shared.log("Error getting selection: \(error)", level: .error, source: "WebView")
                    return
                }
                
                guard let selectedText = result as? String, !selectedText.isEmpty else {
                    DebugLogger.shared.log("No text selected for hyperlink", level: .info, source: "WebView")
                    return
                }
                
                DebugLogger.shared.log("Selected text for hyperlink: \(selectedText)", level: .info, source: "WebView")
                
                // Show hyperlink dialog
                DispatchQueue.main.async {
                    self?.coordinator?.showHyperlinkDialog(for: selectedText)
                }
            }
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        DebugLogger.shared.log("keyDown called: \(event.charactersIgnoringModifiers ?? "nil"), modifiers: \(event.modifierFlags.rawValue)", level: .debug, source: "WebView")
        
        // Check for Cmd+K (backup in case performKeyEquivalent doesn't catch it)
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
            DebugLogger.shared.log("CMD+K detected in keyDown", level: .info, source: "WebView")
            
            // Get selected text
            self.evaluateJavaScript("window.getSelection().toString()") { [weak self] result, error in
                guard let selectedText = result as? String, !selectedText.isEmpty else {
                    // No text selected
                    return
                }
                
                // Show hyperlink dialog
                DispatchQueue.main.async {
                    self?.coordinator?.showHyperlinkDialog(for: selectedText)
                }
            }
            return
        }
        
        super.keyDown(with: event)
    }
}

struct GutenbergWebViewRepresentable: NSViewRepresentable {
    @Bindable var post: Post
    let typeface: String
    let fontSize: Int
    let siteConfig: SiteConfiguration?
    @Binding var dynamicHeight: CGFloat
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var errorMessage: String
    @Binding var webViewRef: WKWebView?
    
    func makeNSView(context: Context) -> GutenbergWKWebView {
        let coordinator = context.coordinator
        
        // Configure web view
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(coordinator, name: "contentUpdate")
        configuration.userContentController.add(coordinator, name: "heightUpdate")
        configuration.userContentController.add(coordinator, name: "editorReady")
        configuration.userContentController.add(coordinator, name: "editorError")
        configuration.userContentController.add(coordinator, name: "imageUpload")
        configuration.userContentController.add(coordinator, name: "requestImagePicker")
        configuration.userContentController.add(coordinator, name: "consoleLog")
        
        let webView = GutenbergWKWebView(frame: .zero, configuration: configuration)
        webView.coordinator = coordinator
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        webView.setValue(false, forKey: "drawsBackground")
        
        // Prevent horizontal scrolling in the WebView itself
        webView.enclosingScrollView?.hasHorizontalScroller = false
        webView.enclosingScrollView?.horizontalScrollElasticity = .none
        
        // Store webView reference for parent
        DispatchQueue.main.async {
            webViewRef = webView
        }
        
        // Load the Gutenberg editor
        loadGutenbergEditor(in: webView)
        
        return webView
    }
    
    func updateNSView(_ webView: GutenbergWKWebView, context: Context) {
        // Update content if post has changed
        context.coordinator.updateContent(post.content)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Same implementation as iOS version...
    private func loadGutenbergEditor(in webView: WKWebView) {
        let htmlContent = generateGutenbergHTML()
        webView.loadHTMLString(htmlContent, baseURL: Bundle.main.bundleURL)
    }
    
    private func generateGutenbergHTML() -> String {
        // Generate shared HTML - referencing iOS version for now
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>Gutenberg Editor</title>
            <!-- Cache bust: v5.0 Professional blue link colors -->
            <style>
                :root {
                    --editor-font-family: \({
                        switch typeface {
                        case "system": return "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
                        case "sf-mono": return "'SF Mono', Monaco, 'Courier New', monospace"
                        case "georgia": return "Georgia, 'Times New Roman', serif"
                        case "verdana": return "Verdana, Geneva, sans-serif"
                        case "arial": return "Arial, Helvetica, sans-serif"
                        default: return "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
                        }
                    }());
                    --editor-font-size: \(fontSize)px;
                    
                    /* Light mode colors */
                    --bg-color: #ffffff;
                    --text-color: #000000;
                    --secondary-text: #666666;
                    --placeholder-color: #999999;
                    --link-color: #0066CC;
                    --code-bg: #f5f5f5;
                    --quote-border: #ddd;
                    --pullquote-border: #666;
                    --popover-bg: rgba(255, 255, 255, 0.95);
                    --popover-border: #0066CC;
                    --popover-shadow: rgba(0, 0, 0, 0.3);
                    --button-secondary-bg: rgba(0, 0, 0, 0.05);
                    --button-secondary-text: #333;
                    --input-border: rgba(0, 0, 0, 0.1);
                    --slash-menu-bg: rgba(255, 255, 255, 0.95);
                    --slash-menu-border: rgba(0, 0, 0, 0.1);
                    --slash-menu-shadow: rgba(0, 0, 0, 0.12);
                    --slash-menu-hover: rgba(0, 102, 204, 0.08);
                    --slash-menu-text: #1d1d1f;
                    --image-error-bg: #ffebee;
                    --image-error-text: #c62828;
                }
                
                @media (prefers-color-scheme: dark) {
                    :root {
                        /* Dark mode colors */
                        --bg-color: #1e1e1e;
                        --text-color: #ffffff;
                        --secondary-text: #999999;
                        --placeholder-color: #666666;
                        --link-color: #66B3FF;
                        --code-bg: #2d2d2d;
                        --quote-border: #555;
                        --pullquote-border: #999;
                        --popover-bg: rgba(40, 40, 40, 0.95);
                        --popover-border: #66B3FF;
                        --popover-shadow: rgba(0, 0, 0, 0.5);
                        --button-secondary-bg: rgba(255, 255, 255, 0.1);
                        --button-secondary-text: #ddd;
                        --input-border: rgba(255, 255, 255, 0.2);
                        --slash-menu-bg: rgba(40, 40, 40, 0.95);
                        --slash-menu-border: rgba(255, 255, 255, 0.2);
                        --slash-menu-shadow: rgba(0, 0, 0, 0.3);
                        --slash-menu-hover: rgba(102, 179, 255, 0.15);
                        --slash-menu-text: #ffffff;
                        --image-error-bg: #5c2828;
                        --image-error-text: #ff9999;
                    }
                }
                
                body {
                    margin: 0;
                    padding: 20px;
                    font-family: var(--editor-font-family);
                    font-size: var(--editor-font-size);
                    background-color: var(--bg-color);
                    color: var(--text-color);
                    overflow-x: hidden;
                }
                
                .editor-container {
                    max-width: 100%;
                    margin: 0 auto;
                    overflow-x: hidden;
                }
                
                .wp-block-editor__container {
                    background: var(--bg-color);
                    max-width: 100%;
                    overflow-x: hidden;
                }
                
                .block-editor-writing-flow {
                    height: auto !important;
                    max-width: 100%;
                    overflow-x: hidden;
                }
                
                /* Native-looking blocks without backgrounds */
                .wp-block {
                    margin: 0.4em 0;
                    position: relative;
                    padding: 4px;
                    border-radius: 4px;
                    transition: background-color 0.15s ease;
                    max-width: 100%;
                    box-sizing: border-box;
                }
                
                /* Remove hover background for more native feel */
                .wp-block:hover {
                    background-color: transparent;
                }
                
                .wp-block-content {
                    min-height: 1.5em;
                    font-family: var(--editor-font-family);
                    font-size: var(--editor-font-size);
                    line-height: 1.6;
                }
                
                .wp-block.is-focused .wp-block-content:empty:before {
                    content: "Type / for commands";
                    color: var(--placeholder-color);
                    font-style: italic;
                }
                
                /* Headings should also use the selected font */
                h1, h2, h3, h4, h5, h6 {
                    font-family: var(--editor-font-family);
                }
                
                /* Better paragraph spacing */
                p {
                    margin: 0;
                    line-height: 1.6;
                }
                
                /* List items with better spacing */
                ul, ol {
                    margin: 0.3em 0;
                    padding-left: 1.5em;
                }
                
                li {
                    line-height: 1.6;
                    margin: 0.2em 0;
                }
                
                /* Code blocks should always use monospace */
                pre.wp-block-content {
                    font-family: 'SF Mono', Monaco, 'Courier New', monospace !important;
                    line-height: 1.4;
                }
                
                /* Image blocks */
                .wp-block[data-type="image"] figure {
                    margin: 0.6em 0;
                    text-align: center;
                }
                
                .wp-block[data-type="image"] img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 4px;
                }
                
                /* WordPress-style image blocks */
                .wp-block-image {
                    margin: 0.6em 0;
                    max-width: 100%;
                    box-sizing: border-box;
                    overflow: hidden;
                }
                
                .wp-block-image figure {
                    margin: 0;
                    max-width: 100%;
                    width: 100%;
                    box-sizing: border-box;
                }
                
                .wp-block-image img {
                    max-width: 100%;
                    width: auto;
                    height: auto;
                    display: block;
                    border-radius: 4px;
                    box-sizing: border-box;
                }
                
                /* Ensure all figure elements are constrained */
                figure {
                    max-width: 100%;
                    margin: 0;
                    box-sizing: border-box;
                }
                
                /* Ensure all images in the editor are constrained */
                .block-editor-writing-flow img {
                    max-width: 100% !important;
                    height: auto !important;
                }
                
                .image-loading {
                    position: relative;
                    padding: 40px;
                    text-align: center;
                    color: #666;
                    background: #f5f5f5;
                    border-radius: 4px;
                    font-style: italic;
                    min-height: 200px;
                }
                
                /* Remove focus outlines */
                .wp-block.is-focused {
                    outline: none;
                }
                
                /* Native macOS-style slash command menu */
                .slash-command-menu {
                    position: fixed;
                    background: rgba(255, 255, 255, 0.95);
                    backdrop-filter: blur(20px);
                    border: 1px solid rgba(0, 0, 0, 0.1);
                    border-radius: 8px;
                    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
                    padding: 4px 0;
                    z-index: 1000;
                    min-width: 240px;
                    max-height: none;
                    overflow: visible;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
                }
                
                .slash-command-item {
                    padding: 8px 16px;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    font-size: 13px;
                    color: #1d1d1f;
                    transition: background-color 0.1s ease;
                }
                
                .slash-command-item:hover {
                    background-color: rgba(0, 122, 255, 0.08);
                }
                
                .slash-command-item:first-child {
                    margin-top: 4px;
                }
                
                .slash-command-item:last-child {
                    margin-bottom: 4px;
                }
                
                
                .loading {
                    text-align: center;
                    padding: 40px;
                    color: #666;
                }
                
                .error {
                    text-align: center;
                    padding: 40px;
                    color: #d32f2f;
                    background-color: #ffebee;
                    border-radius: 8px;
                    margin: 20px;
                }
                
                /* Link styles - v5.0 - Professional blue colors for visibility */
                a, 
                .wp-block-content a,
                .wp-block a,
                p a,
                div a,
                span a,
                [contenteditable] a {
                    color: #0066FF !important;
                    text-decoration: underline !important;
                    text-decoration-color: #0066FF !important;
                    border-bottom: none !important;
                    font-weight: 500 !important;
                    transition: color 0.2s ease !important;
                }
                
                @media (prefers-color-scheme: dark) {
                    a, 
                    .wp-block-content a,
                    .wp-block a,
                    p a,
                    div a,
                    span a,
                    [contenteditable] a {
                        color: #4DA6FF !important;
                        text-decoration-color: #4DA6FF !important;
                    }
                }
                
                a:hover, 
                .wp-block-content a:hover,
                .wp-block a:hover,
                p a:hover,
                div a:hover,
                span a:hover,
                [contenteditable] a:hover {
                    color: #0052CC !important;
                    text-decoration-color: #0052CC !important;
                }
                
                @media (prefers-color-scheme: dark) {
                    a:hover, 
                    .wp-block-content a:hover,
                    .wp-block a:hover,
                    p a:hover,
                    div a:hover,
                    span a:hover,
                    [contenteditable] a:hover {
                        color: #66B3FF !important;
                        text-decoration-color: #66B3FF !important;
                    }
                }
            </style>
        </head>
        <body>
            <div class="editor-container">
                <div id="gutenberg-editor" class="loading">
                    Loading Gutenberg Editor...
                </div>
            </div>
            
            <script>
                // Use the same enhanced implementation as iOS
                console.log('Initializing macOS Gutenberg Editor...');
                
                // Copy the full implementation from iOS version
                class GutenbergEditor {
                    constructor() {
                        console.log('GutenbergEditor: Constructor called');
                        this.content = `\(HTMLHandler.shared.decodeHTMLEntitiesManually(post.content).replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`;
                        this.blocks = [];
                        this.shouldAutoFocus = false; // Don't auto-focus on initial load
                        this.hasUserInteracted = false;
                        console.log('GutenbergEditor: About to call init()');
                        this.init();
                    }
                    
                    init() {
                        console.log('GutenbergEditor: init() called');
                        try {
                            console.log('GutenbergEditor: calling setupEditor()');
                            this.setupEditor();
                            console.log('GutenbergEditor: calling parseContent()');
                            this.parseContent();
                            console.log('GutenbergEditor: calling render()');
                            this.render();
                            console.log('GutenbergEditor: calling notifyReady()');
                            this.notifyReady();
                            console.log('GutenbergEditor: Initialization complete');
                        } catch (error) {
                            console.error('GutenbergEditor: Initialization error:', error);
                            this.handleError(error);
                        }
                    }
                    
                    setupEditor() {
                        this.container = document.getElementById('gutenberg-editor');
                        this.container.className = 'wp-block-editor__container';
                        this.container.innerHTML = '';
                        
                        // Create blocks container
                        this.blocksContainer = document.createElement('div');
                        this.blocksContainer.className = 'block-editor-writing-flow';
                        this.blocksContainer.style.minHeight = '200px';
                        this.blocksContainer.contentEditable = true;
                        this.blocksContainer.style.outline = 'none';
                        
                        this.container.appendChild(this.blocksContainer);
                        
                        // Setup slash command state
                        this.showingSlashCommands = false;
                        this.slashCommandMenu = null;
                        this.currentBlock = null;
                        this.handlingBackspace = false;
                        this.justHidSlashCommands = false;
                        
                        // Add unified event listeners to blocks container
                        this.setupContainerEventListeners();
                        
                        // Setup mutation observer for height changes
                        this.setupHeightObserver();
                    }
                    
                    setupContainerEventListeners() {
                        // Handle input events at container level
                        this.blocksContainer.addEventListener('input', (e) => {
                            // First check if the DOM structure has been altered (multi-block edit)
                            if (this.needsBlockStructureSync()) {
                                this.syncBlocksFromDOM();
                                return; // Let the sync handle the update
                            }
                            
                            const blockElement = this.findBlockElementFromEvent(e);
                            if (blockElement) {
                                const blockId = blockElement.getAttribute('data-block-id');
                                const block = this.blocks.find(b => b.id === blockId);
                                if (block) {
                                    window.webkit.messageHandlers.editorError.postMessage(`INPUT event: blockId="${blockId}", target="${e.target.className}", showingSlash=${this.showingSlashCommands}`);
                                    this.handleBlockInput(e, block);
                                } else {
                                    window.webkit.messageHandlers.editorError.postMessage(`INPUT event: No block found for blockId="${blockId}"`);
                                }
                            } else {
                                window.webkit.messageHandlers.editorError.postMessage(`INPUT event: No block element found from target "${e.target.className}"`);
                            }
                        });
                        
                        // Handle keydown events at container level
                        this.blocksContainer.addEventListener('keydown', (e) => {
                            const blockElement = this.findBlockElementFromEvent(e);
                            if (blockElement) {
                                const blockIndex = parseInt(blockElement.getAttribute('data-block-index'));
                                window.webkit.messageHandlers.editorError.postMessage(`KEYDOWN event: key="${e.key}", text="${e.target.innerText}", showingSlash=${this.showingSlashCommands}`);
                                this.handleKeyDown(e, blockIndex);
                            }
                        });
                        
                        // Handle selection changes to update current block
                        document.addEventListener('selectionchange', () => {
                            const selection = window.getSelection();
                            if (selection.rangeCount > 0) {
                                const range = selection.getRangeAt(0);
                                const blockElement = this.findBlockElementFromNode(range.startContainer);
                                if (blockElement) {
                                    const blockId = blockElement.getAttribute('data-block-id');
                                    this.setCurrentBlock(blockId);
                                }
                            }
                        });
                        
                        // Handle clicks to update current block
                        this.blocksContainer.addEventListener('click', (e) => {
                            // Mark that user has interacted with the editor
                            if (!this.hasUserInteracted) {
                                this.hasUserInteracted = true;
                                this.shouldAutoFocus = true;
                            }
                            
                            const blockElement = this.findBlockElementFromEvent(e);
                            if (blockElement) {
                                const blockId = blockElement.getAttribute('data-block-id');
                                this.setCurrentBlock(blockId);
                                
                                // Don't call focusBlock here - let the browser handle natural cursor placement
                                // focusBlock always moves cursor to end, which interferes with clicking at specific positions
                            }
                        });
                        
                        // Handle focus events to detect user interaction
                        this.blocksContainer.addEventListener('focus', (e) => {
                            if (!this.hasUserInteracted) {
                                this.hasUserInteracted = true;
                                this.shouldAutoFocus = true;
                            }
                        }, true);
                    }
                    
                    findBlockElementFromEvent(event) {
                        let element = event.target;
                        
                        // If the target is the container itself, try to find the focused block
                        if (element === this.blocksContainer) {
                            const selection = window.getSelection();
                            if (selection.rangeCount > 0) {
                                const range = selection.getRangeAt(0);
                                element = range.startContainer.nodeType === Node.TEXT_NODE 
                                    ? range.startContainer.parentElement 
                                    : range.startContainer;
                            }
                        }
                        
                        while (element && element !== this.blocksContainer && !element.classList.contains('wp-block')) {
                            element = element.parentElement;
                        }
                        
                        return element && element.classList.contains('wp-block') ? element : null;
                    }
                    
                    findBlockElementFromNode(node) {
                        let element = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
                        while (element && !element.classList.contains('wp-block')) {
                            element = element.parentElement;
                        }
                        return element;
                    }
                    
                    needsBlockStructureSync() {
                        // Check if the number of block elements in DOM matches our internal blocks array
                        const domBlocks = this.blocksContainer.querySelectorAll('.wp-block');
                        return domBlocks.length !== this.blocks.length;
                    }
                    
                    syncBlocksFromDOM() {
                        window.webkit.messageHandlers.editorError.postMessage('Syncing blocks from DOM due to structure change');
                        
                        // Save current selection/cursor position
                        const selection = window.getSelection();
                        let cursorInfo = null;
                        
                        if (selection.rangeCount > 0) {
                            const range = selection.getRangeAt(0);
                            const blockElement = this.findBlockElementFromNode(range.startContainer);
                            
                            if (blockElement) {
                                const blockIndex = Array.from(this.blocksContainer.children).indexOf(blockElement);
                                const contentElement = blockElement.querySelector('.wp-block-content');
                                
                                if (contentElement) {
                                    // Calculate offset within the block
                                    const preCaretRange = range.cloneRange();
                                    preCaretRange.selectNodeContents(contentElement);
                                    preCaretRange.setEnd(range.endContainer, range.endOffset);
                                    const offset = preCaretRange.toString().length;
                                    
                                    cursorInfo = {
                                        blockIndex: blockIndex,
                                        offset: offset,
                                        collapsed: range.collapsed
                                    };
                                }
                            }
                        }
                        
                        const domBlocks = this.blocksContainer.querySelectorAll('.wp-block');
                        const newBlocks = [];
                        
                        domBlocks.forEach((blockElement, index) => {
                            const contentElement = blockElement.querySelector('.wp-block-content');
                            if (contentElement) {
                                const blockId = blockElement.getAttribute('data-block-id');
                                const existingBlock = this.blocks.find(b => b.id === blockId);
                                
                                if (existingBlock) {
                                    // Update existing block with current content
                                    existingBlock.content = contentElement.innerHTML;
                                    newBlocks.push(existingBlock);
                                } else {
                                    // Create new block from DOM element
                                    const tagName = contentElement.tagName.toLowerCase();
                                    let blockType = 'paragraph';
                                    
                                    // Determine block type from tag
                                    switch (tagName) {
                                        case 'h1': blockType = 'heading-1'; break;
                                        case 'h2': blockType = 'heading-2'; break;
                                        case 'h3': blockType = 'heading-3'; break;
                                        case 'pre': blockType = 'code'; break;
                                        case 'blockquote': blockType = 'quote'; break;
                                        case 'ul': blockType = 'list'; break;
                                        case 'ol': blockType = 'ordered-list'; break;
                                    }
                                    
                                    newBlocks.push({
                                        id: this.generateBlockId(),
                                        type: blockType,
                                        content: contentElement.innerHTML,
                                        attributes: {}
                                    });
                                }
                            }
                        });
                        
                        // Update internal blocks array
                        this.blocks = newBlocks;
                        
                        // Instead of full re-render, just update block attributes
                        this.updateBlockAttributes();
                        
                        // Restore cursor position if we had one
                        if (cursorInfo && cursorInfo.blockIndex < this.blocksContainer.children.length) {
                            const blockElement = this.blocksContainer.children[cursorInfo.blockIndex];
                            const contentElement = blockElement.querySelector('.wp-block-content');
                            
                            if (contentElement) {
                                // Focus the container first
                                this.blocksContainer.focus();
                                
                                // Set cursor at the saved position
                                const textNode = this.getTextNodeAtOffset(contentElement, cursorInfo.offset);
                                if (textNode.node) {
                                    const range = document.createRange();
                                    range.setStart(textNode.node, textNode.offset);
                                    range.collapse(true);
                                    
                                    const sel = window.getSelection();
                                    sel.removeAllRanges();
                                    sel.addRange(range);
                                }
                                
                                // Check if we need to show slash commands after sync
                                const text = contentElement.innerText.trim();
                                if (text === '/') {
                                    const block = this.blocks[cursorInfo.blockIndex];
                                    if (block) {
                                        window.webkit.messageHandlers.editorError.postMessage(`Showing slash commands after sync for block ${cursorInfo.blockIndex}`);
                                        this.showSlashCommands(cursorInfo.blockIndex);
                                    }
                                }
                            }
                        }
                        
                        // Notify of content change
                        this.handleContentChange();
                    }
                    
                    getTextNodeAtOffset(element, offset) {
                        let currentOffset = 0;
                        let targetNode = null;
                        let targetOffset = 0;
                        
                        const walk = (node) => {
                            if (node.nodeType === Node.TEXT_NODE) {
                                const length = node.textContent.length;
                                if (currentOffset + length >= offset) {
                                    targetNode = node;
                                    targetOffset = offset - currentOffset;
                                    return true;
                                }
                                currentOffset += length;
                            } else if (node.nodeType === Node.ELEMENT_NODE) {
                                for (let child of node.childNodes) {
                                    if (walk(child)) return true;
                                }
                            }
                            return false;
                        };
                        
                        walk(element);
                        
                        // If we didn't find a text node, try to use the last available position
                        if (!targetNode && element.lastChild) {
                            if (element.lastChild.nodeType === Node.TEXT_NODE) {
                                targetNode = element.lastChild;
                                targetOffset = element.lastChild.textContent.length;
                            } else {
                                // Create a text node if needed
                                targetNode = document.createTextNode('');
                                element.appendChild(targetNode);
                                targetOffset = 0;
                            }
                        }
                        
                        return { node: targetNode, offset: targetOffset };
                    }
                    
                    updateBlockAttributes() {
                        // Update block attributes without re-rendering
                        const domBlocks = this.blocksContainer.querySelectorAll('.wp-block');
                        
                        domBlocks.forEach((blockElement, index) => {
                            if (index < this.blocks.length) {
                                const block = this.blocks[index];
                                blockElement.setAttribute('data-block-id', block.id);
                                blockElement.setAttribute('data-block-index', index);
                                blockElement.setAttribute('data-block-type', block.type);
                            }
                        });
                    }
                    
                    parseContent() {
                        if (!this.content || this.content.trim() === '') {
                            this.blocks = [{
                                id: this.generateBlockId(),
                                type: 'paragraph',
                                content: '',
                                attributes: {}
                            }];
                            return;
                        }
                        
                        // Parse HTML content into blocks
                        this.blocks = this.parseHTMLToBlocks(this.content);
                        
                        if (this.blocks.length === 0) {
                            this.blocks = [{
                                id: this.generateBlockId(),
                                type: 'paragraph',
                                content: '',
                                attributes: {}
                            }];
                        }
                    }
                    
                    render() {
                        // Save current block before clearing
                        const previousCurrentBlock = this.currentBlock;
                        
                        this.blocksContainer.innerHTML = '';
                        
                        this.blocks.forEach((block, index) => {
                            const blockElement = this.createBlockElement(block, index);
                            this.blocksContainer.appendChild(blockElement);
                        });
                        
                        // Only restore focus if user has interacted with the editor
                        if (this.hasUserInteracted) {
                            if (previousCurrentBlock) {
                                const blockIndex = this.blocks.findIndex(b => b.id === previousCurrentBlock);
                                if (blockIndex >= 0) {
                                    this.focusBlock(blockIndex);
                                } else if (this.blocks.length > 0 && this.shouldAutoFocus) {
                                    this.focusBlock(0);
                                }
                            } else if (this.blocks.length > 0 && this.shouldAutoFocus) {
                                this.focusBlock(0);
                            }
                        }
                    }
                    
                    handleContentChange() {
                        // Serialize blocks to WordPress format with block comments
                        const wpContent = this.serializeBlocksToWordPress();
                        
                        const text = this.blocks.map(block => {
                            const tempDiv = document.createElement('div');
                            tempDiv.innerHTML = block.content;
                            return tempDiv.textContent || tempDiv.innerText || '';
                        }).join('\\n\\n');
                        
                        // Update content with WordPress formatted blocks
                        this.content = wpContent;
                        
                        // Notify native app with WordPress formatted content
                        this.notifyContentUpdate(wpContent);
                        this.updateHeight();
                    }
                    
                    serializeBlocksToWordPress() {
                        return this.blocks.map(block => {
                            let blockName = '';
                            let attrs = '';
                            
                            // Map block types to WordPress block names
                            switch (block.type) {
                                case 'paragraph':
                                    blockName = 'paragraph';
                                    break;
                                case 'heading-1':
                                    blockName = 'heading';
                                    attrs = ' {"level":1}';
                                    break;
                                case 'heading-2':
                                    blockName = 'heading';
                                    attrs = ' {"level":2}';
                                    break;
                                case 'heading-3':
                                    blockName = 'heading';
                                    attrs = ' {"level":3}';
                                    break;
                                case 'heading-4':
                                    blockName = 'heading';
                                    attrs = ' {"level":4}';
                                    break;
                                case 'heading-5':
                                    blockName = 'heading';
                                    attrs = ' {"level":5}';
                                    break;
                                case 'heading-6':
                                    blockName = 'heading';
                                    attrs = ' {"level":6}';
                                    break;
                                case 'list':
                                    blockName = 'list';
                                    break;
                                case 'ordered-list':
                                    blockName = 'list';
                                    attrs = ' {"ordered":true}';
                                    break;
                                case 'quote':
                                    blockName = 'quote';
                                    break;
                                case 'pullquote':
                                    blockName = 'pullquote';
                                    break;
                                case 'code':
                                    blockName = 'code';
                                    break;
                                case 'image':
                                    blockName = 'image';
                                    if (block.attributes && block.attributes.id) {
                                        attrs = ` {"id":${block.attributes.id}}`;
                                    }
                                    break;
                                default:
                                    blockName = 'paragraph';
                            }
                            
                            // Get appropriate HTML tag for content
                            const tagName = this.getBlockTagName(block.type);
                            const content = `<${tagName}>${block.content}</${tagName}>`;
                            
                            // Return WordPress block format with comments
                            return `<!-- wp:${blockName}${attrs} -->\\n${content}\\n<!-- /wp:${blockName} -->`;
                        }).join('\\n\\n');
                    }
                    
                    // Add all the other methods - this is getting long, so I'll add the key ones
                    generateBlockId() {
                        return 'block-' + Math.random().toString(36).substr(2, 9);
                    }
                    
                    createBlockElement(block, index) {
                        const blockElement = document.createElement('div');
                        blockElement.className = 'wp-block';
                        blockElement.setAttribute('data-block-id', block.id);
                        blockElement.setAttribute('data-block-type', block.type);
                        blockElement.setAttribute('data-block-index', index);
                        
                        const contentElement = this.createContentElement(block);
                        blockElement.appendChild(contentElement);
                        
                        // Add click handler for image blocks
                        if (block.type === 'image') {
                            blockElement.style.cursor = 'pointer';
                            blockElement.tabIndex = 0; // Make it focusable
                            blockElement.addEventListener('click', (e) => {
                                e.preventDefault();
                                e.stopPropagation();
                                
                                // Set this as the current block index
                                this.currentBlockIndex = index;
                                this.setCurrentBlock(block.id);
                                
                                // Focus the block element itself
                                blockElement.focus();
                                
                                window.webkit.messageHandlers.editorError.postMessage(`Image block clicked: ${block.id}, index: ${index}`);
                            });
                            
                            // Handle keyboard events on the image block
                            blockElement.addEventListener('keydown', (e) => {
                                if (e.key === 'Enter') {
                                    e.preventDefault();
                                    this.handleEnterKey(index);
                                }
                            });
                        }
                        
                        return blockElement;
                    }
                    
                    createContentElement(block) {
                        const element = document.createElement(this.getBlockTagName(block.type));
                        element.className = 'wp-block-content';
                        element.style.outline = 'none';
                        
                        // Special handling for different block types
                        if (block.type === 'image') {
                            // Image blocks are not editable
                            element.contentEditable = 'false';
                            if (block.attributes.uploading) {
                                element.innerHTML = block.content || '<div class="image-loading">Uploading image...</div>';
                            } else {
                                element.innerHTML = block.content || '';
                            }
                            // Add wp-block-image class for proper styling
                            element.className += ' wp-block-image';
                        } else if (block.type === 'list' || block.type === 'ordered-list') {
                            element.innerHTML = block.content || '<li></li>';
                            
                            // List-specific setup for first item focus
                            if (block.type === 'list' || block.type === 'ordered-list') {
                                // Focus handling is now managed at container level
                                this.setCurrentBlock(block.id);
                            }
                        } else {
                            element.innerHTML = block.content || '';
                            // Focus handling is now managed at container level
                        }
                        
                        // Apply block-specific attributes
                        this.applyBlockAttributes(element, block);
                        
                        // Individual block event listeners are now handled at container level
                        
                        return element;
                    }
                    
                    getBlockTagName(type) {
                        const tags = {
                            'paragraph': 'p',
                            'heading': 'h2',
                            'heading-1': 'h1',
                            'heading-2': 'h2', 
                            'heading-3': 'h3',
                            'heading-4': 'h4',
                            'heading-5': 'h5',
                            'heading-6': 'h6',
                            'code': 'pre',
                            'quote': 'blockquote',
                            'pullquote': 'blockquote',
                            'list': 'ul',
                            'ordered-list': 'ol',
                            'image': 'figure'
                        };
                        return tags[type] || 'p';
                    }
                    
                    applyBlockAttributes(element, block) {
                        switch (block.type) {
                            case 'code':
                                element.style.backgroundColor = 'var(--code-bg)';
                                element.style.padding = '1em';
                                element.style.fontFamily = 'monospace';
                                element.style.borderRadius = '4px';
                                break;
                            case 'pullquote':
                                element.style.fontSize = '1.5em';
                                element.style.fontStyle = 'italic';
                                element.style.textAlign = 'center';
                                element.style.padding = '1.5em 1em';
                                element.style.borderLeft = '4px solid var(--pullquote-border)';
                                break;
                            case 'quote':
                                element.style.borderLeft = '4px solid var(--quote-border)';
                                element.style.paddingLeft = '1em';
                                element.style.fontStyle = 'italic';
                                break;
                            case 'list':
                            case 'ordered-list':
                                element.style.paddingLeft = '1.5em';
                                element.style.margin = '0.2em 0';
                                break;
                        }
                    }
                    
                    handleBlockInput(event, block) {
                        const blockIndex = this.getBlockIndex(block.id);
                        
                        // Find the block content element
                        const blockElement = this.findBlockElementFromEvent(event);
                        const contentElement = blockElement ? blockElement.querySelector('.wp-block-content') : null;
                        
                        if (!contentElement) return;
                        
                        const content = contentElement.innerHTML;
                        
                        // Update block content
                        this.blocks[blockIndex].content = content;
                        
                        // Skip slash command processing if we just hid slash commands via backspace
                        if (this.justHidSlashCommands) {
                            this.justHidSlashCommands = false;
                            this.handleContentChange();
                            return;
                        }
                        
                        // Handle slash commands
                        const text = contentElement.innerText;
                        if (text.startsWith('/')) {
                            if (text.length === 1) {
                                // Show slash commands when text is exactly '/'
                                this.showSlashCommands(blockIndex);
                            } else {
                                // Filter slash commands when text is '/something'
                                this.filterSlashCommands(text.substring(1), blockIndex);
                            }
                        } else if (this.showingSlashCommands) {
                            // Hide slash commands when text doesn't start with '/'
                            this.hideSlashCommands();
                        }
                        
                        this.handleContentChange();
                    }
                    
                    getBlockIndex(blockId) {
                        return this.blocks.findIndex(block => block.id === blockId);
                    }
                    
                    setCurrentBlock(blockId) {
                        // Remove is-focused class from all blocks
                        const allBlocks = this.blocksContainer.querySelectorAll('.wp-block');
                        allBlocks.forEach(block => block.classList.remove('is-focused'));
                        
                        // Add is-focused class to the current block
                        if (blockId) {
                            const blockElement = this.blocksContainer.querySelector(`[data-block-id="${blockId}"]`);
                            if (blockElement) {
                                blockElement.classList.add('is-focused');
                                window.webkit.messageHandlers.editorError.postMessage(`Set focus to block: ${blockId}, has is-focused: ${blockElement.classList.contains('is-focused')}`);
                            }
                        }
                        
                        this.currentBlock = blockId;
                    }
                    
                    focusBlock(index) {
                        if (index >= 0 && index < this.blocks.length) {
                            const blockElement = this.blocksContainer.children[index];
                            const contentElement = blockElement.querySelector('.wp-block-content');
                            const block = this.blocks[index];
                            
                            if (contentElement) {
                                // Update current block
                                const blockId = blockElement.getAttribute('data-block-id');
                                this.setCurrentBlock(blockId);
                                
                                // Skip cursor placement for non-editable blocks
                                if (block.type === 'image') {
                                    // Just set focus to container, don't try to place cursor
                                    this.blocksContainer.focus();
                                } else {
                                    // Focus the container first
                                    this.blocksContainer.focus();
                                    // Place cursor at end of the block
                                    const range = document.createRange();
                                    const sel = window.getSelection();
                                    range.selectNodeContents(contentElement);
                                    range.collapse(false);
                                    sel.removeAllRanges();
                                    sel.addRange(range);
                                }
                            }
                        }
                    }
                    
                    handleKeyDown(event, blockIndex) {
                        window.webkit.messageHandlers.editorError.postMessage(`KeyDown event: key="${event.key}", metaKey=${event.metaKey}, ctrlKey=${event.ctrlKey}, showingSlashCommands: ${this.showingSlashCommands}`);
                        
                        // Handle Cmd+K for links before other key handling
                        if (event.key === 'k' && (event.metaKey || event.ctrlKey) && !event.shiftKey) {
                            event.preventDefault();
                            event.stopPropagation();
                            window.webkit.messageHandlers.editorError.postMessage(`Cmd+K detected, showing link popover for block ${blockIndex}`);
                            this.showLinkPopover(blockIndex);
                            return;
                        }
                        
                        // Handle text formatting shortcuts (Cmd+B, Cmd+I, Cmd+U)
                        if ((event.metaKey || event.ctrlKey) && !event.shiftKey && !event.altKey) {
                            let handled = false;
                            switch (event.key.toLowerCase()) {
                                case 'b':
                                    event.preventDefault();
                                    document.execCommand('bold', false, null);
                                    handled = true;
                                    break;
                                case 'i':
                                    event.preventDefault();
                                    document.execCommand('italic', false, null);
                                    handled = true;
                                    break;
                                case 'u':
                                    event.preventDefault();
                                    document.execCommand('underline', false, null);
                                    handled = true;
                                    break;
                            }
                            
                            if (handled) {
                                // Trigger content update after formatting
                                this.handleContentChange();
                                return;
                            }
                        }
                        
                        if (this.showingSlashCommands) {
                            this.handleSlashCommandKeydown(event);
                            return;
                        }
                        
                        const block = this.blocks[blockIndex];
                        
                        switch (event.key) {
                            case 'Enter':
                                if (!event.shiftKey) {
                                    event.preventDefault();
                                    this.handleEnterKey(blockIndex);
                                } else {
                                    // Shift+Enter always creates a new block, even in lists
                                    event.preventDefault();
                                    const newBlock = {
                                        id: this.generateBlockId(),
                                        type: 'paragraph',
                                        content: '',
                                        attributes: {}
                                    };
                                    
                                    this.blocks.splice(blockIndex + 1, 0, newBlock);
                                    this.render();
                                    this.focusBlock(blockIndex + 1);
                                }
                                break;
                            case 'Backspace':
                                // Handle slash menu hiding FIRST before any other processing
                                if (this.showingSlashCommands) {
                                    const element = event.target;
                                    const text = element.innerText;
                                    window.webkit.messageHandlers.editorError.postMessage(`Backspace with slash menu visible. Text: "${text}"`);
                                    
                                    // Prevent default AND stop propagation to prevent input event
                                    event.preventDefault();
                                    event.stopPropagation();
                                    event.stopImmediatePropagation();
                                    
                                    // Hide slash commands immediately
                                    this.hideSlashCommands();
                                    this.justHidSlashCommands = true;
                                    
                                    // Manually handle the backspace
                                    const selection = window.getSelection();
                                    const range = selection.getRangeAt(0);
                                    
                                    if (range.startOffset > 0) {
                                        // Delete the character before the cursor
                                        range.setStart(range.startContainer, range.startOffset - 1);
                                        range.deleteContents();
                                        
                                        // Update the block content
                                        const newContent = element.innerHTML;
                                        this.blocks[blockIndex].content = newContent;
                                        
                                        // Manually trigger content change without going through input handler
                                        this.handleContentChange();
                                    }
                                    
                                    window.webkit.messageHandlers.editorError.postMessage('Slash menu hidden and backspace handled manually');
                                    return;
                                }
                                
                                // Handle normal backspace behavior
                                this.handleBackspaceKey(event, blockIndex);
                                break;
                            case 'ArrowUp':
                                if (this.isAtBlockStart(blockIndex)) {
                                    this.focusBlock(blockIndex - 1);
                                    event.preventDefault();
                                }
                                break;
                            case 'ArrowDown':
                                if (this.isAtBlockEnd(blockIndex)) {
                                    this.focusBlock(blockIndex + 1);
                                    event.preventDefault();
                                }
                                break;
                            case '/':
                                // Slash command detection is handled in handleBlockInput
                                break;
                        }
                    }
                    
                    // Continue with essential methods
                    handleEnterKey(blockIndex) {
                        const block = this.blocks[blockIndex];
                        
                        // Special handling for image blocks - always create new paragraph below
                        if (block.type === 'image') {
                            const newBlock = {
                                id: this.generateBlockId(),
                                type: 'paragraph',
                                content: '',
                                attributes: {}
                            };
                            
                            this.blocks.splice(blockIndex + 1, 0, newBlock);
                            this.render();
                            this.focusBlock(blockIndex + 1);
                            this.handleContentChange();
                            return;
                        }
                        
                        // Special handling for list blocks
                        if (block.type === 'list' || block.type === 'ordered-list') {
                            const selection = window.getSelection();
                            const anchorNode = selection.anchorNode;
                            
                            // Find the current list item
                            let currentLi = anchorNode;
                            while (currentLi && currentLi.tagName !== 'LI') {
                                currentLi = currentLi.parentNode;
                            }
                            
                            if (currentLi) {
                                const liContent = currentLi.textContent.trim();
                                
                                // If current list item is empty, exit the list
                                if (liContent === '') {
                                    // Remove the empty list item
                                    currentLi.remove();
                                    
                                    // Update block content
                                    const blockElement = this.blocksContainer.children[blockIndex].querySelector('.wp-block-content');
                                    block.content = blockElement.innerHTML;
                                    
                                    // Create new paragraph block
                                    const newBlock = {
                                        id: this.generateBlockId(),
                                        type: 'paragraph',
                                        content: '',
                                        attributes: {}
                                    };
                                    
                                    this.blocks.splice(blockIndex + 1, 0, newBlock);
                                    this.render();
                                    this.focusBlock(blockIndex + 1);
                                    return;
                                }
                                
                                // If current list item has content, create new list item
                                const newLi = document.createElement('li');
                                newLi.innerHTML = '';
                                
                                // Insert after current list item
                                currentLi.parentNode.insertBefore(newLi, currentLi.nextSibling);
                                
                                // Update block content
                                const blockElement = this.blocksContainer.children[blockIndex].querySelector('.wp-block-content');
                                block.content = blockElement.innerHTML;
                                
                                // Focus the new list item
                                const range = document.createRange();
                                const sel = window.getSelection();
                                range.setStart(newLi, 0);
                                range.collapse(true);
                                sel.removeAllRanges();
                                sel.addRange(range);
                                
                                // Update content
                                this.handleContentChange();
                                return;
                            }
                        }
                        
                        // Default behavior for non-list blocks
                        const newBlock = {
                            id: this.generateBlockId(),
                            type: 'paragraph',
                            content: '',
                            attributes: {}
                        };
                        
                        this.blocks.splice(blockIndex + 1, 0, newBlock);
                        this.render();
                        this.focusBlock(blockIndex + 1);
                    }
                    
                    handleBackspaceKey(event, blockIndex) {
                        const block = this.blocks[blockIndex];
                        const element = event.target;
                        
                        // Only handle block deletion if:
                        // 1. Block is empty 
                        // 2. Not the first block
                        // 3. Cursor is at the beginning of the block
                        const selection = window.getSelection();
                        const isAtStart = selection.anchorOffset === 0;
                        
                        if (this.isBlockEmpty(blockIndex) && blockIndex > 0 && isAtStart) {
                            event.preventDefault();
                            this.deleteBlock(blockIndex);
                            this.focusBlock(blockIndex - 1);
                        }
                    }
                    
                    isBlockEmpty(blockIndex) {
                        const block = this.blocks[blockIndex];
                        return !block.content || block.content.trim() === '';
                    }
                    
                    isAtBlockStart(blockIndex) {
                        const selection = window.getSelection();
                        return selection.anchorOffset === 0;
                    }
                    
                    isAtBlockEnd(blockIndex) {
                        const selection = window.getSelection();
                        const element = selection.anchorNode;
                        return selection.anchorOffset === element.textContent.length;
                    }
                    
                    deleteBlock(blockIndex) {
                        if (this.blocks.length > 1) {
                            this.blocks.splice(blockIndex, 1);
                            this.render();
                            this.handleContentChange();
                        }
                    }
                    
                    // Slash Commands System
                    showSlashCommands(blockIndex) {
                        window.webkit.messageHandlers.editorError.postMessage(`showSlashCommands called for block ${blockIndex}`);
                        this.showingSlashCommands = true;
                        this.currentBlockIndex = blockIndex;
                        this.createSlashCommandMenu(blockIndex);
                        window.webkit.messageHandlers.editorError.postMessage(`showSlashCommands completed, showingSlashCommands: ${this.showingSlashCommands}`);
                    }
                    
                    createSlashCommandMenu(blockIndex) {
                        // Remove existing menu if it exists, but don't reset showingSlashCommands flag
                        if (this.slashCommandMenu) {
                            document.body.removeChild(this.slashCommandMenu);
                            this.slashCommandMenu = null;
                        }
                        
                        const commands = [
                            { name: 'Paragraph', type: 'paragraph', icon: '¶' },
                            { name: 'Heading 1', type: 'heading-1', icon: 'H1' },
                            { name: 'Heading 2', type: 'heading-2', icon: 'H2' },
                            { name: 'Heading 3', type: 'heading-3', icon: 'H3' },
                            { name: 'Bulleted List', type: 'list', icon: '•' },
                            { name: 'Numbered List', type: 'ordered-list', icon: '1.' },
                            { name: 'Code', type: 'code', icon: '</>' },
                            { name: 'Quote', type: 'quote', icon: '"' },
                            { name: 'Pullquote', type: 'pullquote', icon: '❝' },
                            { name: 'Image', type: 'image', icon: '🖼' }
                        ];
                        
                        this.slashCommandMenu = document.createElement('div');
                        this.slashCommandMenu.className = 'slash-command-menu';
                        this.slashCommandMenu.style.cssText = `
                            position: absolute;
                            background: var(--slash-menu-bg);
                            backdrop-filter: blur(20px);
                            border: 1px solid var(--slash-menu-border);
                            border-radius: 8px;
                            box-shadow: 0 8px 32px var(--slash-menu-shadow);
                            padding: 4px 0;
                            z-index: 1000;
                            min-width: 240px;
                            max-height: none;
                            overflow: visible;
                            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
                        `;
                        
                        // Track selected index
                        this.selectedCommandIndex = 0;
                        
                        commands.forEach((command, index) => {
                            const item = document.createElement('div');
                            item.className = 'slash-command-item';
                            item.setAttribute('data-command-index', index);
                            item.setAttribute('data-command-type', command.type);
                            item.style.cssText = `
                                padding: 8px 16px;
                                cursor: pointer;
                                display: flex;
                                align-items: center;
                                gap: 12px;
                                font-size: 13px;
                                color: var(--slash-menu-text);
                                transition: background-color 0.1s ease;
                                margin: 2px 0;
                            `;
                            
                            // Auto-select first item
                            if (index === 0) {
                                item.style.backgroundColor = 'var(--slash-menu-hover)';
                                item.classList.add('selected');
                            }
                            
                            item.innerHTML = `
                                <span style="font-size: 14px;">${command.icon}</span>
                                <span>${command.name}</span>
                            `;
                            
                            item.addEventListener('click', () => {
                                this.executeSlashCommand(command.type, blockIndex);
                            });
                            
                            item.addEventListener('mouseover', () => {
                                this.selectCommandItem(index);
                            });
                            
                            this.slashCommandMenu.appendChild(item);
                        });
                        
                        // Position the menu
                        const blockElement = this.blocksContainer.children[blockIndex];
                        const rect = blockElement.getBoundingClientRect();
                        this.slashCommandMenu.style.left = rect.left + 'px';
                        this.slashCommandMenu.style.top = (rect.bottom + 5) + 'px';
                        
                        document.body.appendChild(this.slashCommandMenu);
                    }
                    
                    selectCommandItem(index) {
                        const items = this.slashCommandMenu.querySelectorAll('.slash-command-item');
                        
                        // Clear previous selection
                        items.forEach((item, i) => {
                            if (i === index) {
                                item.style.backgroundColor = 'var(--slash-menu-hover)';
                                item.classList.add('selected');
                            } else {
                                item.style.backgroundColor = 'transparent';
                                item.classList.remove('selected');
                            }
                        });
                        
                        this.selectedCommandIndex = index;
                    }
                    
                    hideSlashCommands() {
                        window.webkit.messageHandlers.editorError.postMessage(`hideSlashCommands called, menu exists: ${!!this.slashCommandMenu}`);
                        if (this.slashCommandMenu) {
                            document.body.removeChild(this.slashCommandMenu);
                            this.slashCommandMenu = null;
                        }
                        this.showingSlashCommands = false;
                        window.webkit.messageHandlers.editorError.postMessage(`hideSlashCommands completed, showingSlashCommands: ${this.showingSlashCommands}`);
                    }
                    
                    executeSlashCommand(blockType, blockIndex) {
                        // Clear the slash command text from the block
                        this.blocks[blockIndex].content = '';
                        
                        // Special handling for image blocks
                        if (blockType === 'image') {
                            this.hideSlashCommands();
                            this.showImagePicker(blockIndex);
                            return;
                        }
                        
                        this.blocks[blockIndex].type = blockType;
                        
                        // Set appropriate content for list types
                        if (blockType === 'list' || blockType === 'ordered-list') {
                            this.blocks[blockIndex].content = '<li></li>';
                        } else {
                            this.blocks[blockIndex].content = '';
                        }
                        
                        this.hideSlashCommands();
                        this.render();
                        this.focusBlock(blockIndex);
                    }
                    
                    showImagePicker(blockIndex) {
                        window.webkit.messageHandlers.editorError.postMessage('showImagePicker called for block ' + blockIndex);
                        
                        // Request native image picker
                        window.webkit.messageHandlers.requestImagePicker.postMessage({
                            blockIndex: blockIndex,
                            blockId: this.blocks[blockIndex].id
                        });
                        
                        // Update block to show placeholder while waiting
                        this.blocks[blockIndex].type = 'image';
                        this.blocks[blockIndex].content = '<div class="image-loading">Select an image...</div>';
                        this.blocks[blockIndex].attributes = {
                            selecting: true
                        };
                        this.render();
                    }
                    
                    handleImageFile(file, blockIndex) {
                        // First, create a placeholder image block with loading state
                        this.blocks[blockIndex].type = 'image';
                        this.blocks[blockIndex].content = '<div class="image-loading">Uploading image...</div>';
                        this.blocks[blockIndex].attributes = {
                            uploading: true
                        };
                        this.render();
                        
                        // Read the file as data URL for immediate preview
                        const reader = new FileReader();
                        reader.onload = (e) => {
                            const dataUrl = e.target.result;
                            
                            // Update block with preview
                            this.blocks[blockIndex].content = `<img src="${dataUrl}" alt="${file.name}" style="max-width: 100%; height: auto;" />`;
                            this.blocks[blockIndex].attributes = {
                                dataUrl: dataUrl,
                                fileName: file.name,
                                uploading: true
                            };
                            this.render();
                            
                            // Notify native app to handle the actual upload
                            window.webkit.messageHandlers.imageUpload.postMessage({
                                blockId: this.blocks[blockIndex].id,
                                blockIndex: blockIndex,
                                dataUrl: dataUrl,
                                fileName: file.name,
                                fileSize: file.size,
                                mimeType: file.type
                            });
                        };
                        
                        reader.readAsDataURL(file);
                    }
                    
                    // Called from native app after successful upload
                    updateImageBlock(blockId, imageUrl, imageId) {
                        const blockIndex = this.blocks.findIndex(b => b.id === blockId);
                        if (blockIndex >= 0) {
                            this.blocks[blockIndex].content = `<figure class="wp-block-image"><img src="${imageUrl}" alt="" /></figure>`;
                            this.blocks[blockIndex].attributes = {
                                id: imageId,
                                url: imageUrl,
                                uploading: false
                            };
                            this.render();
                            this.handleContentChange();
                        }
                    }
                    
                    handleSlashCommandKeydown(event) {
                        if (!this.slashCommandMenu) return;
                        
                        const visibleItems = Array.from(this.slashCommandMenu.querySelectorAll('.slash-command-item'))
                            .filter(item => item.style.display !== 'none');
                        
                        switch (event.key) {
                            case 'Escape':
                                event.preventDefault();
                                this.hideSlashCommands();
                                break;
                                
                            case 'Enter':
                                event.preventDefault();
                                // Execute selected command
                                const selectedItem = this.slashCommandMenu.querySelector('.slash-command-item.selected');
                                if (selectedItem) {
                                    selectedItem.click();
                                }
                                break;
                                
                            case 'ArrowUp':
                                event.preventDefault();
                                if (visibleItems.length > 0) {
                                    // Find current selected item in visible items
                                    let currentVisibleIndex = visibleItems.findIndex(item => item.classList.contains('selected'));
                                    if (currentVisibleIndex === -1) currentVisibleIndex = 0;
                                    
                                    let newVisibleIndex = currentVisibleIndex - 1;
                                    if (newVisibleIndex < 0) {
                                        newVisibleIndex = visibleItems.length - 1;
                                    }
                                    
                                    const itemIndex = parseInt(visibleItems[newVisibleIndex].getAttribute('data-command-index'));
                                    this.selectCommandItem(itemIndex);
                                }
                                break;
                                
                            case 'ArrowDown':
                                event.preventDefault();
                                if (visibleItems.length > 0) {
                                    // Find current selected item in visible items
                                    let currentVisibleIndex = visibleItems.findIndex(item => item.classList.contains('selected'));
                                    if (currentVisibleIndex === -1) currentVisibleIndex = -1;
                                    
                                    let newVisibleIndex = currentVisibleIndex + 1;
                                    if (newVisibleIndex >= visibleItems.length) {
                                        newVisibleIndex = 0;
                                    }
                                    
                                    const itemIndex = parseInt(visibleItems[newVisibleIndex].getAttribute('data-command-index'));
                                    this.selectCommandItem(itemIndex);
                                }
                                break;
                        }
                    }
                    
                    filterSlashCommands(query, blockIndex) {
                        if (!this.slashCommandMenu) {
                            this.createSlashCommandMenu(blockIndex);
                        }
                        
                        const items = this.slashCommandMenu.querySelectorAll('.slash-command-item');
                        let firstVisibleIndex = -1;
                        let hasVisibleItems = false;
                        
                        items.forEach((item, index) => {
                            const text = item.textContent.toLowerCase();
                            const visible = text.includes(query.toLowerCase());
                            item.style.display = visible ? 'flex' : 'none';
                            
                            if (visible && firstVisibleIndex === -1) {
                                firstVisibleIndex = index;
                                hasVisibleItems = true;
                            }
                        });
                        
                        // Auto-select first visible item after filtering
                        if (hasVisibleItems) {
                            this.selectCommandItem(firstVisibleIndex);
                        }
                    }
                    
                    
                    moveBlockUp(blockIndex) {
                        if (blockIndex > 0) {
                            const block = this.blocks.splice(blockIndex, 1)[0];
                            this.blocks.splice(blockIndex - 1, 0, block);
                            this.render();
                            this.focusBlock(blockIndex - 1);
                            this.handleContentChange();
                        }
                    }
                    
                    moveBlockDown(blockIndex) {
                        if (blockIndex < this.blocks.length - 1) {
                            const block = this.blocks.splice(blockIndex, 1)[0];
                            this.blocks.splice(blockIndex + 1, 0, block);
                            this.render();
                            this.focusBlock(blockIndex + 1);
                            this.handleContentChange();
                        }
                    }
                    
                    duplicateBlock(blockIndex) {
                        const originalBlock = this.blocks[blockIndex];
                        const duplicatedBlock = {
                            id: this.generateBlockId(),
                            type: originalBlock.type,
                            content: originalBlock.content,
                            attributes: { ...originalBlock.attributes }
                        };
                        this.blocks.splice(blockIndex + 1, 0, duplicatedBlock);
                        this.render();
                        this.focusBlock(blockIndex + 1);
                        this.handleContentChange();
                    }
                    
                    // HTML Parsing
                    parseHTMLToBlocks(html) {
                        const blocks = [];
                        
                        // Check if content has WordPress block comments
                        if (html.includes('<!-- wp:')) {
                            // Parse WordPress block format
                            const blockRegex = /<!-- wp:([a-z-]+)(?:\\s+(\\{[^}]*\\}))? -->\\n?([\\s\\S]*?)\\n?<!-- \\/wp:\\1 -->/g;
                            let match;
                            
                            while ((match = blockRegex.exec(html)) !== null) {
                                const [fullMatch, blockName, attrsJson, content] = match;
                                let type = 'paragraph';
                                let attributes = {};
                                
                                // Parse attributes if present
                                if (attrsJson) {
                                    try {
                                        attributes = JSON.parse(attrsJson);
                                    } catch (e) {
                                        console.error('Failed to parse block attributes:', e);
                                    }
                                }
                                
                                // Map WordPress block names to our types
                                switch (blockName) {
                                    case 'paragraph':
                                        type = 'paragraph';
                                        break;
                                    case 'heading':
                                        const level = attributes.level || 2;
                                        type = `heading-${level}`;
                                        break;
                                    case 'list':
                                        type = attributes.ordered ? 'ordered-list' : 'list';
                                        break;
                                    case 'quote':
                                        type = 'quote';
                                        break;
                                    case 'pullquote':
                                        type = 'pullquote';
                                        break;
                                    case 'code':
                                        type = 'code';
                                        break;
                                    case 'image':
                                        type = 'image';
                                        // Extract image URL from content
                                        const imgMatch = content.match(/<img[^>]+src=["']([^"']+)["']/);
                                        if (imgMatch) {
                                            attributes.url = imgMatch[1];
                                        }
                                        break;
                                }
                                
                                // Extract inner content from HTML tags
                                const tempDiv = document.createElement('div');
                                tempDiv.innerHTML = content;
                                const innerContent = tempDiv.querySelector('p, h1, h2, h3, h4, h5, h6, pre, blockquote, ul, ol, figure');
                                
                                blocks.push({
                                    id: this.generateBlockId(),
                                    type: type,
                                    content: innerContent ? innerContent.innerHTML : content,
                                    attributes: attributes
                                });
                            }
                        } else {
                            // Fallback to parsing regular HTML
                            const div = document.createElement('div');
                            div.innerHTML = html;
                            
                            Array.from(div.children).forEach(element => {
                                const block = this.elementToBlock(element);
                                if (block) {
                                    blocks.push(block);
                                }
                            });
                            
                            // If no blocks found, create paragraph blocks from text content
                            if (blocks.length === 0 && html.trim()) {
                                const paragraphs = html.split('\\n\\n').filter(p => p.trim());
                                paragraphs.forEach(p => {
                                    blocks.push({
                                        id: this.generateBlockId(),
                                        type: 'paragraph',
                                        content: p.trim(),
                                        attributes: {}
                                    });
                                });
                            }
                        }
                        
                        return blocks;
                    }
                    
                    elementToBlock(element) {
                        const tagName = element.tagName.toLowerCase();
                        const content = element.innerHTML;
                        
                        let type = 'paragraph';
                        let attributes = {};
                        
                        switch (tagName) {
                            case 'h1': type = 'heading-1'; break;
                            case 'h2': type = 'heading-2'; break;
                            case 'h3': type = 'heading-3'; break;
                            case 'h4': type = 'heading-4'; break;
                            case 'h5': type = 'heading-5'; break;
                            case 'h6': type = 'heading-6'; break;
                            case 'pre': type = 'code'; break;
                            case 'blockquote': 
                                type = element.className.includes('pullquote') ? 'pullquote' : 'quote';
                                break;
                            case 'ul': type = 'list'; break;
                            case 'ol': type = 'ordered-list'; break;
                            case 'figure':
                                // Check if it's an image block
                                if (element.className.includes('wp-block-image')) {
                                    type = 'image';
                                    const img = element.querySelector('img');
                                    if (img) {
                                        attributes.url = img.src;
                                        attributes.alt = img.alt || '';
                                    }
                                }
                                break;
                        }
                        
                        return {
                            id: this.generateBlockId(),
                            type: type,
                            content: content,
                            attributes: attributes
                        };
                    }
                    
                    setupHeightObserver() {
                        const observer = new MutationObserver(() => {
                            this.updateHeight();
                        });
                        
                        observer.observe(this.container, {
                            childList: true,
                            subtree: true,
                            attributes: true
                        });
                        
                        // Initial height update
                        setTimeout(() => this.updateHeight(), 100);
                    }
                    
                    updateHeight() {
                        const height = Math.max(this.container.scrollHeight + 40, 300);
                        window.webkit.messageHandlers.heightUpdate.postMessage(height);
                    }
                    
                    notifyContentUpdate(html) {
                        window.webkit.messageHandlers.contentUpdate.postMessage({
                            html: html,
                            text: this.content
                        });
                    }
                    
                    notifyReady() {
                        window.webkit.messageHandlers.editorReady.postMessage('ready');
                    }
                    
                    handleError(error) {
                        console.error('Gutenberg Editor Error:', error);
                        this.container.innerHTML = `
                            <div class="error">
                                <h3>Editor Error</h3>
                                <p>${error.message}</p>
                            </div>
                        `;
                        window.webkit.messageHandlers.editorError.postMessage(error.message);
                    }
                    
                    // Public methods for native app integration
                    setContent(content) {
                        this.content = content;
                        this.parseContent();
                        // Reset user interaction flag when new content is set
                        this.hasUserInteracted = false;
                        this.shouldAutoFocus = false;
                        this.render();
                    }
                    
                    getContent() {
                        return {
                            html: this.container.innerHTML,
                            text: this.content
                        };
                    }
                }
                
                // Initialize editor
                function initializeEditor() {
                    console.log('Initializing GutenbergEditor...');
                    window.webkit.messageHandlers.editorError.postMessage('JavaScript is running - attempting to initialize editor');
                    try {
                        window.gutenbergEditor = new GutenbergEditor();
                        console.log('GutenbergEditor initialized successfully');
                        window.webkit.messageHandlers.editorError.postMessage('GutenbergEditor initialized successfully');
                    } catch (error) {
                        console.error('Failed to initialize GutenbergEditor:', error);
                        window.webkit.messageHandlers.editorError.postMessage('Failed to initialize GutenbergEditor: ' + error.message);
                    }
                }
                
                if (document.readyState === 'loading') {
                    console.log('Document still loading, waiting for DOMContentLoaded...');
                    document.addEventListener('DOMContentLoaded', initializeEditor);
                } else {
                    console.log('Document already loaded, initializing immediately...');
                    initializeEditor();
                }
            </script>
        </body>
        </html>
        """
    }
    
    // Same Coordinator class as iOS version
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
        var parent: GutenbergWebViewRepresentable
        private var contentUpdateTimer: Timer?
        private var lastPendingContent: String?
        
        init(_ parent: GutenbergWebViewRepresentable) {
            self.parent = parent
        }
        
        deinit {
            // Save any pending changes before deallocation
            savePendingChanges()
        }
        
        func savePendingChanges() {
            // Cancel timer and save immediately
            contentUpdateTimer?.invalidate()
            contentUpdateTimer = nil
            
            // If we have pending content, save it immediately
            if let pendingContent = lastPendingContent {
                DispatchQueue.main.async {
                    self.parent.post.content = pendingContent
                    self.parent.post.modifiedDate = Date()
                    self.lastPendingContent = nil
                    
                    // SwiftData automatically saves changes
                    DebugLogger.shared.log("Saved pending changes on cleanup", level: .debug, source: "WebView")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            
            // Inject JavaScript to capture console.log messages
            let consoleLogScript = """
                if (!window.consoleLogInjected) {
                    window.consoleLogInjected = true;
                    const originalLog = console.log;
                    console.log = function(...args) {
                        originalLog.apply(console, args);
                        try {
                            window.webkit.messageHandlers.consoleLog.postMessage(args.map(arg => String(arg)).join(' '));
                        } catch (e) {
                            originalLog('Failed to send log to native:', e);
                        }
                    };
                }
            """
            
            webView.evaluateJavaScript(consoleLogScript) { _, error in
                if let error = error {
                    DebugLogger.shared.log("Failed to inject console log handler: \(error)", level: .error, source: "WebView")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
                self.parent.errorMessage = error.localizedDescription
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            DispatchQueue.main.async {
                switch message.name {
                case "contentUpdate":
                    self.handleContentUpdate(message.body)
                case "heightUpdate":
                    self.handleHeightUpdate(message.body)
                case "editorReady":
                    self.handleEditorReady()
                case "editorError":
                    self.handleEditorError(message.body)
                case "imageUpload":
                    self.handleImageUpload(message.body)
                case "requestImagePicker":
                    self.handleImagePickerRequest(message.body)
                case "consoleLog":
                    if let logMessage = message.body as? String {
                        DebugLogger.shared.log("[JS Console] \(logMessage)", level: .debug, source: "WebView")
                    }
                default:
                    break
                }
            }
        }
        
        private func handleContentUpdate(_ body: Any) {
            guard let data = body as? [String: Any],
                  let html = data["html"] as? String else { return }
            
            // Log the content being saved
            DebugLogger.shared.log("=== Content Update from Editor ===", level: .debug, source: "GutenbergWebView")
            DebugLogger.shared.log("HTML content: \(html)", level: .debug, source: "GutenbergWebView")
            
            // Check for specific patterns that might cause issues
            if html.contains("\\n") {
                DebugLogger.shared.log("Content contains escaped newlines (\\n)", level: .warning, source: "GutenbergWebView")
            }
            if html.contains("&#") || html.contains("&lt;") || html.contains("&gt;") {
                DebugLogger.shared.log("Content contains HTML entities", level: .warning, source: "GutenbergWebView")
            }
            
            // Store the pending content
            lastPendingContent = html
            
            // Debounce content updates
            contentUpdateTimer?.invalidate()
            contentUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.parent.post.content = html
                    self.parent.post.modifiedDate = Date()
                    self.lastPendingContent = nil
                    
                    DebugLogger.shared.log("Content saved to post model", level: .debug, source: "GutenbergWebView")
                }
            }
        }
        
        private func handleHeightUpdate(_ body: Any) {
            guard let height = body as? CGFloat else { return }
            parent.dynamicHeight = max(height, 300)
        }
        
        private func handleEditorReady() {
            parent.isLoading = false
            parent.hasError = false
            
            // Add additional keyboard shortcut handling after editor is ready
            if let webView = parent.webViewRef {
                let script = """
                    // Add additional Cmd+K listener after editor is ready
                    document.addEventListener('keydown', (e) => {
                        if (e.key === 'k' && (e.metaKey || e.ctrlKey) && !e.shiftKey && !e.altKey) {
                            e.preventDefault();
                            e.stopPropagation();
                            
                            window.webkit.messageHandlers.editorError.postMessage('Editor-ready Cmd+K detected - using simple prompt');
                            
                            const selection = window.getSelection();
                            if (!selection.rangeCount || selection.isCollapsed) {
                                alert('Please select some text first to create a link');
                                return false;
                            }
                            
                            const selectedText = selection.toString();
                            const url = prompt('Enter URL for "' + selectedText + '":', 'https://');
                            
                            if (url && url !== '' && url !== 'https://') {
                                try {
                                    const range = selection.getRangeAt(0);
                                    
                                    // Create link element
                                    const link = document.createElement('a');
                                    link.href = url;
                                    link.textContent = selectedText;
                                    
                                    // Replace selection with link
                                    range.deleteContents();
                                    range.insertNode(link);
                                    
                                    // Update content
                                    if (window.gutenbergEditor) {
                                        // Find which block was edited
                                        let blockElement = link.parentElement;
                                        while (blockElement && !blockElement.classList.contains('wp-block')) {
                                            blockElement = blockElement.parentElement;
                                        }
                                        
                                        if (blockElement) {
                                            const blockIndex = parseInt(blockElement.getAttribute('data-block-index'));
                                            const contentElement = blockElement.querySelector('.wp-block-content');
                                            if (window.gutenbergEditor.blocks[blockIndex] && contentElement) {
                                                window.gutenbergEditor.blocks[blockIndex].content = contentElement.innerHTML;
                                                window.gutenbergEditor.handleContentChange();
                                            }
                                        }
                                    }
                                    
                                    window.webkit.messageHandlers.editorError.postMessage(`Link created: ${url}`);
                                } catch (error) {
                                    window.webkit.messageHandlers.editorError.postMessage(`Error creating link: ${error.message}`);
                                }
                            }
                            
                            return false;
                        }
                    }, true);
                    
                    window.webkit.messageHandlers.editorError.postMessage('Added editor-ready Cmd+K listener');
                """
                
                webView.evaluateJavaScript(script) { _, error in
                    if let error = error {
                        DebugLogger.shared.log("Failed to add Cmd+K listener: \(error)", level: .error, source: "WebView")
                    }
                }
            }
        }
        
        private func handleEditorError(_ body: Any) {
            let message = body as? String ?? "Unknown error occurred"
            parent.isLoading = false
            parent.hasError = true
            parent.errorMessage = message
            
            // Send debug message to DebugLogger
            DebugLogger.shared.log(message, level: .error, source: "WebView")
        }
        
        private func handleImageUpload(_ body: Any) {
            guard let data = body as? [String: Any],
                  let blockId = data["blockId"] as? String,
                  let dataUrl = data["dataUrl"] as? String,
                  let fileName = data["fileName"] as? String else {
                DebugLogger.shared.log("Invalid image upload data", level: .error, source: "WebView")
                return
            }
            
            // For now, we'll just use the data URL directly
            // In a real implementation, you would upload to WordPress media library
            DebugLogger.shared.log("Image selected: \(fileName)", level: .info, source: "WebView")
            
            // Update the image block with the data URL
            // In production, this would be the uploaded image URL from WordPress
            if let webView = parent.webViewRef {
                let escapedUrl = dataUrl.replacingOccurrences(of: "'", with: "\\'")
                let script = """
                    if (window.gutenbergEditor && window.gutenbergEditor.updateImageBlock) {
                        window.gutenbergEditor.updateImageBlock('\(blockId)', '\(escapedUrl)', 'temp-id');
                    }
                """
                webView.evaluateJavaScript(script) { _, error in
                    if let error = error {
                        DebugLogger.shared.log("Error updating image block: \(error)", level: .error, source: "WebView")
                    }
                }
            }
        }
        
        private func handleImagePickerRequest(_ body: Any) {
            guard let data = body as? [String: Any],
                  let blockIndex = data["blockIndex"] as? Int,
                  let _ = data["blockId"] as? String else {
                DebugLogger.shared.log("Invalid image picker request data", level: .error, source: "WebView")
                return
            }
            
            #if os(macOS)
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [.image]
            panel.prompt = "Select Image"
            
            if panel.runModal() == .OK, let url = panel.url {
                    // Read the image file
                    if let imageData = try? Data(contentsOf: url) {
                        let mimeType = url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
                        let fileName = url.lastPathComponent
                        
                        // First, show a preview with data URL while uploading
                        let base64String = imageData.base64EncodedString()
                        let dataUrl = "data:\(mimeType);base64,\(base64String)"
                        
                        if let webView = self.parent.webViewRef {
                            // Show preview immediately
                            let escapedUrl = dataUrl.replacingOccurrences(of: "'", with: "\\'")
                            let previewScript = """
                                if (window.gutenbergEditor) {
                                    window.gutenbergEditor.blocks[\(blockIndex)].type = 'image';
                                    window.gutenbergEditor.blocks[\(blockIndex)].content = '<div class="image-loading" style="position: relative;"><img src="\(escapedUrl)" alt="\(fileName)" style="max-width: 100%; height: auto; opacity: 0.5;" /><div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); background: rgba(255,255,255,0.9); padding: 10px; border-radius: 4px;">Uploading to WordPress...</div></div>';
                                    window.gutenbergEditor.blocks[\(blockIndex)].attributes = {
                                        uploading: true,
                                        fileName: '\(fileName)'
                                    };
                                    window.gutenbergEditor.render();
                                }
                            """
                            webView.evaluateJavaScript(previewScript) { _, _ in }
                        }
                        
                        // Upload to WordPress if we have site configuration
                        if let siteConfig = self.parent.siteConfig {
                            DebugLogger.shared.log("Site configuration found. Site URL: \(siteConfig.siteURL), Username: \(siteConfig.username)", level: .info, source: "WebView")
                            Task {
                                do {
                                    DebugLogger.shared.log("Starting image upload to WordPress: \(fileName), Size: \(imageData.count) bytes, MIME: \(mimeType)", level: .info, source: "WebView")
                                    
                                    // Retrieve password from keychain
                                    guard let password = try? KeychainManager.shared.retrieve(for: siteConfig.keychainIdentifier),
                                          !password.isEmpty else {
                                        throw WordPressError.unauthorized
                                    }
                                    
                                    let media = try await WordPressAPI.shared.uploadImage(
                                        siteURL: siteConfig.siteURL,
                                        username: siteConfig.username,
                                        password: password,
                                        imageData: imageData,
                                        filename: fileName,
                                        mimeType: mimeType
                                    )
                                    
                                    DebugLogger.shared.log("Image uploaded successfully. URL: \(media.sourceUrl)", level: .info, source: "WebView")
                                    
                                    // Update the block with the real URL
                                    await MainActor.run {
                                        if let webView = self.parent.webViewRef {
                                            let escapedUrl = media.sourceUrl.replacingOccurrences(of: "'", with: "\\'")
                                            let altText = media.altText.isEmpty ? fileName : media.altText.replacingOccurrences(of: "'", with: "\\'")
                                            let updateScript = """
                                                if (window.gutenbergEditor) {
                                                    window.gutenbergEditor.blocks[\(blockIndex)].content = '<figure class="wp-block-image"><img src="\(escapedUrl)" alt="\(altText)" /></figure>';
                                                    window.gutenbergEditor.blocks[\(blockIndex)].attributes = {
                                                        id: \(media.id),
                                                        url: '\(escapedUrl)',
                                                        alt: '\(altText)',
                                                        uploading: false
                                                    };
                                                    window.gutenbergEditor.render();
                                                    window.gutenbergEditor.handleContentChange();
                                                }
                                            """
                                            webView.evaluateJavaScript(updateScript) { _, error in
                                                if let error = error {
                                                    DebugLogger.shared.log("Error updating image block after upload: \(error)", level: .error, source: "WebView")
                                                }
                                            }
                                        }
                                    }
                                } catch {
                                    DebugLogger.shared.log("Failed to upload image: \(error)", level: .error, source: "WebView")
                                    
                                    // Show error state
                                    await MainActor.run {
                                        if let webView = self.parent.webViewRef {
                                            let errorScript = """
                                                if (window.gutenbergEditor) {
                                                    window.gutenbergEditor.blocks[\(blockIndex)].content = '<div class="image-error" style="padding: 20px; background: var(--image-error-bg); color: var(--image-error-text); border-radius: 4px;">Failed to upload image: \(error.localizedDescription)</div>';
                                                    window.gutenbergEditor.blocks[\(blockIndex)].attributes = {
                                                        error: true,
                                                        uploading: false
                                                    };
                                                    window.gutenbergEditor.render();
                                                }
                                            """
                                            webView.evaluateJavaScript(errorScript) { _, _ in }
                                        }
                                    }
                                }
                            }
                        } else {
                            // No site configuration, just use the data URL
                            DebugLogger.shared.log("No site configuration available, using data URL", level: .warning, source: "WebView")
                            if let webView = self.parent.webViewRef {
                                let escapedUrl = dataUrl.replacingOccurrences(of: "'", with: "\\'")
                                let script = """
                                    if (window.gutenbergEditor) {
                                        window.gutenbergEditor.blocks[\(blockIndex)].content = '<img src="\(escapedUrl)" alt="\(fileName)" style="max-width: 100%; height: auto;" />';
                                        window.gutenbergEditor.blocks[\(blockIndex)].attributes = {
                                            dataUrl: '\(escapedUrl)',
                                            fileName: '\(fileName)',
                                            uploading: false
                                        };
                                        window.gutenbergEditor.render();
                                        window.gutenbergEditor.handleContentChange();
                                    }
                                """
                                webView.evaluateJavaScript(script) { _, _ in }
                            }
                        }
                    }
                }
            #endif
        }
        
        func updateContent(_ content: String) {
            // Save any pending changes first
            self.savePendingChanges()
            
            // Update editor content through JavaScript
            guard let webView = parent.webViewRef else { return }
            
            let decodedContent = HTMLHandler.shared.decodeHTMLEntitiesManually(content)
            let escapedContent = decodedContent
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            
            let script = """
                if (window.gutenbergEditor) {
                    window.gutenbergEditor.setContent(`\(escapedContent)`);
                }
            """
            
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    DebugLogger.shared.log("Failed to update content: \(error)", level: .error, source: "WebView")
                } else {
                    DebugLogger.shared.log("Successfully updated content for new post", level: .debug, source: "WebView")
                }
            }
        }
        
        // MARK: - Native Context Menu Support
        
        @objc func moveBlockUp(_ sender: NSMenuItem) {
            guard let blockIndex = sender.representedObject as? Int else { return }
            executeBlockAction("moveBlockUp", blockIndex: blockIndex)
        }
        
        @objc func moveBlockDown(_ sender: NSMenuItem) {
            guard let blockIndex = sender.representedObject as? Int else { return }
            executeBlockAction("moveBlockDown", blockIndex: blockIndex)
        }
        
        @objc func deleteBlock(_ sender: NSMenuItem) {
            guard let blockIndex = sender.representedObject as? Int else { return }
            executeBlockAction("deleteBlock", blockIndex: blockIndex)
        }
        
        @objc func duplicateBlock(_ sender: NSMenuItem) {
            guard let blockIndex = sender.representedObject as? Int else { return }
            executeBlockAction("duplicateBlock", blockIndex: blockIndex)
        }
        
        private func executeBlockAction(_ action: String, blockIndex: Int) {
            // Get the webView from the parent's webViewRef
            guard let webView = parent.webViewRef else { return }
            
            let script = "window.gutenbergEditor?.\(action)(\(blockIndex))"
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    DebugLogger.shared.log("Failed to execute block action \(action): \(error)", level: .error, source: "WebView")
                }
            }
        }
        
        func showHyperlinkDialog(for selectedText: String) {
            // Create alert for hyperlink URL input
            let alert = NSAlert()
            alert.messageText = "Add Link"
            alert.informativeText = "Enter URL for \"\(selectedText)\""
            alert.alertStyle = .informational
            
            // Create URL input field
            let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            inputField.placeholderString = "https://example.com"
            
            // Check clipboard for URL
            if let clipboardString = NSPasteboard.general.string(forType: .string) {
                // Simple URL detection - check if it starts with http:// or https://
                if clipboardString.hasPrefix("http://") || clipboardString.hasPrefix("https://") {
                    inputField.stringValue = clipboardString
                }
            }
            
            alert.accessoryView = inputField
            alert.addButton(withTitle: "Add Link")
            alert.addButton(withTitle: "Cancel")
            
            // Make input field first responder
            alert.window.initialFirstResponder = inputField
            
            if alert.runModal() == .alertFirstButtonReturn {
                let urlString = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Validate URL
                guard !urlString.isEmpty else { return }
                
                // Add https:// if no protocol specified
                let finalURL = urlString.hasPrefix("http://") || urlString.hasPrefix("https://") 
                    ? urlString 
                    : "https://\(urlString)"
                
                // Apply hyperlink to selected text
                applyHyperlink(url: finalURL, to: selectedText)
            }
        }
        
        private func applyHyperlink(url: String, to selectedText: String) {
            guard let webView = parent.webViewRef else { return }
            
            // JavaScript to wrap selection in a link and notify content update
            let script = """
                (function() {
                    const selection = window.getSelection();
                    if (selection.rangeCount > 0) {
                        const range = selection.getRangeAt(0);
                        const link = document.createElement('a');
                        link.href = '\(url.replacingOccurrences(of: "'", with: "\\'"))';
                        link.textContent = '\(selectedText.replacingOccurrences(of: "'", with: "\\'"))';
                        
                        range.deleteContents();
                        range.insertNode(link);
                        
                        // Clear selection
                        selection.removeAllRanges();
                        
                        // Get the updated content and trigger content update
                        if (window.gutenbergEditor) {
                            // Get all blocks HTML
                            const container = document.querySelector('.editor-container');
                            if (container) {
                                const html = container.innerHTML;
                                
                                // Notify native app of content update
                                window.webkit.messageHandlers.contentUpdate.postMessage({
                                    html: html,
                                    text: container.innerText || ''
                                });
                            }
                        }
                    }
                })();
            """
            
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    DebugLogger.shared.log("Failed to apply hyperlink: \(error)", level: .error, source: "WebView")
                } else {
                    DebugLogger.shared.log("Successfully applied hyperlink to text: \(selectedText)", level: .info, source: "WebView")
                }
            }
        }
    }
}
#endif

// MARK: - Preview

struct GutenbergWebView_Previews: PreviewProvider {
    static var previews: some View {
        let post = Post(
            title: "Sample Post",
            content: "<p>This is a sample post content for testing the Gutenberg editor.</p>",
            status: .draft
        )
        
        return NavigationView {
            GutenbergWebView(
                post: post,
                typeface: "system",
                fontSize: 16,
                siteConfig: nil
            )
        }
    }
}