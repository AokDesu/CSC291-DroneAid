# Belle's shared widgets ship as API stubs on Day 4, full bodies later

Belle owns four shared widgets (`DroneMap`, `BatteryBar`, `StatusChip`, `ItemPicker`) that Bew, Poom, and Tawan all need to consume. The naive sequencing — Belle finishes all four widget bodies before others can start — leaves 3 devs idle for ~3 days and makes Belle the single critical-path blocker for the demo. Instead, Belle commits a single PR on Day 4 (2026-05-25) containing all four widget files with **frozen public APIs (constructor params, callback signatures) but placeholder bodies** (e.g. `Container` returning the right size). Consumers import and code against the real API from Day 4; Belle iterates the rendering inside the widgets across Days 5-7 without breaking consumers.

## Consequences

- Belle's Day 4 PR is treated as an **API freeze** — any public API change after that requires coordination with Bew/Poom/Tawan.
- Reviewers (especially Aok) prioritise the Day 4 widget-API PR even at the cost of pausing their own work, because it unblocks 3 devs.
- Consumers must tolerate placeholder visuals during Days 4-7 and avoid coupling to internal widget implementation details.
- If a widget API turns out to be wrong, the cost is a coordinated multi-file PR, not a re-architecting of the consumer pages.
