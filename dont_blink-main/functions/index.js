const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

// ============================================================
// GLOBAL OPTIONS
// ============================================================

setGlobalOptions({
  maxInstances: 10,
});

// ============================================================
// CASHFREE SECRETS
// ============================================================

const cashfreeAppId = defineSecret("CASHFREE_APP_ID");

const cashfreeSecretKey = defineSecret("CASHFREE_SECRET_KEY");

// ============================================================
// CASHFREE SANDBOX URL
// ============================================================

const CASHFREE_BASE_URL =
  "https://sandbox.cashfree.com/pg";

// ============================================================
// CREATE CASHFREE ORDER
// ============================================================

exports.createCashfreeOrder = onRequest(
  {
    secrets: [
      cashfreeAppId,
      cashfreeSecretKey,
    ],

    cors: true,

    region: "asia-south1",

    timeoutSeconds: 60,

    memory: "256MiB",
  },

  async (req, res) => {
    // ========================================================
    // CORS
    // ========================================================

    res.set("Access-Control-Allow-Origin", "*");

    res.set(
      "Access-Control-Allow-Headers",
      "Content-Type, Authorization",
    );

    res.set(
      "Access-Control-Allow-Methods",
      "POST, OPTIONS",
    );

    // ========================================================
    // PREFLIGHT
    // ========================================================

    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    // ========================================================
    // ONLY POST
    // ========================================================

    if (req.method !== "POST") {
      return res.status(405).json({
        success: false,
        error: "Method not allowed",
      });
    }

    try {
      // ======================================================
      // READ REQUEST BODY
      // ======================================================

      const {
        orderId,
        amount,
        customerId,
        customerName,
        customerPhone,
        customerEmail,
        returnUrl,
      } = req.body || {};

      // ======================================================
      // VALIDATION
      // ======================================================

      if (!orderId) {
        return res.status(400).json({
          success: false,
          error: "Missing orderId",
        });
      }

      if (amount === undefined || amount === null) {
        return res.status(400).json({
          success: false,
          error: "Missing amount",
        });
      }

      const orderAmount = Number(amount);

      if (!Number.isFinite(orderAmount) || orderAmount <= 0) {
        return res.status(400).json({
          success: false,
          error: "Invalid order amount",
        });
      }

      if (!customerId) {
        return res.status(400).json({
          success: false,
          error: "Missing customerId",
        });
      }

      if (!customerPhone) {
        return res.status(400).json({
          success: false,
          error: "Missing customerPhone",
        });
      }

      // ======================================================
      // CASHFREE CREDENTIALS
      // ======================================================

      const appId = cashfreeAppId.value();

      const secretKey = cashfreeSecretKey.value();

      if (!appId || !secretKey) {
        logger.error(
          "Cashfree credentials are not available.",
        );

        return res.status(500).json({
          success: false,
          error: "Cashfree configuration is missing",
        });
      }

      // ======================================================
      // CASHFREE REQUEST
      // ======================================================

      const cashfreePayload = {
        order_id: orderId,

        order_amount: Number(orderAmount.toFixed(2)),

        order_currency: "INR",

        customer_details: {
          customer_id: String(customerId),

          customer_name:
            customerName || "Customer",

          customer_email:
            customerEmail || "customer@example.com",

          customer_phone:
            String(customerPhone),
        },

        order_meta: {
          return_url:
            returnUrl ||
            "https://example.com/payment-success",
        },

        order_note: "Don'tBlink Order",
      };

      // ======================================================
      // CALL CASHFREE
      // ======================================================

      const response = await fetch(
        `${CASHFREE_BASE_URL}/orders`,
        {
          method: "POST",

          headers: {
            "Content-Type": "application/json",

            "x-api-version": "2025-01-01",

            "x-client-id": appId,

            "x-client-secret": secretKey,

            "x-request-id":
              `${orderId}-${Date.now()}`,
          },

          body: JSON.stringify(
            cashfreePayload,
          ),
        },
      );

      // ======================================================
      // CASHFREE RESPONSE
      // ======================================================

      const responseText =
        await response.text();

      let data;

      try {
        data = JSON.parse(responseText);
      } catch (error) {
        data = {
          raw: responseText,
        };
      }

      // ======================================================
      // CASHFREE ERROR
      // ======================================================

      if (!response.ok) {
        logger.error(
          "Cashfree Create Order failed",
          {
            status: response.status,
            response: data,
          },
        );

        return res.status(502).json({
          success: false,

          error:
            data?.message ||
            data?.error_description ||
            "Cashfree order creation failed",

          cashfreeStatus:
            response.status,
        });
      }

      // ======================================================
      // SUCCESS
      // ======================================================

      logger.info(
        "Cashfree order created",
        {
          orderId,
        },
      );

      return res.status(200).json({
        success: true,

        orderId:
          data.order_id || orderId,

        paymentSessionId:
          data.payment_session_id,

        cfOrderId:
          data.cf_order_id || null,

        orderStatus:
          data.order_status || null,
      });
    } catch (error) {
      // ======================================================
      // SERVER ERROR
      // ======================================================

      logger.error(
        "createCashfreeOrder error",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          error?.message ||
          "Internal server error",
      });
    }
  },
);
// ============================================================
// VERIFY CASHFREE PAYMENT
// ============================================================

exports.verifyCashfreePayment = onRequest(
  {
    secrets: [
      cashfreeAppId,
      cashfreeSecretKey,
    ],

    cors: true,

    region: "asia-south1",

    timeoutSeconds: 60,

    memory: "256MiB",
  },

  async (req, res) => {
    // ========================================================
    // CORS
    // ========================================================

    res.set(
      "Access-Control-Allow-Origin",
      "*",
    );

    res.set(
      "Access-Control-Allow-Headers",
      "Content-Type, Authorization",
    );

    res.set(
      "Access-Control-Allow-Methods",
      "POST, OPTIONS",
    );

    // ========================================================
    // PREFLIGHT
    // ========================================================

    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    // ========================================================
    // ONLY POST
    // ========================================================

    if (req.method !== "POST") {
      return res.status(405).json({
        success: false,
        error: "Method not allowed",
      });
    }

    try {
      // ======================================================
      // READ REQUEST
      // ======================================================

      const {
        orderId,
      } = req.body || {};

      // ======================================================
      // VALIDATE ORDER ID
      // ======================================================

      if (!orderId) {
        return res.status(400).json({
          success: false,
          error: "Missing orderId",
        });
      }

      // ======================================================
      // CASHFREE CREDENTIALS
      // ======================================================

      const appId =
        cashfreeAppId.value();

      const secretKey =
        cashfreeSecretKey.value();

      if (!appId || !secretKey) {
        logger.error(
          "Cashfree credentials are missing.",
        );

        return res.status(500).json({
          success: false,
          error:
            "Cashfree configuration is missing",
        });
      }

      // ======================================================
      // GET PAYMENTS FOR ORDER
      // ======================================================

      const response = await fetch(
        `${CASHFREE_BASE_URL}/orders/${encodeURIComponent(orderId)}/payments`,
        {
          method: "GET",

          headers: {
            Accept:
              "application/json",

            "x-api-version":
              "2025-01-01",

            "x-client-id":
              appId,

            "x-client-secret":
              secretKey,
          },
        },
      );

      // ======================================================
      // READ RESPONSE
      // ======================================================

      const responseText =
        await response.text();

      let payments;

      try {
        payments =
          JSON.parse(responseText);
      } catch (error) {
        payments = [];
      }

      // ======================================================
      // CASHFREE ERROR
      // ======================================================

      if (!response.ok) {
        logger.error(
          "Cashfree payment verification failed",
          {
            orderId,
            status: response.status,
            response: payments,
          },
        );

        return res.status(502).json({
          success: false,

          error:
            payments?.message ||
            payments?.error_description ||
            "Unable to verify payment",

          cashfreeStatus:
            response.status,
        });
      }

      // ======================================================
      // NORMALIZE PAYMENT LIST
      // ======================================================

      const paymentList =
        Array.isArray(payments)
          ? payments
          : [];

      // ======================================================
      // FIND SUCCESS PAYMENT
      // ======================================================

      const successfulPayment =
        paymentList.find(
          (payment) =>
            payment?.payment_status ===
            "SUCCESS",
        );

      // ======================================================
      // FIND PENDING PAYMENT
      // ======================================================

      const pendingPayment =
        paymentList.find(
          (payment) =>
            payment?.payment_status ===
            "PENDING",
        );

      // ======================================================
      // DETERMINE FINAL STATUS
      // ======================================================

      let status = "FAILED";

      if (successfulPayment) {
        status = "SUCCESS";
      } else if (pendingPayment) {
        status = "PENDING";
      }

      // ======================================================
      // RETURN RESULT
      // ======================================================

      logger.info(
        "Cashfree payment verification completed",
        {
          orderId,
          status,
        },
      );

      return res.status(200).json({
        success: true,

        orderId,

        paymentStatus: status,

        payment:
          successfulPayment ||
          pendingPayment ||
          paymentList[0] ||
          null,
      });
    } catch (error) {
      // ======================================================
      // SERVER ERROR
      // ======================================================

      logger.error(
        "verifyCashfreePayment error",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          error?.message ||
          "Internal server error",
      });
    }
  },
);