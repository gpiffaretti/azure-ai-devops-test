const express = require("express");
const cors = require("cors");
const config = require("./config");
const { requestLogger } = require("./middleware/logging");
const healthRoutes = require("./routes/health");
const chatRoutes = require("./routes/chat");

const app = express();

// --------------- Middleware ---------------

app.use(
  cors({
    origin: config.frontendOrigin,
    methods: ["GET", "POST", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
    credentials: true,
  })
);

app.use(express.json({ limit: "1mb" }));
app.use(requestLogger);

// --------------- Routes ---------------

app.use(healthRoutes);
app.use(chatRoutes);

// --------------- Error Handling ---------------

app.use((err, _req, res, _next) => {
  if (err.name === "UnauthorizedError") {
    return res.status(401).json({
      error: "Invalid or missing token",
      message: err.message,
    });
  }

  console.error("Unhandled error:", err);
  res.status(500).json({ error: "Internal server error" });
});

// --------------- Start Server ---------------

app.listen(config.port, () => {
  console.log(`Backend API listening on http://localhost:${config.port}`);
  console.log(`Frontend origin: ${config.frontendOrigin}`);
});

module.exports = app;
