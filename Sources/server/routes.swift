import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.post("gemini") { req async throws -> String in
        let dto = try req.content.decode(GenerateDTO.self)
        return try await GeminiService.generate(req, prompt: dto.prompt)
    }
}
