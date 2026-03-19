import React, { useEffect, useRef } from "react";
import ReactMarkdown from "react-markdown";
import { User, Bot, Wrench } from "lucide-react";

function ToolCallBadge({ toolCall }) {
  return (
    <div className="tool-call-badge">
      <Wrench size={14} />
      <span>
        Called <strong>{toolCall.name}</strong>
      </span>
    </div>
  );
}

function Message({ message }) {
  const isUser = message.role === "user";

  return (
    <div className={`message ${isUser ? "message-user" : "message-assistant"}`}>
      <div className="message-avatar">
        {isUser ? <User size={18} /> : <Bot size={18} />}
      </div>
      <div className="message-body">
        {message.toolCalls?.map((tc, i) => (
          <ToolCallBadge key={i} toolCall={tc} />
        ))}
        <div className="message-content">
          <ReactMarkdown>{message.content}</ReactMarkdown>
        </div>
        {message.isStreaming && <span className="cursor-blink" />}
      </div>
    </div>
  );
}

export default function MessageList({ messages }) {
  const endRef = useRef(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  if (messages.length === 0) {
    return (
      <div className="empty-state">
        <Bot size={48} strokeWidth={1.5} />
        <h2>How can I help you today?</h2>
        <p>Send a message to start a conversation with the AI assistant.</p>
      </div>
    );
  }

  return (
    <div className="message-list">
      {messages.map((msg, idx) => (
        <Message key={idx} message={msg} />
      ))}
      <div ref={endRef} />
    </div>
  );
}
