import React from "react";
import { useMsal } from "@azure/msal-react";
import { LogOut, MessageSquarePlus, Bot } from "lucide-react";

export default function Header({ onNewChat, userRoles }) {
  const { instance, accounts } = useMsal();
  const account = accounts[0];

  const handleLogout = () => {
    instance.logoutRedirect({ postLogoutRedirectUri: window.location.origin });
  };

  return (
    <header className="header">
      <div className="header-left">
        <Bot size={24} />
        <h1>Azure AI Chatbot</h1>
      </div>
      <div className="header-right">
        {userRoles.length > 0 && (
          <span className="role-badge">{userRoles[0]}</span>
        )}
        <button
          className="icon-button"
          onClick={onNewChat}
          title="New chat"
        >
          <MessageSquarePlus size={18} />
        </button>
        <span className="user-name">{account?.name || account?.username}</span>
        <button
          className="icon-button"
          onClick={handleLogout}
          title="Sign out"
        >
          <LogOut size={18} />
        </button>
      </div>
    </header>
  );
}
