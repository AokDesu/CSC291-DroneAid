# DroneAid — Software Architecture

C4-style: context → containers → component drill-down.

---

## 1. System context (C4 Level 1)

```mermaid
flowchart TB
    user["End user<br/>(refugee, impacted civilian)"]:::actor
    admin["Relief coordinator<br/>(admin)"]:::actor
    droneaid(("DroneAid<br/>(simulated drone<br/>relief platform)")):::system
    fcm["Firebase Cloud<br/>Messaging<br/>(push pipeline)"]:::ext
    osm["OpenStreetMap<br/>tile servers"]:::ext

    user -- "submits requests,<br/>watches drone,<br/>confirms receipt" --> droneaid
    admin -- "approves requests,<br/>dispatches drones,<br/>sets weather" --> droneaid
    droneaid -- "push notifications" --> fcm
    fcm --> user
    fcm --> admin
    droneaid -- "fetches map tiles" --> osm

    classDef actor fill:#dbeafe,stroke:#1e40af,color:#0c2d6b
    classDef system fill:#fde68a,stroke:#b45309,color:#5a3500
    classDef ext fill:#e5e7eb,stroke:#4b5563,color:#1f2937
```

External actors: end user, admin. External systems: FCM (Google), OSM tiles. Everything else is "us".

---

## 2. Containers (C4 Level 2)

```mermaid
flowchart TB
    subgraph mobile["Mobile device"]
      flutter["Flutter app<br/>(Android, iOS stretch)<br/>Dart + Riverpod"]
    end

    subgraph firebase["Firebase project: csc291-drone-relief"]
      auth["Firebase Auth<br/>(email/password, synthetic email)"]
      fs["Firestore<br/>(realtime DB)"]
      fn["Cloud Functions<br/>(TypeScript)<br/>- callables<br/>- scheduled<br/>- triggers"]
      fcm2["Cloud Messaging<br/>(FCM)"]
    end

    osm["OpenStreetMap<br/>tiles"]

    flutter -- "auth ops" --> auth
    flutter -- "realtime streams,<br/>callable RPC" --> fs
    flutter -- "https.onCall" --> fn
    flutter -- "register FCM token" --> fcm2
    flutter -- "tile fetch (HTTP)" --> osm

    fn -- "read/write" --> fs
    fn -- "send messages" --> fcm2
    fcm2 -- "push" --> flutter
    auth -- "onUserCreated" --> fn
    fs -- "onWrite triggers" --> fn

    style flutter fill:#dbeafe,stroke:#1d4ed8
    style auth fill:#fef3c7,stroke:#a16207
    style fs fill:#fef3c7,stroke:#a16207
    style fn fill:#fef3c7,stroke:#a16207
    style fcm2 fill:#fef3c7,stroke:#a16207
    style osm fill:#e5e7eb,stroke:#4b5563
```

Four Firebase containers all in one project. Flutter is the only client.

---

## 3. Flutter app — internal components (C4 Level 3)

```mermaid
flowchart TB
    subgraph app["Flutter app"]
      direction TB
      router["AppRouter<br/>(go_router)"]
      authgate["AuthGate<br/>(decides user vs admin tree)"]

      subgraph userTree["User feature tree"]
        urequest["Request page"]
        uqueue["Queue page"]
        utrack["Tracking page"]
        uconfirm["Confirm page"]
        uhist["History page"]
        unotif["Notifications inbox"]
        uprof["Profile + Settings"]
      end

      subgraph adminTree["Admin feature tree"]
        actrl["Control map"]
        adlist["Drone list"]
        addet["Drone detail"]
        arlist["Requests list"]
        armgr["Request Manage"]
        aweather["Weather panel"]
        ainv["Inventory"]
      end

      subgraph shared["Shared widgets"]
        wmap["DroneMap"]
        wbat["BatteryBar"]
        wchip["StatusChip"]
        wpick["ItemPicker"]
      end

      subgraph providers["Riverpod providers"]
        pauth["authProvider"]
        preq["requestProvider"]
        pdrn["droneProvider"]
        pflt["flightProvider"]
        pcat["catalogProvider"]
        pwx["weatherProvider"]
      end

      subgraph repos["Repository layer"]
        rauth["AuthRepo"]
        rreq["RequestRepo"]
        rdrn["DroneRepo"]
        rflt["FlightRepo"]
        rcat["CatalogRepo"]
        rwx["WeatherRepo"]
      end

      subgraph utils["utils/"]
        uid["thai_id_validator"]
        ugeo["geo.dart<br/>(haversine, lerp)"]
        utime["time_fmt"]
      end
    end

    router --> authgate
    authgate --> userTree
    authgate --> adminTree
    userTree --> shared
    adminTree --> shared
    userTree --> providers
    adminTree --> providers
    providers --> repos
    repos -.->|Firebase SDK| ext((Firebase))
    utrack --> ugeo
    aweather --> rwx
    urequest --> rcat
    armgr --> rreq
```

### Layer responsibilities

| Layer | Owns |
|---|---|
| **Pages** (`features/user/*`, `features/admin/*`) | UI only. Reads state from providers, calls repo methods through providers. |
| **Providers** (`providers/*`) | Riverpod state + side effects. Streams from repos, debounces UI, holds form state. |
| **Repositories** (`data/repositories/*`) | Single touchpoint to Firebase SDK. Returns models, never Firestore types. Mockable for tests. |
| **Models** (`data/models/*`) | Pure Dart classes with `fromMap`/`toMap`. No SDK imports. |
| **Shared widgets** (`widgets/*`) | Stateless reusables. Owned by Belle, consumed everywhere. |
| **Utils** (`utils/*`) | Pure functions: geo math, ID validation, time formatting. |

### Why this layering

- Pages never import `cloud_firestore` directly → swapping to a different backend or mocking in tests is local change.
- Providers own caching + lifecycle → screens don't redo work on rebuild.
- Repos return models with named fields → no `data['status']` string scattering.

---

## 4. Cloud Functions — internal components

```mermaid
flowchart TB
    subgraph fnpkg["functions/"]
      direction TB
      idx["index.ts<br/>(barrel exports)"]

      subgraph callable["callable/"]
        c1["submitRequest"]
        c2["approveRequest"]
        c3["rejectRequest"]
        c4["assignDrone"]
        c5["confirmDelivery"]
        c6["cancelRequest"]
        c7["setWeather"]
        c8["restockItem"]
        c9["toggleDroneMaintenance"]
      end

      subgraph scheduled["scheduled/"]
        s1["tickFlights<br/>(every 60s)"]
      end

      subgraph triggers["triggers/"]
        t1["onUserCreated"]
        t2["onFlightWritten<br/>(state-transition FCM)"]
      end

      subgraph lib["lib/"]
        l1["sim/<br/>(physics, dice)"]
        l2["geo.ts<br/>(haversine)"]
        l3["weather.ts<br/>(modifier table)"]
        l4["fcm.ts<br/>(send wrapper)"]
        l5["id.ts<br/>(checksum)"]
        l6["roles.ts<br/>(requireAdmin, requireUser)"]
      end

      subgraph seed["seed/"]
        d1["seedCatalog"]
        d2["seedDrones"]
        d3["seedAdmins"]
      end
    end

    idx --> callable
    idx --> scheduled
    idx --> triggers
    callable --> lib
    scheduled --> lib
    triggers --> lib
    callable -. "auth check" .-> l6
    s1 --> l1
    s1 --> l3
    s1 --> l2
    t2 --> l4
```

### Function responsibilities

| Component | Purpose |
|---|---|
| `callable/*` | One `https.onCall` per business action. Validate input + role; perform Firestore transaction; return result. |
| `scheduled/tickFlights` | Cron every 60s. Pulls active flights, advances state, rolls failures, writes transitions. |
| `triggers/onUserCreated` | Auth trigger. Creates `users/{uid}` with role=user. |
| `triggers/onFlightWritten` | Firestore trigger. On flight status change, fans out FCM to user + admins. |
| `lib/sim` | Pure sim functions, testable in isolation. |
| `lib/roles` | `requireAdmin(context)`, `requireUser(context)` helpers. |
| `seed/*` | Idempotent scripts to populate Firestore for demo. |

---

## 5. Cross-cutting concerns

| Concern | How it's handled |
|---|---|
| **Auth** | Firebase Auth on the wire; `context.auth.uid` + `users/{uid}.role` for authorization inside callables. |
| **Realtime** | Firestore listeners for queue, drone, flight, weather. Battery + position derived client-side from stable flight plan doc. |
| **Concurrency** | Stock decrement, drone assignment use Firestore transactions inside callables. |
| **Security rules** | DENY direct writes to mutable collections; only Functions write. |
| **Failure handling** | All callable returns include error codes via `HttpsError`; client maps codes to localized messages. |
| **Testing** | Widget tests with mock repos; Function tests against emulator; rules tests via `@firebase/rules-unit-testing`. |
| **Observability** | Cloud Functions logs; Firestore audit collection deferred (non-goal v1). |

---

## 6. Render the PNG

```bash
npx --yes @mermaid-js/mermaid-cli -i docs/07-software-architecture.md -o docs/diagrams/07-architecture.png
```

Output: one PNG per fenced ```mermaid block, named `07-architecture-{1..4}.png`.
