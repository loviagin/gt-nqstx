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
        // request id & базовые метаданные
        let reqID = req.headers["X-Request-ID"].first ?? UUID().uuidString
        var logger = req.logger
        logger[metadataKey: "rid"] = .string(reqID)
        logger[metadataKey: "endpoint"] = .string(endpoint)
        logger[metadataKey: "prompt_len"] = .string("\(prompt.count)")

        // ключ
        guard let apiKey = Environment.get("GEMINI_KEY"), !apiKey.isEmpty else {
            logger.error("GEMINI_KEY is not set")
            throw Abort(.internalServerError, reason: "GEMINI_KEY is not set")
        }

        // payload
        let payload = GeminiRequest(contents: [.init(parts: [.init(text: prompt)])])
        let bodyData = try JSONEncoder().encode(payload)
        logger[metadataKey: "in_bytes"] = .string("\(bodyData.count)")

        // ЧИСТЫЕ заголовки (никаких X-Forwarded-For и прочего)
        var creq = ClientRequest(method: .POST, url: URI(string: endpoint))
        creq.headers = HTTPHeaders()
        creq.headers.replaceOrAdd(name: .contentType, value: "application/json")
        creq.headers.replaceOrAdd(name: "x-goog-api-key", value: apiKey)
        creq.body = .init(data: bodyData)

        logger.info("gemini: start; outbound headers=\(creq.headers)")

        let start = Date()
        do {
            let cres = try await req.client.send(creq)
            let data = Data(buffer: cres.body ?? .init())

            let dt = Date().timeIntervalSince(start)
            logger[metadataKey: "status"] = .string("\(cres.status.code)")
            logger[metadataKey: "out_bytes"] = .string("\(data.count)")
            logger.info("gemini: done in \(String(format: "%.3f", dt))s")

            // Если апстрим вернул не 2xx — сразу пробрасываем статус клиенту
            guard (200..<300).contains(cres.status.code) else {
                let errBody = String(data: data, encoding: .utf8) ?? "<binary>"
                logger.warning("gemini: non-2xx \(cres.status.code), body: \(errBody.prefix(4096))")
                // Пробросим статус и короткое сообщение клиенту
                throw Abort(cres.status, reason: "Upstream \(cres.status.code)")
            }

            // OK: парсим текст
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
