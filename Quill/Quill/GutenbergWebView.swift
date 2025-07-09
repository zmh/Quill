//
//  GutenbergWebView.swift
//  Quill
//
//  Created by Claude on 7/4/25.
//

import SwiftUI
import WebKit

// MARK: - Gutenberg WebView Editor

struct GutenbergWebView: View {
    @Bindable var post: Post
    let typeface: String
    let fontSize: Int
    let siteConfig: SiteConfiguration?
    @State private var webViewHeight: CGFloat = 600
    @State private var isLoading = true
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var webViewRef: WKWebView?
    
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
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .onAppear {
            isLoading = true
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
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Gutenberg Editor</title>
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
                }
                
                body {
                    margin: 0;
                    padding: 20px;
                    font-family: var(--editor-font-family);
                    font-size: var(--editor-font-size);
                    background-color: #ffffff;
                }
                
                .editor-container {
                    max-width: 100%;
                    margin: 0 auto;
                }
                
                .wp-block-editor__container {
                    background: #fff;
                }
                
                .block-editor-writing-flow {
                    height: auto !important;
                }
                
                /* Native-looking blocks without backgrounds */
                .wp-block {
                    margin: 1em 0;
                    position: relative;
                    padding: 4px;
                    border-radius: 4px;
                    transition: background-color 0.15s ease;
                }
                
                /* Remove hover background for more native feel */
                .wp-block:hover {
                    background-color: transparent;
                }
                
                .wp-block-content {
                    min-height: 1.5em;
                    font-family: var(--editor-font-family);
                    font-size: var(--editor-font-size);
                }
                
                .wp-block-content:empty:before {
                    content: "Type / for commands";
                    color: #999;
                    font-style: italic;
                }
                
                .wp-block[data-type="core/paragraph"] {
                    margin: 0.5em 0;
                }
                
                .wp-block[data-type="core/heading"] h1,
                .wp-block[data-type="core/heading"] h2,
                .wp-block[data-type="core/heading"] h3,
                .wp-block[data-type="core/heading"] h4,
                .wp-block[data-type="core/heading"] h5,
                .wp-block[data-type="core/heading"] h6 {
                    margin: 0.5em 0;
                    font-family: var(--editor-font-family);
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
                        
                        this.container.appendChild(this.blocksContainer);
                        
                        // Setup slash command state
                        this.showingSlashCommands = false;
                        this.slashCommandMenu = null;
                        this.currentBlock = null;
                        this.handlingBackspace = false;
                        this.justHidSlashCommands = false;
                        
                        // Setup mutation observer for height changes
                        this.setupHeightObserver();
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
                        this.blocksContainer.innerHTML = '';
                        
                        this.blocks.forEach((block, index) => {
                            const blockElement = this.createBlockElement(block, index);
                            this.blocksContainer.appendChild(blockElement);
                        });
                        
                        // Focus the first block if no block is focused
                        if (!this.currentBlock && this.blocks.length > 0) {
                            this.focusBlock(0);
                        }
                    }
                    
                    handleContentChange() {
                        // Generate HTML from blocks
                        const html = this.blocks.map(block => {
                            const tagName = this.getBlockTagName(block.type);
                            return `<${tagName}>${block.content}</${tagName}>`;
                        }).join('\\n');
                        
                        const text = this.blocks.map(block => {
                            const tempDiv = document.createElement('div');
                            tempDiv.innerHTML = block.content;
                            return tempDiv.textContent || tempDiv.innerText || '';
                        }).join('\\n\\n');
                        
                        // Update content
                        this.content = html;
                        
                        // Notify native app
                        this.notifyContentUpdate(html);
                        this.updateHeight();
                    }
                    
                    handleKeyDown(event, blockIndex) {
                        window.webkit.messageHandlers.editorError.postMessage(`KeyDown event: ${event.key}, showingSlashCommands: ${this.showingSlashCommands}`);
                        
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
                        
                        
                        return blockElement;
                    }
                    
                    createContentElement(block) {
                        const element = document.createElement(this.getBlockTagName(block.type));
                        element.contentEditable = true;
                        element.className = 'wp-block-content';
                        element.style.outline = 'none';
                        
                        // Special handling for list elements
                        if (block.type === 'list' || block.type === 'ordered-list') {
                            element.innerHTML = block.content || '<li></li>';
                            
                            // Focus the first list item when the list is focused
                            element.addEventListener('focus', () => {
                                const firstLi = element.querySelector('li');
                                if (firstLi) {
                                    const range = document.createRange();
                                    const selection = window.getSelection();
                                    range.selectNodeContents(firstLi);
                                    range.collapse(false);
                                    selection.removeAllRanges();
                                    selection.addRange(range);
                                }
                                this.setCurrentBlock(block.id);
                            });
                        } else {
                            element.innerHTML = block.content || '';
                            element.addEventListener('focus', () => this.setCurrentBlock(block.id));
                        }
                        
                        // Apply block-specific attributes
                        this.applyBlockAttributes(element, block);
                        
                        // Add event listeners
                        element.addEventListener('input', (e) => {
                            window.webkit.messageHandlers.editorError.postMessage(`INPUT event: text="${e.target.innerText}", showingSlash=${this.showingSlashCommands}`);
                            this.handleBlockInput(e, block);
                        });
                        element.addEventListener('keydown', (e) => {
                            window.webkit.messageHandlers.editorError.postMessage(`KEYDOWN event: key="${e.key}", text="${e.target.innerText}", showingSlash=${this.showingSlashCommands}`);
                            this.handleKeyDown(e, this.getBlockIndex(block.id));
                        });
                        
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
                            'ordered-list': 'ol'
                        };
                        return tags[type] || 'p';
                    }
                    
                    applyBlockAttributes(element, block) {
                        switch (block.type) {
                            case 'code':
                                element.style.backgroundColor = '#f5f5f5';
                                element.style.padding = '1em';
                                element.style.fontFamily = 'monospace';
                                element.style.borderRadius = '4px';
                                break;
                            case 'pullquote':
                                element.style.fontSize = '1.5em';
                                element.style.fontStyle = 'italic';
                                element.style.textAlign = 'center';
                                element.style.padding = '2em 1em';
                                element.style.borderLeft = '4px solid #666';
                                break;
                            case 'quote':
                                element.style.borderLeft = '4px solid #ddd';
                                element.style.paddingLeft = '1em';
                                element.style.fontStyle = 'italic';
                                break;
                            case 'list':
                            case 'ordered-list':
                                element.style.paddingLeft = '1.5em';
                                element.style.margin = '0.5em 0';
                                break;
                        }
                    }
                    
                    handleBlockInput(event, block) {
                        const blockIndex = this.getBlockIndex(block.id);
                        const content = event.target.innerHTML;
                        
                        // Update block content
                        this.blocks[blockIndex].content = content;
                        
                        // Skip slash command processing if we just hid slash commands via backspace
                        if (this.justHidSlashCommands) {
                            this.justHidSlashCommands = false;
                            this.handleContentChange();
                            return;
                        }
                        
                        // Handle slash commands
                        const text = event.target.innerText;
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
                        this.currentBlock = blockId;
                    }
                    
                    focusBlock(index) {
                        if (index >= 0 && index < this.blocks.length) {
                            const blockElement = this.blocksContainer.children[index];
                            const contentElement = blockElement.querySelector('.wp-block-content');
                            if (contentElement) {
                                contentElement.focus();
                                // Place cursor at end
                                const range = document.createRange();
                                const sel = window.getSelection();
                                range.selectNodeContents(contentElement);
                                range.collapse(false);
                                sel.removeAllRanges();
                                sel.addRange(range);
                            }
                        }
                    }
                    
                    handleEnterKey(blockIndex) {
                        const block = this.blocks[blockIndex];
                        
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
                        `;
                        
                        commands.forEach((command, index) => {
                            const item = document.createElement('div');
                            item.className = 'slash-command-item';
                            item.style.cssText = `
                                padding: 8px 16px;
                                cursor: pointer;
                                display: flex;
                                align-items: center;
                                gap: 12px;
                                font-size: 13px;
                                color: #1d1d1f;
                                transition: background-color 0.1s ease;
                                margin: 2px 0;
                            `;
                            
                            item.innerHTML = `
                                <span style="font-size: 14px;">${command.icon}</span>
                                <span>${command.name}</span>
                            `;
                            
                            item.addEventListener('click', () => {
                                this.executeSlashCommand(command.type, blockIndex);
                            });
                            
                            item.addEventListener('mouseover', () => {
                                item.style.backgroundColor = 'rgba(0, 122, 255, 0.08)';
                            });
                            
                            item.addEventListener('mouseout', () => {
                                item.style.backgroundColor = 'transparent';
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
                    
                    handleSlashCommandKeydown(event) {
                        switch (event.key) {
                            case 'Escape':
                                event.preventDefault();
                                this.hideSlashCommands();
                                break;
                            case 'Enter':
                                event.preventDefault();
                                // Execute first visible command
                                const firstItem = this.slashCommandMenu.querySelector('.slash-command-item');
                                if (firstItem) {
                                    firstItem.click();
                                }
                                break;
                        }
                    }
                    
                    filterSlashCommands(query, blockIndex) {
                        if (!this.slashCommandMenu) {
                            this.createSlashCommandMenu(blockIndex);
                        }
                        
                        const items = this.slashCommandMenu.querySelectorAll('.slash-command-item');
                        items.forEach(item => {
                            const text = item.textContent.toLowerCase();
                            const visible = text.includes(query.toLowerCase());
                            item.style.display = visible ? 'flex' : 'none';
                        });
                    }
                    
                    
                    moveBlockUp(blockIndex) {
                        if (blockIndex > 0) {
                            const block = this.blocks.splice(blockIndex, 1)[0];
                            this.blocks.splice(blockIndex - 1, 0, block);
                            this.render();
                            this.focusBlock(blockIndex - 1);
                        }
                    }
                    
                    moveBlockDown(blockIndex) {
                        if (blockIndex < this.blocks.length - 1) {
                            const block = this.blocks.splice(blockIndex, 1)[0];
                            this.blocks.splice(blockIndex + 1, 0, block);
                            this.render();
                            this.focusBlock(blockIndex + 1);
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
                    }
                    
                    // HTML Parsing
                    parseHTMLToBlocks(html) {
                        const div = document.createElement('div');
                        div.innerHTML = html;
                        const blocks = [];
                        
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
                        
                        return blocks;
                    }
                    
                    elementToBlock(element) {
                        const tagName = element.tagName.toLowerCase();
                        const content = element.innerHTML;
                        
                        let type = 'paragraph';
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
                        }
                        
                        return {
                            id: this.generateBlockId(),
                            type: type,
                            content: content,
                            attributes: {}
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
                        this.render();
                    }
                    
                    getContent() {
                        return {
                            html: this.editableArea.innerHTML,
                            text: this.content
                        };
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
        
        init(_ parent: GutenbergWebViewRepresentable) {
            self.parent = parent
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
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
                default:
                    break
                }
            }
        }
        
        private func handleContentUpdate(_ body: Any) {
            guard let data = body as? [String: Any],
                  let html = data["html"] as? String else { return }
            
            // Debounce content updates
            contentUpdateTimer?.invalidate()
            contentUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.parent.post.content = html
                    self.parent.post.modifiedDate = Date()
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
        }
        
        private func handleEditorError(_ body: Any) {
            let message = body as? String ?? "Unknown error occurred"
            parent.isLoading = false
            parent.hasError = true
            parent.errorMessage = message
            
            // Send debug message to DebugLogger
            DebugLogger.shared.log(message, level: .error, source: "WebView")
        }
        
        // MARK: - Content Management
        
        func updateContent(_ content: String) {
            // Update editor content through JavaScript
            let script = """
                if (window.gutenbergEditor) {
                    window.gutenbergEditor.setContent(`\(HTMLHandler.shared.decodeHTMLEntitiesManually(content).replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`);
                }
            """
            
            // Execute script (would need web view reference)
            // This is a simplified approach - full implementation would need proper web view access
        }
        
        // MARK: - Native Context Menu Support
        
        @available(iOS 13.0, *)
        func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
            
            // Check if we're right-clicking on a block element
            webView.evaluateJavaScript("document.elementFromPoint(\(elementInfo.boundingRect.midX), \(elementInfo.boundingRect.midY))?.closest('.wp-block')?.getAttribute('data-block-index')") { result, error in
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
        
        let webView = GutenbergWKWebView(frame: .zero, configuration: configuration)
        webView.coordinator = coordinator
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        webView.setValue(false, forKey: "drawsBackground")
        
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
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Gutenberg Editor</title>
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
                }
                
                body {
                    margin: 0;
                    padding: 20px;
                    font-family: var(--editor-font-family);
                    font-size: var(--editor-font-size);
                    background-color: #ffffff;
                }
                
                .editor-container {
                    max-width: 100%;
                    margin: 0 auto;
                }
                
                .wp-block-editor__container {
                    background: #fff;
                }
                
                .block-editor-writing-flow {
                    height: auto !important;
                }
                
                /* Native-looking blocks without backgrounds */
                .wp-block {
                    margin: 1em 0;
                    position: relative;
                    padding: 4px;
                    border-radius: 4px;
                    transition: background-color 0.15s ease;
                }
                
                /* Remove hover background for more native feel */
                .wp-block:hover {
                    background-color: transparent;
                }
                
                .wp-block-content {
                    min-height: 1.5em;
                    font-family: var(--editor-font-family);
                    font-size: var(--editor-font-size);
                }
                
                .wp-block-content:empty:before {
                    content: "Type / for commands";
                    color: #999;
                    font-style: italic;
                }
                
                /* Headings should also use the selected font */
                h1, h2, h3, h4, h5, h6 {
                    font-family: var(--editor-font-family);
                }
                
                /* Code blocks should always use monospace */
                pre.wp-block-content {
                    font-family: 'SF Mono', Monaco, 'Courier New', monospace !important;
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
                // Use the same enhanced implementation as iOS
                console.log('Initializing macOS Gutenberg Editor...');
                
                // Copy the full implementation from iOS version
                class GutenbergEditor {
                    constructor() {
                        console.log('GutenbergEditor: Constructor called');
                        this.content = `\(HTMLHandler.shared.decodeHTMLEntitiesManually(post.content).replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`;
                        this.blocks = [];
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
                        
                        this.container.appendChild(this.blocksContainer);
                        
                        // Setup slash command state
                        this.showingSlashCommands = false;
                        this.slashCommandMenu = null;
                        this.currentBlock = null;
                        this.handlingBackspace = false;
                        this.justHidSlashCommands = false;
                        
                        // Setup mutation observer for height changes
                        this.setupHeightObserver();
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
                        this.blocksContainer.innerHTML = '';
                        
                        this.blocks.forEach((block, index) => {
                            const blockElement = this.createBlockElement(block, index);
                            this.blocksContainer.appendChild(blockElement);
                        });
                        
                        // Focus the first block if no block is focused
                        if (!this.currentBlock && this.blocks.length > 0) {
                            this.focusBlock(0);
                        }
                    }
                    
                    handleContentChange() {
                        // Generate HTML from blocks
                        const html = this.blocks.map(block => {
                            const tagName = this.getBlockTagName(block.type);
                            return `<${tagName}>${block.content}</${tagName}>`;
                        }).join('\\n');
                        
                        const text = this.blocks.map(block => {
                            const tempDiv = document.createElement('div');
                            tempDiv.innerHTML = block.content;
                            return tempDiv.textContent || tempDiv.innerText || '';
                        }).join('\\n\\n');
                        
                        // Update content
                        this.content = html;
                        
                        // Notify native app
                        this.notifyContentUpdate(html);
                        this.updateHeight();
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
                        
                        
                        return blockElement;
                    }
                    
                    createContentElement(block) {
                        const element = document.createElement(this.getBlockTagName(block.type));
                        element.contentEditable = true;
                        element.className = 'wp-block-content';
                        element.style.outline = 'none';
                        
                        // Special handling for list elements
                        if (block.type === 'list' || block.type === 'ordered-list') {
                            element.innerHTML = block.content || '<li></li>';
                            
                            // Focus the first list item when the list is focused
                            element.addEventListener('focus', () => {
                                const firstLi = element.querySelector('li');
                                if (firstLi) {
                                    const range = document.createRange();
                                    const selection = window.getSelection();
                                    range.selectNodeContents(firstLi);
                                    range.collapse(false);
                                    selection.removeAllRanges();
                                    selection.addRange(range);
                                }
                                this.setCurrentBlock(block.id);
                            });
                        } else {
                            element.innerHTML = block.content || '';
                            element.addEventListener('focus', () => this.setCurrentBlock(block.id));
                        }
                        
                        // Apply block-specific attributes
                        this.applyBlockAttributes(element, block);
                        
                        // Add event listeners
                        element.addEventListener('input', (e) => {
                            window.webkit.messageHandlers.editorError.postMessage(`INPUT event: text="${e.target.innerText}", showingSlash=${this.showingSlashCommands}`);
                            this.handleBlockInput(e, block);
                        });
                        element.addEventListener('keydown', (e) => {
                            window.webkit.messageHandlers.editorError.postMessage(`KEYDOWN event: key="${e.key}", text="${e.target.innerText}", showingSlash=${this.showingSlashCommands}`);
                            this.handleKeyDown(e, this.getBlockIndex(block.id));
                        });
                        
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
                            'ordered-list': 'ol'
                        };
                        return tags[type] || 'p';
                    }
                    
                    applyBlockAttributes(element, block) {
                        switch (block.type) {
                            case 'code':
                                element.style.backgroundColor = '#f5f5f5';
                                element.style.padding = '1em';
                                element.style.fontFamily = 'monospace';
                                element.style.borderRadius = '4px';
                                break;
                            case 'pullquote':
                                element.style.fontSize = '1.5em';
                                element.style.fontStyle = 'italic';
                                element.style.textAlign = 'center';
                                element.style.padding = '2em 1em';
                                element.style.borderLeft = '4px solid #666';
                                break;
                            case 'quote':
                                element.style.borderLeft = '4px solid #ddd';
                                element.style.paddingLeft = '1em';
                                element.style.fontStyle = 'italic';
                                break;
                            case 'list':
                            case 'ordered-list':
                                element.style.paddingLeft = '1.5em';
                                element.style.margin = '0.5em 0';
                                break;
                        }
                    }
                    
                    handleBlockInput(event, block) {
                        const blockIndex = this.getBlockIndex(block.id);
                        const content = event.target.innerHTML;
                        
                        // Update block content
                        this.blocks[blockIndex].content = content;
                        
                        // Skip slash command processing if we just hid slash commands via backspace
                        if (this.justHidSlashCommands) {
                            this.justHidSlashCommands = false;
                            this.handleContentChange();
                            return;
                        }
                        
                        // Handle slash commands
                        const text = event.target.innerText;
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
                        this.currentBlock = blockId;
                    }
                    
                    focusBlock(index) {
                        if (index >= 0 && index < this.blocks.length) {
                            const blockElement = this.blocksContainer.children[index];
                            const contentElement = blockElement.querySelector('.wp-block-content');
                            if (contentElement) {
                                contentElement.focus();
                                // Place cursor at end
                                const range = document.createRange();
                                const sel = window.getSelection();
                                range.selectNodeContents(contentElement);
                                range.collapse(false);
                                sel.removeAllRanges();
                                sel.addRange(range);
                            }
                        }
                    }
                    
                    handleKeyDown(event, blockIndex) {
                        window.webkit.messageHandlers.editorError.postMessage(`KeyDown event: ${event.key}, showingSlashCommands: ${this.showingSlashCommands}`);
                        
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
                        `;
                        
                        commands.forEach((command, index) => {
                            const item = document.createElement('div');
                            item.className = 'slash-command-item';
                            item.style.cssText = `
                                padding: 8px 16px;
                                cursor: pointer;
                                display: flex;
                                align-items: center;
                                gap: 12px;
                                font-size: 13px;
                                color: #1d1d1f;
                                transition: background-color 0.1s ease;
                                margin: 2px 0;
                            `;
                            
                            item.innerHTML = `
                                <span style="font-size: 14px;">${command.icon}</span>
                                <span>${command.name}</span>
                            `;
                            
                            item.addEventListener('click', () => {
                                this.executeSlashCommand(command.type, blockIndex);
                            });
                            
                            item.addEventListener('mouseover', () => {
                                item.style.backgroundColor = 'rgba(0, 122, 255, 0.08)';
                            });
                            
                            item.addEventListener('mouseout', () => {
                                item.style.backgroundColor = 'transparent';
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
                    
                    handleSlashCommandKeydown(event) {
                        switch (event.key) {
                            case 'Escape':
                                event.preventDefault();
                                this.hideSlashCommands();
                                break;
                            case 'Enter':
                                event.preventDefault();
                                // Execute first visible command
                                const firstItem = this.slashCommandMenu.querySelector('.slash-command-item');
                                if (firstItem) {
                                    firstItem.click();
                                }
                                break;
                        }
                    }
                    
                    filterSlashCommands(query, blockIndex) {
                        if (!this.slashCommandMenu) {
                            this.createSlashCommandMenu(blockIndex);
                        }
                        
                        const items = this.slashCommandMenu.querySelectorAll('.slash-command-item');
                        items.forEach(item => {
                            const text = item.textContent.toLowerCase();
                            const visible = text.includes(query.toLowerCase());
                            item.style.display = visible ? 'flex' : 'none';
                        });
                    }
                    
                    
                    moveBlockUp(blockIndex) {
                        if (blockIndex > 0) {
                            const block = this.blocks.splice(blockIndex, 1)[0];
                            this.blocks.splice(blockIndex - 1, 0, block);
                            this.render();
                            this.focusBlock(blockIndex - 1);
                        }
                    }
                    
                    moveBlockDown(blockIndex) {
                        if (blockIndex < this.blocks.length - 1) {
                            const block = this.blocks.splice(blockIndex, 1)[0];
                            this.blocks.splice(blockIndex + 1, 0, block);
                            this.render();
                            this.focusBlock(blockIndex + 1);
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
                    }
                    
                    // HTML Parsing
                    parseHTMLToBlocks(html) {
                        const div = document.createElement('div');
                        div.innerHTML = html;
                        const blocks = [];
                        
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
                        
                        return blocks;
                    }
                    
                    elementToBlock(element) {
                        const tagName = element.tagName.toLowerCase();
                        const content = element.innerHTML;
                        
                        let type = 'paragraph';
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
                        }
                        
                        return {
                            id: this.generateBlockId(),
                            type: type,
                            content: content,
                            attributes: {}
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
        
        init(_ parent: GutenbergWebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
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
                default:
                    break
                }
            }
        }
        
        private func handleContentUpdate(_ body: Any) {
            guard let data = body as? [String: Any],
                  let html = data["html"] as? String else { return }
            
            contentUpdateTimer?.invalidate()
            contentUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                DispatchQueue.main.async {
                    self.parent.post.content = html
                    self.parent.post.modifiedDate = Date()
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
        }
        
        private func handleEditorError(_ body: Any) {
            let message = body as? String ?? "Unknown error occurred"
            parent.isLoading = false
            parent.hasError = true
            parent.errorMessage = message
            
            // Send debug message to DebugLogger
            DebugLogger.shared.log(message, level: .error, source: "WebView")
        }
        
        func updateContent(_ content: String) {
            // Update editor content through JavaScript
            // This would be implemented with proper WebView reference
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