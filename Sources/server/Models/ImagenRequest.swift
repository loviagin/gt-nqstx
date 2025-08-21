//
//  File.swift
//  server
//
//  Created by Ilia Loviagin on 8/21/25.
//

import Vapor

struct ImagenRequest: Codable {
    struct Instance: Codable { let prompt: String }
    struct Parameters: Codable { let sampleCount: Int }

    let instances: [Instance]
    let parameters: Parameters
}
