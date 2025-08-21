# Address→Route Component

A compact routing component that turns an origin/destination into a persisted `Route` with labeled waypoints. It is composed of three files:

- `MapsDecoder.swift` — fetches an OpenRouteService (ORS) route and reverse-geocodes the destination.
- `PolylineDecoder.swift` — converts ORS coordinates to 3D space, simplifies the path, and labels points.
- `AddressRouteCalculator.swift` — converts labeled coordinates into app-level `LocationDetail` markers and builds a `Route`.

---
## Interfaces Between Parts

### 1) `MapsDecoder.fetchRoute(origin:destination:)`

**Input**

- `origin`: `"lat,lon"`
- `destination`: `"lat,lon"`

**Output**

- `(resolvedDestination: String?, coordinates: [(Double, Double, Double?, String)]?)`

**Behavior**

- Reverse-geocodes `destination` (best-effort) for a friendly label.  
- Calls ORS **foot-walking** directions (GeoJSON), then passes coordinates to `PolylineDecoder.orsDecode(...)`.  
- Returns the human-readable destination label (trimmed to first two comma parts) and a labeled list of coordinate tuples.  

---

### 2) `PolylineDecoder.orsDecode(from:routeName:origin:destination:)`

**Input**

- `coordinates`: `[[lon, lat], ...]` (from ORS geometry)  
- `routeName`: label used to nickname points  
- Optional `origin` and `destination` strings (`"lat,lon"`) for labeling edges  

**Output**

- `[(Double, Double, Double?, String)]` where each tuple is `(longitude, latitude, altitude?, nickname)`  

**Behavior**

- Converts to 3D (ECEF) and simplifies via Ramer–Douglas–Peucker (ε ≈ `0.04`) to reduce point count.  
- Produces nicknames like `~<route-name> pointN` and appends a labeled **End** point when available.  


---

### 3) `AddressRouteCalculator.createWaypoint(from:index:notify:)`

**Input**

- One labeled coordinate tuple and metadata.  

**Output**

- `RouteWaypoint?`  

**Behavior**

- Deconstructs the tuple **as `(latitude, longitude, _, nickname)`** and creates a `LocationDetail` marker via `createLocationDetailWithMarker(latitude:longitude:nickname:notify:)`.  
- Persists or updates the marker (`saveMarker(...)`), then wraps it in a `RouteWaypoint`.  


---

### 4) Route Builders

- `testCreateRoute(waypointsData:resolvedDestination:)` — maps tuples → waypoints, builds `Route(name:"To <dest>")`, persists it.  
- `createRouteTask(origin:destination:)` — high-level entry point: fetches route, transforms tuples → waypoints → `Route`, saves.  

---

## Data Contracts

- **Caller → MapsDecoder**  
  Strings in `"lat,lon"` form.  

- **MapsDecoder → PolylineDecoder**  
  ORS geometry: `[[lon, lat], ...]`.  

- **PolylineDecoder → MapsDecoder/Caller**  
  Tuples: `(lon, lat, alt?, nickname)`.  

- **Into AddressRouteCalculator.createWaypoint**  
  Expected: `(lat, lon, alt?, nickname)` (swap if coming straight from `PolylineDecoder`).  

---

## Error Handling

- ORS/network/parse failures: logs + user alert (“Routing not possible…”) and aborts route creation.  
- Marker/waypoint persistence failures: logged; waypoint creation returns `nil`, route build skips that point.  

---

## External Dependencies & Config

- **OpenRouteService**:  
  - Directions: `/v2/directions/foot-walking/geojson`  
  - Reverse geocode: `/geocode/reverse`  
  - `User-Agent: Soundscape/1.0` This has to be present for proxy to work

---

## Tuning & Extension Points

- Path density via `PolylineDecoder.simplificationEpsilon` (smaller ε → more points).  
- Labeling rules in `orsDecode(...)` if you want richer waypoint names.  
- Swap ORS endpoints or profiles via `Info.plist`.  


## Diagrams

![Routing Component Diagram](apps/ios/GuideDogs/Code/Behaviors/Route%20Guidance/TurnByTurnRouteGuidance/RoutingComponentDiagram.png)

![Routing Sequence Diagram](apps/ios/GuideDogs/Code/Behaviors/Route%20Guidance/TurnByTurnRouteGuidance/RoutingSequenceDiagram.png)




## Architecture at a Glance

```text
Caller
  └─ AddressRouteCalculator.createRouteTask(origin,destination)
       └─ MapsDecoder.fetchRoute(...)
            ├─ reverseGeocodeORS(...)        → "Street, City"?
            ├─ fetchORSCoordinates(...)      → [[lon, lat] ...] (GeoJSON)
            └─ PolylineDecoder.orsDecode(...)→ [(?, ?, alt?, nickname)]
       └─ For each tuple → AddressRouteCalculator.createWaypoint(...)
            ├─ createLocationDetailWithMarker(...) → LocationDetail(marker)
            └─ saveMarker/updateExisting(...)
       └─ Route(name:"To <resolved>", description, waypoints)
            └─ Route.add(route)
´´´

