const { Router } = require("express");
const { authenticate, authorize } = require("../middleware/auth");
const { streamChatCompletion } = require("../services/aiFoundry");

const router = Router();

/**
 * POST /chat
 * Authenticated SSE endpoint for streaming chat completions.
 *
 * Request body: { messages: [{ role: "user"|"assistant"|"system", content: "..." }] }
 * Response: Server-Sent Events stream with text deltas and tool call notifications.
 *
 * SSE event types:
 *   - "delta"     : partial text content from the model
 *   - "tool_call" : notification that a tool was executed
 *   - "error"     : an error occurred during streaming
 *   - "done"      : stream is complete
 */
router.post(
  "/chat",
  authenticate,
  authorize("ChatUser", "ChatAdmin"),
  async (req, res) => {
    const { messages } = req.body;

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return res
        .status(400)
        .json({ error: "messages array is required and must not be empty" });
    }

    // Set SSE headers
    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    });

    // Heartbeat to keep connection alive
    const heartbeat = setInterval(() => {
      res.write(": heartbeat\n\n");
    }, 15000);

    // Abort controller for client disconnect
    const abortController = new AbortController();

    req.on("close", () => {
      abortController.abort();
      clearInterval(heartbeat);
    });

    try {
      await streamChatCompletion(
        messages,
        (textDelta) => {
          if (!res.writableEnded) {
            res.write(
              `event: delta\ndata: ${JSON.stringify({ content: textDelta })}\n\n`
            );
          }
        },
        (toolInfo) => {
          if (!res.writableEnded) {
            res.write(
              `event: tool_call\ndata: ${JSON.stringify(toolInfo)}\n\n`
            );
          }
        },
        abortController.signal
      );

      if (!res.writableEnded) {
        res.write(`event: done\ndata: {}\n\n`);
        res.end();
      }
    } catch (err) {
      console.error("Chat streaming error:", {
        requestId: req.requestId,
        error: err.message,
      });

      if (!res.writableEnded) {
        res.write(
          `event: error\ndata: ${JSON.stringify({ error: err.message })}\n\n`
        );
        res.end();
      }
    } finally {
      clearInterval(heartbeat);
    }
  }
);

module.exports = router;
