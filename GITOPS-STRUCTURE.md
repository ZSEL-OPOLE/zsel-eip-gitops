# GitOps Repository Structure - ZSEL EIP
## 1 Namespace = 1 Aplikacja = 1 Katalog

```
zsel-eip-gitops/
├── README.md
├── GITOPS-STRUCTURE.md (this file)
│
├── apps/
│   ├── argocd-root/                    # WAVE 0: App-of-Apps
│   │   └── application.yaml
│   │
│   ├── sealed-secrets/                 # WAVE 5: Security
│   │   ├── application.yaml
│   │   └── controller/
│   ├── cert-manager/
│   │   ├── application.yaml
│   │   └── helm-values.yaml
│   │
│   ├── metallb/                        # WAVE 10: Core Infrastructure
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── ip-pools.yaml
│   ├── traefik-ingress/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── middleware/
│   ├── coredns/
│   │   ├── application.yaml
│   │   └── custom-zones.yaml
│   ├── freeipa/
│   │   ├── application.yaml
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   └── pvc.yaml
│   ├── keycloak/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── realms/
│   ├── user-ad/
│   │   ├── application.yaml
│   │   └── (managed by Terraform module)
│   ├── network-ad/
│   │   ├── application.yaml
│   │   └── (managed by Terraform module)
│   │
│   ├── prometheus/                     # WAVE 15: Monitoring & Security
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   ├── alertmanager-config.yaml
│   │   └── prometheus-rules/
│   ├── grafana/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── dashboards/
│   ├── loki/
│   │   ├── application.yaml
│   │   └── helm-values.yaml
│   ├── zabbix/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── templates/
│   ├── falco/
│   │   ├── application.yaml
│   │   └── rules/
│   ├── trivy-operator/
│   │   ├── application.yaml
│   │   └── helm-values.yaml
│   ├── opa-gatekeeper/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── policies/
│   ├── wazuh/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── agents/
│   ├── wireguard-vpn/
│   │   ├── application.yaml
│   │   ├── deployment.yaml
│   │   └── peers/
│   ├── suricata/
│   │   ├── application.yaml
│   │   └── rules/
│   │
│   ├── postgresql-ha/                  # WAVE 20: Databases
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── backup-cronjob.yaml
│   ├── mysql-ha/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── backup-cronjob.yaml
│   │
│   ├── moodle/                         # WAVE 25: Education
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── plugins/
│   ├── bigbluebutton/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── scalelite/
│   ├── mattermost/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── plugins/
│   ├── nextcloud/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── apps/
│   ├── onlyoffice/
│   │   ├── application.yaml
│   │   └── helm-values.yaml
│   ├── etherpad/
│   │   ├── application.yaml
│   │   └── helm-values.yaml
│   ├── calibre-web/
│   │   ├── application.yaml
│   │   ├── deployment.yaml
│   │   └── pvc.yaml
│   ├── minio/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── tenants/
│   │
│   ├── gitlab/                         # WAVE 30: DevOps
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   ├── runners/
│   │   └── registry/
│   ├── harbor/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── projects/
│   ├── zammad/
│   │   ├── application.yaml
│   │   └── helm-values.yaml
│   ├── portainer/
│   │   ├── application.yaml
│   │   └── helm-values.yaml
│   ├── longhorn/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── storage-classes/
│   │
│   ├── ollama-llm/                     # WAVE 35: AI & Lab
│   │   ├── application.yaml
│   │   ├── deployment.yaml
│   │   ├── models/
│   │   └── pvc.yaml
│   ├── whisper/
│   │   ├── application.yaml
│   │   └── deployment.yaml
│   ├── qdrant/
│   │   ├── application.yaml
│   │   └── helm-values.yaml
│   ├── kubevirt/
│   │   ├── application.yaml
│   │   ├── operator/
│   │   └── vms/
│   ├── jupyterhub/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── profiles/
│   ├── code-server/
│   │   ├── application.yaml
│   │   ├── deployment.yaml
│   │   └── extensions/
│   ├── esport-servers/
│   │   ├── application.yaml
│   │   ├── minecraft/
│   │   ├── csgo/
│   │   └── valheim/
│   ├── cctv-analytics/
│   │   ├── application.yaml
│   │   ├── deployment.yaml
│   │   └── models/
│   │
│   ├── mailu/                          # WAVE 40: Communication & Web
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── domains/
│   ├── wordpress-zsel/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── themes/
│   ├── wordpress-bcu/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── themes/
│   ├── wordpress-sue/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── themes/
│   ├── wordpress-mrsu/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── themes/
│   ├── wordpress-elektryk/
│   │   ├── application.yaml
│   │   ├── helm-values.yaml
│   │   └── themes/
│   └── wordpress-k4tec/
│       ├── application.yaml
│       ├── helm-values.yaml
│       └── themes/
│
├── sealed-secrets/                     # Encrypted credentials
│   ├── core/
│   │   ├── freeipa-admin.yaml
│   │   ├── keycloak-admin.yaml
│   │   └── ad-passwords.yaml
│   ├── databases/
│   │   ├── postgres-admin.yaml
│   │   └── mysql-admin.yaml
│   ├── education/
│   │   ├── moodle-secrets.yaml
│   │   ├── nextcloud-secrets.yaml
│   │   └── bbb-secrets.yaml
│   ├── devops/
│   │   ├── gitlab-secrets.yaml
│   │   └── harbor-secrets.yaml
│   └── web/
│       ├── wordpress-db-passwords.yaml
│       └── mailu-secrets.yaml
│
├── rbac/                               # RBAC policies per namespace
│   ├── roles/
│   │   ├── namespace-admin.yaml
│   │   ├── namespace-developer.yaml
│   │   └── namespace-viewer.yaml
│   └── rolebindings/
│       ├── edu-moodle-admins.yaml
│       ├── devtools-gitlab-developers.yaml
│       └── (per-namespace bindings...)
│
├── network-policies/                   # Zero Trust policies per namespace
│   ├── default-deny-all.yaml          # Applied to every namespace
│   ├── allow-from-ingress.yaml
│   ├── allow-to-coredns.yaml
│   ├── allow-to-kube-apiserver.yaml
│   ├── edu-moodle-policies.yaml
│   ├── devtools-gitlab-policies.yaml
│   └── (per-namespace policies...)
│
├── kustomize/                          # Overlays for environments
│   ├── base/
│   ├── production/
│   │   └── kustomization.yaml
│   └── staging/
│       └── kustomization.yaml
│
└── docs/
    ├── DEPLOYMENT-ORDER.md
    ├── SEALED-SECRETS-GUIDE.md
    └── RBAC-STRUCTURE.md
```

## Namespace → Application → Directory Mapping

| Namespace | Application | Directory | Sync Wave |
|-----------|-------------|-----------|-----------|
| `argocd` | ArgoCD | `apps/argocd-root/` | 0 |
| `kube-system` | Sealed Secrets | `apps/sealed-secrets/` | 5 |
| `core-certmanager` | Cert Manager | `apps/cert-manager/` | 5 |
| `core-metallb` | MetalLB | `apps/metallb/` | 10 |
| `core-ingress` | Traefik | `apps/traefik-ingress/` | 10 |
| `kube-system` | CoreDNS | `apps/coredns/` | 10 |
| `core-freeipa` | FreeIPA | `apps/freeipa/` | 10 |
| `admin-keycloak` | Keycloak | `apps/keycloak/` | 10 |
| `core-auth` | User AD | `apps/user-ad/` | 10 |
| `core-auth` | Network AD | `apps/network-ad/` | 10 |
| `mon-prometheus` | Prometheus | `apps/prometheus/` | 15 |
| `mon-grafana` | Grafana | `apps/grafana/` | 15 |
| `mon-loki` | Loki | `apps/loki/` | 15 |
| `mon-zabbix` | Zabbix | `apps/zabbix/` | 15 |
| `sec-falco` | Falco | `apps/falco/` | 15 |
| `sec-trivy` | Trivy Operator | `apps/trivy-operator/` | 15 |
| `sec-gatekeeper` | OPA Gatekeeper | `apps/opa-gatekeeper/` | 15 |
| `sec-wazuh` | Wazuh | `apps/wazuh/` | 15 |
| `sec-vpn` | WireGuard | `apps/wireguard-vpn/` | 15 |
| `sec-suricata` | Suricata | `apps/suricata/` | 15 |
| `db-postgres` | PostgreSQL HA | `apps/postgresql-ha/` | 20 |
| `db-mysql` | MySQL HA | `apps/mysql-ha/` | 20 |
| `edu-moodle` | Moodle | `apps/moodle/` | 25 |
| `edu-bbb` | BigBlueButton | `apps/bigbluebutton/` | 25 |
| `edu-mattermost` | Mattermost | `apps/mattermost/` | 25 |
| `edu-nextcloud` | NextCloud | `apps/nextcloud/` | 25 |
| `edu-onlyoffice` | OnlyOffice | `apps/onlyoffice/` | 25 |
| `edu-etherpad` | Etherpad | `apps/etherpad/` | 25 |
| `edu-library` | Calibre-Web | `apps/calibre-web/` | 25 |
| `edu-minio` | MinIO | `apps/minio/` | 25 |
| `devtools-gitlab` | GitLab | `apps/gitlab/` | 30 |
| `devtools-harbor` | Harbor | `apps/harbor/` | 30 |
| `admin-itsm` | Zammad | `apps/zammad/` | 30 |
| `admin-portainer` | Portainer | `apps/portainer/` | 30 |
| `core-storage` | Longhorn | `apps/longhorn/` | 10 |
| `ai-llm` | Ollama | `apps/ollama-llm/` | 35 |
| `ai-whisper` | Whisper | `apps/whisper/` | 35 |
| `ai-qdrant` | Qdrant | `apps/qdrant/` | 35 |
| `lab-kubevirt` | KubeVirt | `apps/kubevirt/` | 35 |
| `lab-jupyterhub` | JupyterHub | `apps/jupyterhub/` | 35 |
| `lab-vscode` | Code Server | `apps/code-server/` | 35 |
| `lab-esport` | eSport Servers | `apps/esport-servers/` | 35 |
| `video-cctv` | CCTV Analytics | `apps/cctv-analytics/` | 35 |
| `mail-mailu` | Mailu | `apps/mailu/` | 40 |
| `web-zsel` | WordPress ZSEL | `apps/wordpress-zsel/` | 40 |
| `web-bcu` | WordPress BCU | `apps/wordpress-bcu/` | 40 |
| `web-sue` | WordPress SUE | `apps/wordpress-sue/` | 40 |
| `web-mrsu` | WordPress MRSU | `apps/wordpress-mrsu/` | 40 |
| `web-elektryk` | WordPress Elektryk | `apps/wordpress-elektryk/` | 40 |
| `web-k4tec` | WordPress K4TEC | `apps/wordpress-k4tec/` | 40 |

## RBAC Strategy

### Per-Namespace Roles

Każdy namespace ma 3 role:
- **{namespace}-admin**: Full access w namespace
- **{namespace}-developer**: Read/Write (no delete namespace)
- **{namespace}-viewer**: Read-only

### Example: `edu-moodle` namespace

```yaml
# rbac/rolebindings/edu-moodle-admins.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind:RoleBinding
metadata:
  name: edu-moodle-admins
  namespace: edu-moodle
subjects:
  - kind: Group
    name: "cn=moodle-admins,ou=Groups,dc=ad,dc=zsel,dc=opole,dc=pl"
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-admin
  apiGroup: rbac.authorization.k8s.io
```

### FreeIPA Groups Mapping

```bash
# Core Team
cn=k8s-cluster-admins → ClusterRole: admin-full
cn=k8s-developers → ClusterRole: developer

# Per-Application Teams
cn=moodle-admins → RoleBinding: edu-moodle-admins
cn=gitlab-developers → RoleBinding: devtools-gitlab-developers
cn=nextcloud-admins → RoleBinding: edu-nextcloud-admins
# ... (47 namespaces × 3 roles = 141 RoleBindings)
```

## Network Policies - Zero Trust

Każdy namespace ma **default deny all** + explicit allow:

```yaml
# network-policies/default-deny-all.yaml (applied to ALL namespaces)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

Przykład dla Moodle:
```yaml
# network-policies/edu-moodle-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: moodle-allow-policies
  namespace: edu-moodle
spec:
  podSelector:
    matchLabels:
      app: moodle
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: core-ingress  # Traefik
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: db-postgres  # PostgreSQL
      ports:
        - protocol: TCP
          port: 5432
    - to:
        - namespaceSelector:
            matchLabels:
              name: core-auth  # User AD (LDAP)
      ports:
        - protocol: TCP
          port: 389
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system  # CoreDNS
      ports:
        - protocol: UDP
          port: 53
```

## Deployment Workflow

1. **Deploy Terraform** (namespaces + RBAC + network policies):
   ```bash
   cd environments/production
   terraform apply
   ```

2. **Deploy ArgoCD App-of-Apps**:
   ```bash
   kubectl apply -f apps/argocd-root/application.yaml
   ```

3. **ArgoCD automatically deploys all 39 apps** in sync-wave order (0 → 5 → 10 → 15 → 20 → 25 → 30 → 35 → 40)

4. **Verify deployment**:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods --all-namespaces
   ```

## Advantages of 1 Namespace = 1 Application

✅ **RBAC Isolation**: Per-app teams (Moodle admins ≠ GitLab admins)  
✅ **Network Policies**: Zero Trust between apps  
✅ **Resource Quotas**: Per-app CPU/Memory limits (prevents noisy neighbor)  
✅ **Monitoring**: Per-namespace Prometheus metrics  
✅ **Compliance**: RODO audit logs per application  
✅ **GitOps**: Clear directory structure (1 app = 1 folder)  
✅ **Disaster Recovery**: Backup/restore per namespace  

## Resource Summary (47 Namespaces)

| Wave | Namespaces | CPU Total | Memory Total | Storage Total |
|------|------------|-----------|--------------|---------------|
| 0 | 1 | 4 cores | 8 Gi | 50 Gi |
| 5 | 2 | 3 cores | 6 Gi | 15 Gi |
| 10 | 7 | 27 cores | 47 Gi | 275 Gi |
| 15 | 10 | 40 cores | 80 Gi | 1.35 Ti |
| 20 | 2 | 22 cores | 56 Gi | 800 Gi |
| 25 | 8 | 68 cores | 136 Gi | 152 Ti |
| 30 | 5 | 44 cores | 84 Gi | 1.56 Ti |
| 35 | 8 | 84 cores | 256 Gi | 8.8 Ti |
| 40 | 7 | 22 cores | 44 Gi | 320 Gi |
| **TOTAL** | **47** | **~290 cores** | **~740 Gi** | **~164 Ti** |

**Hardware Available**: 9 Mac Pro nodes (potencjalnie ~360 cores, ~1 TB RAM) → 80% utilization OK
