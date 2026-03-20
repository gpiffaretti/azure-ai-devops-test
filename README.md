# Azure AI Chatbot

A full-stack chatbot application built on Azure platform with Entra ID authentication, Azure AI Foundry integration, and real-time SSE streaming.

## Architecture

| Component       | Technology                                      |
| --------------- | ----------------------------------------------- |
| **Frontend**    | React SPA (hosted on Azure Static Web Apps)     |
| **Backend**     | Node.js + Express (hosted on Azure App Service) |
| **Auth**        | Entra ID (single-tenant, OAuth2 PKCE)           |
| **API Security**| JWT access token validated in backend            |
| **AI Layer**    | Azure AI Foundry (streaming + tool calling)      |
| **Streaming**   | Server-Sent Events (SSE)                        |

## Project Structure

```
azure_chatbot/
├── backend/
│   ├── src/
│   │   ├── index.js              # Express server entry point
│   │   ├── config.js             # Environment configuration
│   │   ├── middleware/
│   │   │   ├── auth.js           # JWT validation + RBAC authorization
│   │   │   └── logging.js        # Structured request logging
│   │   ├── routes/
│   │   │   ├── chat.js           # SSE streaming chat endpoint
│   │   │   └── health.js         # Health check endpoint
│   │   └── services/
│   │       ├── aiFoundry.js      # Azure AI Foundry client
│   │       └── tools.js          # Tool definitions and handlers
│   ├── .env.example
│   └── package.json
├── frontend/
│   ├── public/
│   │   └── index.html
│   ├── src/
│   │   ├── index.js              # React entry point
│   │   ├── index.css             # Global styles
│   │   ├── App.jsx               # Root component
│   │   ├── auth/
│   │   │   ├── msalConfig.js     # MSAL configuration
│   │   │   └── AuthProvider.jsx  # Auth wrapper with login page
│   │   ├── components/
│   │   │   ├── Chat.jsx          # Main chat container
│   │   │   ├── Header.jsx        # App header with user info
│   │   │   ├── MessageList.jsx   # Message display with markdown
│   │   │   └── MessageInput.jsx  # Auto-resizing input with send/stop
│   │   ├── hooks/
│   │   │   └── useChat.js        # Chat state and streaming logic
│   │   └── services/
│   │       └── api.js            # Backend API client with token management
│   ├── .env.example
│   └── package.json
├── infrastructure/
│   ├── main.bicep                # Main orchestration template
│   ├── modules/
│   │   ├── staticWebApp.bicep    # Azure Static Web Apps (frontend)
│   │   ├── appService.bicep      # Azure App Service (backend API)
│   │   ├── aiFoundry.bicep       # Azure AI Foundry (OpenAI)
│   │   └── managedIdentity.bicep # User-assigned identity + RBAC
│   ├── parameters.dev.json       # Dev environment config
│   └── parameters.prod.json      # Prod environment config
├── scripts/
│   ├── deploy.ps1                # Main deployment script
│   ├── validate.ps1              # Template validation + what-if
│   └── teardown.ps1              # Resource cleanup
├── plan.md
└── README.md
```

## Prerequisites

1. **Azure Subscription** with the following resources:
   - Azure AI Foundry resource with a deployed model (e.g., `gpt-4o`)
   - Two Entra ID App Registrations (SPA + Backend API)

2. **Node.js** >= 18.x

## Azure Setup

### 1. Entra ID App Registrations

#### Backend API Registration
1. Go to **Azure Portal > Microsoft Entra ID > App registrations > New registration**
2. Name: `azure-chatbot-api`
3. Supported account types: **Single tenant**
4. After creation:
   - Go to **Expose an API** > Set Application ID URI (e.g., `api://<client-id>`)
   - Add a scope: `access_as_user` (Admin and users can consent)
   - Go to **App roles** > Create roles:
     - `ChatUser` - Users who can use the chat
     - `ChatAdmin` - Administrators with full access
   - Note the **Client ID**

#### SPA Registration
1. Create another registration: `azure-chatbot-spa`
2. Supported account types: **Single tenant**
3. Redirect URI: `http://localhost:3000` (type: SPA)
4. After creation:
   - Go to **API permissions** > Add permission > My APIs > select `azure-chatbot-api`
   - Add the `access_as_user` scope
   - Grant admin consent
5. Note the **Client ID**

#### Assign Roles to Users
1. Go to **Enterprise Applications** > find `azure-chatbot-api`
2. **Users and groups** > Add user/group > Assign the `ChatUser` or `ChatAdmin` role

### 2. Deployment Service Principal (for CI/CD)

If using GitHub Actions or automated deployments, the service principal needs additional permissions to update redirect URIs:

1. Go to **Azure Portal > Microsoft Entra ID > App registrations**
2. Find your deployment service principal (the one with `AZURE_CLIENT_ID` used in GitHub secrets)
3. Navigate to **API permissions** > **Add a permission** > **Microsoft Graph** > **Application permissions**
4. Search for and add: `Application.ReadWrite.All`
5. Click **Grant admin consent** (requires Global Administrator role)

**Why this is needed:** The deployment pipeline automatically updates the SPA app registration's redirect URIs to match the deployed Static Web App URL, preventing authentication errors when the URL changes (especially for PR environments).

Alternatively, using Azure CLI:
```bash
# Assign Application.ReadWrite.All permission
az ad app permission add \
  --id <AZURE_CLIENT_ID> \
  --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role

# Grant admin consent
az ad app permission admin-consent --id <AZURE_CLIENT_ID>
```

### 3. Azure AI Foundry
1. Create an **Azure AI Foundry** resource
2. Deploy a model (e.g., `gpt-4o`)
3. Note the **Endpoint URL** and **API Key**

## Local Development

### Backend

```bash
cd backend
cp .env.example .env
# Fill in your Azure credentials in .env
npm install
npm run dev
```

The backend runs on `http://localhost:4000`.

### Frontend

```bash
cd frontend
cp .env.example .env
# Fill in your Azure credentials in .env
npm install
npm start
```

The frontend runs on `http://localhost:3000`.

## Environment Variables

### Backend (`backend/.env`)

| Variable                    | Description                              |
| --------------------------- | ---------------------------------------- |
| `AZURE_TENANT_ID`          | Entra ID tenant ID                       |
| `AZURE_CLIENT_ID`          | Backend API app registration client ID   |
| `AZURE_CLIENT_ID_SPA`      | SPA app registration client ID           |
| `AZURE_AI_FOUNDRY_ENDPOINT`| AI Foundry resource endpoint URL         |
| `AZURE_AI_FOUNDRY_API_KEY` | AI Foundry API key                       |
| `AZURE_AI_FOUNDRY_MODEL`   | Deployed model name (default: `gpt-4o`)  |
| `PORT`                     | Server port (default: `4000`)            |
| `FRONTEND_ORIGIN`          | Allowed CORS origin (default: `http://localhost:3000`) |

### Frontend (`frontend/.env`)

| Variable                     | Description                              |
| ---------------------------- | ---------------------------------------- |
| `REACT_APP_AZURE_CLIENT_ID`  | SPA app registration client ID          |
| `REACT_APP_AZURE_TENANT_ID`  | Entra ID tenant ID                      |
| `REACT_APP_AZURE_REDIRECT_URI` | Redirect URI (default: `http://localhost:3000`) |
| `REACT_APP_API_BASE_URL`     | Backend API URL (default: `http://localhost:4000`) |
| `REACT_APP_API_SCOPE`        | Backend API scope (e.g., `api://<backend-client-id>/access_as_user`) |

## API Endpoints

| Method | Path      | Auth     | Description                          |
| ------ | --------- | -------- | ------------------------------------ |
| GET    | `/health` | Public   | Health check                         |
| POST   | `/chat`   | Bearer JWT | SSE streaming chat completions     |

### SSE Event Types

| Event       | Description                                |
| ----------- | ------------------------------------------ |
| `delta`     | Partial text content from the model        |
| `tool_call` | Notification that a tool was executed      |
| `error`     | An error occurred during streaming         |
| `done`      | Stream is complete                         |

## Adding Custom Tools

Edit `backend/src/services/tools.js` to add new tools:

1. Add a tool definition to `toolDefinitions` array (OpenAI function calling format)
2. Add the corresponding handler to `toolHandlers` object
3. The handler receives parsed arguments and returns a JSON string result

## Infrastructure & Deployment (Azure)

The project uses **Bicep** templates for infrastructure-as-code and **PowerShell** scripts for deployment automation.

### Project Structure (Infrastructure)

```
azure_chatbot/
├── infrastructure/
│   ├── main.bicep                    # Main orchestration template
│   ├── modules/
│   │   ├── staticWebApp.bicep        # Azure Static Web Apps (frontend)
│   │   ├── appService.bicep          # Azure App Service (backend API)
│   │   ├── aiFoundry.bicep           # Azure AI Foundry (OpenAI)
│   │   └── managedIdentity.bicep     # User-assigned identity + RBAC
│   ├── parameters.dev.json           # Dev environment parameters
│   └── parameters.prod.json          # Prod environment parameters
├── scripts/
│   ├── deploy.ps1                    # Main deployment script
│   ├── validate.ps1                  # Template validation + what-if
│   └── teardown.ps1                  # Resource cleanup
```

### Prerequisites

1. **Azure CLI** installed and logged in (`az login`)
2. **Azure PowerShell** module (`Install-Module Az`)
3. **Bicep CLI** (bundled with Azure CLI, or install standalone)
4. **Azure Static Web Apps CLI** (`npm install -g @azure/static-web-apps-cli`)
5. An **Azure Subscription** with permissions to create resources

### Configuration

Before deploying, update the parameters file for your target environment:

- `infrastructure/parameters.dev.json` — Development
- `infrastructure/parameters.prod.json` — Production

Replace all `<YOUR_...>` placeholder values with your actual Azure configuration:

| Parameter | Description |
| --- | --- |
| `tenantId` | Entra ID tenant ID |
| `backendClientId` | Backend API app registration client ID |
| `spaClientId` | SPA app registration client ID |

### Validate Templates

```powershell
# Syntax check and what-if analysis
.\scripts\validate.ps1 -Environment dev -ResourceGroupName rg-azure-chatbot-dev

# With what-if preview of changes
.\scripts\validate.ps1 -Environment dev -ResourceGroupName rg-azure-chatbot-dev -WhatIf
```

### Deploy

```powershell
# Full deployment (infrastructure + application code)
.\scripts\deploy.ps1 -Environment dev -ResourceGroupName rg-azure-chatbot-dev -Location eastus2

# Infrastructure only
.\scripts\deploy.ps1 -Environment dev -ResourceGroupName rg-azure-chatbot-dev -InfraOnly

# Application code only (requires prior infrastructure deployment)
.\scripts\deploy.ps1 -Environment dev -ResourceGroupName rg-azure-chatbot-dev -AppOnly

# Production deployment
.\scripts\deploy.ps1 -Environment prod -ResourceGroupName rg-azure-chatbot-prod -Location eastus2
```

### Teardown

```powershell
# Interactive confirmation
.\scripts\teardown.ps1 -Environment dev -ResourceGroupName rg-azure-chatbot-dev

# Skip confirmation prompt
.\scripts\teardown.ps1 -Environment dev -ResourceGroupName rg-azure-chatbot-dev -Force
```

> **Note:** Teardown deletes the resource group and all resources. Entra ID app registrations must be deleted manually from the Azure Portal.

### What Gets Deployed

| Resource | Service | Purpose |
| --- | --- | --- |
| Static Web App | `Microsoft.Web/staticSites` | React SPA frontend hosting |
| App Service Plan | `Microsoft.Web/serverfarms` | Linux compute plan for backend |
| App Service | `Microsoft.Web/sites` | Node.js Express backend API |
| Cognitive Services (OpenAI) | `Microsoft.CognitiveServices/accounts` | AI Foundry with model deployment |
| User-Assigned Identity | `Microsoft.ManagedIdentity` | Backend → AI Foundry auth (RBAC) |

### Security

- **HTTPS only** enforced on App Service
- **CORS** configured to allow only the Static Web App origin
- **Managed Identity** used for backend-to-AI-Foundry authentication (no API keys in production)
- **FTPS disabled** on App Service
- **TLS 1.2** minimum enforced
