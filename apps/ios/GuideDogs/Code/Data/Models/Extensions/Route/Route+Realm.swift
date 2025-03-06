//
//  Route+Realm.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import RealmSwift
import CoreLocation

extension Route {
    
    // MARK: Query All Routes
    
    static func object(forPrimaryKey key: String) -> Route? {
        return autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return nil
            }
            
            return database.object(ofType: Route.self, forPrimaryKey: key)
        }
    }
    
    static func objectKeys(sortedBy: SortStyle) -> [String] {
        return autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                return []
            }
            
            switch sortedBy {
            case .alphanumeric:
                return database.objects(Route.self)
                    .sorted(by: { $0.name < $1.name })
                    .compactMap({ $0.id })
                
            case .distance:
                let userLocation = AppContext.shared.geolocationManager.location ?? CLLocation(latitude: 0.0, longitude: 0.0)
                
                return database.objects(Route.self)
                    .compactMap { route -> (id: String, distance: CLLocationDistance)? in
                        guard let start = route.waypoints.ordered.first, let entity = SpatialDataCache.referenceEntityByKey(start.markerId) else {
                            return (id: route.id, distance: CLLocationDistance.greatestFiniteMagnitude)
                        }
                        
                        return (id: route.id, distance: entity.distanceToClosestLocation(from: userLocation))
                    }
                    .sorted { $0.distance < $1.distance }
                    .compactMap({ $0.id })
            }
        }
    }
    
    // MARK: Add or Delete Routes
    
    static func add(_ route: Route, context: String? = nil) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                print("🐛 Failed to get database realm")
                throw RouteRealmError.databaseError
            }
            print("🐛 Database retrieved successfully")

            // Log the route details before processing
            print("🐛 Adding route - ID: \(route.id), Name: \(route.name), Waypoints: \(route.waypoints.count)")

            try route.waypoints.forEach {
                guard let locationDetail = $0.asLocationDetail else {
                    print("🐛 Skipping waypoint due to missing location detail")
                    return
                }
                let markerId = try ReferenceEntity.add(detail: locationDetail, telemetryContext: "add_route", notify: false)
                $0.markerId = markerId
                print("🐛 Waypoint processed - Marker ID: \(markerId)")
            }

            if let existingRoute = database.object(ofType: Route.self, forPrimaryKey: route.id) {
                print("🐛 Route already exists, updating instead of adding")
                try update(id: existingRoute.id, name: route.name, description: route.routeDescription, waypoints: route.waypoints)
                AppContext.shared.cloudKeyValueStore.update(route: route)
            } else {
                try database.write {
                    database.add(route, update: .modified)
                    print("🐛 New route added to database")
                }
                AppContext.shared.cloudKeyValueStore.store(route: route)
                print("🐛 Route stored in cloud key-value store")

                let id = route.id
                NotificationCenter.default.post(name: .routeAdded, object: self, userInfo: [Route.Keys.id: id])
                print("🐛 Notification posted for route addition - ID: \(id)")

                GDATelemetry.track("routes.added", with: [
                    "context": context ?? "none",
                    "activity": AppContext.shared.motionActivityContext.currentActivity.rawValue
                ])
                print("🐛 Telemetry logged for route addition")
            }
        }
    }

    
    static func delete(_ id: String) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }
            
            guard let route = database.object(ofType: Route.self, forPrimaryKey: id) else {
                throw RouteRealmError.doesNotExist
            }
            
            // `delete` should never be called when a route is active, but just in case it is,
            // deactive the route behavior to prevent unknown consequences of deleting active route
            if route.isActive {
                AppContext.shared.eventProcessor.deactivateCustom()
            }
            
            AppContext.shared.cloudKeyValueStore.remove(route: route)
            
            try database.write {
                database.delete(route)
            }
            
            NotificationCenter.default.post(name: .routeDeleted, object: self, userInfo: [Route.Keys.id: id])
            GDATelemetry.track("routes.removed")
        }
    }
    
    static func deleteAll() throws {
        try SpatialDataCache.routes().forEach({
            try delete($0.id)
        })
    }
    
    // MARK: Update Routes
    
    private static func onRouteDidUpdate(_ route: Route) {
        AppContext.shared.cloudKeyValueStore.update(route: route)

        NotificationCenter.default.post(name: .routeUpdated, object: self, userInfo: [Route.Keys.id: route.id])
        GDATelemetry.track("routes.edited", with: ["activity": AppContext.shared.motionActivityContext.currentActivity.rawValue])
    }
    
    static func updateLastSelectedDate(id: String, _ lastSelectedDate: Date = Date()) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }
            
            guard let route = database.object(ofType: Route.self, forPrimaryKey: id) else {
                throw RouteRealmError.doesNotExist
            }
            
            try database.write {
                route.lastSelectedDate = lastSelectedDate
            }
            
            onRouteDidUpdate(route)
        }
    }
    
    static func update(id: String, name: String, description: String?, waypoints: List<RouteWaypoint>) throws {
        try autoreleasepool {
            guard let database = try? RealmHelper.getDatabaseRealm() else {
                throw RouteRealmError.databaseError
            }
            
            guard let route = database.object(ofType: Route.self, forPrimaryKey: id) else {
                throw RouteRealmError.doesNotExist
            }
            
            // `update` should never be called when a route is active,
            // but just in case it is, deactive the route behavior to prevent unknown
            // consequences of updating waypoints in an active route
            if route.isActive {
                AppContext.shared.eventProcessor.deactivateCustom()
            }
            
            try database.write {
                route.name = name
                route.routeDescription = description
                route.waypoints = waypoints
                // Update `lastSelectedDate` and `lastUpdatedDate`
                let lastSelectedAndUpdatedDate = Date()
                route.lastSelectedDate = lastSelectedAndUpdatedDate
                route.lastUpdatedDate = lastSelectedAndUpdatedDate
                
                // Update first waypoint latitude and longitude
                if let first = waypoints.ordered.first, let marker = SpatialDataCache.referenceEntityByKey(first.markerId) {
                    route.firstWaypointLatitude = marker.latitude
                    route.firstWaypointLongitude = marker.longitude
                } else {
                    route.firstWaypointLatitude = nil
                    route.firstWaypointLongitude = nil
                }
            }
            
            onRouteDidUpdate(route)
        }
    }
    
    static func update(id: String, name: String, description: String?, waypoints: [LocationDetail]) throws {
        // `LocationDetail` -> `RouteWaypoint`
        let wRealmObjects = waypoints.enumerated().compactMap({ return RouteWaypoint(index: $0, locationDetail: $1) })
        
        // Append waypoints to a Realm list
        let wList = List<RouteWaypoint>()
        wRealmObjects.forEach({ wList.append($0) })
        
        try update(id: id, name: name, description: description, waypoints: wList)
    }
    
    // MARK: Add, Delete or Update Route Waypoints
    
    static func removeWaypoint(from route: Route, markerId: String) throws {
        // Currently, a marker cannot be added to a route more than once, so `firstIndex`
        // will return the only instance of `markerId`
        guard let index = route.waypoints.firstIndex(where: { $0.markerId == markerId }) else {
            return
        }
        
        // Create a copy of the route waypoints
        let waypoints: List<RouteWaypoint> = List<RouteWaypoint>()
        route.waypoints.forEach({
            waypoints.append(RouteWaypoint(value: $0))
        })
        
        // Save the waypoint index
        let waypointIndex = waypoints[index].index
        
        waypoints.remove(at: index)
        
        // Update the remaining waypoint indices
        waypoints.forEach({
            if $0.index > waypointIndex {
                $0.index -= 1
            }
        })
        
        try update(id: route.id, name: route.name, description: route.routeDescription, waypoints: waypoints)
    }
    
    static func removeWaypointFromAllRoutes(markerId: String) throws {
        try SpatialDataCache.routesContaining(markerId: markerId).forEach({
            try removeWaypoint(from: $0, markerId: markerId)
        })
    }
    
    static func updateWaypointInAllRoutes(markerId: String) throws {
        try SpatialDataCache.routesContaining(markerId: markerId).forEach({
            guard let first = $0.waypoints.ordered.first else {
                return
            }
            
            guard first.markerId == markerId else {
                return
            }
            
            // Update the first waypoint
            try update(id: $0.id, name: $0.name, description: $0.routeDescription, waypoints: $0.waypoints)
        })
    }
    
}
