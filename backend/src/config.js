require("dotenv").config();

const config = {
  port: process.env.PORT || 4000,
  frontendOrigin: process.env.FRONTEND_ORIGIN || "http://localhost:3000",

  // Entra ID
  tenantId: process.env.AZURE_TENANT_ID,
  clientId: process.env.AZURE_CLIENT_ID,
  clientIdSpa: process.env.AZURE_CLIENT_ID_SPA,
  get jwksUri() {
    return `https://login.microsoftonline.com/${this.tenantId}/discovery/keys`;
  },
  get issuerV1() {
    return `https://sts.windows.net/${this.tenantId}/`;
  },
  get issuerV2() {
    return `https://login.microsoftonline.com/${this.tenantId}/v2.0`;
  },
  get issuers() {
    return [this.issuerV1, this.issuerV2];
  },

  // Azure AI Foundry
  aiFoundryEndpoint: process.env.AZURE_AI_FOUNDRY_ENDPOINT,
  aiFoundryApiKey: process.env.AZURE_AI_FOUNDRY_API_KEY,
  aiFoundryModel: process.env.AZURE_AI_FOUNDRY_MODEL || "gpt-4o",
  aiFoundryDeployment: process.env.AZURE_AI_FOUNDRY_DEPLOYMENT || "gpt-4o",
  aiFoundryApiVersion: process.env.AZURE_AI_FOUNDRY_API_VERSION || "2024-04-01-preview",
};

module.exports = config;
