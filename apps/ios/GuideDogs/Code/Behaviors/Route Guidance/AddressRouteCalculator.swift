//
//  AddressRouteCalculator.swift
//  GuideDogs
//
//  Created by Bryan Besong on 2025-03-04.
//  Copyright © 2025 Soundscape community. All rights reserved.
//


import CoreLocation


class AddressRouteCalculator {
    
    /// Parses a Mapbox GeoJSON response and creates a RouteWaypoint
    /// - Parameters:
    ///   - geoJSON: The Mapbox GeoJSON response as a dictionary
    ///   - index: The waypoint's position in the route (default = 0)
    /// - Returns: A RouteWaypoint if successful, otherwise nil
    func createWaypoint(from geoJSON: [String: Any], index: Int = 0) -> RouteWaypoint? {
        // Extract the first feature
        guard let features = geoJSON["features"] as? [[String: Any]],
              let firstFeature = features.first,
              let geometry = firstFeature["geometry"] as? [String: Any],
              let nickname = firstFeature["text"] as? String, // Extract nickname
              let coordinates = geometry["coordinates"] as? [Double],
              coordinates.count == 2 else {
            print("🐛 Error: Invalid GeoJSON format")
            return nil
        }
        
        let longitude = coordinates[0]
        let latitude = coordinates[1]
        
        do {
            
            let locationDetail = try createLocationDetailWithMarker(latitude: latitude, longitude: longitude, nickname: nickname)
            try saveMarker(locationDetail: locationDetail, updatedLocation: nil)
            
            guard let waypoint = RouteWaypoint(index: index, locationDetail: locationDetail) else {
                print("🐛 Error: RouteWaypoint could not be created")
                return nil
            }
            
            print("✅ Waypoint created at index \(index), Marker ID: \(waypoint.markerId ?? "None")")
            return waypoint
        } catch {
            print("❌ Error creating waypoint: \(error.localizedDescription)")
            return nil
        }

    }
    
    func saveMarker(locationDetail: LocationDetail, updatedLocation: LocationDetail?) throws {
        let markerId: String
        let detail = updatedLocation ?? locationDetail

        // 🔍 Check if marker already exists in Realm
        if let id = locationDetail.markerId ?? SpatialDataCache.referenceEntity(source: locationDetail.source, isTemp: true)?.id {
            // ✅ Marker exists → Update it
            markerId = id
            try updateExisting(
                id: id,
                coordinate: detail.location.coordinate,
                nickname: detail.nickname,
                address: detail.estimatedAddress,
                annotation: detail.annotation
            )
        } else if case .entity(let id) = locationDetail.source, updatedLocation == nil {
            // ✅ New marker that references an existing POI
            markerId = try ReferenceEntity.add(
                entityKey: id,
                nickname: detail.nickname,
                estimatedAddress: detail.estimatedAddress,
                annotation: detail.annotation,
                context: nil
            )
        } else {
            // ✅ New marker at a generic location
            let loc = GenericLocation(
                lat: detail.location.coordinate.latitude,
                lon: detail.location.coordinate.longitude
            )
            markerId = try ReferenceEntity.add(
                location: loc,
                nickname: detail.nickname,
                estimatedAddress: detail.estimatedAddress,
                annotation: detail.annotation,
                temporary: false,
                context: nil
            )
        }
    }

    private func updateExisting(id: String, coordinate: CLLocationCoordinate2D?, nickname: String?, address: String?, annotation: String?) throws {
        try autoreleasepool {
            guard let entity = SpatialDataCache.referenceEntityByKey(id) else {
                return
            }

            try ReferenceEntity.update(
                entity: entity,
                location: coordinate,
                nickname: nickname,
                address: address,
                annotation: annotation,
                context: nil,
                isTemp: false
            )
        }
    }
    
    func createLocationDetailWithMarker(latitude: Double, longitude: Double, nickname: String?) throws -> LocationDetail {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let source = LocationDetail.Source.coordinate(at: location)

        print("📍 Checking for existing marker at (\(latitude), \(longitude))")

        if let existingMarker = SpatialDataCache.referenceEntity(source: source, isTemp: false) {
            print("✅ Existing marker found, using it")
            return LocationDetail(marker: existingMarker)
        } else {
            print("❌ No existing marker. Creating new marker with nickname: \(nickname ?? "None")")

            let genericLocation = GenericLocation(lat: latitude, lon: longitude)
            let newMarkerId = try ReferenceEntity.add(
                location: genericLocation,
                nickname: nickname, // Now setting nickname
                estimatedAddress: nil,
                annotation: nil,
                temporary: false,
                context: nil
            )

            guard let newMarker = SpatialDataCache.referenceEntityByKey(newMarkerId) else {
                throw NSError(domain: "LocationDetailError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve newly created marker."])
            }

            print("✅ New marker created with ID: \(newMarkerId)")
            return LocationDetail(marker: newMarker)
        }
    }
    
    static func testCreateWaypoints() -> [RouteWaypoint] {
        let waypointsData = getWaypointsFromAPI() // ✅ Fetch waypoints
        
        print("🚀 Creating multiple waypoints")
        
        let waypoints = waypointsData.enumerated().compactMap { index, data in
            print("🔍 Processing waypoint \(index + 1): \(data["text"] ?? "Unknown")")
            return AddressRouteCalculator().createWaypoint(from: ["features": [data]], index: index + 1)
        }

        print("✅ Successfully created \(waypoints.count) waypoints")
        return waypoints
    }

    
    static func testCreateRoute(waypointsData: [[String: Any]]) -> Route { // ✅ Accept waypointsData as a parameter
        let waypoints = waypointsData.enumerated().compactMap { index, data in
            AddressRouteCalculator().createWaypoint(from: ["features": [data]], index: index + 1)
        }

        let routeName = "To Eiffel Tower"
        let routeDescription = "Scenic path leading to the Eiffel Tower."

        print("🚀 Creating Route: \(routeName) with \(waypoints.count) waypoints")

        let route = Route(name: routeName, description: routeDescription, waypoints: waypoints)

        do {
            try Route.add(route) // ✅ Correctly adds the route to the database
            print("✅ Route added to database: \(route.name)")
        } catch {
            print("❌ Failed to add route: \(error.localizedDescription)")
        }

        return route
    }


    
    static func getWaypointsFromAPI() -> [[String: Any]] {
        print("🌐 Fetching waypoints from API")
        return [
            [
                "id": "poi.123456",
                "type": "Feature",
                "place_type": ["poi"],
                "text": "Eiffel Tower",
                "geometry": [
                    "type": "Point",
                    "coordinates": [2.294481, 48.858370]
                ]
            ],
            [
                "id": "poi.123457",
                "type": "Feature",
                "place_type": ["poi"],
                "text": "Champ de Mars",
                "geometry": [
                    "type": "Point",
                    "coordinates": [2.297220, 48.855480]
                ]
            ],
            [
                "id": "poi.123458",
                "type": "Feature",
                "place_type": ["poi"],
                "text": "Seine Riverside",
                "geometry": [
                    "type": "Point",
                    "coordinates": [2.293480, 48.857800]
                ]
            ]
        ]
    }




}






