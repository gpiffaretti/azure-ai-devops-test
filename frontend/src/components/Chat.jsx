import React from "react";
import { useMsal } from "@azure/msal-react";
import { useChat } from "../hooks/useChat";
import Header from "./Header";
import MessageList from "./MessageList";
import MessageInput from "./MessageInput";
import { AlertTriangle } from "lucide-react";

export default function Chat() {
  const { accounts } = useMsal();
  const { messages, isStreaming, error, sendMessage, stopStreaming, clearChat } =
    useChat();

  // Extract roles from the ID token claims
  const account = accounts[0];
  const idTokenClaims = account?.idTokenClaims || {};
  const userRoles = idTokenClaims.roles || [];

  return (
    <div className="chat-container">
      <Header onNewChat={clearChat} userRoles={userRoles} />
      <main className="chat-main">
        <MessageList messages={messages} />
      </main>
      {error && (
        <div className="error-banner">
          <AlertTriangle size={16} />
          <span>{error}</span>
        </div>
      )}
      <footer className="chat-footer">
        <MessageInput
          onSend={sendMessage}
          onStop={stopStreaming}
          isStreaming={isStreaming}
        />
      </footer>
    </div>
  );
}
