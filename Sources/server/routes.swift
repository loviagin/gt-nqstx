import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.post("gemini") { req async throws -> String in
        let dto = try req.content.decode(GenerateDTO.self)
        return try await GeminiService.generate(req, prompt: dto.prompt)
    }
    
    app.post("imagen") { req async throws -> String in
        let dto = try req.content.decode(GenerateImageDTO.self)
        return try await ImagenService.generate(req, prompt: dto.prompt)
    }
    
    app.get("donate") { req async throws -> DonateDTO in
        return DonateDTO(allowed: false)
    }
}
