//
//  WordPressAPI.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

import Foundation
import Darwin

class WordPressAPI {
    static let shared = WordPressAPI()
    private init() {}
    
    private var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
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
        
        DebugLogger.shared.log("Starting image upload to: \(endpoint)", level: .info, source: "WordPressAPI")
        DebugLogger.shared.log("Image details - Filename: \(filename), Size: \(imageData.count) bytes, MIME: \(mimeType)", level: .info, source: "WordPressAPI")
        
        guard let url = URL(string: endpoint) else {
            DebugLogger.shared.log("Invalid URL: \(endpoint)", level: .error, source: "WordPressAPI")
            throw WordPressError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add Basic Auth header
        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            DebugLogger.shared.log("Authorization header added for user: \(username)", level: .debug, source: "WordPressAPI")
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
        
        DebugLogger.shared.log("Sending multipart request with body size: \(body.count) bytes", level: .info, source: "WordPressAPI")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            DebugLogger.shared.log("Invalid response type", level: .error, source: "WordPressAPI")
            throw WordPressError.invalidResponse
        }
        
        DebugLogger.shared.log("Response status code: \(httpResponse.statusCode)", level: .info, source: "WordPressAPI")
        
        if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
            if httpResponse.statusCode == 200 {
                DebugLogger.shared.log("Received HTTP 200 on image upload; treating as success", level: .warning, source: "WordPressAPI")
            }
            do {
                let decoder = JSONDecoder()
                let media = try decoder.decode(WordPressMedia.self, from: data)
                DebugLogger.shared.log("Image uploaded successfully! Media ID: \(media.id), URL: \(media.sourceUrl)", level: .info, source: "WordPressAPI")
                return media
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    DebugLogger.shared.log("Raw media response: \(responseString)", level: .debug, source: "WordPressAPI")
                    print("Raw media response: \(responseString)")
                }
                DebugLogger.shared.log("Media decoding error: \(error)", level: .error, source: "WordPressAPI")
                print("Media decoding error: \(error)")
                throw WordPressError.decodingError
            }
        } else if httpResponse.statusCode == 401 {
            DebugLogger.shared.log("Unauthorized - check username and password", level: .error, source: "WordPressAPI")
            throw WordPressError.unauthorized
        } else {
            // Print error response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                DebugLogger.shared.log("Media upload error response: \(responseString)", level: .error, source: "WordPressAPI")
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
        
        // Log the content being sent to WordPress
        DebugLogger.shared.log("=== Sending content to WordPress ===", level: .info, source: "WordPressAPI")
        DebugLogger.shared.log("Post ID: \(post.remoteID ?? 0)", level: .info, source: "WordPressAPI")
        DebugLogger.shared.log("Title: \(post.title)", level: .info, source: "WordPressAPI")
        DebugLogger.shared.log("Content length: \(post.content.count) characters", level: .info, source: "WordPressAPI")
        DebugLogger.shared.log("Content preview: \(String(post.content.prefix(500)))", level: .debug, source: "WordPressAPI")
        
        // Check for potential issues
        if post.content.contains("\\n") {
            DebugLogger.shared.log("WARNING: Content contains escaped newlines (\\n)", level: .warning, source: "WordPressAPI")
        }
        if post.content.contains("&#") || post.content.contains("&lt;") || post.content.contains("&gt;") {
            DebugLogger.shared.log("WARNING: Content contains HTML entities", level: .warning, source: "WordPressAPI")
        }
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(postData)
            
            // Log the JSON being sent
            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                DebugLogger.shared.log("JSON being sent: \(String(jsonString.prefix(1000)))", level: .debug, source: "WordPressAPI")
            }
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
        
        // Log the content being sent to WordPress
        DebugLogger.shared.log("=== Sending content to WordPress ===", level: .info, source: "WordPressAPI")
        DebugLogger.shared.log("Post ID: \(post.remoteID ?? 0)", level: .info, source: "WordPressAPI")
        DebugLogger.shared.log("Title: \(post.title)", level: .info, source: "WordPressAPI")
        DebugLogger.shared.log("Content length: \(post.content.count) characters", level: .info, source: "WordPressAPI")
        DebugLogger.shared.log("Content preview: \(String(post.content.prefix(500)))", level: .debug, source: "WordPressAPI")
        
        // Check for potential issues
        if post.content.contains("\\n") {
            DebugLogger.shared.log("WARNING: Content contains escaped newlines (\\n)", level: .warning, source: "WordPressAPI")
        }
        if post.content.contains("&#") || post.content.contains("&lt;") || post.content.contains("&gt;") {
            DebugLogger.shared.log("WARNING: Content contains HTML entities", level: .warning, source: "WordPressAPI")
        }
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(postData)
            
            // Log the JSON being sent
            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                DebugLogger.shared.log("JSON being sent: \(String(jsonString.prefix(1000)))", level: .debug, source: "WordPressAPI")
            }
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
                
                // Log the response content
                DebugLogger.shared.log("=== WordPress Update Response ===", level: .info, source: "WordPressAPI")
                DebugLogger.shared.log("Updated post ID: \(updatedPost.id)", level: .info, source: "WordPressAPI")
                DebugLogger.shared.log("Response content preview: \(String(updatedPost.content.rendered.prefix(500)))", level: .debug, source: "WordPressAPI")
                
                return updatedPost
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw update post response: \(responseString)")
                    DebugLogger.shared.log("Raw update response: \(responseString)", level: .error, source: "WordPressAPI")
                }
                print("Post update decoding error: \(error)")
                DebugLogger.shared.log("Post update decoding error: \(error)", level: .error, source: "WordPressAPI")
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
    
    func fetchPosts(siteURL: String, username: String, password: String, page: Int = 1, perPage initialPerPage: Int = 50) async throws -> [WordPressPost] {
        let baseURL = normalizeURL(siteURL)

        do {
            return try await fetchPostsPaged(
                baseURL: baseURL,
                username: username,
                password: password,
                startPage: page,
                initialPerPage: initialPerPage
            )
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSPOSIXErrorDomain && nsError.code == POSIXErrorCode.EMSGSIZE.rawValue {
                DebugLogger.shared.log("Paged post fetch exceeded message size, retrying with individual post requests.", level: .warning, source: "WordPressAPI")
                return try await fetchPostsIndividually(
                    baseURL: baseURL,
                    username: username,
                    password: password,
                    startPage: page,
                    initialPerPage: initialPerPage
                )
            }
            throw error
        }
    }

    private func fetchPostsPaged(
        baseURL: String,
        username: String,
        password: String,
        startPage: Int,
        initialPerPage: Int
    ) async throws -> [WordPressPost] {
        var allPosts: [WordPressPost] = []
        var currentPage = startPage
        var currentPerPage = initialPerPage
        var totalPages: Int?

        DebugLogger.shared.log("Preparing to fetch WordPress posts with initial per_page=\(initialPerPage)", level: .debug, source: "WordPressAPI")

        while totalPages == nil || currentPage <= (totalPages ?? 0) {
            let pageResult = try await fetchPostsPage(
                baseURL: baseURL,
                username: username,
                password: password,
                page: currentPage,
                perPage: currentPerPage
            )

            allPosts.append(contentsOf: pageResult.posts)
            currentPerPage = pageResult.perPageUsed

            if let pageCount = pageResult.totalPages {
                totalPages = pageCount
            }

            DebugLogger.shared.log(
                "Fetched page \(currentPage) with per_page=\(pageResult.perPageUsed); retrieved \(pageResult.posts.count) posts",
                level: .debug,
                source: "WordPressAPI"
            )

            if pageResult.posts.count < pageResult.perPageUsed {
                break
            }

            currentPage += 1
        }

        DebugLogger.shared.log("Completed WordPress fetch. Total posts retrieved: \(allPosts.count)", level: .info, source: "WordPressAPI")
        return allPosts
    }

    private func fetchPostsPage(
        baseURL: String,
        username: String,
        password: String,
        page: Int,
        perPage: Int
    ) async throws -> (posts: [WordPressPost], totalPages: Int?, perPageUsed: Int) {
        var attemptPerPage = perPage
        var lastError: Error?

        while attemptPerPage >= 1 {
            guard var components = URLComponents(string: "\(baseURL)/wp-json/wp/v2/posts") else {
                throw WordPressError.invalidURL
            }

            components.queryItems = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(attemptPerPage)),
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
            request.setValue("clear", forHTTPHeaderField: "Alt-Svc")

            let credentials = "\(username):\(password)"
            if let credentialData = credentials.data(using: .utf8) {
                let base64Credentials = credentialData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
                DebugLogger.shared.log("Authorization header length: \(base64Credentials.count) characters", level: .debug, source: "WordPressAPI")
            } else {
                DebugLogger.shared.log("Failed to encode credentials as UTF-8", level: .error, source: "WordPressAPI")
            }

            DebugLogger.shared.log("Requesting posts page \(page) with per_page=\(attemptPerPage)", level: .debug, source: "WordPressAPI")

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WordPressError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    do {
                        let decoder = JSONDecoder()
                        let posts = try decoder.decode([WordPressPost].self, from: data)
                        let totalPagesHeader = httpResponse.value(forHTTPHeaderField: "X-WP-TotalPages")
                        let totalPages = totalPagesHeader.flatMap { Int($0) }
                        return (posts, totalPages, attemptPerPage)
                    } catch {
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("Raw response: \(responseString)")
                        }
                        print("Decoding error: \(error)")
                        throw WordPressError.decodingError
                    }
                } else if httpResponse.statusCode == 401 {
                    throw WordPressError.unauthorized
                } else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        DebugLogger.shared.log("Fetch posts error response: \(responseString)", level: .error, source: "WordPressAPI")
                    }
                    throw WordPressError.httpError(statusCode: httpResponse.statusCode)
                }
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSPOSIXErrorDomain && nsError.code == POSIXErrorCode.EMSGSIZE.rawValue && attemptPerPage > 1 {
                    let newPerPage = max(1, attemptPerPage / 2)
                    DebugLogger.shared.log(
                        "Received EMSGSIZE when fetching page \(page). Reducing per_page from \(attemptPerPage) to \(newPerPage) and retrying.",
                        level: .warning,
                        source: "WordPressAPI"
                    )
                    attemptPerPage = newPerPage
                    lastError = error
                    continue
                } else {
                    throw error
                }
            }
        }

        if let error = lastError {
            throw error
        }

        throw WordPressError.invalidResponse
    }

    private func fetchPostsIndividually(
        baseURL: String,
        username: String,
        password: String,
        startPage: Int,
        initialPerPage: Int
    ) async throws -> [WordPressPost] {
        DebugLogger.shared.log("Falling back to individual post fetch", level: .warning, source: "WordPressAPI")

        let postIDs = try await fetchPostIDs(
            baseURL: baseURL,
            username: username,
            password: password,
            startPage: startPage,
            initialPerPage: initialPerPage
        )

        DebugLogger.shared.log("Fetching \(postIDs.count) posts individually", level: .info, source: "WordPressAPI")

        var posts: [WordPressPost] = []
        posts.reserveCapacity(postIDs.count)

        for (index, postID) in postIDs.enumerated() {
            do {
                let post = try await fetchSinglePost(
                    baseURL: baseURL,
                    username: username,
                    password: password,
                    postID: postID
                )
                posts.append(post)

                if (index + 1) % 5 == 0 || index == postIDs.count - 1 {
                    DebugLogger.shared.log("Fetched \(index + 1)/\(postIDs.count) posts individually", level: .debug, source: "WordPressAPI")
                }
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSPOSIXErrorDomain && nsError.code == POSIXErrorCode.EMSGSIZE.rawValue {
                    DebugLogger.shared.log("Failed to fetch post \(postID) individually due to EMSGSIZE", level: .error, source: "WordPressAPI")
                }
                throw error
            }
        }

        return posts
    }

    private func fetchPostIDs(
        baseURL: String,
        username: String,
        password: String,
        startPage: Int,
        initialPerPage: Int
    ) async throws -> [Int] {
        var allIDs: [Int] = []
        var currentPage = startPage
        var currentPerPage = initialPerPage
        var totalPages: Int?

        while totalPages == nil || currentPage <= (totalPages ?? 0) {
            let pageResult = try await fetchPostIDsPage(
                baseURL: baseURL,
                username: username,
                password: password,
                page: currentPage,
                perPage: currentPerPage
            )

            allIDs.append(contentsOf: pageResult.ids)
            currentPerPage = pageResult.perPageUsed

            if let pageCount = pageResult.totalPages {
                totalPages = pageCount
            }

            DebugLogger.shared.log(
                "Fetched ID page \(currentPage) with per_page=\(pageResult.perPageUsed); retrieved \(pageResult.ids.count) IDs",
                level: .debug,
                source: "WordPressAPI"
            )

            if pageResult.ids.count < pageResult.perPageUsed {
                break
            }

            currentPage += 1
        }

        return allIDs
    }

    private func fetchPostIDsPage(
        baseURL: String,
        username: String,
        password: String,
        page: Int,
        perPage: Int
    ) async throws -> (ids: [Int], totalPages: Int?, perPageUsed: Int) {
        var attemptPerPage = perPage
        var lastError: Error?

        while attemptPerPage >= 1 {
            guard var components = URLComponents(string: "\(baseURL)/wp-json/wp/v2/posts") else {
                throw WordPressError.invalidURL
            }

            components.queryItems = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(attemptPerPage)),
                URLQueryItem(name: "status", value: "any"),
                URLQueryItem(name: "orderby", value: "date"),
                URLQueryItem(name: "order", value: "desc"),
                URLQueryItem(name: "_fields", value: "id")
            ]

            guard let url = components.url else {
                throw WordPressError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let credentials = "\(username):\(password)"
            if let credentialData = credentials.data(using: .utf8) {
                let base64Credentials = credentialData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
                DebugLogger.shared.log("Authorization header length (ID fetch): \(base64Credentials.count) characters", level: .debug, source: "WordPressAPI")
            }

            DebugLogger.shared.log("Requesting post ID page \(page) with per_page=\(attemptPerPage)", level: .debug, source: "WordPressAPI")

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw WordPressError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    let summaries = try decoder.decode([WordPressPostIDSummary].self, from: data)
                    let totalPagesHeader = httpResponse.value(forHTTPHeaderField: "X-WP-TotalPages")
                    let totalPages = totalPagesHeader.flatMap { Int($0) }
                    let ids = summaries.map { $0.id }
                    return (ids, totalPages, attemptPerPage)
                } else if httpResponse.statusCode == 401 {
                    throw WordPressError.unauthorized
                } else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        DebugLogger.shared.log("Post ID fetch error response: \(responseString)", level: .error, source: "WordPressAPI")
                    }
                    throw WordPressError.httpError(statusCode: httpResponse.statusCode)
                }
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSPOSIXErrorDomain && nsError.code == POSIXErrorCode.EMSGSIZE.rawValue && attemptPerPage > 1 {
                    let newPerPage = max(1, attemptPerPage / 2)
                    DebugLogger.shared.log(
                        "Received EMSGSIZE when fetching ID page \(page). Reducing per_page from \(attemptPerPage) to \(newPerPage) and retrying.",
                        level: .warning,
                        source: "WordPressAPI"
                    )
                    attemptPerPage = newPerPage
                    lastError = error
                    continue
                } else {
                    throw error
                }
            }
        }

        if let error = lastError {
            throw error
        }

        throw WordPressError.invalidResponse
    }

    private func fetchSinglePost(
        baseURL: String,
        username: String,
        password: String,
        postID: Int
    ) async throws -> WordPressPost {
        guard var components = URLComponents(string: "\(baseURL)/wp-json/wp/v2/posts/\(postID)") else {
            throw WordPressError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "_fields", value: "id,date,date_gmt,modified,modified_gmt,slug,status,title,content,excerpt")
        ]

        guard let url = components.url else {
            throw WordPressError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let credentials = "\(username):\(password)"
        if let credentialData = credentials.data(using: .utf8) {
            let base64Credentials = credentialData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            DebugLogger.shared.log("Authorization header length (single post): \(base64Credentials.count) characters", level: .debug, source: "WordPressAPI")
        }

        DebugLogger.shared.log("Requesting individual post \(postID)", level: .debug, source: "WordPressAPI")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WordPressError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(WordPressPost.self, from: data)
        } else if httpResponse.statusCode == 401 {
            throw WordPressError.unauthorized
        } else {
            if let responseString = String(data: data, encoding: .utf8) {
                DebugLogger.shared.log("Single post fetch error response: \(responseString)", level: .error, source: "WordPressAPI")
            }
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


struct WordPressPostIDSummary: Codable {
    let id: Int
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
