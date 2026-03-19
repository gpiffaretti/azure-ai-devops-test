{
  "architecture": {
    "frontend": "SPA hosted on Azure Static Web Apps",
    "backend": "Node.js + Express API hosted on Azure App Service",
    "auth": "Entra ID (single-tenant, OAuth2 PKCE)",
    "api_security": "JWT access token validated in backend",
    "ai_layer": "Azure AI Foundry (single model, tool calling enabled)",
    "streaming": "Server-Sent Events (SSE) from backend to frontend",
    "observability": "Application Insights",
    "ci_cd": "GitHub Actions"
  },
  "phases": [
    {
      "name": "Phase 1 - Identity and App Registration",
      "objective": "Set up authentication and secure communication between SPA and backend",
      "steps": [
        "Create Entra ID App Registration for SPA (public client with PKCE enabled)",
        "Create Entra ID App Registration for backend API",
        "Expose API scopes in backend app registration",
        "Configure SPA to request access tokens for backend scopes",
        "Define RBAC roles in Entra ID (App Roles)",
        "Assign users/groups to roles",
        "Document token structure (audience, issuer, roles claims)"
      ],
      "deliverables": [
        "Working login flow from SPA",
        "Access token issued for backend API",
        "RBAC roles defined and testable"
      ]
    },
    {
      "name": "Phase 2 - Backend API Foundation",
      "objective": "Build secure Express API with Entra ID validation and SSE support",
      "steps": [
        "Initialize Node.js + Express project",
        "Add middleware to validate JWT tokens (using jwks endpoint from Entra ID)",
        "Extract and validate roles from token claims",
        "Implement authorization middleware (RBAC enforcement)",
        "Create base route structure (/chat, /health)",
        "Implement SSE endpoint with proper headers (Content-Type: text/event-stream)",
        "Ensure connection keep-alive and proper stream flushing",
        "Add structured logging (request id, user id, role, latency)"
      ],
      "deliverables": [
        "Protected API endpoints",
        "SSE streaming endpoint functional",
        "RBAC enforced at API level"
      ]
    },
    {
      "name": "Phase 3 - Azure AI Foundry Integration",
      "objective": "Connect backend to Foundry model with streaming and tool calling",
      "steps": [
        "Provision Azure AI Foundry resource and deploy model",
        "Configure authentication (managed identity or API key)",
        "Implement Foundry client in backend",
        "Enable streaming responses from model",
        "Implement tool/function calling schema",
        "Create tool handlers in backend (functions executed when model calls tools)",
        "Stream model responses directly to SSE clients",
        "Handle partial tokens and end-of-stream events"
      ],
      "deliverables": [
        "Backend successfully streams model responses",
        "Tool calling working end-to-end",
        "Stable streaming pipeline"
      ]
    },
    {
      "name": "Phase 4 - Frontend SPA",
      "objective": "Build UI with authentication and real-time streaming chat",
      "steps": [
        "Initialize SPA (React, Vue, or similar)",
        "Integrate MSAL for Entra ID authentication (PKCE flow)",
        "Acquire access token for backend API",
        "Attach token to API requests (Authorization: Bearer)",
        "Implement chat UI",
        "Connect to SSE endpoint using EventSource",
        "Render streaming responses incrementally",
        "Handle reconnects and errors",
        "Conditionally render UI based on RBAC roles"
      ],
      "deliverables": [
        "User login/logout flow",
        "Authenticated API calls",
        "Streaming chat interface"
      ]
    },
    {
      "name": "Phase 5 - Infrastructure as Code and Deployment",
      "objective": "Define infrastructure with Bicep and automate deployment with PowerShell scripts",
      "status": "IN PROGRESS",
      "directory_structure": {
        "infrastructure/": "Bicep templates for Azure resources",
        "scripts/": "PowerShell deployment scripts"
      },
      "steps": [
        "Create infrastructure/ directory for Bicep files",
        "Create main.bicep (orchestrates all resources)",
        "Create staticWebApp.bicep (Azure Static Web Apps for frontend)",
        "Create appService.bicep (Azure App Service for backend)",
        "Create aiFoundry.bicep (Azure AI Foundry resource)",
        "Create managedIdentity.bicep (for backend to access Foundry)",
        "Create parameters files (parameters.dev.json, parameters.prod.json)",
        "Create scripts/ directory for PowerShell deployment scripts",
        "Create deploy.ps1 (main deployment orchestration script)",
        "Create validate.ps1 (validates Bicep templates)",
        "Create teardown.ps1 (removes resources for cleanup)",
        "Add environment-specific configuration (dev/prod)",
        "Configure CORS, HTTPS, and custom domains in Bicep",
        "Set up managed identity assignments and RBAC in Bicep",
        "Document deployment process in README"
      ],
      "deliverables": [
        "Complete Bicep infrastructure templates",
        "PowerShell deployment scripts for dev and prod",
        "Parameterized configurations for multiple environments",
        "Repeatable, automated deployment process"
      ],
      "bicep_files": [
        "main.bicep - Main orchestration template",
        "modules/staticWebApp.bicep - Frontend hosting",
        "modules/appService.bicep - Backend API hosting",
        "modules/aiFoundry.bicep - AI Foundry resource",
        "modules/managedIdentity.bicep - Identity and RBAC",
        "parameters.dev.json - Development environment config",
        "parameters.prod.json - Production environment config"
      ],
      "powershell_scripts": [
        "deploy.ps1 - Main deployment script with environment selection",
        "validate.ps1 - Template validation and what-if analysis",
        "teardown.ps1 - Resource cleanup script"
      ]
    },
    {
      "name": "Phase 6 - Observability and Monitoring",
      "objective": "Ensure visibility into system behavior and errors",
      "steps": [
        "Integrate Application Insights in backend",
        "Log request traces, errors, and streaming lifecycle events",
        "Add correlation IDs across requests",
        "Track latency for model responses",
        "Set up alerts for failures and high error rates",
        "Optionally log tool execution metrics"
      ],
      "deliverables": [
        "Centralized logging",
        "Monitoring dashboards",
        "Alerting configured"
      ]
    },
    {
      "name": "Phase 7 - CI/CD",
      "objective": "Automate build and deployment",
      "steps": [
        "Create GitHub repository structure (frontend/backend separation)",
        "Configure GitHub Actions for frontend build and deploy",
        "Configure GitHub Actions for backend build and deploy",
        "Add environment-specific configurations (dev/prod)",
        "Add secrets management (GitHub Secrets)",
        "Implement deployment validation checks"
      ],
      "deliverables": [
        "Automated deployments",
        "Consistent build pipeline",
        "Environment separation"
      ]
    }
  ],
  "key_decisions": {
    "auth_flow": "SPA authenticates via Entra ID and sends JWT to backend",
    "token_validation": "Handled exclusively in backend",
    "streaming_protocol": "SSE (unidirectional, simpler than WebSockets)",
    "ai_integration_pattern": "Backend acts as proxy to Foundry",
    "state_management": "Stateless (no persistence)",
    "security_boundary": "Backend is the only trusted component interacting with Foundry"
  },
  "risks_and_mitigations": [
    {
      "risk": "SSE connection drops",
      "mitigation": "Implement retry logic in frontend and heartbeat events in backend"
    },
    {
      "risk": "Token expiration during streaming",
      "mitigation": "Validate token at connection start; keep streams short-lived"
    },
    {
      "risk": "Tool execution latency",
      "mitigation": "Stream intermediate responses and optimize tool handlers"
    },
    {
      "risk": "CORS misconfiguration",
      "mitigation": "Explicitly configure allowed origins and headers"
    }
  ]
}