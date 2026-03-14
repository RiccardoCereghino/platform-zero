# Platform Zero — Architecture

## Three-Tier Architecture

The system implements a three-tier architecture that separates infrastructure provisioning, platform services, and end-user applications into distinct layers with different deployment models and lifecycles.

```mermaid
graph TB
    subgraph "Tier 1: Infrastructure Layer"
        TF["OpenTofu/Terraform<br/>(infrastructure/)"]
        TF -->|"tofu apply"| HC["Hetzner Cloud<br/>Servers, Networks, Volumes"]
        HC -->|"provisions"| TALOS["Talos Linux Cluster<br/>1 Control Plane + 2 Workers"]
        TALOS -->|"embeds"| EMBED["Embedded Components<br/>Cilium CNI, Hetzner CCM/CSI,<br/>metrics-server"]
    end

    subgraph "Tier 2: Platform Layer"
        GIT["Git Repository<br/>platform/"] -->|"GitOps pull<br/>(3-minute poll)"| ARGO["ArgoCD<br/>GitOps Controller"]
        ARGO -->|"deploys"| PLAT["Platform Services<br/>cert-manager, external-dns,<br/>dex, oauth2-proxy,<br/>kube-prometheus-stack, velero"]
    end

    subgraph "Tier 3: Application Layer"
        APPS["Application Manifests<br/>platform/argocd-apps/"] -->|"defines"| DEPLOYED["Deployed Applications<br/>vaultwarden, coraza-waf"]
    end

    TALOS -->|"hosts"| ARGO
    ARGO -->|"deploys"| DEPLOYED
```

## Infrastructure Components

```mermaid
graph TB
    subgraph "infrastructure/ Directory"
        TFVARS["terraform.tfvars<br/>Configuration values"] -->|"inputs to"| MAIN["*.tf files<br/>Hetzner resources"]
        TEMPLATES["templates/<br/>Talos shell scripts"]
        PACKER["packer/<br/>Image definitions"]
    end

    MAIN -->|"creates"| NET["hcloud_network<br/>10.0.0.0/16"]
    NET -->|"contains"| SUBNET["hcloud_network_subnet<br/>10.0.64.0/25"]
    MAIN -->|"creates"| CP["hcloud_server<br/>CP: CPX22 (2 vCPU, 4GB)"]
    MAIN -->|"creates"| WORKERS["hcloud_server<br/>Workers: CPX22 (2 vCPU, 4GB)"]
    MAIN -->|"creates"| VOL["hcloud_volume<br/>LUKS encrypted"]

    CP -->|"bootstraps"| CLUSTER["Talos Kubernetes Cluster"]
    WORKERS -->|"joins"| CLUSTER
```

## GitOps with ArgoCD

```mermaid
graph TB
    subgraph "Git Repository (Source of Truth)"
        HF["platform/helmfile.yaml<br/>Helm chart definitions + values"]
        KS["platform/kustomization.yaml<br/>Resource orchestration"]
        AA["platform/argocd-apps/<br/>Application manifests"]
        SEC["platform/*-secrets.yaml<br/>SOPS+age encrypted"]
        HF -->|"values mirrored in"| AA
    end

    subgraph "ArgoCD (GitOps Engine)"
        REPO["argocd-repo-server<br/>+ KSOPS init container"]
        CTRL["argocd-application-controller<br/>Sync orchestration"]
        SRV["argocd-server<br/>UI + API"]
    end

    AA -->|"kubectl apply<br/>(manual bootstrap)"| CTRL
    CTRL -->|"git pull<br/>(3-minute poll)"| KS

    subgraph "Deployed Platform Services"
        PM["platform-manifests App<br/>Kustomize + KSOPS"]
        PROM["kube-prometheus-stack App<br/>Helm"]
        CERT["cert-manager App<br/>Helm"]
        EDNS["external-dns App<br/>Helm"]
        DEX["dex App<br/>Helm"]
        VW["vaultwarden App<br/>Helm"]
        O2P["oauth2-proxy App<br/>Helm"]
        VEL["velero App<br/>Helm"]
        WAF["waf App<br/>Helm"]
    end

    REPO -->|"decrypts"| SEC
    CTRL -->|"syncs"| PM
    CTRL -->|"syncs"| PROM
    CTRL -->|"syncs"| CERT
    CTRL -->|"syncs"| EDNS
    CTRL -->|"syncs"| DEX
    CTRL -->|"syncs"| VW
    CTRL -->|"syncs"| O2P
    CTRL -->|"syncs"| VEL
    CTRL -->|"syncs"| WAF
```

## Application Dependencies

```mermaid
graph TB
    subgraph "Platform Dependencies"
        CERT["cert-manager<br/>TLS certificates"]
        EDNS["external-dns<br/>DNS records"]
        AUTH["dex + oauth2-proxy<br/>Authentication"]
        CSI["Hetzner CSI<br/>LUKS volumes"]
        GW["Gateway API<br/>HTTPRoute routing"]
    end

    subgraph "Application Deployments"
        VW["vaultwarden Application<br/>platform/argocd-apps/vaultwarden.yaml"]
        WAF["waf Application<br/>platform/argocd-apps/waf.yaml"]
    end

    VW -->|"uses"| CERT
    VW -->|"uses"| EDNS
    VW -->|"uses"| CSI
    VW -->|"uses"| GW
    WAF -->|"protected by"| AUTH
    WAF -->|"uses"| GW
```

## Infrastructure CI/CD Flow

```mermaid
sequenceDiagram
    participant DEV as Developer
    participant GH as GitHub Actions (CI/CD)
    participant TF as OpenTofu CLI
    participant HZ as Hetzner Cloud API
    participant TALOS as Talos Linux
    participant K8S as Kubernetes API

    rect rgb(40, 40, 60)
    note over DEV, K8S: Pull Request (Validation Only)
    DEV->>GH: Push to PR branch (infrastructure/**)
    GH->>TF: tofu fmt -check
    GH->>TF: tofu init
    GH->>TF: tofu validate
    GH->>TF: tofu plan
    GH->>DEV: Post plan to PR comment
    end

    rect rgb(40, 60, 40)
    note over DEV, K8S: Merge to Master (Auto-Deploy)
    DEV->>GH: Merge PR to master
    GH->>TF: tofu apply -auto-approve
    TF->>HZ: Create/update servers, networks
    TF->>TALOS: Generate machine configs
    TALOS->>K8S: Bootstrap cluster
    K8S-->>TF: Cluster operational
    TF->>K8S: Create sops-age-key Secret (Talos inline manifest)
    end
```

## Platform CI/CD Flow

```mermaid
sequenceDiagram
    participant DEV as Developer
    participant CI as GitHub Actions (Platform CI)
    participant GIT as Git Repository (master branch)
    participant ARGO as ArgoCD Controller
    participant KSOPS as KSOPS Plugin
    participant K8S as Kubernetes API

    rect rgb(40, 40, 60)
    note over DEV, K8S: Pull Request (Validation Only)
    DEV->>CI: Push to PR branch (platform/**)
    CI->>CI: yamllint platform/
    CI->>CI: helmfile lint
    CI->>CI: helmfile template | kubeconform
    end

    rect rgb(40, 60, 40)
    note over DEV, K8S: Merge to Master (GitOps Sync)
    DEV->>GIT: Merge PR to master
    ARGO->>GIT: Poll every 3 minutes
    ARGO->>ARGO: Detect changes
    ARGO->>KSOPS: Decrypt *-secrets.yaml
    KSOPS->>K8S: Use sops-age-key Secret
    ARGO->>K8S: Apply manifests (sync + self-heal + prune)
    end
```

## Directory Structure

```mermaid
graph LR
    subgraph "Repository Root"
        subgraph "Infrastructure Tier"
            INFRA["infrastructure/<br/>OpenTofu configs"]
            TF_FILES["*.tf files<br/>Resource definitions"]
            TFVARS["terraform.tfvars<br/>Configuration values"]
            TMPL["templates/<br/>Talos shell scripts"]
            PKR["packer/<br/>Image definitions"]
        end

        subgraph "Platform Tier"
            PLAT["platform/<br/>GitOps configs"]
            HELMFILE["helmfile.yaml<br/>Helm releases"]
            KUST["kustomization.yaml<br/>Kustomize orchestration"]
            ARGOCD_APPS["argocd-apps/<br/>Application manifests"]
            ARGOCD_VALS["argocd-values.yaml<br/>ArgoCD config"]
            SECRETS["*-secrets.yaml<br/>SOPS encrypted"]
            WAF_CHART["waf-chart/<br/>Custom Helm chart"]
        end

        subgraph "Supporting Directories"
            SCRIPTS["scripts/<br/>Utility scripts"]
            GH_WORKFLOWS[".github/workflows/<br/>CI/CD pipelines"]
        end
    end
```
