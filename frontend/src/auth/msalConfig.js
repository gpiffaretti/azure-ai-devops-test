import { LogLevel } from "@azure/msal-browser";

/**
 * MSAL configuration for Entra ID authentication using Authorization Code + PKCE.
 */
export const msalConfig = {
  auth: {
    clientId: process.env.REACT_APP_AZURE_CLIENT_ID,
    authority: `https://login.microsoftonline.com/${process.env.REACT_APP_AZURE_TENANT_ID}`,
    redirectUri: process.env.REACT_APP_AZURE_REDIRECT_URI || window.location.origin,
    postLogoutRedirectUri: window.location.origin,
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  },
  system: {
    loggerOptions: {
      loggerCallback: (level, message, containsPii) => {
        if (containsPii) return;
        switch (level) {
          case LogLevel.Error:
            console.error(message);
            break;
          case LogLevel.Warning:
            console.warn(message);
            break;
          default:
            break;
        }
      },
      logLevel: LogLevel.Warning,
    },
  },
};

/**
 * Scopes required to call the backend API.
 * The scope must match the one exposed in the backend App Registration.
 */
export const apiScope = process.env.REACT_APP_API_SCOPE;

export const loginRequest = {
  scopes: [apiScope],
};

export const tokenRequest = {
  scopes: [apiScope],
};
