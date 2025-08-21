//
//  File.swift
//  server
//
//  Created by Ilia Loviagin on 8/20/25.
//
import Vapor
// import NIOCore // <- если хочешь использовать NIODeadline, раскомментируй и см. ниже

enum GeminiService {
    static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    static func generate(_ req: Request, prompt: String) async throws -> String {
        // --- request id (берём из хедеров строкой, либо генерим)
        let reqID = req.headers["X-Request-ID"].first ?? UUID().uuidString

        var logger = req.logger
        logger[metadataKey: "rid"] = .string(reqID)
        logger[metadataKey: "endpoint"] = .string(endpoint)
        logger[metadataKey: "prompt_len"] = .string("\(prompt.count)")

        // --- ключ
        guard let apiKey = Environment.get("GEMINI_KEY"), !apiKey.isEmpty else {
            logger.error("GEMINI_KEY is not set")
            throw Abort(.internalServerError, reason: "GEMINI_KEY is not set")
        }

        // --- payload
        let payload = GeminiRequest(contents: [.init(parts: [.init(text: prompt)])])
        let bodyData = try JSONEncoder().encode(payload)
        logger[metadataKey: "in_bytes"] = .string("\(bodyData.count)")

        // --- upstream request
        var creq = ClientRequest(method: .POST, url: URI(string: endpoint))
        creq.headers.replaceOrAdd(name: .contentType, value: "application/json")
        creq.headers.replaceOrAdd(name: "x-goog-api-key", value: apiKey)
        creq.body = .init(data: bodyData)

        // --- таймер (через Date, чтобы не тянуть NIOCore)
        let start = Date()
        logger.info("gemini: start")

        do {
            let cres = try await req.client.send(creq)
            let data = Data(buffer: cres.body ?? .init())

            let dt = Date().timeIntervalSince(start)
            logger[metadataKey: "status"] = .string("\(cres.status.code)")
            logger[metadataKey: "out_bytes"] = .string("\(data.count)")
            logger.info("gemini: done in \(String(format: "%.3f", dt))s")

            guard cres.status == .ok || cres.status == .accepted else {
                let errBody = String(data: data, encoding: .utf8) ?? "<binary>"
                let snippet = String(errBody.prefix(8_192))
                logger.warning("gemini: non-2xx \(cres.status.code), body: \(snippet)")
                throw Abort(.badRequest, reason: "Gemini error \(cres.status.code)")
            }

            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            if let text = decoded.candidates?.first?.content?.parts?.first?.text, !text.isEmpty {
                return text
            } else {
                logger.warning("gemini: empty text in response")
                throw Abort(.badRequest, reason: "No text in Gemini response")
            }
        } catch {
            let dt = Date().timeIntervalSince(start)
            logger.error("gemini: failed after \(String(format: "%.3f", dt))s: \(error.localizedDescription)")
            throw error
        }
    }
}
