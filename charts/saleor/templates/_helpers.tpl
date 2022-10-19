{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "saleor-helm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "saleor-helm.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "saleor-helm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "saleor.internalDatabaseUrl" -}}
{{- if eq .Values.postgresql.architecture "replication" -}}
{{- printf "%s%s%s%s%s%s%s%s" "postgresql://" .Values.postgresql.auth.username ":" .Values.postgresql.auth.password "@" .Release.Name "-postgresql-primary:5432/" .Values.postgresql.auth.database }}
{{- else -}}
{{- printf "%s%s%s%s%s%s%s%s" "postgresql://" .Values.postgresql.auth.username ":" .Values.postgresql.auth.password "@" .Release.Name "-postgresql:5432/" .Values.postgresql.auth.database }}
{{- end -}}
{{- end -}}


{{- define "saleor.internalDatabaseUrlRead" -}}
{{- printf "%s%s%s%s%s%s%s%s" "postgresql://" .Values.postgresql.auth.username ":" .Values.postgresql.auth.password "@" .Release.Name "-postgresql-read:5432/" .Values.postgresql.auth.database }}
{{- end }}

{{- define "saleor.internalPgPoolUrl" -}}
{{- printf "%s%s%s%s%s%s%s%s" "postgresql://" .Values.postgresql.auth.username ":" .Values.postgresql.auth.password "@" .Values.saleor.pgpool.serviceName ":5432/" .Values.postgresql.auth.database }}
{{- end }}


{{/*
Common labels
*/}}
{{- define "saleor-helm.labels" -}}
helm.sh/chart: {{ include "saleor-helm.chart" . }}
{{ include "saleor-helm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "saleor-helm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "saleor-helm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "saleor-helm.selectorLabelsCelery" -}}
app.kubernetes.io/name: "celery-worker"
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "saleor-helm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "saleor-helm.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.imageCredentials.registry (printf "%s:%s" .Values.imageCredentials.username .Values.imageCredentials.password | b64enc) | b64enc }}
{{- end }}