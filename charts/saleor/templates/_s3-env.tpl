{{/*
S3 environment variables generated if S3 is enabled
*/}}
{{- define "saleor.s3Env" -}}
{{- if .Values.storage.s3.enabled }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "saleor.fullname" . }}-s3-credentials
      key: AWS_ACCESS_KEY_ID
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "saleor.fullname" . }}-s3-credentials
      key: AWS_SECRET_ACCESS_KEY
{{- if .Values.storage.s3.config.staticBucketName }}
- name: AWS_STATIC_BUCKET_NAME
  value: {{ .Values.storage.s3.config.staticBucketName | quote }}
{{- end }}
{{- if .Values.storage.s3.config.mediaBucketName }}
- name: AWS_MEDIA_BUCKET_NAME
  value: {{ .Values.storage.s3.config.mediaBucketName | quote }}
{{- end }}
{{- if .Values.storage.s3.config.mediaPrivateBucketName }}
- name: AWS_MEDIA_PRIVATE_BUCKET_NAME
  value: {{ .Values.storage.s3.config.mediaPrivateBucketName | quote }}
{{- end }}
{{- if .Values.storage.s3.config.customDomain }}
- name: AWS_STATIC_CUSTOM_DOMAIN
  value: {{ .Values.storage.s3.config.customDomain | quote }}
{{- end }}
{{- if .Values.storage.s3.config.mediaCustomDomain }}
- name: AWS_MEDIA_CUSTOM_DOMAIN
  value: {{ .Values.storage.s3.config.mediaCustomDomain | quote }}
{{- end }}
- name: AWS_DEFAULT_ACL
  value: {{ .Values.storage.s3.config.defaultAcl | quote }}
- name: AWS_QUERYSTRING_AUTH
  # Use python / django "True" or "False"
  value: {{ .Values.storage.s3.config.queryStringAuth | ternary "True" "False" | quote }}
- name: AWS_QUERYSTRING_EXPIRE
  value: {{ .Values.storage.s3.config.queryStringExpire | quote }}
{{- end }}
{{- end -}}
