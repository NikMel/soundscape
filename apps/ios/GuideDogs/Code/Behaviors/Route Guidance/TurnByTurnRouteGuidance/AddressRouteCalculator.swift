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
                return nil
            }
            
            return waypoint
        } catch {
            GDLogError(.routeGuidance, "Error creating waypoint: \(error.localizedDescription)")

            return nil
        }
    }

    
    func saveMarker(locationDetail: LocationDetail, updatedLocation: LocationDetail?) throws {
        let markerId: String
        let detail = updatedLocation ?? locationDetail

        // 🔍 Check if marker already exists in Realm
        if let id = locationDetail.markerId ?? SpatialDataCache.referenceEntity(source: locationDetail.source, isTemp: true)?.id {
            markerId = id
            try updateExisting(
                id: id,
                coordinate: detail.location.coordinate,
                nickname: detail.nickname,
                address: detail.estimatedAddress,
                annotation: detail.annotation
            )
        } else if case .entity(let id) = locationDetail.source, updatedLocation == nil {
            markerId = try ReferenceEntity.add(
                entityKey: id,
                nickname: detail.nickname,
                estimatedAddress: detail.estimatedAddress,
                annotation: detail.annotation,
                context: nil
            )
        } else {
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


        if let existingMarker = SpatialDataCache.referenceEntity(source: source, isTemp: false) {
            return LocationDetail(marker: existingMarker)
        } else {
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

            return LocationDetail(marker: newMarker)
        }
    }
    
    
    static func testCreateRoute(waypointsData: [(Double, Double, Double?, String)], resolvedDestination: String) -> Route {

        let waypoints = waypointsData.enumerated().compactMap { index, data in
            return AddressRouteCalculator().createWaypoint(from: data, index: index + 1)
        }

        let routeName = "To \(resolvedDestination)"
        let routeDescription = "Scenic path leading to \(resolvedDestination)."


        let route = Route(name: routeName, description: routeDescription, waypoints: waypoints)

        do {
            try Route.add(route)
        } catch {
            GDLogError(.routeGuidance, "Failed to add route: \(error.localizedDescription)")

        }

        return route
    }
    
    // MARK: - Static Method: Create Route as Task (per GPT suggestion)

    static func createRouteTask(origin: String, destination: String) {
        // Debug: Start
        print("🛣️ Starting route creation task from: \(origin) to: \(destination)")
        
        Task {
            let mapsDecoder = MapsDecoder()
            let (resolvedDestination, coordinates) = await mapsDecoder.fetchRoute(
                origin: origin,
                destination: destination
            )
            
            guard let coordinates = coordinates else {
                print("❌ Failed to fetch coordinates for route")
                return
            }
            
            if let resolvedDestination = resolvedDestination {
                print("📍 Using resolved destination: \(resolvedDestination)")
            } else {
                print("⚠️ Using raw destination coordinates")
            }
            
            let route = AddressRouteCalculator.testCreateRoute(
                waypointsData: coordinates,
                resolvedDestination: resolvedDestination ?? "Unknown Destination"
            )
            
        }
    }
    
    static func createRouteTask(originLocation: CLLocation, destinationDetail: LocationDetail) {
        let originLat = originLocation.coordinate.latitude
        let originLon = originLocation.coordinate.longitude
        let origin = "\(originLat),\(originLon)"
        print("🟢 Formatted Origin: \(origin)")

        let destLat = destinationDetail.location.coordinate.latitude
        let destLon = destinationDetail.location.coordinate.longitude
        let destination = "\(destLat),\(destLon)"
        print("🟢 Formatted Destination: \(destination)")

        // Call existing method
        createRouteTask(origin: origin, destination: destination)
    }


}






