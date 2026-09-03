# dwpk Helm Chart

[dwpk](https://github.com/devops-ia/dwpk) is a development workspace platform for Kubernetes: a Go operator, an SSH gateway, and a marketplace web UI, deployed together by this chart.

## Usage

Charts are available in:

* [Chart Repository](https://helm.sh/docs/topics/chart_repository/)
* [OCI Artifacts](https://helm.sh/docs/topics/registries/)

### Chart Repository

#### Add repository

```console
helm repo add dwpk https://devops-ia.github.io/helm-dwpk
helm repo update
```

#### Install Helm chart

```console
helm install [RELEASE_NAME] dwpk/dwpk
```

This install all the Kubernetes components associated with the chart and creates the release.

_See [helm install](https://helm.sh/docs/helm/helm_install/) for command documentation._

### OCI Registry

Charts are also available in OCI format. The list of available charts can be found [here](https://github.com/devops-ia/helm-dwpk/pkgs/container/helm-dwpk%2Fdwpk).

#### Install Helm chart

```console
helm install [RELEASE_NAME] oci://ghcr.io/devops-ia/helm-dwpk/dwpk --version=[version]
```

## dwpk chart

Can be found in [dwpk chart](charts/dwpk).
