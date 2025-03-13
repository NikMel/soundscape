//
//  HereMapsModels.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-06.
//  Copyright © 2025 Soundscape community. All rights reserved.
//

import Foundation

struct HereRouteResponse: Decodable {
    let routes: [HereNavigationRoute]
}

struct HereNavigationRoute: Decodable {  
    let id: String
    let sections: [HereSection]
}

struct HereSection: Decodable {
    let id: String
    let type: String
    let polyline: String
    let spans: [HereSpan]?
    let turnByTurnActions: [HereTurnAction]?
    
    func getSpanOffsets() -> [Int] {
        return spans?.map { $0.offset } ?? []
    }
}

struct HereSpan: Decodable {
    let offset: Int
    let streetAttributes: [String]?
    let names: [HereStreetName]?
}

struct HereTurnAction: Decodable {
    let action: String
    let duration: Int
    let length: Int
    let offset: Int
    let direction: String?
    let turnAngle: Double?
}

struct HereStreetName: Decodable {
    let value: String
    let language: String
}
