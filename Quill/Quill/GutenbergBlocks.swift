import Foundation
import SwiftUI

// MARK: - Block Types

enum GutenbergBlockType: String, CaseIterable {
    case paragraph = "paragraph"
    case heading = "heading"
    case list = "list"
    case quote = "quote"
    case code = "code"
    case image = "image"
    case separator = "separator"
    case buttons = "buttons"
    case button = "button"
    case columns = "columns"
    case column = "column"
    case gallery = "gallery"
    case video = "video"
    case audio = "audio"
    case table = "table"
    case spacer = "spacer"
    case group = "group"
    case cover = "cover"
    case embed = "embed"
    case pullquote = "pullquote"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .paragraph: return "Paragraph"
        case .heading: return "Heading"
        case .list: return "List"
        case .quote: return "Quote"
        case .code: return "Code"
        case .image: return "Image"
        case .separator: return "Separator"
        case .buttons: return "Buttons"
        case .button: return "Button"
        case .columns: return "Columns"
        case .column: return "Column"
        case .gallery: return "Gallery"
        case .video: return "Video"
        case .audio: return "Audio"
        case .table: return "Table"
        case .spacer: return "Spacer"
        case .group: return "Group"
        case .cover: return "Cover"
        case .embed: return "Embed"
        case .pullquote: return "Pull Quote"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .paragraph: return "text.alignleft"
        case .heading: return "textformat"
        case .list: return "list.bullet"
        case .quote: return "quote.opening"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .separator: return "minus"
        case .buttons: return "rectangle.on.rectangle"
        case .button: return "rectangle.roundedtop"
        case .columns: return "rectangle.split.2x1"
        case .column: return "rectangle"
        case .gallery: return "photo.on.rectangle.angled"
        case .video: return "video"
        case .audio: return "speaker.wave.2"
        case .table: return "tablecells"
        case .spacer: return "arrow.up.and.down"
        case .group: return "square.on.square"
        case .cover: return "photo.on.rectangle"
        case .embed: return "link"
        case .pullquote: return "quote.bubble"
        case .unknown: return "questionmark.square"
        }
    }
}

// MARK: - Block Attributes

struct HeadingAttributes: Codable {
    var level: Int = 2
    var textAlign: String?
    var anchor: String?
}

struct ListAttributes: Codable {
    var ordered: Bool = false
    var reversed: Bool = false
    var start: Int?
}

struct ImageAttributes: Codable {
    var id: Int?
    var url: String?
    var alt: String?
    var caption: String?
    var link: String?
    var width: Int?
    var height: Int?
    var sizeSlug: String?
}

struct QuoteAttributes: Codable {
    var citation: String?
}

struct ButtonAttributes: Codable {
    var url: String?
    var text: String?
    var linkTarget: String?
    var rel: String?
    var placeholder: String?
    var backgroundColor: String?
    var textColor: String?
    var gradient: String?
    var style: ButtonStyle?
    
    enum ButtonStyle: String, Codable {
        case fill = "fill"
        case outline = "outline"
    }
}

struct ColumnAttributes: Codable {
    var width: String?
    var verticalAlignment: String?
}

struct GalleryAttributes: Codable {
    var ids: [Int]?
    var columns: Int?
    var linkTo: String?
    var sizeSlug: String?
    var imageCrop: Bool?
    var fixedHeight: Bool?
}

struct VideoAttributes: Codable {
    var src: String?
    var id: Int?
    var caption: String?
    var controls: Bool?
    var autoplay: Bool?
    var loop: Bool?
    var muted: Bool?
    var playsInline: Bool?
    var preload: String?
    var poster: String?
}

struct AudioAttributes: Codable {
    var src: String?
    var id: Int?
    var caption: String?
    var autoplay: Bool?
    var loop: Bool?
    var preload: String?
}

struct TableAttributes: Codable {
    var hasFixedLayout: Bool?
    var head: [[String]]?
    var body: [[String]]?
    var foot: [[String]]?
}

struct SpacerAttributes: Codable {
    var height: String?
}

struct CoverAttributes: Codable {
    var url: String?
    var id: Int?
    var alt: String?
    var hasParallax: Bool?
    var isRepeated: Bool?
    var dimRatio: Int?
    var overlayColor: String?
    var customOverlayColor: String?
    var backgroundType: String?
    var focalPoint: FocalPoint?
    var minHeight: String?
    var minHeightUnit: String?
    var contentPosition: String?
    var isDark: Bool?
    
    struct FocalPoint: Codable {
        var x: Double
        var y: Double
    }
}

struct EmbedAttributes: Codable {
    var url: String?
    var type: String?
    var providerNameSlug: String?
    var responsive: Bool?
    var previewable: Bool?
}

// MARK: - Gutenberg Block Model

struct GutenbergBlock: Identifiable, Equatable {
    let id = UUID()
    let type: GutenbergBlockType
    let name: String
    var content: String
    var attributes: [String: Any]
    var innerBlocks: [GutenbergBlock]
    
    // Computed properties for common attributes
    var textAlign: String? {
        attributes["textAlign"] as? String
    }
    
    var className: String? {
        attributes["className"] as? String
    }
    
    // Type-specific attribute getters
    var headingLevel: Int {
        guard type == .heading else { return 2 }
        return (attributes["level"] as? Int) ?? 2
    }
    
    var isOrderedList: Bool {
        guard type == .list else { return false }
        return (attributes["ordered"] as? Bool) ?? false
    }
    
    var imageURL: String? {
        guard type == .image else { return nil }
        return attributes["url"] as? String
    }
    
    var imageAlt: String? {
        guard type == .image else { return nil }
        return attributes["alt"] as? String
    }
    
    var quoteCitation: String? {
        guard type == .quote else { return nil }
        return attributes["citation"] as? String
    }
    
    // Initialize with explicit values
    init(type: GutenbergBlockType, name: String, content: String = "", attributes: [String: Any] = [:], innerBlocks: [GutenbergBlock] = []) {
        self.type = type
        self.name = name
        self.content = content
        self.attributes = attributes
        self.innerBlocks = innerBlocks
    }
    
    // Factory methods for common blocks
    static func paragraph(_ content: String, attributes: [String: Any] = [:]) -> GutenbergBlock {
        GutenbergBlock(type: .paragraph, name: "core/paragraph", content: content, attributes: attributes)
    }
    
    static func heading(_ content: String, level: Int = 2, attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        attrs["level"] = level
        return GutenbergBlock(type: .heading, name: "core/heading", content: content, attributes: attrs)
    }
    
    static func list(ordered: Bool = false, items: [String], attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        attrs["ordered"] = ordered
        let listItems = items.map { item in
            GutenbergBlock(type: .list, name: "core/list-item", content: item)
        }
        return GutenbergBlock(type: .list, name: "core/list", content: "", attributes: attrs, innerBlocks: listItems)
    }
    
    static func quote(_ content: String, citation: String? = nil, attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        if let citation = citation {
            attrs["citation"] = citation
        }
        return GutenbergBlock(type: .quote, name: "core/quote", content: content, attributes: attrs)
    }
    
    static func code(_ content: String, attributes: [String: Any] = [:]) -> GutenbergBlock {
        GutenbergBlock(type: .code, name: "core/code", content: content, attributes: attributes)
    }
    
    static func image(url: String, alt: String? = nil, caption: String? = nil, attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        attrs["url"] = url
        if let alt = alt {
            attrs["alt"] = alt
        }
        if let caption = caption {
            attrs["caption"] = caption
        }
        return GutenbergBlock(type: .image, name: "core/image", attributes: attrs)
    }
    
    static func separator(attributes: [String: Any] = [:]) -> GutenbergBlock {
        GutenbergBlock(type: .separator, name: "core/separator", attributes: attributes)
    }
    
    static func button(text: String, url: String? = nil, attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        attrs["text"] = text
        if let url = url {
            attrs["url"] = url
        }
        return GutenbergBlock(type: .button, name: "core/button", content: text, attributes: attrs)
    }
    
    static func buttons(buttons: [GutenbergBlock] = [], attributes: [String: Any] = [:]) -> GutenbergBlock {
        GutenbergBlock(type: .buttons, name: "core/buttons", attributes: attributes, innerBlocks: buttons)
    }
    
    static func columns(columns: [GutenbergBlock] = [], attributes: [String: Any] = [:]) -> GutenbergBlock {
        GutenbergBlock(type: .columns, name: "core/columns", attributes: attributes, innerBlocks: columns)
    }
    
    static func column(content: [GutenbergBlock] = [], width: String? = nil, attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        if let width = width {
            attrs["width"] = width
        }
        return GutenbergBlock(type: .column, name: "core/column", attributes: attrs, innerBlocks: content)
    }
    
    static func gallery(images: [String] = [], columns: Int = 3, attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        attrs["columns"] = columns
        attrs["ids"] = images
        return GutenbergBlock(type: .gallery, name: "core/gallery", attributes: attrs)
    }
    
    static func video(src: String, caption: String? = nil, attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        attrs["src"] = src
        if let caption = caption {
            attrs["caption"] = caption
        }
        return GutenbergBlock(type: .video, name: "core/video", attributes: attrs)
    }
    
    static func audio(src: String, caption: String? = nil, attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        attrs["src"] = src
        if let caption = caption {
            attrs["caption"] = caption
        }
        return GutenbergBlock(type: .audio, name: "core/audio", attributes: attrs)
    }
    
    static func table(head: [[String]] = [], body: [[String]] = [], foot: [[String]] = [], attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        if !head.isEmpty { attrs["head"] = head }
        if !body.isEmpty { attrs["body"] = body }
        if !foot.isEmpty { attrs["foot"] = foot }
        return GutenbergBlock(type: .table, name: "core/table", attributes: attrs)
    }
    
    static func spacer(height: String = "100px", attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        attrs["height"] = height
        return GutenbergBlock(type: .spacer, name: "core/spacer", attributes: attrs)
    }
    
    static func group(blocks: [GutenbergBlock] = [], attributes: [String: Any] = [:]) -> GutenbergBlock {
        GutenbergBlock(type: .group, name: "core/group", attributes: attributes, innerBlocks: blocks)
    }
    
    static func cover(backgroundImage: String? = nil, content: [GutenbergBlock] = [], attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        if let backgroundImage = backgroundImage {
            attrs["url"] = backgroundImage
        }
        return GutenbergBlock(type: .cover, name: "core/cover", attributes: attrs, innerBlocks: content)
    }
    
    static func embed(url: String, type: String? = nil, attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        attrs["url"] = url
        if let type = type {
            attrs["type"] = type
        }
        return GutenbergBlock(type: .embed, name: "core/embed", attributes: attrs)
    }
    
    static func pullquote(content: String, citation: String? = nil, attributes: [String: Any] = [:]) -> GutenbergBlock {
        var attrs = attributes
        if let citation = citation {
            attrs["citation"] = citation
        }
        return GutenbergBlock(type: .pullquote, name: "core/pullquote", content: content, attributes: attrs)
    }
    
    // Equatable implementation
    static func == (lhs: GutenbergBlock, rhs: GutenbergBlock) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Block Container

class BlockDocument: ObservableObject {
    @Published var blocks: [GutenbergBlock] = []
    @Published var selectedBlockID: UUID?
    
    var selectedBlock: GutenbergBlock? {
        blocks.first { $0.id == selectedBlockID }
    }
    
    func addBlock(_ block: GutenbergBlock, after blockID: UUID? = nil) {
        if let blockID = blockID,
           let index = blocks.firstIndex(where: { $0.id == blockID }) {
            blocks.insert(block, at: index + 1)
        } else {
            blocks.append(block)
        }
        selectedBlockID = block.id
    }
    
    func removeBlock(id: UUID) {
        blocks.removeAll { $0.id == id }
        if selectedBlockID == id {
            selectedBlockID = nil
        }
    }
    
    func moveBlock(from source: IndexSet, to destination: Int) {
        blocks.move(fromOffsets: source, toOffset: destination)
    }
    
    func updateBlock(id: UUID, content: String) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index].content = content
        }
    }
    
    func updateBlockAttributes(id: UUID, attributes: [String: Any]) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index].attributes = attributes
        }
    }
}