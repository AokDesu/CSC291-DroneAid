import { getMessaging } from "firebase-admin/messaging";
import { db } from "./admin";
import { sendToAdmins, sendToUser } from "./fcm";

jest.mock("firebase-admin/messaging", () => ({
  getMessaging: jest.fn(),
}));

jest.mock("./admin", () => {
  const arrayRemove = jest.fn((...args: string[]) => ({ __arrayRemove: args }));
  const serverTimestamp = jest.fn().mockReturnValue(null);
  return {
    db: {
      doc: jest.fn(),
      collection: jest.fn(),
    },
    FieldValue: { arrayRemove, serverTimestamp },
    Timestamp: {},
  };
});

const sendEachForMulticast = jest.fn();

beforeEach(() => {
  jest.clearAllMocks();
  (getMessaging as jest.Mock).mockReturnValue({ sendEachForMulticast });
  // Default: notification subcollection writes succeed silently.
  (db.collection as jest.Mock).mockReturnValue({
    add: jest.fn().mockResolvedValue({}),
    where: jest.fn().mockReturnValue({
      get: jest.fn().mockResolvedValue({ docs: [] }),
    }),
  });
});

describe("sendToUser", () => {
  it("sends to all tokens and prunes only the stale one", async () => {
    const update = jest.fn().mockResolvedValue(undefined);
    const docRef = {
      get: jest.fn().mockResolvedValue({
        data: () => ({ fcmTokens: ["good1", "stale", "good2"] }),
      }),
      update,
    };
    (db.doc as jest.Mock).mockReturnValue(docRef);

    sendEachForMulticast.mockResolvedValue({
      successCount: 2,
      failureCount: 1,
      responses: [
        { success: true },
        {
          success: false,
          error: { code: "messaging/registration-token-not-registered" },
        },
        { success: true },
      ],
    });

    await sendToUser("u1", { title: "t", body: "b", deepLink: "/x" });

    expect(sendEachForMulticast).toHaveBeenCalledWith(
      expect.objectContaining({ tokens: ["good1", "stale", "good2"] }),
    );
    expect(db.doc).toHaveBeenCalledWith("users/u1");
    expect(update).toHaveBeenCalledTimes(1);
    expect(update).toHaveBeenCalledWith({
      fcmTokens: { __arrayRemove: ["stale"] },
    });
  });

  it("does not call update when no tokens are stale", async () => {
    const update = jest.fn().mockResolvedValue(undefined);
    const docRef = {
      get: jest.fn().mockResolvedValue({
        data: () => ({ fcmTokens: ["good1", "good2"] }),
      }),
      update,
    };
    (db.doc as jest.Mock).mockReturnValue(docRef);

    sendEachForMulticast.mockResolvedValue({
      successCount: 2,
      failureCount: 0,
      responses: [{ success: true }, { success: true }],
    });

    await sendToUser("u1", { title: "t", body: "b", deepLink: "/x" });

    expect(update).not.toHaveBeenCalled();
  });

  it("ignores non-stale error codes", async () => {
    const update = jest.fn().mockResolvedValue(undefined);
    const docRef = {
      get: jest.fn().mockResolvedValue({
        data: () => ({ fcmTokens: ["good", "rate-limited"] }),
      }),
      update,
    };
    (db.doc as jest.Mock).mockReturnValue(docRef);

    sendEachForMulticast.mockResolvedValue({
      successCount: 1,
      failureCount: 1,
      responses: [
        { success: true },
        { success: false, error: { code: "messaging/internal-error" } },
      ],
    });

    await sendToUser("u1", { title: "t", body: "b", deepLink: "/x" });

    expect(update).not.toHaveBeenCalled();
  });

  it("does not call FCM when user has no tokens", async () => {
    const docRef = {
      get: jest.fn().mockResolvedValue({ data: () => ({ fcmTokens: [] }) }),
      update: jest.fn(),
    };
    (db.doc as jest.Mock).mockReturnValue(docRef);

    await sendToUser("u1", { title: "t", body: "b", deepLink: "/x" });

    expect(sendEachForMulticast).not.toHaveBeenCalled();
    expect(docRef.update).not.toHaveBeenCalled();
  });
});

describe("sendToAdmins", () => {
  it("prunes stale tokens on the correct admin docs", async () => {
    const updateA = jest.fn().mockResolvedValue(undefined);
    const updateB = jest.fn().mockResolvedValue(undefined);

    (db.collection as jest.Mock).mockImplementation((path: string) => {
      if (path === "users") {
        return {
          where: jest.fn().mockReturnValue({
            get: jest.fn().mockResolvedValue({
              docs: [
                {
                  id: "adminA",
                  data: () => ({ fcmTokens: ["a-good", "a-stale"] }),
                },
                {
                  id: "adminB",
                  data: () => ({ fcmTokens: ["b-stale"] }),
                },
              ],
            }),
          }),
        };
      }
      return { add: jest.fn().mockResolvedValue({}) };
    });

    (db.doc as jest.Mock).mockImplementation((path: string) => {
      if (path === "users/adminA") return { update: updateA };
      if (path === "users/adminB") return { update: updateB };
      throw new Error(`unexpected doc path: ${path}`);
    });

    sendEachForMulticast.mockResolvedValue({
      successCount: 1,
      failureCount: 2,
      responses: [
        { success: true },
        {
          success: false,
          error: { code: "messaging/invalid-registration-token" },
        },
        {
          success: false,
          error: { code: "messaging/registration-token-not-registered" },
        },
      ],
    });

    await sendToAdmins({ title: "t", body: "b", deepLink: "/x" });

    expect(updateA).toHaveBeenCalledWith({
      fcmTokens: { __arrayRemove: ["a-stale"] },
    });
    expect(updateB).toHaveBeenCalledWith({
      fcmTokens: { __arrayRemove: ["b-stale"] },
    });
  });
});
