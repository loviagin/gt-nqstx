//
//  File.swift
//  server
//
//  Created by Ilia Loviagin on 8/20/25.
//

import Vapor

enum GeminiService {
    static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    static func generate(_ req: Request, prompt: String) async throws -> String {
        // 1) API key
        guard let apiKey = Environment.get("GEMINI_KEY"), !apiKey.isEmpty else {
            throw Abort(.internalServerError, reason: "GEMINI_KEY is not set")
        }

        // 2) Request payload
        let payload = GeminiRequest(
            contents: [.init(parts: [.init(text: prompt)])]
        )
        let bodyData = try JSONEncoder().encode(payload)

        // 3) Build client request
        var creq = ClientRequest(method: .POST, url: URI(string: endpoint))
        creq.headers.replaceOrAdd(name: .contentType, value: "application/json")
        creq.headers.replaceOrAdd(name: "x-goog-api-key", value: apiKey)
        creq.body = .init(data: bodyData)

        // 4) Send & decode
        let cres = try await req.client.send(creq)

        guard cres.status == .ok || cres.status == .accepted else {
            let errBody = cres.body.flatMap { String(buffer: $0) } ?? "<empty>"
            throw Abort(.badRequest, reason: "Gemini error \(cres.status.code): \(errBody)")
        }

        let data = Data(buffer: cres.body ?? .init())
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let text = decoded.candidates?
            .first?.content?
            .parts?.first?.text, !text.isEmpty {
            return text
        } else {
            throw Abort(.badRequest, reason: "No text in Gemini response")
        }
    }
}
