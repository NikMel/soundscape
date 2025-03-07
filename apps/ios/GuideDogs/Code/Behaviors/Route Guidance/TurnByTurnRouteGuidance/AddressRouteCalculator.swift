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
    func createWaypoint(from coordinateData: (Double, Double, Double?, String), index: Int = 0) -> RouteWaypoint? {
        let (latitude, longitude, _, nickname) = coordinateData
        
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
            let (latitude, longitude, elevation, nickname) = data
            print("🔍 Processing waypoint \(index + 1): \(nickname)")

            return AddressRouteCalculator().createWaypoint(from: data, index: index + 1)
        }

        print("✅ Successfully created \(waypoints.count) waypoints")
        return waypoints
    }


    
    static func testCreateRoute(waypointsData: [(Double, Double, Double?, String)]) -> Route {
        print("🚀 Creating Route")

        let waypoints = waypointsData.enumerated().compactMap { index, data in
            print("🔍 Processing waypoint \(index + 1): \(data.3)") // Using nickname from tuple
            return AddressRouteCalculator().createWaypoint(from: data, index: index + 1)
        }

        let routeName = "To Eiffel Tower"
        let routeDescription = "Scenic path leading to the Eiffel Tower."

        print("✅ Creating Route: \(routeName) with \(waypoints.count) waypoints")

        let route = Route(name: routeName, description: routeDescription, waypoints: waypoints)

        do {
            try Route.add(route) // ✅ Correctly adds the route to the database
            print("✅ Route added to database: \(route.name)")
        } catch {
            print("❌ Failed to add route: \(error.localizedDescription)")
        }

        return route
    }



    
    static func getWaypointsFromAPI() -> [(Double, Double, Double?, String)] {
        print("🌍 Fetching waypoints from API")
        return [
            (48.858370, 2.294481, nil, "point_1"),
            (48.855480, 2.297220, nil, "point_2"),
            (48.857800, 2.293480, nil, "point_3")
        ]
    }




}






