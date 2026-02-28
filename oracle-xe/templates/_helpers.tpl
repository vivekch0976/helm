{{/*
Expand the name of the chart.
*/}}
{{- define "oracle-xe.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "oracle-xe.fullname" -}}
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
{{- define "oracle-xe.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "oracle-xe.labels" -}}
helm.sh/chart: {{ include "oracle-xe.chart" . }}
{{ include "oracle-xe.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "oracle-xe.selectorLabels" -}}
app.kubernetes.io/name: {{ include "oracle-xe.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Namespace
*/}}
{{- define "oracle-xe.namespace" -}}
{{- default .Release.Namespace .Values.namespace.name }}
{{- end }}

{{/*
Image name
*/}}
{{- define "oracle-xe.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}
