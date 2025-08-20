//
//  File.swift
//  server
//
//  Created by Ilia Loviagin on 8/20/25.
//

import Vapor

struct GeminiRequest: Encodable {
    struct Content: Codable {
        struct Part: Codable { let text: String }
        let parts: [Part]
    }
    let contents: [Content]
}
