//
//  QodSession.swift
//  Basic-Video-Chat
//
//  Created by Benjamin Aronov on 30/10/2024.
//  Copyright © 2024 tokbox. All rights reserved.
//
struct Session: Codable {
    let channels: [Channel]
    let duration: Int
    let id: String
    let msisdn: String
    let sourceIp: String
    let update: Update?

}

struct Channel: Codable {
    let destination: Destination
    let qodProfile: String
    let source: Source
    let statuses: [Status]
}

struct Destination: Codable {
    let cidr: String
}

struct Source: Codable {
    // Define properties if any
}

struct Status: Codable {
    let reason: String
    let status: String
    let updated: String
}

struct Update: Codable {
    let status: String
    let updated: String
}
