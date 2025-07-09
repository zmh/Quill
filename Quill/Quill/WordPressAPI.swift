//
//  WordPressAPI.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

import Foundation

class WordPressAPI {
    static let shared = WordPressAPI()
    private init() {}
    
    private var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()
    
    // MARK: - Authentication
    
    func testConnection(siteURL: String, username: String, password: String) async throws -> Bool {
        let baseURL = normalizeURL(siteURL)
        let endpoint = "\(baseURL)/wp-json/wp/v2/users/me"
        
        guard let url = URL(string: endpoint) else {
            throw WordPressError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add Basic Auth header
        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordPressError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return true
        } else if httpResponse.statusCode == 401 {
            throw WordPressError.unauthorized
        } else {
            throw WordPressError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Media
    
    func uploadImage(siteURL: String, username: String, password: String, imageData: Data, filename: String, mimeType: String) async throws -> WordPressMedia {
        let baseURL = normalizeURL(siteURL)
        let endpoint = "\(baseURL)/wp-json/wp/v2/media"
        
        guard let url = URL(string: endpoint) else {
            throw WordPressError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add Basic Auth header
        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add the file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordPressError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            do {
                let decoder = JSONDecoder()
                let media = try decoder.decode(WordPressMedia.self, from: data)
                return media
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw media response: \(responseString)")
                }
                print("Media decoding error: \(error)")
                throw WordPressError.decodingError
            }
        } else if httpResponse.statusCode == 401 {
            throw WordPressError.unauthorized
        } else {
            // Print error response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Media upload error response: \(responseString)")
            }
            throw WordPressError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Posts
    
    func createPost(siteURL: String, username: String, password: String, post: Post) async throws -> WordPressPost {
        let baseURL = normalizeURL(siteURL)
        let endpoint = "\(baseURL)/wp-json/wp/v2/posts"
        
        guard let url = URL(string: endpoint) else {
            throw WordPressError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Basic Auth header
        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        // Create the post data to send
        let postData = WordPressPostRequest(
            title: post.title,
            content: post.content,
            status: post.status.wordPressStatus,
            slug: post.slug.isEmpty ? nil : post.slug,
            excerpt: post.excerpt.isEmpty ? nil : post.excerpt,
            date: post.status == .scheduled ? post.publishedDate?.toWordPressDateString() : nil
        )
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(postData)
        } catch {
            throw WordPressError.encodingError
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordPressError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            do {
                let decoder = JSONDecoder()
                let createdPost = try decoder.decode(WordPressPost.self, from: data)
                return createdPost
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw create post response: \(responseString)")
                }
                print("Post creation decoding error: \(error)")
                throw WordPressError.decodingError
            }
        } else if httpResponse.statusCode == 401 {
            throw WordPressError.unauthorized
        } else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Post creation error response: \(responseString)")
            }
            throw WordPressError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    func updatePost(siteURL: String, username: String, password: String, post: Post) async throws -> WordPressPost {
        guard let remoteID = post.remoteID else {
            throw WordPressError.missingRemoteID
        }
        
        let baseURL = normalizeURL(siteURL)
        let endpoint = "\(baseURL)/wp-json/wp/v2/posts/\(remoteID)"
        
        guard let url = URL(string: endpoint) else {
            throw WordPressError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST" // WordPress REST API uses POST for updates
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Basic Auth header
        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        // Create the post data to send
        let postData = WordPressPostRequest(
            title: post.title,
            content: post.content,
            status: post.status.wordPressStatus,
            slug: post.slug.isEmpty ? nil : post.slug,
            excerpt: post.excerpt.isEmpty ? nil : post.excerpt,
            date: post.status == .scheduled ? post.publishedDate?.toWordPressDateString() : nil
        )
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(postData)
        } catch {
            throw WordPressError.encodingError
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordPressError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let decoder = JSONDecoder()
                let updatedPost = try decoder.decode(WordPressPost.self, from: data)
                return updatedPost
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw update post response: \(responseString)")
                }
                print("Post update decoding error: \(error)")
                throw WordPressError.decodingError
            }
        } else if httpResponse.statusCode == 401 {
            throw WordPressError.unauthorized
        } else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Post update error response: \(responseString)")
            }
            throw WordPressError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    func deletePost(siteURL: String, username: String, password: String, postID: Int) async throws {
        let baseURL = normalizeURL(siteURL)
        let endpoint = "\(baseURL)/wp-json/wp/v2/posts/\(postID)"
        
        guard let url = URL(string: endpoint) else {
            throw WordPressError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        // Add Basic Auth header
        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordPressError.invalidResponse
        }
        
        // WordPress returns 200 OK when post is moved to trash
        if httpResponse.statusCode == 200 {
            return
        } else if httpResponse.statusCode == 401 {
            throw WordPressError.unauthorized
        } else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Post deletion error response: \(responseString)")
            }
            throw WordPressError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    func fetchPosts(siteURL: String, username: String, password: String, page: Int = 1, perPage: Int = 100) async throws -> [WordPressPost] {
        let baseURL = normalizeURL(siteURL)
        let endpoint = "\(baseURL)/wp-json/wp/v2/posts"
        
        guard var components = URLComponents(string: endpoint) else {
            throw WordPressError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "status", value: "any"),
            URLQueryItem(name: "orderby", value: "date"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "_fields", value: "id,date,date_gmt,modified,modified_gmt,slug,status,title,content,excerpt")
        ]
        
        guard let url = components.url else {
            throw WordPressError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add Basic Auth header
        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordPressError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let decoder = JSONDecoder()
                let posts = try decoder.decode([WordPressPost].self, from: data)
                return posts
            } catch {
                // Print the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(responseString)")
                }
                print("Decoding error: \(error)")
                throw WordPressError.decodingError
            }
        } else if httpResponse.statusCode == 401 {
            throw WordPressError.unauthorized
        } else {
            throw WordPressError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Helpers
    
    private func normalizeURL(_ url: String) -> String {
        var normalized = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https if no protocol specified
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://\(normalized)"
        }
        
        // Remove trailing slash
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        
        return normalized
    }
}

// MARK: - Models

// Request model for creating/updating posts
struct WordPressPostRequest: Codable {
    let title: String
    let content: String
    let status: String
    let slug: String?
    let excerpt: String?
    let date: String?
}

struct WordPressPost: Codable {
    let id: Int
    let date: String
    let dateGmt: String
    let modified: String
    let modifiedGmt: String
    let slug: String
    let status: String
    let title: RenderedContent
    let content: RenderedContent
    let excerpt: RenderedContent
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case dateGmt = "date_gmt"
        case modified
        case modifiedGmt = "modified_gmt"
        case slug
        case status
        case title
        case content
        case excerpt
    }
    
    // Helper computed properties to get dates
    var dateAsDate: Date {
        // WordPress date format: "2023-12-31T12:00:00"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: date) {
            return date
        }
        
        // Fallback to ISO8601
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: date) ?? Date()
    }
    
    var modifiedAsDate: Date {
        // WordPress date format: "2023-12-31T12:00:00"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: modified) {
            return date
        }
        
        // Fallback to ISO8601
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: modified) ?? Date()
    }
}

struct RenderedContent: Codable {
    let rendered: String
}

struct WordPressMedia: Codable {
    let id: Int
    let date: String
    let slug: String
    let status: String
    let title: RenderedContent
    let description: RenderedContent
    let caption: RenderedContent
    let altText: String
    let mediaType: String
    let mimeType: String
    let sourceUrl: String
    let mediaDetails: MediaDetails?
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case slug
        case status
        case title
        case description
        case caption
        case altText = "alt_text"
        case mediaType = "media_type"
        case mimeType = "mime_type"
        case sourceUrl = "source_url"
        case mediaDetails = "media_details"
    }
}

struct MediaDetails: Codable {
    let width: Int?
    let height: Int?
    let file: String?
    let sizes: [String: MediaSize]?
}

struct MediaSize: Codable {
    let file: String?
    let width: Int?
    let height: Int?
    let mimeType: String?
    let sourceUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case file
        case width
        case height
        case mimeType = "mime_type"
        case sourceUrl = "source_url"
    }
}

// MARK: - Errors

enum WordPressError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case decodingError
    case encodingError
    case missingRemoteID
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WordPress site URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Invalid username or password"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError:
            return "Failed to decode response"
        case .encodingError:
            return "Failed to encode request data"
        case .missingRemoteID:
            return "Cannot update post: missing remote ID"
        }
    }
}