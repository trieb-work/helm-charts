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

{{/*
Get Redis password - either from values, existing secret, or generate new one
*/}}
{{- define "saleor.redisPassword" -}}
{{- if .Values.redis.auth.password -}}
{{- .Values.redis.auth.password -}}
{{- else -}}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace (printf "%s-redis" .Release.Name)) -}}
{{- if $secret -}}
{{- index $secret.data "redis-password" | b64dec -}}
{{- else -}}
{{- $generatedPassword := randAlphaNum 32 -}}
{{- $_ := set .Values.redis.auth "password" $generatedPassword -}}
{{- $generatedPassword -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get internal Redis URL with database 0 for general usage
*/}}
{{- define "saleor.internalRedisUrl" -}}
{{- if .Values.redis.auth.enabled -}}
{{- $redisPassword := include "saleor.redisPassword" . -}}
{{- printf "redis://:%s@%s-redis-master:6379/0" $redisPassword .Release.Name -}}
{{- else -}}
{{- printf "redis://%s-redis-master:6379/0" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Get internal Redis URL with database 1 for Celery
*/}}
{{- define "saleor.internalCeleryRedisUrl" -}}
{{- if .Values.redis.auth.enabled -}}
{{- $redisPassword := include "saleor.redisPassword" . -}}
{{- printf "redis://:%s@%s-redis-master:6379/1" $redisPassword .Release.Name -}}
{{- else -}}
{{- printf "redis://%s-redis-master:6379/1" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Get Redis URL - either from global value, external config, or internal Redis
*/}}
{{- define "saleor.redisUrl" -}}
{{- if .Values.global.redisUrl -}}
{{- .Values.global.redisUrl -}}
{{- else if not .Values.redis.enabled -}}
{{- $host := required "External Redis host is required when redis.enabled=false" .Values.redis.external.host -}}
{{- $port := .Values.redis.external.port | default "6379" -}}
{{- $db := .Values.redis.external.database | default "0" -}}
{{- $username := .Values.redis.external.username -}}
{{- $password := .Values.redis.external.password -}}
{{- $protocol := ternary "rediss" "redis" .Values.redis.external.tls.enabled -}}
{{- if and $username $password -}}
{{- printf "%s://%s:%s@%s:%s/%s" $protocol $username $password $host $port $db -}}
{{- else if $password -}}
{{- printf "%s://:%s@%s:%s/%s" $protocol $password $host $port $db -}}
{{- else -}}
{{- printf "%s://%s:%s/%s" $protocol $host $port $db -}}
{{- end -}}
{{- else -}}
{{- include "saleor.internalRedisUrl" . -}}
{{- end -}}
{{- end -}}

{{/*
Get Celery Redis URL - either from global value, external config, or internal Redis
*/}}
{{- define "saleor.celeryRedisUrl" -}}
{{- if .Values.global.celeryRedisUrl -}}
{{- .Values.global.celeryRedisUrl -}}
{{- else if not .Values.redis.enabled -}}
{{- $host := required "External Redis host is required when redis.enabled=false" .Values.redis.external.host -}}
{{- $port := .Values.redis.external.port | default "6379" -}}
{{- $db := .Values.redis.external.celeryDatabase | default "1" -}}
{{- $username := .Values.redis.external.username -}}
{{- $password := .Values.redis.external.password -}}
{{- $protocol := ternary "rediss" "redis" .Values.redis.external.tls.enabled -}}
{{- if and $username $password -}}
{{- printf "%s://%s:%s@%s:%s/%s" $protocol $username $password $host $port $db -}}
{{- else if $password -}}
{{- printf "%s://:%s@%s:%s/%s" $protocol $password $host $port $db -}}
{{- else -}}
{{- printf "%s://%s:%s/%s" $protocol $host $port $db -}}
{{- end -}}
{{- else -}}
{{- include "saleor.internalCeleryRedisUrl" . -}}
{{- end -}}
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

{{/*
Get the database read replica URL
*/}}
{{- define "saleor.databaseReplicaUrl" -}}
{{- if .Values.global.database.replicaUrl -}}
{{- .Values.global.database.replicaUrl -}}
{{- else if and .Values.postgresql.enabled (eq .Values.postgresql.architecture "replication") -}}
{{- $postgresqlPassword := include "saleor.postgresqlPassword" . -}}
{{- printf "postgresql://%s:%s@%s-postgresql-read:5432/%s" "postgres" $postgresqlPassword (include "saleor.fullname" .) "postgres" -}}
{{- else -}}
{{- include "saleor.databaseUrl" . -}}
{{- end -}}
{{- end -}}

{{/*
Determine if read replica is enabled
*/}}
{{- define "saleor.readReplicaEnabled" -}}
{{- if or (and (not .Values.postgresql.enabled) .Values.global.database.replicaUrl) (and .Values.postgresql.enabled (eq .Values.postgresql.architecture "replication")) -}}
{{- true -}}
{{- end -}}
{{- end -}}

{{/*
Determine if this is a cloud instance based on the apps marketplace URL
Returns "true" if a custom marketplace URL is set and doesn't contain apps.saleor.io/
Returns "false" otherwise
s you to directly install your own apps from the dashboard*/}}
{{- define "saleor.isCloudInstance" -}}
{{- if and .Values.dashboard.appsMarketplaceApiUrl (not (contains "apps.saleor.io/" .Values.dashboard.appsMarketplaceApiUrl)) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}