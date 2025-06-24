{{/*
GCS environment variables generated if GCS is enabled
*/}}
{{- define "saleor.gcsEnv" -}}
{{- if .Values.storage.gcs.enabled }}
{{- if .Values.storage.gcs.config.staticBucketName }}
- name: GS_BUCKET_NAME
  value: {{ .Values.storage.gcs.config.staticBucketName | quote }}
{{- end }}
{{- if .Values.storage.gcs.config.mediaBucketName }}
- name: GS_MEDIA_BUCKET_NAME
  value: {{ .Values.storage.gcs.config.mediaBucketName | quote }}
{{- end }}
{{- if .Values.storage.gcs.config.mediaPrivateBucketName }}
- name: GS_MEDIA_PRIVATE_BUCKET_NAME
  value: {{ .Values.storage.gcs.config.mediaPrivateBucketName | quote }}
{{- end }}
{{- if .Values.storage.gcs.config.customEndpoint }}
- name: GS_CUSTOM_ENDPOINT
  value: {{ .Values.storage.gcs.config.customEndpoint | quote }}
{{- end }}
{{- if .Values.storage.gcs.config.mediaCustomEndpoint }}
- name: GS_MEDIA_CUSTOM_ENDPOINT
  value: {{ .Values.storage.gcs.config.mediaCustomEndpoint | quote }}
{{- end }}
{{- if .Values.storage.gcs.config.defaultAcl }}
- name: GS_DEFAULT_ACL
  value: {{ .Values.storage.gcs.config.defaultAcl | quote }}
{{- end }}
- name: GS_QUERYSTRING_AUTH
  value: {{ .Values.storage.gcs.config.queryStringAuth | ternary "True" "False" | quote }}
{{- if .Values.storage.gcs.config.queryStringExpire }}
- name: GS_EXPIRATION
  value: {{ .Values.storage.gcs.config.queryStringExpire | quote }}
{{- end }}
{{- if .Values.storage.gcs.credentials.jsonKey }}
- name: GOOGLE_APPLICATION_CREDENTIALS
  value: "/var/secrets/google/credentials.json"
{{- end }}
{{- end }}
{{- end -}}
