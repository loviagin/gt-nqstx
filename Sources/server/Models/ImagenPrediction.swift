//
//  File.swift
//  server
//
//  Created by Ilia Loviagin on 8/21/25.
//

import Vapor

struct ImagenPrediction: Codable {
    let bytesBase64Encoded: String?
    let mimeType: String?
}
