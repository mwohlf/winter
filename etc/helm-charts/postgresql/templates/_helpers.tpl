{{/* vim: set filetype=mustache: */}}
{{/*

  minus blank at the beging and end of brackets remove trailing or preceeding whitespace
  .Values : properties coming from the values.yaml file
  .Release : object describes the release itself
  .Chart : The contents of the Chart.yaml file.
  .Capabilities : provides information about what capabilities the Kubernetes cluster supports.

  The built-in values always begin with a capital letter.
  see: https://helm.sh/docs/topics/chart_template_guide/builtin_objects/





*/}}

{{/*
 function to render the chart name,
 use .Values.nameOverride and default to .Chart.Name
*/}}
{{- define "postgresql.name" -}}
{{- .Values.nameOverride | default .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "postgresql.fullname" -}}
{{- $name := .Values.nameOverride | default .Chart.Name -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "postgresql.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selector labels
this is included by "{{- include "postgresql.selectorLabels" . | nindent 6 }}"
*/}}
{{- define "postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "postgresql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Common labels
this is included by "{{- include "postgresql.labels" . | nindent 4 }}"
*/}}
{{- define "postgresql.labels" -}}
helm.sh/chart: {{ include "postgresql.chart" . }}
{{ include "postgresql.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Return PostgreSQL port
*/}}
{{- define "postgresql.port" -}}
{{- .Values.service.port -}}
{{- end -}}
