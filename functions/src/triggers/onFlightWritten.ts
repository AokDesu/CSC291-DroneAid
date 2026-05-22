// Firestore trigger: on every write to flights/{flightId}, detect a status
// transition and FCM the right audience.
// Spec: §10 onFlightWritten, flow F-12.

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { sendToUser, sendToAdmins } from "../lib/fcm";

type FlightStatus =
  | "enroute"
  | "delivering"
  | "returning"
  | "completed"
  | "aborted"
  | "failed";

export const onFlightWritten = onDocumentWritten("flights/{flightId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after) return; // deletion — ignore

  const prevStatus = before?.status as FlightStatus | undefined;
  const nextStatus = after.status as FlightStatus;
  if (prevStatus === nextStatus) return;

  const userId = after.userId as string | undefined;
  const flightId = event.params.flightId;
  const requestId = after.requestId as string | undefined;

  if (!userId) return;

  switch (nextStatus) {
    case "delivering":
      void sendToUser(userId, {
        title: "Drone arriving",
        body: "Step outside to receive your supplies.",
        deepLink: `/user/tracking/${flightId}`,
        data: { type: "flight_arriving", flightId, requestId: requestId ?? "" },
      });
      return;
    case "completed":
      void sendToUser(userId, {
        title: "Delivered — please confirm",
        body: "Tap to confirm you received your supplies.",
        deepLink: `/user/confirm/${requestId}`,
        data: { type: "flight_completed", flightId, requestId: requestId ?? "" },
      });
      return;
    case "aborted":
    case "failed": {
      const reason = (after.failureType as string | undefined) ?? "unknown";
      void sendToUser(userId, {
        title: `Flight aborted: ${reason}`,
        body: "A coordinator will reassign a new drone shortly.",
        deepLink: `/user/queue`,
        data: { type: "flight_aborted", flightId, requestId: requestId ?? "", reason },
      });
      void sendToAdmins({
        title: `Reassign needed (${reason})`,
        body: `Flight ${flightId} aborted.`,
        deepLink: `/admin/requests/${requestId}`,
        data: { type: "flight_aborted_admin", flightId, requestId: requestId ?? "" },
      });
      return;
    }
    default:
      return;
  }
});
