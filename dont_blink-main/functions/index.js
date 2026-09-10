const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// ============================================================
// SETTINGS
// ============================================================

// Maximum distance from the customer's delivery location
// at which a rider can receive the delivery offer.
const RIDER_RADIUS_KM = 10;

// Rider location must have been updated within this period (30 minutes).
const RIDER_LOCATION_MAX_AGE_MS = 30 * 60 * 1000;

// ============================================================
// HELPERS
// ============================================================

function number(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function validCoordinates(latitude, longitude) {
  return (
    latitude !== null &&
    longitude !== null &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180 &&
    !(latitude === 0 && longitude === 0)
  );
}

function distanceKm(lat1, lon1, lat2, lon2) {
  const earthRadiusKm = 6371;

  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c =
    2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return earthRadiusKm * c;
}

function timestampMillis(value) {
  if (!value) return null;

  if (typeof value.toMillis === "function") {
    return value.toMillis();
  }

  if (value._seconds !== undefined) {
    return value._seconds * 1000;
  }

  return null;
}

function getTokens(userData) {
  const tokens = new Set();

  // Single FCM token
  const singleToken = userData.fcmToken;

  if (
    typeof singleToken === "string" &&
    singleToken.trim()
  ) {
    tokens.add(singleToken.trim());
  }

  // Multiple FCM tokens
  const tokenArray = userData.fcmTokens;

  if (Array.isArray(tokenArray)) {
    for (const token of tokenArray) {
      if (
        typeof token === "string" &&
        token.trim()
      ) {
        tokens.add(token.trim());
      }
    }
  }

  return [...tokens];
}

// ============================================================
// FIND NEARBY RIDERS
// ============================================================

async function findNearbyRiders(
  customerLatitude,
  customerLongitude,
  orderStoreId,
) {
  const snapshot = await db
    .collection("users")
    .where("role", "==", "rider")
    .where("isAvailable", "==", true)
    .get();

  const riders = [];

  const now = Date.now();

  console.log(
    `Checking ${snapshot.size} available riders for store ${orderStoreId}.`,
  );

  for (const doc of snapshot.docs) {
    const data = doc.data();

    // --------------------------------------------------------
    // STORE MATCH
    //
    // If the rider has a specific store assigned, ensure it matches.
    // If the rider has no storeId assigned (general/freelance rider),
    // allow them to receive deliveries for any nearby store.
    // --------------------------------------------------------

    const riderStoreId = String(
      data.storeId || data.storedId || "",
    ).trim();

    if (
      orderStoreId &&
      riderStoreId &&
      riderStoreId !== orderStoreId
    ) {
      console.log(
        `Rider ${doc.id} skipped: store mismatch. ` +
        `riderStoreId=${riderStoreId}, ` +
        `orderStoreId=${orderStoreId}`,
      );

      continue;
    }

    const isAssignedToThisStore =
      Boolean(orderStoreId && riderStoreId && riderStoreId === orderStoreId);

    const latitude = number(data.riderLatitude);
    const longitude = number(data.riderLongitude);
    const hasValidGps = validCoordinates(latitude, longitude);

    const updatedAt = timestampMillis(data.riderLocationUpdatedAt);
    const isGpsFresh =
      updatedAt === null || now - updatedAt <= RIDER_LOCATION_MAX_AGE_MS;

    // For unassigned/freelance riders, require valid and fresh GPS within radius
    if (!isAssignedToThisStore) {
      if (!hasValidGps) {
        console.log(`Rider ${doc.id} skipped: invalid GPS for unassigned rider.`);
        continue;
      }

      if (!isGpsFresh) {
        console.log(
          `Rider ${doc.id} skipped: GPS location is stale (> ${RIDER_LOCATION_MAX_AGE_MS / 60000} mins).`,
        );
        continue;
      }

      const distance = distanceKm(
        customerLatitude,
        customerLongitude,
        latitude,
        longitude,
      );

      if (distance > RIDER_RADIUS_KM) {
        console.log(
          `Rider ${doc.id} skipped: outside ${RIDER_RADIUS_KM} km radius (${distance.toFixed(2)} km).`,
        );
        continue;
      }
    }

    const distance = hasValidGps
      ? distanceKm(customerLatitude, customerLongitude, latitude, longitude)
      : 0;

    const tokens = getTokens(data);

    console.log(
      `Rider ${doc.id} is eligible. ` +
      `store=${riderStoreId || "any"}, ` +
      `assigned=${isAssignedToThisStore}, ` +
      `distance=${distance.toFixed(3)} km, ` +
      `tokens=${tokens.length}`,
    );

    riders.push({
      uid: doc.id,
      distanceKm: distance,
      tokens,
    });
  }

  // Closest riders first
  riders.sort((a, b) => a.distanceKm - b.distanceKm);

  return riders;
}

// ============================================================
// NOTIFY STORE MANAGERS
// ============================================================

async function notifyStoreManagers(
  orderId,
  order,
  orderStoreId,
  orderStoreName,
  itemCount,
) {
  if (!orderStoreId) {
    console.log(`No storeId on order ${orderId}; skipping store manager notifications.`);
    return 0;
  }

  try {
    const managersSnapshot = await db
      .collection("users")
      .where("storeId", "==", orderStoreId)
      .get();

    const managerTokens = new Set();
    const managerUids = [];

    for (const doc of managersSnapshot.docs) {
      const data = doc.data();
      const role = String(data.role || "").trim().toLowerCase();
      if (role === "storemanager" || role === "store_manager") {
        managerUids.push(doc.id);
        const tokens = getTokens(data);
        tokens.forEach((t) => managerTokens.add(t));
      }
    }

    console.log(
      `Order ${orderId}: Found ${managerUids.length} manager(s) for store ${orderStoreId} with ${managerTokens.size} token(s).`,
    );

    if (managerTokens.size > 0) {
      const shortId = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
      const totalAmount = number(order.grandTotal) || 0;
      const totalText = totalAmount > 0 ? ` • ₹${totalAmount.toFixed(0)}` : "";
      const isRerouted = order.isRerouted === true;

      const title = isRerouted
        ? `⚡ Rerouted Order Received! (${orderStoreName})`
        : `📦 New Order for ${orderStoreName}!`;

      const body = `Order #${shortId} • ${itemCount} item${itemCount === 1 ? "" : "s"}${totalText}. Please pack for pickup.`;

      const response = await messaging.sendEachForMulticast({
        tokens: [...managerTokens],
        notification: {
          title,
          body,
        },
        data: {
          type: "store_order",
          orderId: orderId,
          storeId: orderStoreId,
          storeName: orderStoreName,
          status: String(order.status || "Placed"),
          isRerouted: String(isRerouted),
          clickAction: "OPEN_STORE_ORDERS",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "doorstepp_orders",
            sound: "default",
          },
        },
      });

      console.log(
        `Store manager notifications for order ${orderId}: ` +
        `${response.successCount} sent, ${response.failureCount} failed.`,
      );

      return response.successCount;
    }

    return 0;
  } catch (error) {
    console.error(`Failed to notify store managers for order ${orderId}:`, error);
    return 0;
  }
}

// ============================================================
// SEND DELIVERY OFFER & NOTIFICATIONS
// ============================================================

exports.offerNewDeliveryToNearbyRiders = onDocumentCreated(
  {
    document: "orders/{orderId}",
    region: "asia-south2",
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      console.log("No order snapshot.");
      return;
    }

    const orderId = event.params.orderId;
    const order = snapshot.data();

    console.log(`Processing new order ${orderId}.`);

    // --------------------------------------------------------
    // ONLY NEWLY PLACED ORDERS
    // --------------------------------------------------------

    const status = String(order.status || "").trim().toLowerCase();

    if (status !== "placed") {
      console.log(`Order ${orderId} ignored because status is "${status}".`);
      return;
    }

    // --------------------------------------------------------
    // NEVER OFFER AN ALREADY ASSIGNED ORDER
    // --------------------------------------------------------

    const existingRiderId = String(order.riderId || "").trim();

    if (existingRiderId) {
      console.log(`Order ${orderId} already has rider ${existingRiderId}.`);
      return;
    }

    // --------------------------------------------------------
    // ORDER STORE & ITEM DETAILS
    // --------------------------------------------------------

    const orderStoreId = String(order.storeId || "").trim();
    const orderStoreCode = String(order.storeCode || "").trim();
    const orderStoreName =
      String(order.storeName || "").trim() || "Nearby store";

    const itemCount = Array.isArray(order.items)
      ? order.items.reduce(
          (total, item) => total + (number(item?.quantity) || 1),
          0,
        )
      : 0;

    // --------------------------------------------------------
    // STEP 1: NOTIFY STORE MANAGERS (ALWAYS)
    // --------------------------------------------------------

    let storeManagerNotifiedCount = 0;
    if (orderStoreId) {
      storeManagerNotifiedCount = await notifyStoreManagers(
        orderId,
        order,
        orderStoreId,
        orderStoreName,
        itemCount,
      );
    }

    // --------------------------------------------------------
    // STEP 2: CUSTOMER COORDINATES & VALIDATION FOR RIDERS
    // --------------------------------------------------------

    const customerLatitude = number(order.customerLatitude);
    const customerLongitude = number(order.customerLongitude);

    if (!validCoordinates(customerLatitude, customerLongitude)) {
      console.log(`Order ${orderId} has invalid customer coordinates.`);
      await snapshot.ref.set(
        {
          storeManagerNotifiedCount,
          riderOfferStatus: "invalid_coordinates",
          riderOfferUpdatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return;
    }

    if (!orderStoreId) {
      console.log(`Order ${orderId} has no storeId. Cannot safely offer this delivery.`);
      await snapshot.ref.set(
        {
          storeManagerNotifiedCount,
          offeredRiderIds: [],
          riderOfferStatus: "missing_store_id",
          riderOfferRadiusKm: RIDER_RADIUS_KM,
          riderOfferUpdatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return;
    }

    console.log(
      `Order ${orderId} store: ${orderStoreName} ` +
      `(storeId=${orderStoreId}, storeCode=${orderStoreCode})`,
    );

    // --------------------------------------------------------
    // STEP 3: FIND NEARBY RIDERS FOR THIS STORE
    // --------------------------------------------------------

    const nearbyRiders = await findNearbyRiders(
      customerLatitude,
      customerLongitude,
      orderStoreId,
    );

    if (nearbyRiders.length === 0) {
      console.log(`No eligible nearby riders found for order ${orderId}.`);
      await snapshot.ref.set(
        {
          storeManagerNotifiedCount,
          offeredRiderIds: [],
          riderOfferStatus: "no_nearby_riders",
          riderOfferRadiusKm: RIDER_RADIUS_KM,
          riderOfferUpdatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return;
    }

    // --------------------------------------------------------
    // UNIQUE RIDER IDS & FCM TOKENS
    // --------------------------------------------------------

    const offeredRiderIds = [...new Set(nearbyRiders.map((r) => r.uid))];
    const allTokens = [...new Set(nearbyRiders.flatMap((r) => r.tokens))];

    await snapshot.ref.set(
      {
        storeManagerNotifiedCount,
        offeredRiderIds,
        riderOfferStatus: "offered",
        riderOfferRadiusKm: RIDER_RADIUS_KM,
        riderOfferUpdatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    console.log(
      `Order ${orderId} assigned to ${offeredRiderIds.length} eligible riders.`,
    );

    // --------------------------------------------------------
    // STEP 4: SEND RIDER FCM NOTIFICATIONS
    // --------------------------------------------------------

    const customerAddress =
      String(order.address || "").trim() || "Customer location";
    const isRerouted = order.isRerouted === true;

    const notificationTitle = isRerouted
      ? "⚡ Rerouted Pickup Available"
      : "🚴 Delivery Available";

    const notificationBody =
      itemCount > 0
        ? `${itemCount} item${itemCount === 1 ? "" : "s"} • ${orderStoreName} • ${customerAddress}`
        : `New delivery from ${orderStoreName} near you`;

    if (allTokens.length > 0) {
      try {
        const response = await messaging.sendEachForMulticast({
          tokens: allTokens,
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            type: "delivery_offer",
            orderId: orderId,
            storeId: orderStoreId,
            storeName: orderStoreName,
            isRerouted: String(isRerouted),
            customerAddress: customerAddress,
            clickAction: "OPEN_DELIVERY",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "delivery_offers",
              sound: "default",
            },
          },
        });

        console.log(
          `Order ${orderId}: sent ${response.successCount} rider notifications, ` +
          `${response.failureCount} failures.`,
        );

        if (response.failureCount > 0) {
          response.responses.forEach((result, index) => {
            if (!result.success) {
              console.log(
                `FCM token ${index} failed:`,
                result.error?.message || "Unknown FCM error",
              );
            }
          });
        }
      } catch (error) {
        console.error(`FCM notification failed for order ${orderId}:`, error);
      }
    } else {
      console.log(`Order ${orderId}: no FCM tokens available for riders.`);
    }

    // --------------------------------------------------------
    // STEP 5: SAVE RIDER DISTANCES
    // --------------------------------------------------------

    await snapshot.ref.set(
      {
        riderOfferCount: offeredRiderIds.length,
        nearbyRiderDistancesKm: nearbyRiders.map((rider) => ({
          riderId: rider.uid,
          distanceKm: Number(rider.distanceKm.toFixed(3)),
        })),
      },
      { merge: true },
    );

    console.log(
      `Order ${orderId} successfully processed for store managers & riders.`,
    );
  },
);