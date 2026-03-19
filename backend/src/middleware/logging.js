const { v4: uuidv4 } = require("uuid");

/**
 * Structured logging middleware.
 * Attaches a unique request ID and logs request/response details
 * including user ID, role, and latency.
 */
function requestLogger(req, res, next) {
  const requestId = req.headers["x-request-id"] || uuidv4();
  const startTime = Date.now();

  req.requestId = requestId;
  res.setHeader("X-Request-Id", requestId);

  res.on("finish", () => {
    const latency = Date.now() - startTime;
    const userId = req.auth?.oid || req.auth?.sub || "anonymous";
    const roles = req.auth?.roles || [];

    const logEntry = {
      timestamp: new Date().toISOString(),
      requestId,
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      userId,
      roles,
      latencyMs: latency,
      userAgent: req.headers["user-agent"],
    };

    if (res.statusCode >= 400) {
      console.error(JSON.stringify(logEntry));
    } else {
      console.log(JSON.stringify(logEntry));
    }
  });

  next();
}

module.exports = { requestLogger };
