# DroneAid — Implementation Diagrams

Concrete views of how the architecture runs: deployment, sequences, state, and data.

---

## 1. Deployment view

```mermaid
flowchart TB
    subgraph dev["Developer machines (×5)"]
      direction TB
      dev1["Aok<br/>Windows<br/>+ emulator suite"]
      dev2["Belle<br/>Mac/Win<br/>+ Flutter SDK"]
      dev3["Bew<br/>Mac/Win<br/>+ Flutter SDK"]
      dev4["Poom<br/>Mac/Win<br/>+ Flutter SDK"]
      dev5["Tawan<br/>Mac/Win<br/>+ Flutter SDK"]
    end

    subgraph github["GitHub"]
      repo["Repo: csc291<br/>main + feat/* branches"]
      actions["GitHub Actions<br/>(ci, deploy, log-index)"]
      secrets["Secrets:<br/>FIREBASE_SERVICE_ACCOUNT,<br/>ANTHROPIC_API_KEY (optional)"]
    end

    subgraph gcp["Google Cloud / Firebase project: csc291-drone-relief"]
      auth["Firebase Auth"]
      fs["Firestore"]
      cf["Cloud Functions<br/>asia-southeast1"]
      fcm["Cloud Messaging"]
      sched["Cloud Scheduler<br/>(60s cron)"]
    end

    subgraph endusers["End-user devices"]
      phone["Android phone<br/>(primary)<br/>+ iOS (stretch)"]
    end

    dev1 -- "git push" --> repo
    dev2 -- "git push" --> repo
    dev3 -- "git push" --> repo
    dev4 -- "git push" --> repo
    dev5 -- "git push" --> repo

    repo -- "PR / push main" --> actions
    actions -- "uses" --> secrets
    actions -- "firebase deploy --only functions" --> cf
    actions -- "firebase deploy --only firestore:rules,indexes" --> fs

    sched -- "every 60s" --> cf
    cf -- "read/write" --> fs
    cf -- "read" --> auth
    cf -- "send" --> fcm
    auth -. "onCreate trigger" .-> cf
    fs -. "onWrite trigger" .-> cf

    phone -- "HTTPS" --> auth
    phone -- "streams + writes" --> fs
    phone -- "callable RPC" --> cf
    fcm -- "push" --> phone

    classDef dev fill:#e0e7ff,stroke:#4f46e5,color:#1e1b4b
    classDef cloud fill:#fef3c7,stroke:#a16207,color:#3f2d00
    classDef gh fill:#dbeafe,stroke:#1d4ed8,color:#0c2d6b
    classDef end_ fill:#d1fae5,stroke:#047857,color:#04372a
    class dev1,dev2,dev3,dev4,dev5 dev
    class auth,fs,cf,fcm,sched cloud
    class repo,actions,secrets gh
    class phone end_
```

---

## 2. Sequence — happy-path delivery

```mermaid
sequenceDiagram
    actor U as Mali (user)
    participant A as Flutter app
    participant F as Firestore
    participant Fn as Cloud Functions
    participant FCM as FCM
    actor Ad as Naree (admin)

    U->>A: open Request page, pick items, submit
    A->>Fn: submitRequest({items, address})
    Fn->>F: validate stock, create requests/{id} status=pending
    Fn-->>A: 200 {requestId}
    A-->>U: show in Queue: "Pending"

    Fn->>FCM: notify all admins
    FCM-->>Ad: push "new request"

    Ad->>A: open Request Manage
    A->>F: stream request + user profile
    A-->>Ad: render

    Ad->>Fn: approveRequest({reqId})
    Fn->>F: tx: stock-- · status=approved · return eligible drones
    Fn-->>A: eligible[]
    A-->>Ad: render drone picker

    Ad->>Fn: assignDrone({reqId, droneId})
    Fn->>F: tx: create flight enroute · drone.status=flying · request.status=in_flight
    Fn-->>A: ok
    Fn->>FCM: notify user "dispatched"
    FCM-->>U: push

    Note over Fn,F: Scheduler every 60s
    loop tickFlights
      Fn->>F: query active flights
      Fn->>Fn: compute progress + battery + dice
      alt no failure & progress reaches 1.0 (enroute)
        Fn->>F: flight.status=delivering
        Fn->>FCM: notify user "arriving"
      else next tick after delivering
        Fn->>F: flight.status=completed · request.status=delivered
        Fn->>FCM: notify user "confirm please"
      end
    end

    U->>A: Confirm
    A->>Fn: confirmDelivery({reqId})
    Fn->>F: request.status=confirmed · flight.status=returning · drone.status=flying
    Note over Fn,F: ticks bring drone home
    Fn->>F: drone.status=idle
```

---

## 3. Sequence — storm aborts mid-flight, admin reassigns

```mermaid
sequenceDiagram
    actor U as Mali (user)
    participant A as Flutter app
    participant F as Firestore
    participant Fn as Cloud Functions
    participant FCM as FCM
    actor Ad as Naree (admin)

    Note over Ad,Fn: Weather already set to "storm" earlier
    U->>Fn: submitRequest
    Fn->>F: requests/{id} status=pending
    Ad->>Fn: approveRequest
    Ad->>Fn: assignDrone(DRN-005)
    Fn->>F: flight enroute, drone DRN-005 flying

    loop tickFlights every 60s
      Fn->>F: read weather=storm + flight
      Fn->>Fn: rand() < 0.20 → ABORT
      Fn->>F: flight.failureType=weather, status=aborted · request.status=failed · drone.status=idle
      Fn->>FCM: notify user + admins
      FCM-->>U: "flight aborted"
      FCM-->>Ad: "reassign needed"
    end

    Ad->>A: open Request Manage (re-entry)
    Ad->>Fn: setWeather("wind")
    Fn->>F: weather/current state=wind
    Ad->>Fn: assignDrone(DRN-002)
    Fn->>F: new flight enroute (2nd attempt) · request.status=in_flight

    loop tickFlights
      Fn->>F: progress=1.0 → delivering → completed · request.status=delivered
      Fn->>FCM: notify user
    end

    U->>Fn: confirmDelivery
    Fn->>F: request.status=confirmed · flight returning
```

---

## 4. Request status state machine

```mermaid
stateDiagram-v2
    [*] --> pending : user submits
    pending --> approved : admin approves
    pending --> rejected : admin rejects
    pending --> cancelled : user cancels
    approved --> in_flight : admin assigns drone
    in_flight --> delivered : tickFlights detects arrival
    in_flight --> failed : sim rolls fail / battery / weather
    failed --> in_flight : admin reassigns (new flight)
    failed --> [*] : admin abandons (no reassign)
    delivered --> confirmed : user taps Confirm
    rejected --> [*]
    cancelled --> [*]
    confirmed --> [*]
```

---

## 5. Flight status state machine

```mermaid
stateDiagram-v2
    [*] --> enroute : assignDrone
    enroute --> delivering : progress >= 1.0
    enroute --> aborted : weather/battery/mech dice
    delivering --> completed : next tick (60s hold)
    completed --> returning : confirmDelivery fires
    returning --> [*] : reaches base → drone idle
    aborted --> [*] : drone returns or maintenance
```

---

## 6. Drone status state machine

```mermaid
stateDiagram-v2
    [*] --> idle : seed
    idle --> flying : assignDrone
    flying --> idle : flight returning completes OR aborted no damage
    flying --> maintenance : aborted mechanical OR battery exhausted
    idle --> maintenance : admin toggles
    maintenance --> idle : admin toggles
    idle --> offline : admin takes offline
    offline --> idle : admin brings online
```

---

## 7. Entity-relationship (Firestore collections)

```mermaid
erDiagram
    USER ||--o{ REQUEST : "submits"
    USER ||--o{ NOTIFICATION : "receives"
    USER ||--o| ADDRESS : "has pin"

    REQUEST }o--|| CATALOG_ITEM : "contains many"
    REQUEST ||--o{ FLIGHT : "spawns attempts"
    REQUEST }o--|| USER : "owned by"

    DRONE ||--o{ FLIGHT : "assigned to"

    FLIGHT }o--|| WEATHER : "snapshot at takeoff"

    CATALOG_ITEM {
        string itemId PK
        string name
        float weightKg
        int stock
        bool active
    }
    USER {
        string uid PK
        string nationalId UK
        string name
        string phone
        string role
        Address deliveryAddress
        bool locked
    }
    REQUEST {
        string reqId PK
        string userId FK
        array items
        float totalWeightKg
        string status
        string priority
        string currentFlightId FK
        ts createdAt
    }
    DRONE {
        string droneId PK
        string status
        int batteryPct
        Coord baseLocation
        float maxPayloadKg
        string currentFlightId FK
    }
    FLIGHT {
        string flightId PK
        string droneId FK
        string requestId FK
        string status
        Coord origin
        Coord destination
        ts takeoffAt
        ts etaAt
        float speedKmh
        float weatherModifierAtTakeoff
        int batteryAtTakeoff
        string failureType
    }
    NOTIFICATION {
        string nid PK
        string type
        string title
        string body
        string requestId FK
        string flightId FK
        ts readAt
    }
    WEATHER {
        string state
        ts updatedAt
        string updatedBy FK
    }
```

---

## 8. Render the PNGs

```bash
npx --yes @mermaid-js/mermaid-cli -i docs/08-implementation-diagram.md -o docs/diagrams/08-implementation.png
```

Mermaid CLI emits one PNG per fenced block: `08-implementation-1.png` … `08-implementation-7.png`.
