import Foundation

class GutenbergParser {
    
    // MARK: - Parse HTML to Blocks
    
    static func parseBlocks(from html: String) -> [GutenbergBlock] {
        var blocks: [GutenbergBlock] = []
        
        // Regular expression to match Gutenberg block comments
        let blockPattern = "<!-- wp:(\\S+)(\\s+({[^}]*}))? -->([\\s\\S]*?)<!-- /wp:\\1 -->"
        let regex = try? NSRegularExpression(pattern: blockPattern, options: .dotMatchesLineSeparators)
        
        let nsString = html as NSString
        let matches = regex?.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        var lastEndIndex = 0
        
        for match in matches {
            // Check if there's content before this block
            if match.range.location > lastEndIndex {
                let beforeRange = NSRange(location: lastEndIndex, length: match.range.location - lastEndIndex)
                let beforeContent = nsString.substring(with: beforeRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !beforeContent.isEmpty {
                    // Parse as classic content (usually paragraphs)
                    let classicBlocks = parseClassicContent(beforeContent)
                    blocks.append(contentsOf: classicBlocks)
                }
            }
            
            // Extract block components
            let blockName = nsString.substring(with: match.range(at: 1))
            
            var attributes: [String: Any] = [:]
            if match.range(at: 3).location != NSNotFound {
                let attributesJSON = nsString.substring(with: match.range(at: 3))
                if let data = attributesJSON.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    attributes = json
                }
            }
            
            let content = nsString.substring(with: match.range(at: 4))
            
            // Parse the block
            if let block = parseBlock(name: blockName, content: content, attributes: attributes) {
                blocks.append(block)
            }
            
            lastEndIndex = match.range.location + match.range.length
        }
        
        // Check for content after the last block
        if lastEndIndex < nsString.length {
            let afterContent = nsString.substring(from: lastEndIndex).trimmingCharacters(in: .whitespacesAndNewlines)
            if !afterContent.isEmpty {
                let classicBlocks = parseClassicContent(afterContent)
                blocks.append(contentsOf: classicBlocks)
            }
        }
        
        // If no blocks were found, treat entire content as classic
        if blocks.isEmpty && !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks = parseClassicContent(html)
        }
        
        return blocks
    }
    
    // MARK: - Parse Individual Block
    
    private static func parseBlock(name: String, content: String, attributes: [String: Any]) -> GutenbergBlock? {
        let type = blockTypeFromName(name)
        
        switch name {
        case "core/paragraph":
            let cleanContent = extractTextContent(from: content)
            return GutenbergBlock(type: .paragraph, name: name, content: cleanContent, attributes: attributes)
            
        case "core/heading":
            let cleanContent = extractTextContent(from: content)
            return GutenbergBlock(type: .heading, name: name, content: cleanContent, attributes: attributes)
            
        case "core/list":
            let (items, innerAttributes) = parseListItems(from: content)
            let listBlocks = items.map { GutenbergBlock(type: .list, name: "core/list-item", content: $0) }
            return GutenbergBlock(type: .list, name: name, content: "", attributes: attributes, innerBlocks: listBlocks)
            
        case "core/quote":
            let cleanContent = extractTextContent(from: content)
            return GutenbergBlock(type: .quote, name: name, content: cleanContent, attributes: attributes)
            
        case "core/code":
            // For code blocks, preserve the content as-is
            let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return GutenbergBlock(type: .code, name: name, content: cleanContent, attributes: attributes)
            
        case "core/image":
            // Extract image attributes from HTML
            var imageAttrs = attributes
            if let (url, alt, caption) = parseImageHTML(content) {
                imageAttrs["url"] = url
                imageAttrs["alt"] = alt
                if let caption = caption {
                    imageAttrs["caption"] = caption
                }
            }
            return GutenbergBlock(type: .image, name: name, attributes: imageAttrs)
            
        case "core/separator":
            return GutenbergBlock(type: .separator, name: name, attributes: attributes)
            
        case "core/button":
            let cleanContent = extractTextContent(from: content)
            return GutenbergBlock(type: .button, name: name, content: cleanContent, attributes: attributes)
            
        case "core/buttons":
            // Parse inner button blocks
            let buttonBlocks = parseInnerBlocks(from: content)
            return GutenbergBlock(type: .buttons, name: name, attributes: attributes, innerBlocks: buttonBlocks)
            
        case "core/columns":
            // Parse inner column blocks
            let columnBlocks = parseInnerBlocks(from: content)
            return GutenbergBlock(type: .columns, name: name, attributes: attributes, innerBlocks: columnBlocks)
            
        case "core/column":
            // Parse inner blocks within the column
            let innerBlocks = parseInnerBlocks(from: content)
            return GutenbergBlock(type: .column, name: name, attributes: attributes, innerBlocks: innerBlocks)
            
        case "core/gallery":
            // Parse gallery images from content
            let images = parseGalleryImages(from: content)
            var galleryAttrs = attributes
            if !images.isEmpty {
                galleryAttrs["images"] = images
            }
            return GutenbergBlock(type: .gallery, name: name, attributes: galleryAttrs)
            
        case "core/video":
            // Extract video attributes from HTML
            var videoAttrs = attributes
            if let src = extractVideoSrc(from: content) {
                videoAttrs["src"] = src
            }
            return GutenbergBlock(type: .video, name: name, attributes: videoAttrs)
            
        case "core/audio":
            // Extract audio attributes from HTML
            var audioAttrs = attributes
            if let src = extractAudioSrc(from: content) {
                audioAttrs["src"] = src
            }
            return GutenbergBlock(type: .audio, name: name, attributes: audioAttrs)
            
        case "core/table":
            // Parse table content
            let tableData = parseTableHTML(content)
            var tableAttrs = attributes
            if !tableData.isEmpty {
                tableAttrs["body"] = tableData
            }
            return GutenbergBlock(type: .table, name: name, attributes: tableAttrs)
            
        case "core/spacer":
            return GutenbergBlock(type: .spacer, name: name, attributes: attributes)
            
        case "core/group":
            // Parse inner blocks within the group
            let innerBlocks = parseInnerBlocks(from: content)
            return GutenbergBlock(type: .group, name: name, attributes: attributes, innerBlocks: innerBlocks)
            
        case "core/cover":
            // Parse inner blocks and background image
            let innerBlocks = parseInnerBlocks(from: content)
            var coverAttrs = attributes
            if let bgImage = extractBackgroundImage(from: content) {
                coverAttrs["url"] = bgImage
            }
            return GutenbergBlock(type: .cover, name: name, attributes: coverAttrs, innerBlocks: innerBlocks)
            
        case "core/embed":
            // Extract embed URL
            var embedAttrs = attributes
            if let url = extractEmbedURL(from: content) {
                embedAttrs["url"] = url
            }
            return GutenbergBlock(type: .embed, name: name, attributes: embedAttrs)
            
        case "core/pullquote":
            let cleanContent = extractTextContent(from: content)
            return GutenbergBlock(type: .pullquote, name: name, content: cleanContent, attributes: attributes)
            
        default:
            // Unknown block type
            return GutenbergBlock(type: .unknown, name: name, content: content, attributes: attributes)
        }
    }
    
    // MARK: - Helper Methods
    
    private static func blockTypeFromName(_ name: String) -> GutenbergBlockType {
        switch name {
        case "core/paragraph": return .paragraph
        case "core/heading": return .heading
        case "core/list": return .list
        case "core/quote": return .quote
        case "core/code": return .code
        case "core/image": return .image
        case "core/separator": return .separator
        default: return .unknown
        }
    }
    
    private static func extractTextContent(from html: String) -> String {
        // Remove HTML tags
        let tagPattern = "<[^>]+>"
        let stripped = html.replacingOccurrences(of: tagPattern, with: "", options: .regularExpression)
        
        // Decode HTML entities
        let decoded = stripped
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        
        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func parseListItems(from html: String) -> ([String], [String: Any]) {
        var items: [String] = []
        var attributes: [String: Any] = [:]
        
        // Check if it's an ordered list
        if html.contains("<ol") {
            attributes["ordered"] = true
        }
        
        // Extract list items
        let itemPattern = "<li[^>]*>([\\s\\S]*?)</li>"
        if let regex = try? NSRegularExpression(pattern: itemPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let itemContent = String(html[range])
                    items.append(extractTextContent(from: itemContent))
                }
            }
        }
        
        return (items, attributes)
    }
    
    private static func parseImageHTML(_ html: String) -> (url: String, alt: String?, caption: String?)? {
        // More flexible image URL patterns to handle different quote styles and attributes
        let imgPatterns = [
            "<img[^>]+src=\"([^\"]+)\"[^>]*>",  // Double quotes
            "<img[^>]+src='([^']+)'[^>]*>",    // Single quotes
            "<img[^>]+src=([^\\s>]+)[^>]*>"    // No quotes
        ]
        
        var url: String?
        for pattern in imgPatterns {
            if let imgRegex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let imgMatch = imgRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let urlRange = Range(imgMatch.range(at: 1), in: html) {
                url = String(html[urlRange])
                break
            }
        }
        
        guard let imageUrl = url else {
            return nil
        }
        
        // Extract alt text with more flexible patterns
        var alt: String?
        let altPatterns = [
            "alt=\"([^\"]*?)\"",
            "alt='([^']*?)'",
            "alt=([^\\s>]+)"
        ]
        
        for pattern in altPatterns {
            if let altRegex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let altMatch = altRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let altRange = Range(altMatch.range(at: 1), in: html) {
                alt = String(html[altRange])
                break
            }
        }
        
        // Extract caption from various possible structures
        var caption: String?
        let captionPatterns = [
            "<figcaption[^>]*>([\\s\\S]*?)</figcaption>",  // figcaption
            "<p[^>]*class[^>]*caption[^>]*>([\\s\\S]*?)</p>", // paragraph with caption class
            "<div[^>]*class[^>]*caption[^>]*>([\\s\\S]*?)</div>" // div with caption class
        ]
        
        for pattern in captionPatterns {
            if let captionRegex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let captionMatch = captionRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               let captionRange = Range(captionMatch.range(at: 1), in: html) {
                caption = extractTextContent(from: String(html[captionRange]))
                if !caption!.isEmpty {
                    break
                }
            }
        }
        
        return (imageUrl, alt, caption)
    }
    
    private static func parseClassicContent(_ content: String) -> [GutenbergBlock] {
        var blocks: [GutenbergBlock] = []
        
        // Split content by double newlines or <p> tags
        let paragraphs = content.components(separatedBy: "\n\n")
        
        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                // Check if it's an image
                if let (url, alt, caption) = parseImageHTML(trimmed) {
                    var imageAttrs: [String: Any] = ["url": url]
                    if let alt = alt {
                        imageAttrs["alt"] = alt
                    }
                    if let caption = caption {
                        imageAttrs["caption"] = caption
                    }
                    blocks.append(GutenbergBlock(type: .image, name: "core/image", attributes: imageAttrs))
                }
                // Check if it's a heading
                else if let headingLevel = detectHeading(in: trimmed) {
                    let cleanContent = extractTextContent(from: trimmed)
                    blocks.append(GutenbergBlock.heading(cleanContent, level: headingLevel))
                } else {
                    // Default to paragraph
                    let cleanContent = extractTextContent(from: trimmed)
                    if !cleanContent.isEmpty {
                        blocks.append(GutenbergBlock.paragraph(cleanContent))
                    }
                }
            }
        }
        
        return blocks
    }
    
    private static func detectHeading(in html: String) -> Int? {
        let headingPattern = "<h([1-6])[^>]*>"
        if let regex = try? NSRegularExpression(pattern: headingPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
           let levelRange = Range(match.range(at: 1), in: html),
           let level = Int(html[levelRange]) {
            return level
        }
        return nil
    }
}

// MARK: - Block Serializer

extension GutenbergParser {
    
    static func serializeBlocks(_ blocks: [GutenbergBlock]) -> String {
        return blocks.map { serializeBlock($0) }.joined(separator: "\n\n")
    }
    
    private static func serializeBlock(_ block: GutenbergBlock) -> String {
        let attributesJSON = serializeAttributes(block.attributes)
        let attributesString = attributesJSON.isEmpty ? "" : " \(attributesJSON)"
        
        switch block.type {
        case .paragraph:
            let content = block.content.isEmpty ? "" : "<p>\(escapeHTML(block.content))</p>"
            return "<!-- wp:paragraph\(attributesString) -->\n\(content)\n<!-- /wp:paragraph -->"
            
        case .heading:
            let level = block.headingLevel
            let content = block.content.isEmpty ? "" : "<h\(level)>\(escapeHTML(block.content))</h\(level)>"
            return "<!-- wp:heading\(attributesString) -->\n\(content)\n<!-- /wp:heading -->"
            
        case .list:
            let tag = block.isOrderedList ? "ol" : "ul"
            let items = block.innerBlocks.map { "<li>\(escapeHTML($0.content))</li>" }.joined(separator: "\n")
            let content = items.isEmpty ? "" : "<\(tag)>\n\(items)\n</\(tag)>"
            return "<!-- wp:list\(attributesString) -->\n\(content)\n<!-- /wp:list -->"
            
        case .quote:
            var content = "<blockquote class=\"wp-block-quote\">"
            if !block.content.isEmpty {
                content += "<p>\(escapeHTML(block.content))</p>"
            }
            if let citation = block.quoteCitation, !citation.isEmpty {
                content += "<cite>\(escapeHTML(citation))</cite>"
            }
            content += "</blockquote>"
            return "<!-- wp:quote\(attributesString) -->\n\(content)\n<!-- /wp:quote -->"
            
        case .code:
            let content = "<pre class=\"wp-block-code\"><code>\(escapeHTML(block.content))</code></pre>"
            return "<!-- wp:code\(attributesString) -->\n\(content)\n<!-- /wp:code -->"
            
        case .image:
            var content = "<figure class=\"wp-block-image\">"
            if let url = block.imageURL {
                content += "<img src=\"\(escapeHTML(url))\""
                if let alt = block.imageAlt {
                    content += " alt=\"\(escapeHTML(alt))\""
                }
                content += "/>"
            }
            if let caption = block.attributes["caption"] as? String, !caption.isEmpty {
                content += "<figcaption>\(escapeHTML(caption))</figcaption>"
            }
            content += "</figure>"
            return "<!-- wp:image\(attributesString) -->\n\(content)\n<!-- /wp:image -->"
            
        case .separator:
            return "<!-- wp:separator\(attributesString) -->\n<hr class=\"wp-block-separator\"/>\n<!-- /wp:separator -->"
            
        case .button:
            let content = "<div class=\"wp-block-button\"><a class=\"wp-block-button__link\">\(escapeHTML(block.content))</a></div>"
            return "<!-- wp:button\(attributesString) -->\n\(content)\n<!-- /wp:button -->"
            
        case .buttons:
            let innerHTML = block.innerBlocks.map { serializeBlock($0) }.joined(separator: "\n\n")
            return "<!-- wp:buttons\(attributesString) -->\n<div class=\"wp-block-buttons\">\n\(innerHTML)\n</div>\n<!-- /wp:buttons -->"
            
        case .columns:
            let innerHTML = block.innerBlocks.map { serializeBlock($0) }.joined(separator: "\n\n")
            return "<!-- wp:columns\(attributesString) -->\n<div class=\"wp-block-columns\">\n\(innerHTML)\n</div>\n<!-- /wp:columns -->"
            
        case .column:
            let innerHTML = block.innerBlocks.map { serializeBlock($0) }.joined(separator: "\n\n")
            return "<!-- wp:column\(attributesString) -->\n<div class=\"wp-block-column\">\n\(innerHTML)\n</div>\n<!-- /wp:column -->"
            
        case .gallery:
            let content = "<figure class=\"wp-block-gallery\"></figure>"
            return "<!-- wp:gallery\(attributesString) -->\n\(content)\n<!-- /wp:gallery -->"
            
        case .video:
            let content = "<figure class=\"wp-block-video\"><video controls></video></figure>"
            return "<!-- wp:video\(attributesString) -->\n\(content)\n<!-- /wp:video -->"
            
        case .audio:
            let content = "<figure class=\"wp-block-audio\"><audio controls></audio></figure>"
            return "<!-- wp:audio\(attributesString) -->\n\(content)\n<!-- /wp:audio -->"
            
        case .table:
            let content = "<figure class=\"wp-block-table\"><table><tbody></tbody></table></figure>"
            return "<!-- wp:table\(attributesString) -->\n\(content)\n<!-- /wp:table -->"
            
        case .spacer:
            let height = block.attributes["height"] as? String ?? "100px"
            let content = "<div style=\"height:\(height)\" aria-hidden=\"true\" class=\"wp-block-spacer\"></div>"
            return "<!-- wp:spacer\(attributesString) -->\n\(content)\n<!-- /wp:spacer -->"
            
        case .group:
            let innerHTML = block.innerBlocks.map { serializeBlock($0) }.joined(separator: "\n\n")
            return "<!-- wp:group\(attributesString) -->\n<div class=\"wp-block-group\">\n\(innerHTML)\n</div>\n<!-- /wp:group -->"
            
        case .cover:
            let innerHTML = block.innerBlocks.map { serializeBlock($0) }.joined(separator: "\n\n")
            return "<!-- wp:cover\(attributesString) -->\n<div class=\"wp-block-cover\">\n\(innerHTML)\n</div>\n<!-- /wp:cover -->"
            
        case .embed:
            let content = "<figure class=\"wp-block-embed\"></figure>"
            return "<!-- wp:embed\(attributesString) -->\n\(content)\n<!-- /wp:embed -->"
            
        case .pullquote:
            let content = "<figure class=\"wp-block-pullquote\"><blockquote><p>\(escapeHTML(block.content))</p></blockquote></figure>"
            return "<!-- wp:pullquote\(attributesString) -->\n\(content)\n<!-- /wp:pullquote -->"
            
        case .unknown:
            return "<!-- wp:\(block.name)\(attributesString) -->\n\(block.content)\n<!-- /wp:\(block.name) -->"
        }
    }
    
    private static func serializeAttributes(_ attributes: [String: Any]) -> String {
        guard !attributes.isEmpty else { return "" }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: attributes, options: [.sortedKeys])
            if let json = String(data: data, encoding: .utf8) {
                return json
            }
        } catch {
            print("Error serializing attributes: \(error)")
        }
        
        return ""
    }
    
    private static func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    // MARK: - New Block Type Helper Methods
    
    private static func parseInnerBlocks(from content: String) -> [GutenbergBlock] {
        // Recursively parse inner blocks from content
        return parseBlocks(from: content)
    }
    
    private static func parseGalleryImages(from content: String) -> [String] {
        // Extract image URLs from gallery HTML
        var images: [String] = []
        let imgPattern = "<img[^>]*src=[\"']([^\"']*)[\"'][^>]*>"
        
        if let regex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive) {
            let nsString = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches {
                if match.numberOfRanges > 1 {
                    let srcURL = nsString.substring(with: match.range(at: 1))
                    images.append(srcURL)
                }
            }
        }
        
        return images
    }
    
    private static func extractVideoSrc(from content: String) -> String? {
        // Extract video source from video tag
        let videoPattern = "<video[^>]*src=[\"']([^\"']*)[\"'][^>]*>"
        return extractAttribute(from: content, pattern: videoPattern)
    }
    
    private static func extractAudioSrc(from content: String) -> String? {
        // Extract audio source from audio tag
        let audioPattern = "<audio[^>]*src=[\"']([^\"']*)[\"'][^>]*>"
        return extractAttribute(from: content, pattern: audioPattern)
    }
    
    private static func parseTableHTML(_ content: String) -> [[String]] {
        // Basic table parsing - extract cell content
        var rows: [[String]] = []
        
        // Extract table rows
        let rowPattern = "<tr[^>]*>(.*?)</tr>"
        if let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let nsString = content as NSString
            let rowMatches = rowRegex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for rowMatch in rowMatches {
                let rowContent = nsString.substring(with: rowMatch.range(at: 1))
                
                // Extract cells from row
                let cellPattern = "<t[hd][^>]*>(.*?)</t[hd]>"
                if let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                    let cellMatches = cellRegex.matches(in: rowContent, options: [], range: NSRange(location: 0, length: (rowContent as NSString).length))
                    
                    var cells: [String] = []
                    for cellMatch in cellMatches {
                        let cellContent = (rowContent as NSString).substring(with: cellMatch.range(at: 1))
                        cells.append(extractTextContent(from: cellContent))
                    }
                    
                    if !cells.isEmpty {
                        rows.append(cells)
                    }
                }
            }
        }
        
        return rows
    }
    
    private static func extractBackgroundImage(from content: String) -> String? {
        // Extract background image URL from style attribute or img tag
        let bgImagePattern = "background-image:[^;]*url\\([\"']?([^\"')]*)[\"']?\\)"
        return extractAttribute(from: content, pattern: bgImagePattern)
    }
    
    private static func extractEmbedURL(from content: String) -> String? {
        // Extract URL from various embed formats
        let urlPattern = "(?:src|href)=[\"']([^\"']*)[\"']"
        return extractAttribute(from: content, pattern: urlPattern)
    }
    
    private static func extractAttribute(from content: String, pattern: String) -> String? {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsString = content as NSString
            if let match = regex.firstMatch(in: content, options: [], range: NSRange(location: 0, length: nsString.length)) {
                if match.numberOfRanges > 1 {
                    return nsString.substring(with: match.range(at: 1))
                }
            }
        }
        return nil
    }
}