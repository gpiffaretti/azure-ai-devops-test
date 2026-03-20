# GitHub Workflows CI/CD Plan

## Overview
This plan outlines the implementation of GitHub Actions workflows for automated deployment of the Azure AI Chatbot application across development and production environments.

## Workflow Structure

### 1. Main Branch Workflow (Production)
**Trigger**: Push to `main` branch  
**Environment**: Production  
**Resource Group**: `rg-azure-chatbot-prod`  
**Suffix**: `-prod`

### 2. Development Branch Workflow (Staging)
**Trigger**: Push to `development` branch  
**Environment**: Development  
**Resource Group**: `rg-azure-chatbot-dev`  
**Suffix**: `-dev`

### 3. PR Environment Deployment Workflow
**Trigger**: Pull request labeled with `deploy-env`  
**Environment**: Dynamic (based on branch name)  
**Resource Group**: `rg-azure-chatbot-{branch-name}`  
**Suffix**: `-{branch-name}`

**Features**:
- **Dynamic Environment Creation**: Uses PR branch name as environment suffix
- **Temporary Infrastructure**: Creates isolated environment for testing
- **Automatic Cleanup**: Optional cleanup when PR is merged/closed
- **Resource Naming**: `rg-azure-chatbot-{branch-name}`, `{branch-name}` suffix for all resources

**Use Cases**:
- Feature testing in isolated environments
- Staging environment for PR validation
- Integration testing with real resources
- Performance testing in production-like setup

## Workflow Architecture

### File Structure
```
.github/
├── workflows/
│   ├── deploy-main.yml          # Production deployment
│   ├── deploy-development.yml   # Development deployment
│   ├── deploy-pr-env.yml        # PR environment deployment
│   └── infrastructure.yml      # Reusable infrastructure deployment
├── actions/
│   ├── deploy-infrastructure/   # Custom action for infra deployment
│   ├── deploy-backend/         # Custom action for backend deployment
│   └── deploy-frontend/        # Custom action for frontend deployment
```

## Workflow Components

### 1. Infrastructure Deployment Stage
**File**: `.github/workflows/infrastructure.yml` (reusable workflow)

**Features**:
- **What-if Analysis**: Runs `az deployment group what-if` to detect changes
- **Change Detection**: Compares current infrastructure state with proposed changes
- **Notification System**: Sends email/notification if changes detected
- **Conditional Deployment**: Only proceeds if changes detected or forced

**Steps**:
1. Checkout code
2. Azure login using service principal
3. Run what-if analysis
4. Parse what-if results for changes
5. Send notification if changes detected
6. Deploy infrastructure (if changes detected)
7. Export deployment outputs

**Security**:
- Service principal with minimal permissions
- Secrets stored in GitHub Secrets
- No sensitive data in logs

### 2. Backend Deployment Stage
**Target**: Azure Container Apps via ACR

**Steps**:
1. Build Docker image
2. Push to Azure Container Registry
3. Update Container App with new image
4. Wait for deployment completion
5. Health check validation

**Environment Variables**:
- `ACR_NAME`: From infrastructure outputs
- `CONTAINER_APP_NAME`: From infrastructure outputs
- `BACKEND_URL`: From infrastructure outputs

### 3. Frontend Deployment Stage
**Target**: Azure Static Web Apps

**Steps**:
1. Install dependencies
2. Build with production API URL
3. Fetch SWA deployment token (securely)
4. Deploy using SWA CLI
5. Validate deployment

**Security Measures**:
- SWA token fetched at runtime
- Token masked in logs
- No hardcoded secrets

## Environment Configuration

### Resource Naming Convention
| Workflow | Resource Group | Environment | Suffix |
|----------|----------------|------------|--------|
| Main | `rg-azure-chatbot-prod` | prod | `-prod` |
| Development | `rg-azure-chatbot-dev` | dev | `-dev` |
| PR Environment | `rg-azure-chatbot-{branch}` | {branch} | `-{branch}` |

### Dynamic Environment Configuration
For PR environments, the branch name is sanitized to create valid resource names:
- **Branch**: `feature/new-ui` → **Environment**: `feature-new-ui`
- **Branch**: `bugfix/auth-issue` → **Environment**: `bugfix-auth-issue`
- **Branch**: `hotfix/critical-patch` → **Environment**: `hotfix-critical-patch`

### Parameter Files
- **Dev**: `infrastructure/parameters.dev.json`
- **Prod**: `infrastructure/parameters.prod.json`
- **PR Env**: Generated dynamically from base parameters

### Environment-specific Configurations
| Parameter | Dev Value | Prod Value | PR Env Value |
|-----------|-----------|------------|--------------|
| environment | dev | prod | {branch-name} |
| staticWebAppSku | Free | Standard | Free |
| aiModelCapacity | 30 | 80 | 30 |

## Required GitHub Secrets

### Azure Authentication
- `AZURE_CLIENT_ID`: Service principal client ID
- `AZURE_CLIENT_SECRET`: Service principal client secret
- `AZURE_TENANT_ID`: Azure tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID

### Application Configuration
- `BACKEND_CLIENT_ID`: Backend app registration client ID
- `SPA_CLIENT_ID`: SPA app registration client ID

### Notification Configuration
- `NOTIFICATION_EMAIL`: Email for infrastructure change notifications
- `SENDGRID_API_KEY`: (Optional) For email notifications

## What-if Implementation

### Change Detection Process
1. Run `az deployment group what-if` with `--no-pretty-print`
2. Parse JSON output for change types:
   - `Create`: New resources
   - `Delete`: Removed resources
   - `Modify`: Changed resources
   - `NoChange`: No modifications

### Notification Logic
```yaml
- name: Check for infrastructure changes
  id: whatif
  run: |
    changes=$(az deployment group what-if \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --template-file infrastructure/main.bicep \
      --parameters @infrastructure/parameters.${{ env.ENVIRONMENT }}.json \
      --no-pretty-print \
      --query "properties.changes[?changeType!='NoChange']")
    
    if [ -n "$changes" ]; then
      echo "has_changes=true" >> $GITHUB_OUTPUT
      echo "changes=$changes" >> $GITHUB_OUTPUT
    else
      echo "has_changes=false" >> $GITHUB_OUTPUT
    fi
```

### Notification Content
- Summary of changes detected
- Resources affected
- Change types (Create/Modify/Delete)
- Link to deployment run

## Security Considerations

### Secret Management
- All sensitive data in GitHub Secrets
- No hardcoded credentials in workflows
- Service principal with least privilege

### Logging Security
- SWA deployment tokens masked
- Azure CLI outputs filtered for secrets
- No parameter values echoed in logs

### Access Control
- Branch protection rules
- Required approvals for production deployments
- Environment-specific permissions

## Workflow Triggers

### Main Branch (Production)
```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      force_infra:
        description: 'Force infrastructure deployment'
        required: false
        default: false
        type: boolean
```

### Development Branch (Staging)
```yaml
on:
  push:
    branches: [development]
  workflow_dispatch:
    inputs:
      force_infra:
        description: 'Force infrastructure deployment'
        required: false
        default: false
        type: boolean
```

### PR Environment Deployment
```yaml
on:
  pull_request:
    types: [labeled, closed]
  workflow_dispatch:
    inputs:
      branch_name:
        description: 'Branch name for environment'
        required: true
        type: string
      cleanup:
        description: 'Cleanup environment'
        required: false
        default: false
        type: boolean
```

**Trigger Conditions**:
- PR labeled with `deploy-env` → Create environment
- PR closed/merged (with `deploy-env` label) → Cleanup environment
- Manual workflow dispatch for testing/cleanup

## Deployment Strategy

### Infrastructure-First Approach
1. Infrastructure deployment (with what-if analysis)
2. Backend deployment to Container Apps
3. Frontend deployment to Static Web Apps

### Rollback Strategy
- Previous container image tags maintained in ACR
- SWA supports rollback to previous deployment
- Infrastructure changes tracked via deployment history
- PR environments can be completely destroyed and recreated

### PR Environment Lifecycle
1. **Creation**: PR labeled with `deploy-env` triggers infrastructure deployment
2. **Deployment**: Full application deployment to new environment
3. **Testing**: Automated tests and manual validation in isolated environment
4. **Cleanup**: Automatic resource group deletion when PR is merged/closed
5. **Manual Control**: Option to keep environment for extended testing

### Validation Steps
1. Infrastructure deployment validation
2. Backend health checks
3. Frontend accessibility tests
4. End-to-end integration tests

## Monitoring and Alerting

### Deployment Monitoring
- GitHub Actions workflow status
- Azure resource deployment status
- Application health metrics

### Alerting Configuration
- Failed deployment notifications
- Infrastructure change alerts
- Performance degradation alerts

## Migration from Current Deployment Scripts

### Current Scripts to be Deprecated
The following PowerShell scripts will no longer be needed after implementing GitHub workflows:
- `scripts/deploy.ps1` - Main deployment orchestration
- `scripts/teardown.ps1` - Resource cleanup

### Migration Benefits
1. **Eliminate Manual Execution**: No more local PowerShell script runs
2. **Centralized CI/CD**: All deployment logic in GitHub Actions
3. **Version Control**: Workflow changes tracked in Git history
4. **Consistency**: Same deployment process across all environments
5. **Automation**: Triggered automatically on branch pushes

### Script Functionality Migration
| PowerShell Script | GitHub Actions Equivalent |
|------------------|--------------------------|
| `deploy.ps1 -Environment dev` | `deploy-development.yml` workflow |
| `deploy.ps1 -Environment prod` | `deploy-main.yml` workflow |
| `deploy.ps1 -InfraOnly` | Infrastructure stage in workflows |
| `deploy.ps1 -AppOnly` | Application stages in workflows |
| `teardown.ps1` | Manual Azure portal/CLI operations |
| `deploy.ps1 -Environment custom` | `deploy-pr-env.yml` workflow (dynamic) |

## Implementation Steps

1. **Create service principal** with required permissions
2. **Set up GitHub Secrets** for authentication
3. **Create reusable infrastructure workflow**
4. **Implement main branch workflow**
5. **Implement development branch workflow**
6. **Implement PR environment workflow**
7. **Add what-if analysis and notifications**
8. **Configure branch protection rules**
9. **Test deployment workflows**
10. **Set up monitoring and alerting**
11. **Archive deprecated PowerShell scripts** (move to `scripts/legacy/`)

## Benefits

1. **Automated CI/CD**: Zero-touch deployments
2. **Infrastructure as Code**: Consistent environments
3. **Change Detection**: Proactive infrastructure monitoring
4. **Security**: No hardcoded secrets
5. **Scalability**: Environment-specific configurations
6. **Reliability**: Automated testing and validation
7. **Visibility**: Comprehensive logging and notifications
8. **Script Deprecation**: Eliminate manual PowerShell deployment scripts
9. **Dynamic Environments**: On-demand PR environments for testing
10. **Cost Efficiency**: Automatic cleanup of temporary environments

## Next Steps

1. Create Azure service principal
2. Create an empty Github repository (azure-ai-devops-test)
3. Create `main`, `development`, and `feature/test` branches
4. Configure GitHub repository secrets
5. Implement workflow files
6. Test with development environment
8. Deploy to production after validation
9. Archive current PowerShell scripts to `scripts/legacy/`
8. Test PR environment deployment workflow by pushing to `feature/test`
9. Configure PR label automation and cleanup policies
