{{/*
Generate Redis URL based on configuration
Priority:
1. global.redisUrl if set
2. Internal Redis URL with password if redis.enabled=true
*/}}
{{- define "saleor-apps.redis.url" -}}
{{- if .Values.global.redisUrl -}}
{{- .Values.global.redisUrl -}}
{{- else -}}
{{- $redisHost := printf "%s-redis-master" .Release.Name -}}
{{- if .Values.redis.auth.enabled -}}
{{- printf "redis://:%s@%s:6379" .Values.redis.auth.password $redisHost -}}
{{- else -}}
{{- printf "redis://%s:6379" $redisHost -}}
{{- end -}}
{{- end -}}
{{- end -}}
