# dwpk

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square)  ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)  ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Development Workspace Platform for Kubernetes: a Go operator, an SSH gateway, and a marketplace web UI, deployed together by this chart.

## What this chart installs

- **manager** - the CRD controller (`UserSpace`, `Workspace`, `WorkspaceImage`), leader-elected for HA, plus the validating/defaulting/conversion webhooks and cert-manager-issued webhook certificate.
- **gateway** - the SSH endpoint users connect to (`ssh <workspace>@<host>`), proxying into the right Workspace pod.
- **ui** - the marketplace web UI: OAuth2/local login, image catalog, workspace CRUD, embedded terminal, admin screens.

Any of the three can be disabled independently (`manager` is always installed; set `gateway.enabled=false` or `ui.enabled=false` to skip the other two).

## Quick start

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
kubectl wait --for=condition=Available -n cert-manager deployment --all --timeout=120s

helm upgrade --install dwpk oci://ghcr.io/devops-ia/dwpk/charts/dwpk \
  --namespace dwpk-system --create-namespace \
  --set ui.image.repository=<registry>/dwpk-ui \
  --set gateway.image.repository=<registry>/dwpk-gateway
```

See [`docs/INSTALLATION.md`](../docs/INSTALLATION.md) in the project repository for the full walkthrough: OAuth2 provider setup, ingress/Gateway API exposure, admin bootstrap, and verification steps.

## Naming the release

The chart takes its name from the release, so `dwpk` is a default rather than a
requirement:

```sh
helm upgrade --install platform helm-dwpk/ -n platform-system --create-namespace
```

Every Kubernetes object the chart creates is then prefixed `platform-`. Two
installs can share a cluster, provided each gets its own namespace.

Two things do **not** follow the release name, by design:

- **The CRDs and their API group** (`dwpk.devops-ia.io`). They are cluster-wide
  and shared: a second release manages the same kinds. Install them once, with
  `crd.enabled=false` on any release that should not own them.
- **Per-user namespaces**, which are `dwpk-<user>` unless a `UserSpace` names
  its own `spec.namespace`.

`nameOverride` and `fullnameOverride` work as they do in any chart if you want
the object names to differ from the release name.

## Examples

[`examples/`](examples/) holds working values files and custom resources:

- `examples/helm-values/` - values for common setups, one file per scenario.
- `examples/crs/` - `WorkspaceImage`, `UserSpace` and `Project` objects to apply
  once the chart is installed.

## Exposing the UI

Two independent options, see `ui.ingress.*` and `ui.gateway.*` below:

- Classic `networking.k8s.io/v1` `Ingress` (`ui.ingress.enabled=true`).
- [Kubernetes Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/) `Gateway`/`HTTPRoute` (`ui.gateway.enabled=true`), for clusters standardizing on Gateway API instead of Ingress. Set `ui.gateway.create=false` and `ui.gateway.parentRefs` to attach to a `Gateway` managed outside this chart.

## Local authentication (demo mode)

`ui.localAuth.enabled=true` turns on username/password login stored as Kubernetes Secrets, alongside any configured OAuth2 providers - useful for demos or environments without an identity provider. See `docs/API.md` for the local-user management endpoints.

## Admin bootstrap

On first install, a Helm pre-install/pre-upgrade hook Job mints an initial admin API token (`adminBootstrap.*`), readable once from the `dwpk-admin-bootstrap` Secret in the release namespace, alongside the generated admin password. See `docs/ADMINISTRATION.md`.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| adminBootstrap | object | `{"email":"admin@dwpk.local","enabled":true,"password":{"existingSecret":"","existingSecretKey":"password","value":""},"resources":{},"serviceAccount":{"annotations":{}},"userSpaceName":"admin","username":"admin"}` | Local admin API token bootstrap (§7.7). A Helm pre-install/pre-upgrade hook Job issues a one-time admin token if none exists yet, so the platform is usable before any OAuth2 provider is configured. Requires rbac.helpers.enabled=true and rbac.namespaced=false. |
| adminBootstrap.email | string | `"admin@dwpk.local"` | Owner identity for the admin. Must be unique across UserSpaces: login resolves an identity to exactly one UserSpace by this value. |
| adminBootstrap.enabled | bool | `true` | Set to false to skip local admin token bootstrap entirely |
| adminBootstrap.password | object | `{"existingSecret":"","existingSecretKey":"password","value":""}` | Admin password. Leave both keys empty to have one generated on first install and written once to the dwpk-admin-bootstrap Secret. |
| adminBootstrap.password.existingSecret | string | `""` | Name of an existing Secret holding the password |
| adminBootstrap.password.existingSecretKey | string | `"password"` | Key within existingSecret |
| adminBootstrap.password.value | string | `""` | Literal password. Prefer existingSecret; a literal here lands in the Helm release stored in the cluster. |
| adminBootstrap.resources | object | `{}` | Resources for the bootstrap Job's pod |
| adminBootstrap.serviceAccount.annotations | object | `{}` | Extra annotations for the admin bootstrap ServiceAccount |
| adminBootstrap.userSpaceName | string | `"admin"` | Name of the UserSpace created for the admin. Its namespace is dwpk-<name>, and it is provisioned with quota.workspaces=0 so no pod can ever run as the identity that holds cluster-wide admin. |
| adminBootstrap.username | string | `"admin"` | Username for the bootstrapped admin login |
| certManager | object | `{"enabled":true}` | Cert-manager integration for TLS certificates. Required for webhook certificates and metrics endpoint certificates. |
| crd | object | `{"enabled":true,"keep":true}` | Custom Resource Definitions |
| fullnameOverride | string | `""` | String to fully override chart.fullname template |
| gateway | object | `{"affinity":{},"annotations":{},"command":[],"dnsConfig":{},"dnsPolicy":"","enabled":true,"env":{},"envFromConfigMap":{},"envFromFiles":[],"envFromSecrets":{},"extraArgs":[],"hostKey":{"existingSecret":"","path":"/var/run/dwpk-gateway/hostkey/hostkey.pem","secretKey":"hostkey.pem"},"image":{"pullPolicy":"IfNotPresent","repository":"ghcr.io/devops-ia/dwpk-gateway"},"imagePullSecrets":[],"initContainers":[],"labels":{},"lifecycle":{},"listenAddress":":2222","livenessProbe":{"enabled":true,"failureThreshold":3,"initialDelaySeconds":15,"periodSeconds":20,"successThreshold":1,"timeoutSeconds":1},"livenessProbeCustom":{},"nodeSelector":{},"pod":{"annotations":{},"labels":{}},"podDisruptionBudget":{"enabled":false,"minAvailable":1},"podSecurityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"priorityClassName":"","readinessProbe":{"enabled":true,"failureThreshold":3,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1},"readinessProbeCustom":{},"replicas":2,"resources":{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"10m","memory":"64Mi"}},"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true},"service":{"annotations":{},"labels":{},"port":22,"type":"LoadBalancer"},"serviceAccount":{"create":true,"name":""},"startupProbe":{"enabled":false,"failureThreshold":30,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1},"startupProbeCustom":{},"strategy":{},"terminationGracePeriodSeconds":10,"tolerations":[],"topologySpreadConstraints":[]}` | Configure the SSH gateway deployment |
| gateway.affinity | object | `{}` | Gateway pod's affinity |
| gateway.annotations | object | `{}` | Custom Deployment annotations |
| gateway.command | list | `[]` | Override the container command. Empty keeps the image's own entrypoint, which is what you want unless you are debugging. |
| gateway.dnsConfig | object | `{}` | Pod DNS configuration |
| gateway.dnsPolicy | string | `""` | Pod DNS policy. Empty leaves the cluster default. </br> Ref: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/ |
| gateway.enabled | bool | `true` | Set to false to skip gateway installation |
| gateway.env | object | `{}` | Extra environment variables, as a plain map. Names are upper-cased. A name also present in `envFromSecrets` or `envFromConfigMap` is ignored here: those take precedence. |
| gateway.envFromConfigMap | object | `{}` | Environment variables read from existing ConfigMaps </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/ |
| gateway.envFromFiles | list | `[]` | Load every key of a ConfigMap or Secret as environment variables </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#configure-all-key-value-pairs-in-a-configmap-as-container-environment-variables |
| gateway.envFromSecrets | object | `{}` | Environment variables read from existing Secrets </br> Ref: https://kubernetes.io/docs/concepts/configuration/secret/ |
| gateway.hostKey | object | `{"existingSecret":"","path":"/var/run/dwpk-gateway/hostkey/hostkey.pem","secretKey":"hostkey.pem"}` | SSH host key configuration. Every replica and every restart mounts the same key from a Secret - VS Code Remote-SSH and other clients that pin a host key refuse to connect the moment two connections to the same address see two different ones. |
| gateway.hostKey.existingSecret | string | `""` | Existing Secret containing the private key file. Leave empty and the chart generates one itself on first install (kept across upgrades, so it is not regenerated and re-trusted every release). |
| gateway.hostKey.secretKey | string | `"hostkey.pem"` | Secret key containing the PEM-encoded private key |
| gateway.image.pullPolicy | string | `"IfNotPresent"` | Image tag (defaults to Chart.appVersion if not set) tag: "" |
| gateway.image.repository | string | `"ghcr.io/devops-ia/dwpk-gateway"` | Image repository |
| gateway.imagePullSecrets | list | `[]` | Image pull secrets, merged with `global.imagePullSecrets` </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| gateway.initContainers | list | `[]` | Additional init containers </br> Ref: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/ |
| gateway.labels | object | `{}` | Custom Deployment labels |
| gateway.lifecycle | object | `{}` | Container lifecycle hooks </br> Ref: https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/ |
| gateway.livenessProbe | object | `{"enabled":true,"failureThreshold":3,"initialDelaySeconds":15,"periodSeconds":20,"successThreshold":1,"timeoutSeconds":1}` | Liveness probe timings. Opens a TCP connection to the SSH port. The check itself is fixed, because which endpoint reports health is a property of the binary rather than a deployment choice. Replace the whole probe with `livenessProbeCustom`. </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| gateway.livenessProbeCustom | object | `{}` | Replace the liveness probe entirely. When set it wins over `livenessProbe`. |
| gateway.nodeSelector | object | `{}` | Gateway pod's node selector |
| gateway.pod | object | `{"annotations":{},"labels":{}}` | Custom Pod labels and annotations |
| gateway.podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | Disruption budget. The gateway carries live SSH sessions, so keeping a replica through a drain is the difference between a reconnect and a dropped shell. </br> Ref: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/ |
| gateway.podSecurityContext | object | `{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod-level security settings |
| gateway.priorityClassName | string | `""` | Priority class name </br> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/ |
| gateway.readinessProbe | object | `{"enabled":true,"failureThreshold":3,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1}` | Readiness probe timings. Opens a TCP connection to the SSH port. |
| gateway.readinessProbeCustom | object | `{}` | Replace the readiness probe entirely |
| gateway.resources | object | `{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"10m","memory":"64Mi"}}` | Resource limits and requests |
| gateway.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Container-level security settings |
| gateway.service | object | `{"annotations":{},"labels":{},"port":22,"type":"LoadBalancer"}` | Gateway Service configuration |
| gateway.service.annotations | object | `{}` | Service annotations, for example to request an internal load balancer |
| gateway.service.labels | object | `{}` | Custom Service labels |
| gateway.serviceAccount | object | `{"create":true,"name":""}` | ServiceAccount configuration |
| gateway.serviceAccount.create | bool | `true` | Set to false to reuse an existing ServiceAccount |
| gateway.serviceAccount.name | string | `""` | Existing ServiceAccount name (used when create=false) |
| gateway.startupProbe | object | `{"enabled":false,"failureThreshold":30,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1}` | Startup probe timings. Off by default: the gateway binds its listener immediately. |
| gateway.startupProbeCustom | object | `{}` | Replace the startup probe entirely |
| gateway.strategy | object | `{}` | Deployment strategy </br> Ref: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy |
| gateway.terminationGracePeriodSeconds | int | `10` | Termination grace period seconds |
| gateway.tolerations | list | `[]` | Gateway pod's tolerations |
| gateway.topologySpreadConstraints | list | `[]` | Topology spread constraints </br> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/ |
| global | object | `{"imagePullSecrets":[],"imageRegistry":""}` | Settings shared by every component |
| global.imagePullSecrets | list | `[]` | Pull secrets applied to every component, merged with each component's own </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| global.imageRegistry | string | `""` | Registry prefixed to every image repository, for a mirror or an air-gapped install. Empty pulls each image from where its own `repository` points. |
| manager | object | `{"affinity":{},"annotations":{},"args":["--leader-elect"],"command":[],"dnsConfig":{},"dnsPolicy":"","enabled":true,"env":{},"envFromConfigMap":{},"envFromFiles":[],"envFromSecrets":{},"gatewayHost":"","gitSSHEncryptionKey":{"existingSecret":false},"image":{"pullPolicy":"IfNotPresent","repository":"ghcr.io/devops-ia/dwpk"},"imagePullSecrets":[],"initContainers":[],"labels":{},"lifecycle":{},"livenessProbe":{"enabled":true,"failureThreshold":3,"initialDelaySeconds":15,"periodSeconds":20,"successThreshold":1,"timeoutSeconds":1},"livenessProbeCustom":{},"nodeSelector":{},"pod":{"annotations":{},"labels":{}},"podDisruptionBudget":{"enabled":false,"minAvailable":1},"podSecurityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"priorityClassName":"","readinessProbe":{"enabled":true,"failureThreshold":3,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1},"readinessProbeCustom":{},"replicas":2,"resources":{"limits":{"cpu":"500m","memory":"128Mi"},"requests":{"cpu":"10m","memory":"64Mi"}},"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true},"startupProbe":{"enabled":false,"failureThreshold":30,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1},"startupProbeCustom":{},"strategy":{},"terminationGracePeriodSeconds":10,"tolerations":[],"topologySpreadConstraints":[]}` | Configure the controller manager deployment |
| manager.affinity | object | `{}` | Manager pod's affinity |
| manager.annotations | object | `{}` | Custom Deployment annotations |
| manager.args | list | `["--leader-elect"]` | Arguments |
| manager.command | list | `[]` | Override the container command. Empty keeps the image's own entrypoint, which is what you want unless you are debugging. |
| manager.dnsConfig | object | `{}` | Pod DNS configuration |
| manager.dnsPolicy | string | `""` | Pod DNS policy. Empty leaves the cluster default. </br> Ref: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/ |
| manager.enabled | bool | `true` | Set to false to skip manager installation |
| manager.env | object | `{}` | Extra environment variables, as a plain map. Names are upper-cased. A name also present in `envFromSecrets` or `envFromConfigMap` is ignored here: those take precedence. |
| manager.envFromConfigMap | object | `{}` | Environment variables read from existing ConfigMaps </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/ |
| manager.envFromFiles | list | `[]` | Load every key of a ConfigMap or Secret as environment variables </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#configure-all-key-value-pairs-in-a-configmap-as-container-environment-variables |
| manager.envFromSecrets | object | `{}` | Environment variables read from existing Secrets </br> Ref: https://kubernetes.io/docs/concepts/configuration/secret/ |
| manager.gatewayHost | string | `""` | SSH hostname published in Workspace `status.endpoint` as `<workspace>@<host>`. Only used as a fallback: when the gateway Service has a LoadBalancer address, that address is published instead. Leave empty to keep the controller's own default. |
| manager.gitSSHEncryptionKey | object | `{"existingSecret":false}` | The AES-256 key that encrypts every user's self-service git-ssh-keys Secret at rest. The manager decrypts with it on reconcile; the UI encrypts with it on upload (see templates/rbac/ui-git-ssh-key-role.yaml). |
| manager.gitSSHEncryptionKey.existingSecret | bool | `false` | Set true when a Secret literally named dwpk-git-ssh-encryption-key (data key `key`, 32 random bytes) already exists and this chart should not manage it. Unlike gateway.hostKey.existingSecret this is not a name to point at a different Secret - the operator's Go code addresses this one by a fixed name, with no flag to override it. Leave false and the chart generates it itself on first install (kept across upgrades, for the same reason gateway.hostKey is: a rotated key would leave every already-uploaded git-ssh key undecryptable). |
| manager.image.pullPolicy | string | `"IfNotPresent"` | Image tag (defaults to Chart.appVersion if not set) tag: "" |
| manager.image.repository | string | `"ghcr.io/devops-ia/dwpk"` | Image repository |
| manager.imagePullSecrets | list | `[]` | Image pull secrets, merged with `global.imagePullSecrets` </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| manager.initContainers | list | `[]` | Additional init containers </br> Ref: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/ |
| manager.labels | object | `{}` | Custom Deployment labels |
| manager.lifecycle | object | `{}` | Container lifecycle hooks </br> Ref: https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/ |
| manager.livenessProbe | object | `{"enabled":true,"failureThreshold":3,"initialDelaySeconds":15,"periodSeconds":20,"successThreshold":1,"timeoutSeconds":1}` | Liveness probe timings. Checks `/healthz` on the probe port. The check itself is fixed, because which endpoint reports health is a property of the binary rather than a deployment choice. Replace the whole probe with `livenessProbeCustom`. </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| manager.livenessProbeCustom | object | `{}` | Replace the liveness probe entirely. When set it wins over `livenessProbe`. |
| manager.nodeSelector | object | `{}` | Manager pod's node selector |
| manager.pod | object | `{"annotations":{},"labels":{}}` | Custom Pod labels and annotations |
| manager.podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | Disruption budget. Leader election makes the extra replicas warm spares, and this is what stops a node drain evicting all of them before a standby holds the lease. </br> Ref: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/ |
| manager.podSecurityContext | object | `{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod-level security settings |
| manager.priorityClassName | string | `""` | Priority class name </br> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/ |
| manager.readinessProbe | object | `{"enabled":true,"failureThreshold":3,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1}` | Readiness probe timings. Checks `/readyz` on the probe port. |
| manager.readinessProbeCustom | object | `{}` | Replace the readiness probe entirely |
| manager.replicas | int | `2` | Number of manager replicas. Leader election means the extras are warm spares rather than added throughput: one replica reconciles, and a standby takes the lease when it dies. Pair with `manager.podDisruptionBudget` so a drain cannot evict both before the handover. |
| manager.resources | object | `{"limits":{"cpu":"500m","memory":"128Mi"},"requests":{"cpu":"10m","memory":"64Mi"}}` | Resource limits and requests |
| manager.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Container-level security settings |
| manager.startupProbe | object | `{"enabled":false,"failureThreshold":30,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1}` | Startup probe timings. Off by default: the manager starts fast enough that the liveness probe's initial delay covers it. |
| manager.startupProbeCustom | object | `{}` | Replace the startup probe entirely |
| manager.strategy | object | `{}` | Deployment strategy </br> Ref: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy |
| manager.terminationGracePeriodSeconds | int | `10` | Termination grace period seconds |
| manager.tolerations | list | `[]` | Manager pod's tolerations |
| manager.topologySpreadConstraints | list | `[]` | Topology spread constraints </br> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/ |
| metrics | object | `{"enabled":true,"port":8443,"secure":true}` | Controller metrics endpoint. Enable to expose /metrics endpoint |
| nameOverride | string | `""` | String to partially override chart.fullname template (will maintain the release name) |
| networkPolicy | object | `{"enabled":false}` | Network policies for controlling traffic flow. Enable to restrict ingress to the controller manager. |
| prometheus | object | `{"enabled":false}` | Prometheus ServiceMonitor for metrics scraping. Requires prometheus-operator to be installed in the cluster. |
| rbac | object | `{"helpers":{"enabled":true},"namespaced":false}` | RBAC configuration |
| rbac.helpers | object | `{"enabled":true}` | Helper roles for CRD management (admin/editor/viewer) |
| rbac.helpers.enabled | bool | `true` | Install convenience admin/editor/viewer roles for CRDs. Defaults to true because adminBootstrap (below) binds the local admin token to these ClusterRoles; set both to false together if you don't want either. |
| rbac.namespaced | bool | `false` | RBAC resource scope - false (default): ClusterRole/ClusterRoleBinding (all namespaces) - true: Role/RoleBinding (release namespace only) |
| serviceAccount | object | `{"enabled":true}` | ServiceAccount configuration |
| ui | object | `{"affinity":{},"annotations":{},"basePath":"","baseURL":"","command":[],"cookieSecure":true,"dnsConfig":{},"dnsPolicy":"","enabled":true,"env":{},"envFromConfigMap":{},"envFromFiles":[],"envFromSecrets":{},"gateway":{"annotations":{},"className":"","create":true,"enabled":false,"hostnames":[],"listeners":[{"allowedRoutes":{"namespaces":{"from":"Same"}},"name":"http","port":80,"protocol":"HTTP"}],"parentRefs":[],"rules":[{"matches":[{"path":{"type":"PathPrefix","value":"/"}}]}]},"gatewayHost":"dwpk.example.com","image":{"pullPolicy":"IfNotPresent","repository":"ghcr.io/devops-ia/dwpk-ui"},"imagePullSecrets":[],"ingress":{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"ui.example.com","paths":[{"path":"/","pathType":"Prefix"}]}],"tls":[]},"initContainers":[],"kubeconfig":"","labels":{},"lifecycle":{},"listenAddress":":8080","livenessProbe":{"enabled":true,"failureThreshold":3,"initialDelaySeconds":15,"periodSeconds":20,"successThreshold":1,"timeoutSeconds":1},"livenessProbeCustom":{},"localAuth":{"enabled":true,"namespace":""},"logLevel":"info","nodeSelector":{},"oauth":{"entraID":{"adminGroups":[],"clientID":"","clientSecretKey":"entra-id-client-secret","issuerURL":"","redirectURL":"","userGroups":[]},"existingSecret":"","gitHub":{"clientID":"","clientSecretKey":"github-client-secret","redirectURL":""},"gitLab":{"adminGroups":[],"clientID":"","clientSecretKey":"gitlab-client-secret","issuerURL":"","redirectURL":"","userGroups":[]},"google":{"adminGroups":[],"clientID":"","clientSecretKey":"google-client-secret","issuerURL":"","redirectURL":"","userGroups":[]},"keycloak":{"adminGroups":[],"clientID":"","clientSecretKey":"keycloak-client-secret","issuerURL":"","redirectURL":"","userGroups":[]}},"pod":{"annotations":{},"labels":{}},"podDisruptionBudget":{"enabled":false,"minAvailable":1},"podSecurityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"priorityClassName":"","readinessProbe":{"enabled":true,"failureThreshold":3,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1},"readinessProbeCustom":{},"replicas":1,"resources":{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"10m","memory":"64Mi"}},"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true},"service":{"annotations":{},"labels":{},"port":80,"type":"ClusterIP"},"serviceAccount":{"create":true,"name":""},"sessionTTL":"15m","startupProbe":{"enabled":false,"failureThreshold":30,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1},"startupProbeCustom":{},"strategy":{},"terminationGracePeriodSeconds":10,"tokenNamespace":"","tolerations":[],"topologySpreadConstraints":[]}` | Configure the UI deployment |
| ui.affinity | object | `{}` | UI pod's affinity |
| ui.annotations | object | `{}` | Custom Deployment annotations |
| ui.basePath | string | `""` | Optional path prefix if the UI is served behind a reverse proxy under a non-root path (e.g. "/dwpk"). Passed through DWPK__UI_BASE_PATH. The proxy must forward the full prefixed path unmodified (no rewrite). |
| ui.baseURL | string | `""` | Public base URL used to derive default OAuth callback URLs |
| ui.command | list | `[]` | Override the container command. Empty keeps the image's own entrypoint, which is what you want unless you are debugging. |
| ui.cookieSecure | bool | `true` | Cookie Secure flag passed through DWPK__UI_COOKIE_SECURE |
| ui.dnsConfig | object | `{}` | Pod DNS configuration |
| ui.dnsPolicy | string | `""` | Pod DNS policy. Empty leaves the cluster default. </br> Ref: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/ |
| ui.enabled | bool | `true` | Set to false to skip UI installation |
| ui.env | object | `{}` | Extra environment variables, as a plain map. Names are upper-cased. A name also present in `envFromSecrets` or `envFromConfigMap` is ignored here: those take precedence. |
| ui.envFromConfigMap | object | `{}` | Environment variables read from existing ConfigMaps </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/ |
| ui.envFromFiles | list | `[]` | Load every key of a ConfigMap or Secret as environment variables </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#configure-all-key-value-pairs-in-a-configmap-as-container-environment-variables |
| ui.envFromSecrets | object | `{}` | Environment variables read from existing Secrets </br> Ref: https://kubernetes.io/docs/concepts/configuration/secret/ |
| ui.gateway | object | `{"annotations":{},"className":"","create":true,"enabled":false,"hostnames":[],"listeners":[{"allowedRoutes":{"namespaces":{"from":"Same"}},"name":"http","port":80,"protocol":"HTTP"}],"parentRefs":[],"rules":[{"matches":[{"path":{"type":"PathPrefix","value":"/"}}]}]}` | Optional Kubernetes Gateway API (https://kubernetes.io/docs/concepts/services-networking/gateway/) route for the UI Service, as an alternative to ui.ingress. Mutually independent of ingress: enable one or the other (or neither). |
| ui.gateway.annotations | object | `{}` | HTTPRoute annotations |
| ui.gateway.className | string | `""` | Required when gateway.create is true. |
| ui.gateway.create | bool | `true` | Create a Gateway object for this release. Set to false to attach to an existing Gateway via gateway.parentRefs instead. |
| ui.gateway.hostnames | list | `[]` | HTTPRoute hostnames |
| ui.gateway.listeners | list | `[{"allowedRoutes":{"namespaces":{"from":"Same"}},"name":"http","port":80,"protocol":"HTTP"}]` | Listeners for the Gateway this chart creates. Only used when gateway.create is true. See the Gateway API Listener spec. |
| ui.gateway.parentRefs | list | `[]` | HTTPRoute parentRefs, used instead of gateway.create's own Gateway when gateway.create is false (attach to an existing Gateway). |
| ui.gateway.rules | list | `[{"matches":[{"path":{"type":"PathPrefix","value":"/"}}]}]` | HTTPRoute rules. backendRefs to the UI Service are added automatically; set matches/filters per rule as needed. |
| ui.gatewayHost | string | `"dwpk.example.com"` | Public gateway host shown in generated SSH commands |
| ui.image.pullPolicy | string | `"IfNotPresent"` | Image tag (defaults to Chart.appVersion if not set) tag: "" |
| ui.image.repository | string | `"ghcr.io/devops-ia/dwpk-ui"` | Image repository |
| ui.imagePullSecrets | list | `[]` | Image pull secrets, merged with `global.imagePullSecrets` </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ui.ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"ui.example.com","paths":[{"path":"/","pathType":"Prefix"}]}],"tls":[]}` | Optional Ingress for the UI Service |
| ui.initContainers | list | `[]` | Additional init containers </br> Ref: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/ |
| ui.kubeconfig | string | `""` | Optional DWPK__UI_KUBECONFIG override. Leave empty for in-cluster config. |
| ui.labels | object | `{}` | Custom Deployment labels |
| ui.lifecycle | object | `{}` | Container lifecycle hooks </br> Ref: https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/ |
| ui.listenAddress | string | `":8080"` | Listen address passed through DWPK__UI_LISTEN_ADDRESS |
| ui.livenessProbe | object | `{"enabled":true,"failureThreshold":3,"initialDelaySeconds":15,"periodSeconds":20,"successThreshold":1,"timeoutSeconds":1}` | Liveness probe timings. Requests `/login`, which needs no session. The check itself is fixed, because which endpoint reports health is a property of the binary rather than a deployment choice. Replace the whole probe with `livenessProbeCustom`. </br> Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |
| ui.livenessProbeCustom | object | `{}` | Replace the liveness probe entirely. When set it wins over `livenessProbe`. |
| ui.localAuth | object | `{"enabled":true,"namespace":""}` | Local username/password login, for demos and environments without an OAuth2 provider. Local users are stored as Kubernetes Secrets (§7.8). |
| ui.localAuth.namespace | string | `""` | Namespace local-user credential Secrets are stored in. Defaults to the release namespace when unset. |
| ui.logLevel | string | `"info"` | Log level passed through DWPK__UI_LOG_LEVEL (debug, info, warn, error) |
| ui.nodeSelector | object | `{}` | UI pod's node selector |
| ui.oauth | object | `{"entraID":{"adminGroups":[],"clientID":"","clientSecretKey":"entra-id-client-secret","issuerURL":"","redirectURL":"","userGroups":[]},"existingSecret":"","gitHub":{"clientID":"","clientSecretKey":"github-client-secret","redirectURL":""},"gitLab":{"adminGroups":[],"clientID":"","clientSecretKey":"gitlab-client-secret","issuerURL":"","redirectURL":"","userGroups":[]},"google":{"adminGroups":[],"clientID":"","clientSecretKey":"google-client-secret","issuerURL":"","redirectURL":"","userGroups":[]},"keycloak":{"adminGroups":[],"clientID":"","clientSecretKey":"keycloak-client-secret","issuerURL":"","redirectURL":"","userGroups":[]}}` | OAuth provider configuration |
| ui.oauth.entraID | object | `{"adminGroups":[],"clientID":"","clientSecretKey":"entra-id-client-secret","issuerURL":"","redirectURL":"","userGroups":[]}` | Entra ID provider configuration (maps to DWPK__UI_PROVIDER_ENTRA_ID_*) |
| ui.oauth.entraID.adminGroups | list | `[]` | Group object IDs granted the admin role on login, regardless of their UserSpace's own spec.role. Requires GroupMembershipClaims enabled on the app registration. See docs/INSTALLATION.md. |
| ui.oauth.entraID.userGroups | list | `[]` | Group object IDs granted the user role on login (only checked when none of adminGroups match). |
| ui.oauth.existingSecret | string | `""` | Existing Secret containing provider client secrets |
| ui.oauth.gitHub | object | `{"clientID":"","clientSecretKey":"github-client-secret","redirectURL":""}` | GitHub provider configuration (maps to DWPK__UI_PROVIDER_GITHUB_*). GitHub has no group claim, so it has no adminGroups/userGroups option. |
| ui.oauth.gitLab | object | `{"adminGroups":[],"clientID":"","clientSecretKey":"gitlab-client-secret","issuerURL":"","redirectURL":"","userGroups":[]}` | GitLab provider configuration (maps to DWPK__UI_PROVIDER_GITLAB_*) |
| ui.oauth.gitLab.adminGroups | list | `[]` | Group paths/IDs granted the admin role on login. |
| ui.oauth.gitLab.userGroups | list | `[]` | Group paths/IDs granted the user role on login. |
| ui.oauth.google | object | `{"adminGroups":[],"clientID":"","clientSecretKey":"google-client-secret","issuerURL":"","redirectURL":"","userGroups":[]}` | Google provider configuration (maps to DWPK__UI_PROVIDER_GOOGLE_*) |
| ui.oauth.google.adminGroups | list | `[]` | Group identifiers granted the admin role on login. See docs/INSTALLATION.md for group-claim mapping. |
| ui.oauth.google.userGroups | list | `[]` | Group identifiers granted the user role on login. |
| ui.oauth.keycloak | object | `{"adminGroups":[],"clientID":"","clientSecretKey":"keycloak-client-secret","issuerURL":"","redirectURL":"","userGroups":[]}` | Keycloak provider configuration (maps to DWPK__UI_PROVIDER_KEYCLOAK_*) |
| ui.oauth.keycloak.adminGroups | list | `[]` | Realm group names granted the admin role on login. |
| ui.oauth.keycloak.userGroups | list | `[]` | Realm group names granted the user role on login. |
| ui.pod | object | `{"annotations":{},"labels":{}}` | Custom Pod labels and annotations |
| ui.podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | Disruption budget. Keeps the UI reachable through a node drain. </br> Ref: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/ |
| ui.podSecurityContext | object | `{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod-level security settings |
| ui.priorityClassName | string | `""` | Priority class name </br> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/ |
| ui.readinessProbe | object | `{"enabled":true,"failureThreshold":3,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1}` | Readiness probe timings. Requests `/login`, which needs no session. |
| ui.readinessProbeCustom | object | `{}` | Replace the readiness probe entirely |
| ui.resources | object | `{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"10m","memory":"64Mi"}}` | Resource limits and requests |
| ui.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Container-level security settings |
| ui.service | object | `{"annotations":{},"labels":{},"port":80,"type":"ClusterIP"}` | UI Service configuration |
| ui.service.annotations | object | `{}` | Service annotations |
| ui.service.labels | object | `{}` | Custom Service labels |
| ui.serviceAccount | object | `{"create":true,"name":""}` | ServiceAccount configuration |
| ui.serviceAccount.create | bool | `true` | Set to false to reuse an existing ServiceAccount |
| ui.serviceAccount.name | string | `""` | Existing ServiceAccount name (used when create=false) |
| ui.sessionTTL | string | `"15m"` | Session TTL passed through DWPK__UI_SESSION_TTL |
| ui.startupProbe | object | `{"enabled":false,"failureThreshold":30,"initialDelaySeconds":5,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1}` | Startup probe timings. Off by default. Turn it on if the UI's first Kubernetes call is slow on a cold cluster. |
| ui.startupProbeCustom | object | `{}` | Replace the startup probe entirely |
| ui.strategy | object | `{}` | Deployment strategy </br> Ref: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy |
| ui.terminationGracePeriodSeconds | int | `10` | Termination grace period seconds |
| ui.tokenNamespace | string | `""` | Namespace holding the API token Secrets the REST API issues and looks up. Passed through DWPK__UI_TOKEN_NAMESPACE. Defaults to the release namespace, and the UI's Secrets access is scoped to this namespace alone. |
| ui.tolerations | list | `[]` | UI pod's tolerations |
| ui.topologySpreadConstraints | list | `[]` | Topology spread constraints </br> Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/ |
| webhook | object | `{"enabled":true,"port":9443}` | Webhook server configuration |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
