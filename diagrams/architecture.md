# Architecture Diagram

The diagram below shows the end-to-end data flow from Azure resource telemetry through Microsoft Sentinel's detection and response pipeline.

```mermaid
flowchart TB
    subgraph Sources ["Azure Resources (Telemetry Sources)"]
        VM["🖥️ Linux VM<br/>Honeypot"]
        NSG["🔒 Network Security<br/>Group"]
        STOR["📦 Storage<br/>Account"]
        AAD["🔑 Azure AD<br/>(Entra ID)"]
        SUB["📋 Subscription<br/>Activity"]
        AKS["☸️ AKS Cluster<br/>(Optional)"]
    end

    subgraph Ingestion ["Data Ingestion Layer"]
        DIAG["📡 Diagnostic<br/>Settings"]
        DC["🔌 Data<br/>Connectors"]
    end

    subgraph Analytics ["Microsoft Sentinel Platform"]
        LAW["📊 Log Analytics<br/>Workspace"]
        AR["⚡ Analytics Rules<br/>(KQL Queries)"]
        ALERTS["🔔 Alerts"]
        INC["🎫 Incidents"]
        WB["📈 Workbooks<br/>(Dashboards)"]
    end

    subgraph Response ["Automated Response"]
        LA["🤖 Logic App<br/>Playbook"]
        EMAIL["📧 Email<br/>Notification"]
    end

    subgraph Governance ["Governance & Compliance"]
        POLICY["📜 Azure Policy"]
        DEFENDER["🛡️ Defender for<br/>Cloud"]
        BUDGET["💰 Consumption<br/>Budget"]
    end

    %% Telemetry flows into Diagnostic Settings
    VM -- "Heartbeat, Perf Metrics" --> DIAG
    NSG -- "NSG Flow Logs,<br/>Security Events" --> DIAG
    STOR -- "Storage Analytics,<br/>Blob Audit Logs" --> DIAG
    SUB -- "Activity Logs<br/>(Admin, Security, Policy)" --> DIAG
    AKS -. "Container Logs,<br/>Kube Audit" .-> DIAG

    %% Azure AD uses Data Connectors
    AAD -- "Sign-in Logs,<br/>Audit Logs" --> DC

    %% Ingestion into Log Analytics
    DIAG -- "Streams to" --> LAW
    DC -- "Streams to" --> LAW

    %% Sentinel analytics pipeline
    LAW -- "KQL queries run<br/>on schedule" --> AR
    AR -- "Threshold exceeded" --> ALERTS
    ALERTS -- "Correlated into" --> INC

    %% Workbook reads directly from LAW
    LAW -- "Visualizations" --> WB

    %% Incident response
    INC -- "Triggers automation" --> LA
    LA -- "Sends alert" --> EMAIL
    LA -. "Tags incident:<br/>AutoTagged=true" .-> INC

    %% Governance evaluation
    POLICY -. "Evaluates compliance<br/>on all resources" .-> Sources
    DEFENDER -. "Security recommendations<br/>& threat detection" .-> LAW
    BUDGET -. "Cost alerts at<br/>80% threshold" .-> EMAIL

    %% Styling
    classDef source fill:#1a1a2e,stroke:#e94560,color:#fff,stroke-width:2px
    classDef ingest fill:#16213e,stroke:#0f3460,color:#fff,stroke-width:2px
    classDef sentinel fill:#0f3460,stroke:#533483,color:#fff,stroke-width:2px
    classDef response fill:#533483,stroke:#e94560,color:#fff,stroke-width:2px
    classDef govern fill:#2d3436,stroke:#00b894,color:#fff,stroke-width:2px

    class VM,NSG,STOR,AAD,SUB,AKS source
    class DIAG,DC ingest
    class LAW,AR,ALERTS,INC,WB sentinel
    class LA,EMAIL response
    class POLICY,DEFENDER,BUDGET govern
```

## Data Flow Summary

| Step | Source | Destination | Data Type |
|------|--------|-------------|-----------|
| 1 | Linux VM | Diagnostic Settings | Heartbeat, Performance Metrics |
| 2 | NSG | Diagnostic Settings | Flow Logs, Security Events |
| 3 | Storage Account | Diagnostic Settings | Blob Audit Logs |
| 4 | Subscription | Diagnostic Settings | Activity Logs (Admin, Security, Policy) |
| 5 | Azure AD (Entra ID) | Sentinel Data Connector | Sign-in Logs, Audit Logs |
| 6 | Diagnostic Settings | Log Analytics Workspace | All telemetry streams |
| 7 | Log Analytics | Analytics Rules | Scheduled KQL queries |
| 8 | Analytics Rules | Alerts → Incidents | Threshold-based detections |
| 9 | Incidents | Logic App Playbook | Automated tagging + email |
| 10 | Azure Policy | All Resources | Compliance evaluation |
| 11 | Defender for Cloud | Log Analytics | Security recommendations |
