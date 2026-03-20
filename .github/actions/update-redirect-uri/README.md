# Update Azure AD Redirect URI Action

This action automatically updates the redirect URI for an Azure AD app registration during deployment.

## Purpose

When deploying to Azure Static Web Apps, the URL may change (especially for PR environments). This action ensures the Azure AD app registration's redirect URIs are automatically updated to match the deployed frontend URL, preventing authentication errors like:

```
AADSTS50011: The redirect URI specified in the request does not match the redirect URIs configured for the application
```

## Inputs

- `app_client_id` (required): The Azure AD App Registration client ID
- `redirect_uri` (required): The redirect URI to add (e.g., https://your-app.azurestaticapps.net)

## Required Permissions

The service principal used for deployment must have the following Microsoft Graph API permissions:

### Application Permissions Required

1. **Application.ReadWrite.All** - Allows the app to create, read, update and delete applications and service principals

### Setting Up Permissions

1. Go to Azure Portal → Azure Active Directory → App registrations
2. Find your deployment service principal (the one with `AZURE_CLIENT_ID`)
3. Navigate to **API permissions**
4. Click **Add a permission** → **Microsoft Graph** → **Application permissions**
5. Search for and add: `Application.ReadWrite.All`
6. Click **Grant admin consent** (requires Global Administrator role)

### Alternative: Using Azure CLI

```bash
# Get the service principal object ID
SP_OBJECT_ID=$(az ad sp show --id <AZURE_CLIENT_ID> --query id -o tsv)

# Assign the Application.ReadWrite.All permission
az ad app permission add \
  --id <AZURE_CLIENT_ID> \
  --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role

# Grant admin consent
az ad app permission admin-consent --id <AZURE_CLIENT_ID>
```

## Usage

```yaml
- name: Update Redirect URI
  uses: ./.github/actions/update-redirect-uri
  with:
    app_client_id: ${{ secrets.SPA_CLIENT_ID }}
    redirect_uri: ${{ needs.infrastructure.outputs.frontend_url }}
```

## How It Works

1. Retrieves current SPA redirect URIs from the app registration
2. Checks if the new URI already exists
3. If not present, adds the new URI to the app registration
4. Verifies the update was successful

## Notes

- This action preserves existing redirect URIs
- It only adds the URI if it doesn't already exist (idempotent)
- Designed for SPA (Single Page Application) redirect URIs
- Requires Azure CLI to be available and authenticated
