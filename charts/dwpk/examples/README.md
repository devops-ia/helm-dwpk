# Examples

Working YAML for the scenarios that come up most often when running dwpk. `config/samples/`
holds the minimal one-of-each sample kubebuilder scaffolds by default; these cover more
realistic combinations.

## Custom resources (`crs/`)

| File | Shows |
|---|---|
| `workspaceimage-python.yaml` | A plain CPU-only catalog entry, the common case |
| `workspaceimage-gpu.yaml` | A GPU image pinned to a `worker-gpu` nodepool via `placement` and a `nvidia.com/gpu` resource limit |
| `workspaceimage-deprecated.yaml` | An entry hidden from the catalog with `deprecated: true` without deleting existing Workspaces built from it |
| `userspace-isolated.yaml` | A user namespace with `networkPolicy: Isolated` (default posture, no egress beyond the cluster) |
| `userspace-cluster-egress.yaml` | A user namespace with `networkPolicy: ClusterEgress` for someone who needs to reach other in-cluster services (a shared database, an internal registry) |
| `workspace-basic.yaml` | A running workspace built from the Python image |
| `workspace-gpu.yaml` | A running workspace built from the GPU image, requesting the `large` size |

Apply any of them once the CRDs are installed:

```sh
kubectl apply -f examples/crs/workspaceimage-python.yaml
kubectl apply -f examples/crs/userspace-isolated.yaml
kubectl apply -f examples/crs/workspace-basic.yaml
```

`Workspace` objects live in the namespace the matching `UserSpace` creates
(`dwpk-<owner-local-part>` by convention), so create the `UserSpace` first.

## Helm values (`helm-values/`)

| File | Shows |
|---|---|
| `values-dev.yaml` | A single-provider (GitHub) setup for a local kind/OrbStack cluster: no ingress, `LoadBalancer` gateway swapped for `NodePort`, cert-manager left on since the webhook needs it |
| `values-production.yaml` | All five OAuth2 providers wired to an existing secret, ingress with TLS for the UI, higher replica counts for HA, resource requests sized for real traffic |

Neither file contains real client secrets. Both reference a Kubernetes `Secret` you create
separately (see `docs/INSTALLATION.md`) and point `oauth.<provider>.clientSecretKey` at a key
inside it.

```sh
helm install dwpk dist/chart -n dwpk-system --create-namespace -f examples/helm-values/values-dev.yaml
```
