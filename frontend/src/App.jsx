import React from "react";
import AuthProvider from "./auth/AuthProvider";
import Chat from "./components/Chat";

export default function App() {
  return (
    <AuthProvider>
      <Chat />
    </AuthProvider>
  );
}
