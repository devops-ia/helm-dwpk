# Testing dwpk Helm Chart

This document provides guidelines for testing the dwpk Helm chart. Follow these instructions to ensure the chart works as expected before deployment to production.

## Steps

### 1. Lint Testing

```bash
# Run helm lint to check for any syntax issues
helm lint charts/dwpk
```

### 2. Template Testing

```bash
# Generate and verify the template output
helm template dwpk charts/dwpk --debug
```

### 3. Local installation testing

```bash
# Install the chart in a test namespace
kubectl create namespace dwpk-test
helm install dwpk-test charts/dwpk --namespace dwpk-test
```

### 4. Verification steps

1. Check all pods are running:

```bash
kubectl get pods -n dwpk-test
```

2. Verify services are exposed:

```bash
kubectl get svc -n dwpk-test
```

3. Check UI accessibility:

```bash
kubectl port-forward svc/dwpk-test-ui 8080:8080 -n dwpk-test
```

4. Validate component health:

- manager (controller and webhooks) is ready
- gateway accepts SSH connections
- ui is reachable and can list images

### 5. Functional testing

1. **UI Login**
   - Verify local auth or configured OAuth2 provider works

2. **Workspace Operations**
   - Create a `WorkspaceImage`
   - Create a `UserSpace` and a `Workspace`
   - Connect via `ssh <workspace>@<host>`

3. **Integration Testing**
   - Verify webhook admission (defaulting/validation/conversion)
   - Check cert-manager issued webhook certificate

### 6. Upgrade testing

```bash
# Test upgrade from previous version
helm upgrade dwpk-test charts/dwpk --namespace dwpk-test
```

### 7. Clean-up

```bash
# Remove test deployment
helm uninstall dwpk-test --namespace dwpk-test
kubectl delete namespace dwpk-test
```

## Automated testing

For CI/CD pipelines, you can use the following tools:

1. [Chart Testing](https://github.com/helm/chart-testing)
2. [Helm Unit Tests](https://github.com/helm-unittest/helm-unittest)

Example CI test command:

```bash
ct lint-and-install --config ct.yaml
```
