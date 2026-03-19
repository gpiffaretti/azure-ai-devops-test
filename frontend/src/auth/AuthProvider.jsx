import React from "react";
import {
  MsalProvider,
  AuthenticatedTemplate,
  UnauthenticatedTemplate,
  useMsal,
} from "@azure/msal-react";
import { PublicClientApplication, EventType } from "@azure/msal-browser";
import { msalConfig, loginRequest } from "./msalConfig";
import { LogIn } from "lucide-react";

/**
 * MSAL instance – initialized once and passed to MsalProvider.
 */
const msalInstance = new PublicClientApplication(msalConfig);

// Set the first account as active if available after redirect
msalInstance.initialize().then(() => {
  const accounts = msalInstance.getAllAccounts();
  if (accounts.length > 0) {
    msalInstance.setActiveAccount(accounts[0]);
  }

  msalInstance.addEventCallback((event) => {
    if (event.eventType === EventType.LOGIN_SUCCESS && event.payload?.account) {
      msalInstance.setActiveAccount(event.payload.account);
      
      console.log("=== LOGIN SUCCESS ===");
      console.log("Account:", event.payload.account);
      
      if (event.payload.idToken) {
        console.log("ID Token:", event.payload.idToken);
        try {
          const idTokenPayload = JSON.parse(atob(event.payload.idToken.split('.')[1]));
          console.log("ID Token Payload:", idTokenPayload);
        } catch (e) {
          console.error("Failed to parse ID token:", e);
        }
      }
      
      if (event.payload.accessToken) {
        console.log("Access Token:", event.payload.accessToken);
        try {
          const accessTokenPayload = JSON.parse(atob(event.payload.accessToken.split('.')[1]));
          console.log("Access Token Payload:", accessTokenPayload);
        } catch (e) {
          console.error("Failed to parse access token:", e);
        }
      }
    }
  });
});

/**
 * Login page shown to unauthenticated users.
 */
function LoginPage() {
  const { instance } = useMsal();

  const handleLogin = () => {
    instance.loginRedirect(loginRequest).catch((error) => {
      console.error("Login failed:", error);
    });
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-icon">
          <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
            <rect width="48" height="48" rx="12" fill="#2563eb" />
            <path
              d="M14 16h8v8h-8zM26 16h8v8h-8zM14 26h8v8h-8zM26 26h8v8h-8z"
              fill="white"
              opacity="0.9"
            />
          </svg>
        </div>
        <h1>Azure AI Chatbot</h1>
        <p>Sign in with your organization account to continue.</p>
        <button className="login-button" onClick={handleLogin}>
          <LogIn size={18} />
          Sign in with Microsoft
        </button>
      </div>
    </div>
  );
}

/**
 * Auth wrapper that provides MSAL context to the app.
 * Shows login page for unauthenticated users, renders children when authenticated.
 */
export default function AuthProvider({ children }) {
  return (
    <MsalProvider instance={msalInstance}>
      <AuthenticatedTemplate>{children}</AuthenticatedTemplate>
      <UnauthenticatedTemplate>
        <LoginPage />
      </UnauthenticatedTemplate>
    </MsalProvider>
  );
}
