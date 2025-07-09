import SwiftUI

// Demo view to showcase the block editor
struct BlockEditorDemo: View {
    @StateObject private var document = BlockDocument()
    
    var body: some View {
        NavigationView {
            BlockEditorView(document: document)
                .navigationTitle("Block Editor Demo")
        }
        .onAppear {
            setupDemoContent()
        }
    }
    
    private func setupDemoContent() {
        if document.blocks.isEmpty {
            document.blocks = [
                GutenbergBlock.heading("Welcome to Quill's Block Editor", level: 1),
                GutenbergBlock.paragraph("This is a native WordPress block editor built with SwiftUI. You can edit blocks directly inline and they'll be saved as WordPress-compatible HTML."),
                GutenbergBlock.heading("Features", level: 2),
                GutenbergBlock.list(ordered: false, items: [
                    "Native SwiftUI block rendering",
                    "Inline editing with focus states",
                    "Drag & drop reordering",
                    "HTML fallback for complex blocks"
                ]),
                GutenbergBlock.quote("The best way to predict the future is to create it.", citation: "Peter Drucker"),
                GutenbergBlock.heading("Code Example", level: 3),
                GutenbergBlock.code("func createBlock() -> GutenbergBlock {\n    return GutenbergBlock.paragraph(\"Hello, World!\")\n}"),
                GutenbergBlock.separator(),
                GutenbergBlock.paragraph("Try editing any of these blocks by tapping on them. Use the + button to add new blocks.")
            ]
        }
    }
}

// Preview
struct BlockEditorDemo_Previews: PreviewProvider {
    static var previews: some View {
        BlockEditorDemo()
    }
}