import { useState, useCallback, useRef } from "react";
import { useMsal } from "@azure/msal-react";
import { streamChat } from "../services/api";

/**
 * Custom hook for managing chat state and SSE streaming.
 * Handles message history, streaming state, and abort control.
 */
export function useChat() {
  const { instance } = useMsal();
  const [messages, setMessages] = useState([]);
  const [isStreaming, setIsStreaming] = useState(false);
  const [error, setError] = useState(null);
  const abortControllerRef = useRef(null);

  /**
   * Send a user message and stream the assistant response.
   * @param {string} userMessage - The user's message text
   */
  const sendMessage = useCallback(
    async (userMessage) => {
      if (!userMessage.trim() || isStreaming) return;

      setError(null);

      const userMsg = { role: "user", content: userMessage.trim() };
      const updatedMessages = [...messages, userMsg];

      setMessages([...updatedMessages, { role: "assistant", content: "", isStreaming: true }]);
      setIsStreaming(true);

      abortControllerRef.current = new AbortController();

      try {
        let assistantContent = "";

        await streamChat(
          instance,
          updatedMessages,
          {
            onDelta: (delta) => {
              assistantContent += delta;
              setMessages((prev) => {
                const next = [...prev];
                const last = next[next.length - 1];
                if (last.role === "assistant") {
                  next[next.length - 1] = {
                    ...last,
                    content: assistantContent,
                    isStreaming: true,
                  };
                }
                return next;
              });
            },
            onToolCall: (info) => {
              setMessages((prev) => {
                const next = [...prev];
                const last = next[next.length - 1];
                if (last.role === "assistant") {
                  const toolCalls = last.toolCalls || [];
                  next[next.length - 1] = {
                    ...last,
                    toolCalls: [...toolCalls, info],
                  };
                }
                return next;
              });
            },
            onError: (err) => {
              setError(err.message);
            },
            onDone: () => {
              setMessages((prev) => {
                const next = [...prev];
                const last = next[next.length - 1];
                if (last.role === "assistant") {
                  next[next.length - 1] = { ...last, isStreaming: false };
                }
                return next;
              });
            },
          },
          abortControllerRef.current.signal
        );
      } catch (err) {
        if (err.name !== "AbortError") {
          setError(err.message);
          // Remove the empty assistant message on error
          setMessages((prev) => {
            const last = prev[prev.length - 1];
            if (last?.role === "assistant" && !last.content) {
              return prev.slice(0, -1);
            }
            return prev;
          });
        }
      } finally {
        setIsStreaming(false);
        abortControllerRef.current = null;
      }
    },
    [instance, messages, isStreaming]
  );

  /**
   * Abort the current streaming response.
   */
  const stopStreaming = useCallback(() => {
    abortControllerRef.current?.abort();
    setIsStreaming(false);
    setMessages((prev) => {
      const next = [...prev];
      const last = next[next.length - 1];
      if (last?.role === "assistant") {
        next[next.length - 1] = { ...last, isStreaming: false };
      }
      return next;
    });
  }, []);

  /**
   * Clear all messages and start a new conversation.
   */
  const clearChat = useCallback(() => {
    abortControllerRef.current?.abort();
    setMessages([]);
    setIsStreaming(false);
    setError(null);
  }, []);

  return {
    messages,
    isStreaming,
    error,
    sendMessage,
    stopStreaming,
    clearChat,
  };
}
