//
//  File.swift
//  server
//
//  Created by Ilia Loviagin on 8/21/25.
//

import Vapor

enum ImagenService {
    // эндпоинт из твоего примера
    static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-generate-001:predict"

    static func generate(_ req: Request, prompt: String) async throws -> String {
        // request-id / метаданные
        let reqID = req.headers["X-Request-ID"].first ?? UUID().uuidString
        var logger = req.logger
        logger[metadataKey: "rid"] = .string(reqID)
        logger[metadataKey: "endpoint"] = .string(endpoint)
        logger[metadataKey: "prompt_len"] = .string("\(prompt.count)")

        // ключ
        guard let apiKey = Environment.get("IMAGEN_KEY"), !apiKey.isEmpty else {
            logger.error("IMAGEN_KEY is not set")
            throw Abort(.internalServerError, reason: "IMAGEN_KEY is not set")
        }

        // payload (с твоей добавкой «NO TEXT ON IMAGE!!!»)
        let fullPrompt = "\(prompt) " + NSLocalizedString("No labels, no text, just a picture. NO TEXT ON IMAGE!!!", comment: "Generator")
        let payload = ImagenRequest(
            instances: [.init(prompt: fullPrompt)],
            parameters: .init(sampleCount: 1)
        )
        let bodyData = try JSONEncoder().encode(payload)
        logger[metadataKey: "in_bytes"] = .string("\(bodyData.count)")

        // чистые заголовки
        var creq = ClientRequest(method: .POST, url: URI(string: endpoint))
        creq.headers = HTTPHeaders()
        creq.headers.replaceOrAdd(name: .contentType, value: "application/json")
        creq.headers.replaceOrAdd(name: "x-goog-api-key", value: apiKey)
        creq.body = .init(data: bodyData)

        logger.info("imagen: start; outbound headers=\(creq.headers)")

        let start = Date()
        do {
            let cres = try await req.client.send(creq)
            let data = Data(buffer: cres.body ?? .init())
            let dt = Date().timeIntervalSince(start)

            logger[metadataKey: "status"] = .string("\(cres.status.code)")
            logger[metadataKey: "out_bytes"] = .string("\(data.count)")
            logger.info("imagen: done in \(String(format: "%.3f", dt))s")

            // non-2xx -> сразу клиенту, чтобы не висел
            guard (200..<300).contains(cres.status.code) else {
                let snippet = (String(data: data, encoding: .utf8) ?? "<binary>").prefix(4096)
                logger.warning("imagen: non-2xx \(cres.status.code), body: \(snippet)")
                throw Abort(cres.status, reason: "Upstream \(cres.status.code)")
            }

            // парсим base64
            let decoded = try JSONDecoder().decode(ImagenResponse.self, from: data)
            if let b64 = decoded.predictions?.first?.bytesBase64Encoded, !b64.isEmpty {
                return b64
            } else {
                logger.warning("imagen: no bytesBase64Encoded in response")
                throw Abort(.badRequest, reason: "No image in Imagen response")
            }
        } catch {
            let dt = Date().timeIntervalSince(start)
            logger.error("imagen: failed after \(String(format: "%.3f", dt))s: \(error.localizedDescription)")
            throw error
        }
    }
}
