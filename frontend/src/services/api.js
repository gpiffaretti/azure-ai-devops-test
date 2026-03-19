import { tokenRequest } from "../auth/msalConfig";

const API_BASE_URL = process.env.REACT_APP_API_BASE_URL || "http://localhost:4000";

/**
 * Acquire a fresh access token for the backend API.
 * Tries silent acquisition first, falls back to redirect.
 *
 * @param {import("@azure/msal-browser").IPublicClientApplication} msalInstance
 * @returns {Promise<string>} Bearer access token
 */
async function getAccessToken(msalInstance) {
  const account = msalInstance.getActiveAccount();
  if (!account) {
    throw new Error("No active account. Please sign in.");
  }

  try {
    const response = await msalInstance.acquireTokenSilent({
      ...tokenRequest,
      account,
    });
    return response.accessToken;
  } catch (error) {
    // If silent fails, trigger redirect
    await msalInstance.acquireTokenRedirect(tokenRequest);
    throw new Error("Redirecting for token acquisition...");
  }
}

/**
 * Stream a chat completion from the backend via SSE (POST request).
 * Uses fetch + ReadableStream since EventSource only supports GET.
 *
 * @param {import("@azure/msal-browser").IPublicClientApplication} msalInstance
 * @param {Array} messages - Chat messages [{role, content}]
 * @param {Object} callbacks
 * @param {Function} callbacks.onDelta   - Called with each text delta string
 * @param {Function} callbacks.onToolCall - Called with tool call info
 * @param {Function} callbacks.onError   - Called with error object
 * @param {Function} callbacks.onDone    - Called when stream completes
 * @param {AbortSignal} [signal] - Optional abort signal
 */
export async function streamChat(msalInstance, messages, callbacks, signal) {
  const token = await getAccessToken(msalInstance);

  const response = await fetch(`${API_BASE_URL}/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ messages }),
    signal,
  });

  if (!response.ok) {
    const errorBody = await response.json().catch(() => ({}));
    throw new Error(errorBody.error || `HTTP ${response.status}`);
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      let eventType = null;

      for (const line of lines) {
        const trimmed = line.trim();

        if (trimmed.startsWith("event:")) {
          eventType = trimmed.slice(6).trim();
          continue;
        }

        if (trimmed.startsWith("data:")) {
          const dataStr = trimmed.slice(5).trim();
          if (!dataStr) continue;

          try {
            const data = JSON.parse(dataStr);

            switch (eventType) {
              case "delta":
                callbacks.onDelta?.(data.content || "");
                break;
              case "tool_call":
                callbacks.onToolCall?.(data);
                break;
              case "error":
                callbacks.onError?.(new Error(data.error));
                break;
              case "done":
                callbacks.onDone?.();
                break;
              default:
                break;
            }
          } catch {
            // Skip malformed JSON
          }

          eventType = null;
        }
      }
    }

    // Stream ended without explicit done event
    callbacks.onDone?.();
  } finally {
    reader.releaseLock();
  }
}

/**
 * Check backend health.
 * @returns {Promise<Object>} Health status
 */
export async function checkHealth() {
  const response = await fetch(`${API_BASE_URL}/health`);
  return response.json();
}
