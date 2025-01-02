{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "saleor.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "saleor.fullname" -}}
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
{{- define "saleor.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "saleor.labels" -}}
helm.sh/chart: {{ include "saleor.chart" . }}
{{ include "saleor.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "saleor.selectorLabels" -}}
app.kubernetes.io/name: {{ include "saleor.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "saleor.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "saleor.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "saleor.internalRedisUrl" -}}
{{- printf "%s%s%s%s%s%s" "redis://:" .Values.redis.auth.password "@" .Release.Name "-redis-master:6379/" -}}
{{- end -}}

{{/*
Get PostgreSQL password - either from values, existing secret, or generate new one
*/}}
{{- define "saleor.postgresqlPassword" -}}
{{- if .Values.postgresql.auth.postgresPassword -}}
{{- .Values.postgresql.auth.postgresPassword -}}
{{- else -}}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace "postgresql-credentials") -}}
{{- if $secret -}}
{{- index $secret.data "postgresql-password" | b64dec -}}
{{- else -}}
{{- $generatedPassword := randAlphaNum 32 -}}
{{- $_ := set .Values.postgresql.auth "postgresPassword" $generatedPassword -}}
{{- $generatedPassword -}}
{{- end -}}
{{- end -}}
{{- end -}} 

{{/*
Get the database URL with password from postgresql-credentials secret
*/}}
{{- define "saleor.databaseUrl" -}}
{{- if .Values.global.database.primaryUrl -}}
{{- .Values.global.database.primaryUrl -}}
{{- else if .Values.postgresql.enabled -}}
{{- $postgresqlPassword := include "saleor.postgresqlPassword" . -}}
{{- printf "postgresql://%s:%s@%s-postgresql-primary:5432/%s" "postgres" $postgresqlPassword (include "saleor.fullname" .) "postgres" -}}
{{- end -}}
{{- end -}}

{{/*
Get the database read URLs with password from postgresql-credentials secret
*/}}
{{- define "saleor.databaseReadUrls" -}}
{{- if .Values.global.database.replicaUrls -}}
{{- .Values.global.database.replicaUrls | toJson -}}
{{- else if and .Values.postgresql.enabled (eq .Values.postgresql.architecture "replication") -}}
{{- $postgresqlPassword := include "saleor.postgresqlPassword" . -}}
{{- printf "[\"postgresql://%s:%s@%s-postgresql-read:5432/%s\"]" "postgres" $postgresqlPassword (include "saleor.fullname" .) "postgres" -}}
{{- end -}}
{{- end -}}