{{/*
Expand the name of the chart.
*/}}
{{- define "dwpk.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dwpk.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Namespace for generated references.
Always uses the Helm release namespace.
*/}}
{{- define "dwpk.namespaceName" -}}
{{- .Release.Namespace }}
{{- end }}

{{/*
Resource name with proper truncation for Kubernetes 63-character limit.
Takes a dict with:
  - .suffix: Resource name suffix (e.g., "metrics", "webhook")
  - .context: Template context (root context with .Values, .Release, etc.)
Dynamically calculates safe truncation to ensure total name length <= 63 chars.
*/}}
{{- define "dwpk.resourceName" -}}
{{- $fullname := include "dwpk.fullname" .context }}
{{- $suffix := .suffix }}
{{- $maxLen := sub 62 (len $suffix) | int }}
{{- if gt (len $fullname) $maxLen }}
{{- printf "%s-%s" (trunc $maxLen $fullname | trimSuffix "-") $suffix | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" $fullname $suffix | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
ServiceAccount name to use.
If serviceAccount.enabled is false and serviceAccount.name is set, use that name.
Otherwise, use the standard resourceName helper with "controller-manager" suffix.
*/}}
{{- define "dwpk.serviceAccountName" -}}
{{- if and (not (.Values.serviceAccount.enabled | default true)) .Values.serviceAccount.name }}
{{- .Values.serviceAccount.name }}
{{- else }}
{{- include "dwpk.resourceName" (dict "suffix" "controller-manager" "context" .) }}
{{- end }}
{{- end }}

{{/*
Extract the trailing port number from a listen address.
*/}}
{{- define "dwpk.listenPort" -}}
{{- $port := regexFind "[0-9]+$" . -}}
{{- if eq $port "" -}}
{{- fail (printf "listen address %q must end with a numeric port" .) -}}
{{- end -}}
{{- $port -}}
{{- end }}

{{/*
Gateway ServiceAccount name to use.
*/}}
{{- define "dwpk.gatewayServiceAccountName" -}}
{{- if and (not (.Values.gateway.serviceAccount.create | default true)) .Values.gateway.serviceAccount.name }}
{{- .Values.gateway.serviceAccount.name }}
{{- else }}
{{- include "dwpk.resourceName" (dict "suffix" "gateway" "context" .) }}
{{- end }}
{{- end }}

{{/*
Two different identities, deliberately not the same account.

adminBootstrapServiceAccountName is what the bootstrap Job's own pod runs as.
It needs only to write token and user records and create one UserSpace.

adminSessionServiceAccountName is what the admin API token and a browser login
both authenticate as (§7.7). It matches internal/workspace.SessionServiceAccountName,
which the UI's ClusterRole permits "serviceaccounts/token create" for. It must
never be a pod's serviceAccountName: the admin ClusterRoles are bound to it, so
a pod running as it would hand cluster admin to anyone with a shell inside.
*/}}
{{- define "dwpk.adminBootstrapServiceAccountName" -}}
dwpk-admin-bootstrap
{{- end }}

{{- define "dwpk.adminSessionServiceAccountName" -}}
session
{{- end }}

{{/*
The UserSpace the admin login resolves to, and the namespace the controller
derives from it. The namespace prefix "dwpk-" is the convention in
internal/controller.namespaceFor; these two helpers must stay in agreement,
because the admin ClusterRoleBindings target the session ServiceAccount inside
that namespace.
*/}}
{{- define "dwpk.adminUserSpaceName" -}}
{{- .Values.adminBootstrap.userSpaceName | default "admin" -}}
{{- end }}

{{- define "dwpk.adminUserSpaceNamespace" -}}
{{- printf "dwpk-%s" (include "dwpk.adminUserSpaceName" .) -}}
{{- end }}

{{/*
UI ServiceAccount name to use.
*/}}
{{- define "dwpk.uiServiceAccountName" -}}
{{- if and (not (.Values.ui.serviceAccount.create | default true)) .Values.ui.serviceAccount.name }}
{{- .Values.ui.serviceAccount.name }}
{{- else }}
{{- include "dwpk.resourceName" (dict "suffix" "ui" "context" .) }}
{{- end }}
{{- end }}

{{/*
The ClusterRoles a UserSpace with role: administrator is bound to.

One definition, two consumers that must agree: the --admin-cluster-roles flag
the manager reconciles from, and the resourceNames on the manager's `bind`
grant. RBAC escalation prevention refuses a binding to rights the creator lacks
unless it holds `bind` on that exact name, so a mismatch here shows up as the
controller silently failing to promote anyone.
*/}}
{{- define "dwpk.adminClusterRoles" -}}
{{- $names := list -}}
{{- range list "userspace-admin-role" "workspace-admin-role" "workspaceimage-admin-role" "platformconfig-admin-role" "workspace-volume-admin-role" "imageregistry-admin-role" -}}
{{- $names = append $names (include "dwpk.resourceName" (dict "suffix" . "context" $)) -}}
{{- end -}}
{{- join "," $names -}}
{{- end }}

{{/*
Fully qualified image reference for a component.

Takes a dict with:
  - .image: the component's image block (repository, tag, pullPolicy)
  - .context: root context, for .Chart.AppVersion and .Values.global

global.imageRegistry prefixes the repository, which is how an air-gapped
install repoints every image at a mirror without restating each one. A
repository pinned by digest ("repo@sha256:...") keeps its digest and takes no
tag. values.schema.json has always declared global.imageRegistry; until now
nothing read it.
*/}}
{{- define "dwpk.image" -}}
{{- $image := .image -}}
{{- $registry := (.context.Values.global).imageRegistry -}}
{{- $repository := $image.repository -}}
{{- if $registry -}}
{{- $repository = printf "%s/%s" (trimSuffix "/" $registry) $repository -}}
{{- end -}}
{{- if contains "@" $repository -}}
{{- $repository -}}
{{- else -}}
{{- printf "%s:%s" $repository ($image.tag | default .context.Chart.AppVersion | toString) -}}
{{- end -}}
{{- end }}

{{/*
Image pull secrets for a component: the global ones first, then its own.

Takes a dict with .pullSecrets (the component's list) and .context. Accepts
either bare strings or {name: x} entries, because both spellings are common
enough that rejecting one is just a papercut.
*/}}
{{- define "dwpk.imagePullSecrets" -}}
{{- $all := concat ((.context.Values.global).imagePullSecrets | default list) (.pullSecrets | default list) -}}
{{- if $all -}}
imagePullSecrets:
{{- range $all }}
{{- if kindIs "string" . }}
  - name: {{ . }}
{{- else }}
  - {{ toYaml . | nindent 4 | trim }}
{{- end }}
{{- end }}
{{- end -}}
{{- end }}

{{/*
One probe, rendered without its leading key so the caller controls indentation.

Takes a dict with:
  - .probe: the values block (enabled plus timing fields)
  - .custom: a complete probe that replaces everything when set
  - .handler: the chart's own check for this component (httpGet, tcpSocket...)

The handler is chart knowledge, not user knowledge: which path reports health
is a property of the binary, so values expose the timings and an all-or-nothing
custom override rather than half a probe that cannot work.

Emits nothing when the probe is disabled, which is what lets the caller omit
the key entirely rather than write an empty one.
*/}}
{{- define "dwpk.probe" -}}
{{- $probe := .probe | default dict -}}
{{- if .custom -}}
{{- toYaml .custom -}}
{{- else if $probe.enabled -}}
{{- toYaml .handler }}
{{- range $field := list "initialDelaySeconds" "periodSeconds" "timeoutSeconds" "successThreshold" "failureThreshold" }}
{{- if hasKey $probe $field }}
{{ $field }}: {{ get $probe $field }}
{{- end }}
{{- end }}
{{- end -}}
{{- end }}

{{/*
Container env entries drawn from envFromSecrets, envFromConfigMap and env.

Takes a dict with .component (that component's values block).

Precedence follows the order below: a name taken from a Secret wins over the
same name in a ConfigMap, which wins over a plain value. Defining one name
twice is a configuration mistake either way, but resolving it by map ordering
would make the winner unpredictable between renders.

Names are upper-cased, matching the environment variables the binaries read.
*/}}
{{- define "dwpk.env" -}}
{{- $component := .component -}}
{{- $seen := dict -}}
{{- range $key, $value := ($component.envFromSecrets | default dict) }}
{{- if not (hasKey $seen $key) }}
- name: {{ $key | upper }}
  valueFrom:
    secretKeyRef:
      name: {{ $value.name }}
      key: {{ $value.key | default $key }}
{{- $_ := set $seen $key true }}
{{- end }}
{{- end }}
{{- range $key, $value := ($component.envFromConfigMap | default dict) }}
{{- if not (hasKey $seen $key) }}
- name: {{ $key | upper }}
  valueFrom:
    configMapKeyRef:
      name: {{ $value.name }}
      key: {{ $value.key | default $key }}
{{- $_ := set $seen $key true }}
{{- end }}
{{- end }}
{{- range $key, $value := ($component.env | default dict) }}
{{- if not (hasKey $seen $key) }}
- name: {{ $key | upper }}
  value: {{ $value | quote }}
{{- $_ := set $seen $key true }}
{{- end }}
{{- end }}
{{- end }}
