Overview
Data Flow Diagram:
Salesforce Webhook Event → Azure Function (Provisioning-API) → Azure Service Bus → Azure Function (License-Worker) → Microsoft Graph API → Dynamics CRM
This document provides detailed instructions for replacing the Microsoft Identity Manager (MIM) system with a direct license assignment solution using Salesforce and Microsoft Graph API for Dynamics CRM. The new solution removes the dependency on MIM, directly integrating Salesforce user events with Microsoft Graph API, significantly reducing license assignment delays from up to 4 hours to within 15 minutes.

Current Challenges
•	Complex workflow with multiple synchronization steps causing delays.
•	License assignment delays affecting user productivity.
•	High maintenance efforts requiring specialized knowledge.
•	Troubleshooting complexity due to middleware involvement.
These limitations of MIM lead to user inconvenience, reduced operational efficiency, and challenges in resolving license assignment issues quickly.

Best and Alternate Approaches
Best Approach (Event-Driven)
Workflow: Salesforce Webhook → Custom Application → Azure Service Bus → Microsoft Graph API → Dynamics CRM License Assigned
•	Real-time license assignment triggered by Salesforce webhook events.
•	Robust error handling and retry mechanisms.
•	Comprehensive logging and alerting.
•	Scalable, easily maintainable architecture.
Alternate Approach (Polling)
Workflow: Scheduled Polling Service → Custom Application → Microsoft Graph API → Dynamics CRM License Assigned
•	Scheduled data synchronization from Salesforce.
•	Moderate complexity.
•	Suitable for lower volumes and less dynamic environments.

Architecture Overview
Flow:
Salesforce Webhook → Azure Function (HTTP "Provisioning-API") → Azure Service Bus Topic (crm-license-requests) → Azure Function (Service Bus "License-Worker") → Microsoft Graph API → Azure Active Directory → Dynamics 365 CRM

Component Details
1.	Salesforce Webhook
o	Purpose: Triggers when a user is marked ready for a license.
o	Trigger: Fires on user-ready events in Salesforce.
o	Payload: Sends signed JSON containing user details.
o	Security: Validates payloads with webhook signatures.
2.	Provisioning-API (Azure Function - HTTP Trigger)
o	Runtime: Azure Functions (HTTP trigger).
o	Responsibilities:
	Validate incoming webhook signatures.
	Append a correlation ID for tracking.
	Enqueue messages to the crm-license-requests Service Bus topic.
o	Error Handling: Returns appropriate HTTP status codes.
o	Logging: Uses structured logs with correlation IDs.
3.	Azure Service Bus Topic: crm-license-requests
o	Purpose: Buffers messages and decouples components.
o	Features:
	Main subscription for processing.
	Dead-letter queue for failed messages.
	Message deduplication to prevent duplicates.
o	Scaling: Handles burst traffic automatically.
4.	License-Worker (Azure Function - Service Bus Trigger)
o	Runtime: Azure Functions (Service Bus trigger).
o	Responsibilities:
	Read messages from the topic.
	Map user attributes to Dynamics 365 SKU codes.
	Call Microsoft Graph API to assign licenses.
o	Authentication: Uses a managed identity to authenticate with Graph API.
o	Retry Logic: Leverages built-in Service Bus retry policies.
5.	Microsoft Graph API Integration
o	Endpoint: POST /users/{id}/assignLicense.
o	Authentication: Uses the function's managed identity.
o	Operations: License assignment and entitlement management.
o	Error Handling: Handles Graph API error codes and surfaces meaningful messages.
6.	Azure Active Directory (AAD)
o	Function: Manages license records and user entitlements.
o	Features: Native group and role mappings, compliance tracking.
7.	Dynamics 365 CRM
o	Result: Users gain immediate access with correct licenses.
o	Integration: SSO via Azure AD and support for various SKU types.

Salesforce Data Mapping & Integration
User Attribute Mapping
•	Source Fields: The following Salesforce fields determine license eligibility:
o	User.Department – Maps to license type requirements
o	User.Role – Determines specific Dynamics 365 modules needed
o	User.Custom_License_Level__c – Custom field indicating license tier
o	User.IsActive – Controls license assignment/revocation
o	User.CRM_Access_Required__c – Boolean field triggering license workflow
Webhook Configuration
•	Event Types:
o	User.Created – Triggers initial license assessment
o	User.Updated – Re-evaluates license requirements when relevant fields change
o	User.Custom_Status_Change – Custom event for license-specific updates
License Determination Logic
•	Business Rules Engine:
o	Maps Salesforce role hierarchies to Dynamics 365 license SKUs
o	Applies department-specific license templates
o	Handles special cases (contractors, temporary access, regional variations)
o	Supports license upgrades/downgrades based on role changes

Custom Application Details
•	Runtime: .NET 8 or Node.js 20
•	Provisioning-API Function: Validates, enriches, and enqueues events.
•	License-Worker Function: Processes queue messages and invokes Graph API.
•	Security: Uses managed identity with minimal Graph permissions (User.ReadWrite.All) and Service Bus RBAC.
•	Error Handling: Built-in retry policies and dead-letter queue for manual review.

Technical Dependencies & Prerequisites
System Requirements
•	Azure Subscription with permissions to create:
o	Azure Functions (consumption or premium plan)
o	Azure Service Bus (standard tier minimum)
o	Key Vault for secret management
Authentication Prerequisites
•	Microsoft Graph API Access:
o	Azure AD application registration with admin consent for required permissions
o	Certificate-based or managed identity authentication configured
o	License administration roles assigned to service principal
Salesforce Requirements
•	API Access: Enterprise or Unlimited edition with API access enabled
•	Connected App: Configured with appropriate OAuth scopes
•	Event Monitoring: Enabled for webhook event triggers
•	Custom Fields: Implementation of required tracking fields if not present
•	Permission Sets: API integration user with correct object permissions
Networking
•	Connectivity: Ensure Azure can reach Microsoft Graph endpoints
•	IP Allowlisting: Configure Salesforce IP ranges for webhook callbacks
•	DNS Resolution: Proper name resolution for all service endpoints
Operational
•	Monitoring Tools: Azure Application Insights or equivalent
•	Alert Configuration: Email or Teams notification channels
•	Support Access: Appropriate RBAC for support personnel

Key Requirements
Functional Requirements
•	Direct Salesforce integration for real-time user data.
•	Immediate Dynamics CRM license assignment.
•	Efficient bulk operations capability.
•	Detailed audit logging for compliance.
Technical Specifications
•	Integration via Microsoft Graph API for licensing.
•	Salesforce API integration (REST API and Webhooks).
•	Secure Azure AD application registration.
•	Structured error handling with retry logic.
•	Monitoring via Azure Application Insights.

Detailed Implementation Plan
Phase 1: Proof of Concept
•	Register Azure AD application:
o	Navigate Azure Portal → App Registrations → New Registration.
o	Set permissions clearly based on Graph API requirements (User.ReadWrite.All, Directory.ReadWrite.All).
•	Validate Microsoft Graph API:
o	Develop a test script using PowerShell or Python.
o	Assign licenses to 1–2 users to confirm functionality.
•	Salesforce Integration:
o	Establish Salesforce sandbox.
o	Configure Salesforce webhooks for event-driven updates.
•	Document outcomes and recommendations.
Phase 2: Development
•	License Assignment Engine:
o	Implement license assignment via Graph API.
o	Trigger assignments based on Salesforce webhook events.
•	Salesforce Integration:
o	Secure webhook endpoints using OAuth2 authentication.
•	Error Management:
o	Automated retry logic with exponential backoff.
o	Detailed error logging.
•	Monitoring and Alerts:
o	Azure Application Insights integration for real-time metrics.
o	Set automated alerts for exceptions or failures.
•	Configuration Management:
o	Configurable system for dynamic license assignment rules.
Phase 3: Testing & Deployment
•	Comprehensive unit and integration testing.
•	Performance load testing.
•	Phased, controlled deployment.
•	Continuous performance monitoring and optimization.
•	Detailed operational manuals and user training.
Phase 4: MIM Decommissioning
•	Run both systems in parallel for a short period.
•	Compare outcomes and disable MIM workflows once stable.
