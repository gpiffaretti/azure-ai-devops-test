import React, { useState, useRef, useEffect } from "react";
import { Send, Square } from "lucide-react";

export default function MessageInput({ onSend, onStop, isStreaming, disabled }) {
  const [input, setInput] = useState("");
  const textareaRef = useRef(null);

  useEffect(() => {
    if (!isStreaming) {
      textareaRef.current?.focus();
    }
  }, [isStreaming]);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (input.trim() && !isStreaming && !disabled) {
      onSend(input);
      setInput("");
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  // Auto-resize textarea
  const handleInput = (e) => {
    setInput(e.target.value);
    const el = textareaRef.current;
    if (el) {
      el.style.height = "auto";
      el.style.height = Math.min(el.scrollHeight, 200) + "px";
    }
  };

  return (
    <form className="message-input-form" onSubmit={handleSubmit}>
      <div className="message-input-container">
        <textarea
          ref={textareaRef}
          className="message-input"
          value={input}
          onChange={handleInput}
          onKeyDown={handleKeyDown}
          placeholder="Type a message..."
          rows={1}
          disabled={disabled}
        />
        {isStreaming ? (
          <button
            type="button"
            className="send-button stop-button"
            onClick={onStop}
            title="Stop generating"
          >
            <Square size={18} />
          </button>
        ) : (
          <button
            type="submit"
            className="send-button"
            disabled={!input.trim() || disabled}
            title="Send message"
          >
            <Send size={18} />
          </button>
        )}
      </div>
    </form>
  );
}
