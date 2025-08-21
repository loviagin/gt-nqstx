//
//  File.swift
//  server
//
//  Created by Ilia Loviagin on 8/21/25.
//

import Vapor

struct GenerateImageDTO: Content {
    let prompt: String
}
