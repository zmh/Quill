import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Block Editor Container View

struct BlockEditorView: View {
    @ObservedObject var document: BlockDocument
    @State private var showingBlockPicker = false
    @State private var draggedBlock: GutenbergBlock?
    
    var body: some View {
        VStack(spacing: 0) {
            editorScrollView
            toolbarView
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingBlockPicker = true }) {
                        Label("Add Block", systemImage: "plus")
                    }
                    
                    Divider()
                    
                    Section("Keyboard Shortcuts") {
                        Label("⌘+Space: Add Block", systemImage: "keyboard")
                        Label("⌘+Return: New Paragraph", systemImage: "keyboard")
                        Label("⌘+Backspace: Delete Block", systemImage: "keyboard")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingBlockPicker) {
            BlockPickerView(document: document)
        }
        .keyboardShortcut(.space, modifiers: [.command])
    }
    
    private var toolbarBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    private func deleteBlocks(offsets: IndexSet) {
        for index in offsets {
            let block = document.blocks[index]
            document.removeBlock(id: block.id)
        }
    }
    
    private func addNewParagraphBlock() {
        let newBlock = GutenbergBlock.paragraph("")
        document.addBlock(newBlock, after: document.selectedBlockID)
    }
    
    private func deleteSelectedBlock() {
        guard let selectedID = document.selectedBlockID else { return }
        document.removeBlock(id: selectedID)
    }
    
    // MARK: - View Components
    
    private var editorScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if document.blocks.isEmpty {
                    emptyStateView
                } else {
                    blocksListView
                    addBlockButtonView
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Start Writing")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Add your first block to begin")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                let newBlock = GutenbergBlock.paragraph("")
                document.addBlock(newBlock)
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Paragraph")
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .buttonStyle(QuillButtonStyle())
        }
        .padding(.top, 100)
    }
    
    private var blocksListView: some View {
        ForEach(document.blocks) { block in
            BlockRenderer(document: document, block: block)
                .onDrag {
                    draggedBlock = block
                    return NSItemProvider(object: block.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: BlockDropDelegate(
                    document: document,
                    draggedBlock: $draggedBlock,
                    targetBlock: block
                ))
        }
        .onDelete(perform: deleteBlocks)
    }
    
    private var addBlockButtonView: some View {
        AddBlockButton {
            showingBlockPicker = true
        }
        .padding(.top, 20)
    }
    
    private var toolbarView: some View {
        Group {
            if document.selectedBlockID != nil {
                BlockToolbar(document: document)
                    .background(toolbarBackgroundColor)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
            }
        }
    }
}

// MARK: - Add Block Button

struct AddBlockButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Add Block")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Block Toolbar

struct BlockToolbar: View {
    @ObservedObject var document: BlockDocument
    
    var selectedBlock: GutenbergBlock? {
        document.selectedBlock
    }
    
    var body: some View {
        HStack {
            if let block = selectedBlock {
                // Block type indicator
                Label(block.type.displayName, systemImage: block.type.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Block actions
                HStack(spacing: 16) {
                    Button(action: moveBlockUp) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(!canMoveUp)
                    
                    Button(action: moveBlockDown) {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(!canMoveDown)
                    
                    Button(action: duplicateBlock) {
                        Image(systemName: "doc.on.doc")
                    }
                    
                    Button(action: deleteBlock) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
    }
    
    private var canMoveUp: Bool {
        guard let block = selectedBlock,
              let index = document.blocks.firstIndex(where: { $0.id == block.id }) else {
            return false
        }
        return index > 0
    }
    
    private var canMoveDown: Bool {
        guard let block = selectedBlock,
              let index = document.blocks.firstIndex(where: { $0.id == block.id }) else {
            return false
        }
        return index < document.blocks.count - 1
    }
    
    private func moveBlockUp() {
        guard let block = selectedBlock,
              let index = document.blocks.firstIndex(where: { $0.id == block.id }),
              index > 0 else {
            return
        }
        
        document.blocks.swapAt(index, index - 1)
    }
    
    private func moveBlockDown() {
        guard let block = selectedBlock,
              let index = document.blocks.firstIndex(where: { $0.id == block.id }),
              index < document.blocks.count - 1 else {
            return
        }
        
        document.blocks.swapAt(index, index + 1)
    }
    
    private func duplicateBlock() {
        guard let block = selectedBlock else { return }
        
        let duplicatedBlock = GutenbergBlock(
            type: block.type,
            name: block.name,
            content: block.content,
            attributes: block.attributes,
            innerBlocks: block.innerBlocks
        )
        
        document.addBlock(duplicatedBlock, after: block.id)
    }
    
    private func deleteBlock() {
        guard let block = selectedBlock else { return }
        document.removeBlock(id: block.id)
    }
}

// MARK: - Block Picker View

struct BlockPickerView: View {
    @ObservedObject var document: BlockDocument
    @Environment(\.dismiss) private var dismiss
    
    let commonBlocks: [GutenbergBlockType] = [
        .paragraph, .heading, .list, .quote, .image, .separator, .code
    ]
    
    let layoutBlocks: [GutenbergBlockType] = [
        .columns, .group, .spacer, .cover
    ]
    
    let mediaBlocks: [GutenbergBlockType] = [
        .image, .gallery, .video, .audio, .embed
    ]
    
    let designBlocks: [GutenbergBlockType] = [
        .buttons, .table, .pullquote, .separator
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Common Blocks") {
                    ForEach(commonBlocks, id: \.self) { blockType in
                        blockButton(for: blockType)
                    }
                }
                
                Section("Layout") {
                    ForEach(layoutBlocks, id: \.self) { blockType in
                        blockButton(for: blockType)
                    }
                }
                
                Section("Media") {
                    ForEach(mediaBlocks, id: \.self) { blockType in
                        blockButton(for: blockType)
                    }
                }
                
                Section("Design") {
                    ForEach(designBlocks, id: \.self) { blockType in
                        blockButton(for: blockType)
                    }
                }
            }
            .navigationTitle("Add Block")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func blockButton(for blockType: GutenbergBlockType) -> some View {
        Button(action: {
            addBlock(type: blockType)
        }) {
            HStack {
                Image(systemName: blockType.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                Text(blockType.displayName)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    private func addBlock(type: GutenbergBlockType) {
        let newBlock: GutenbergBlock
        
        switch type {
        case .paragraph:
            newBlock = GutenbergBlock.paragraph("")
        case .heading:
            newBlock = GutenbergBlock.heading("", level: 2)
        case .list:
            newBlock = GutenbergBlock.list(ordered: false, items: [""])
        case .quote:
            newBlock = GutenbergBlock.quote("")
        case .code:
            newBlock = GutenbergBlock.code("")
        case .image:
            newBlock = GutenbergBlock.image(url: "")
        case .separator:
            newBlock = GutenbergBlock.separator()
        case .buttons:
            let button = GutenbergBlock.button(text: "Click here")
            newBlock = GutenbergBlock.buttons(buttons: [button])
        case .button:
            newBlock = GutenbergBlock.button(text: "Click here")
        case .columns:
            let column1 = GutenbergBlock.column(content: [GutenbergBlock.paragraph("")])
            let column2 = GutenbergBlock.column(content: [GutenbergBlock.paragraph("")])
            newBlock = GutenbergBlock.columns(columns: [column1, column2])
        case .column:
            newBlock = GutenbergBlock.column(content: [GutenbergBlock.paragraph("")])
        case .gallery:
            newBlock = GutenbergBlock.gallery()
        case .video:
            newBlock = GutenbergBlock.video(src: "")
        case .audio:
            newBlock = GutenbergBlock.audio(src: "")
        case .table:
            newBlock = GutenbergBlock.table(body: [["", ""], ["", ""]])
        case .spacer:
            newBlock = GutenbergBlock.spacer()
        case .group:
            newBlock = GutenbergBlock.group(blocks: [GutenbergBlock.paragraph("")])
        case .cover:
            newBlock = GutenbergBlock.cover(content: [GutenbergBlock.paragraph("")])
        case .embed:
            newBlock = GutenbergBlock.embed(url: "")
        case .pullquote:
            newBlock = GutenbergBlock.pullquote(content: "")
        case .unknown:
            newBlock = GutenbergBlock.paragraph("")
        }
        
        document.addBlock(newBlock, after: document.selectedBlockID)
        dismiss()
    }
}

// MARK: - Drag and Drop Support

struct BlockDropDelegate: DropDelegate {
    @ObservedObject var document: BlockDocument
    @Binding var draggedBlock: GutenbergBlock?
    let targetBlock: GutenbergBlock
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedBlock = draggedBlock else { return false }
        
        // Find indices
        guard let draggedIndex = document.blocks.firstIndex(where: { $0.id == draggedBlock.id }),
              let targetIndex = document.blocks.firstIndex(where: { $0.id == targetBlock.id }) else {
            return false
        }
        
        // Perform the move
        document.blocks.move(fromOffsets: IndexSet(integer: draggedIndex), toOffset: targetIndex)
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedBlock = draggedBlock else { return }
        
        if draggedBlock.id != targetBlock.id {
            // Visual feedback for drop target
        }
    }
}

// MARK: - Preview

struct BlockEditorView_Previews: PreviewProvider {
    static var previews: some View {
        let document = BlockDocument()
        document.blocks = [
            GutenbergBlock.heading("Sample Article", level: 1),
            GutenbergBlock.paragraph("This is a sample paragraph with some text content."),
            GutenbergBlock.quote("This is a quote block with some inspirational text."),
            GutenbergBlock.list(ordered: false, items: ["First item", "Second item", "Third item"])
        ]
        
        return NavigationView {
            BlockEditorView(document: document)
                .navigationTitle("Block Editor")
        }
    }
}