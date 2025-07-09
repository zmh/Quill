import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}

// MARK: - Paragraph Block Renderer

struct ParagraphBlockRenderer: View {
    let block: GutenbergBlock
    @Binding var isEditing: Bool
    @Binding var editingContent: String
    let onFinishEditing: (String) -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                TextField("Write your paragraph...", text: $editingContent, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(nil)
                    .focused($isFocused)
                    .onSubmit {
                        if editingContent.isEmpty {
                            finishEditing()
                        } else {
                            // Create new paragraph below
                            finishEditing()
                            // TODO: Add new block after this one
                        }
                    }
                    .onAppear {
                        isFocused = true
                    }
            } else {
                Text(block.content.isEmpty ? "Empty paragraph" : block.content)
                    .font(.body)
                    .foregroundColor(block.content.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: CGFloat.infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func finishEditing() {
        onFinishEditing(editingContent)
        isFocused = false
    }
}

// MARK: - Heading Block Renderer

struct HeadingBlockRenderer: View {
    let block: GutenbergBlock
    @Binding var isEditing: Bool
    @Binding var editingContent: String
    let onFinishEditing: (String) -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                TextField("Heading text...", text: $editingContent)
                    .textFieldStyle(.plain)
                    .font(fontForLevel(block.headingLevel))
                    .fontWeight(.bold)
                    .focused($isFocused)
                    .onSubmit {
                        finishEditing()
                    }
                    .onAppear {
                        isFocused = true
                    }
            } else {
                Text(block.content.isEmpty ? "Empty heading" : block.content)
                    .font(fontForLevel(block.headingLevel))
                    .fontWeight(.bold)
                    .foregroundColor(block.content.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: CGFloat.infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        case 5: return .headline
        case 6: return .subheadline
        default: return .title2
        }
    }
    
    private func finishEditing() {
        onFinishEditing(editingContent)
        isFocused = false
    }
}

// MARK: - List Block Renderer

struct ListBlockRenderer: View {
    let block: GutenbergBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(block.innerBlocks.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    if block.isOrderedList {
                        Text("\(index + 1).")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)
                    } else {
                        Text("•")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .center)
                    }
                    
                    Text(item.content)
                        .font(.body)
                        .frame(maxWidth: CGFloat.infinity, alignment: .leading)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Quote Block Renderer

struct QuoteBlockRenderer: View {
    let block: GutenbergBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(block.content)
                        .font(.body)
                        .italic()
                        .frame(maxWidth: CGFloat.infinity, alignment: .leading)
                    
                    if let citation = block.quoteCitation, !citation.isEmpty {
                        Text("— \(citation)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Code Block Renderer

struct CodeBlockRenderer: View {
    let block: GutenbergBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(block.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: CGFloat.infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
#if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
#else
        .background(Color(.systemGray6))
#endif
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Image Block Renderer

struct ImageBlockRenderer: View {
    let block: GutenbergBlock
    @State private var image: PlatformImage?
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = image {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: CGFloat.infinity)
                    .cornerRadius(8)
            } else if isLoading {
                RoundedRectangle(cornerRadius: 8)
#if os(macOS)
                    .fill(Color(NSColor.controlBackgroundColor))
#else
                    .fill(Color(.systemGray6))
#endif
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
#if os(macOS)
                    .fill(Color(NSColor.controlBackgroundColor))
#else
                    .fill(Color(.systemGray6))
#endif
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Image not available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
            
            if let caption = block.attributes["caption"] as? String, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: CGFloat.infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let urlString = block.imageURL,
              let url = URL(string: urlString) else {
            return
        }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data, let loadedImage = PlatformImage(data: data) {
                    self.image = loadedImage
                }
            }
        }.resume()
    }
}

// MARK: - Separator Block Renderer

struct SeparatorBlockRenderer: View {
    let block: GutenbergBlock
    
    var body: some View {
        Divider()
            .padding(.horizontal)
            .padding(.vertical, 16)
    }
}

// MARK: - Unknown Block Renderer

struct UnknownBlockRenderer: View {
    let block: GutenbergBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)
                Text("Unknown Block Type: \(block.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            if !block.content.isEmpty {
                Text(block.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
#if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
#else
        .background(Color(.systemGray6))
#endif
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}