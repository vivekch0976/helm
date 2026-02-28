{{/*
Expand the name of the chart.
*/}}
{{- define "cnpg-postgres.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cnpg-postgres.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "cnpg-postgres.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cnpg-postgres.labels" -}}
helm.sh/chart: {{ include "cnpg-postgres.chart" . }}
{{ include "cnpg-postgres.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cnpg-postgres.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cnpg-postgres.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Cluster name
*/}}
{{- define "cnpg-postgres.clusterName" -}}
{{- default .Values.cluster.name (include "cnpg-postgres.fullname" .) }}
{{- end }}

{{/*
Namespace
*/}}
{{- define "cnpg-postgres.namespace" -}}
{{- default .Release.Namespace .Values.namespace.name }}
{{- end }}
