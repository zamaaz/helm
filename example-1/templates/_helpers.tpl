{{- define "partsui.fullname" -}}
{{ printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "partsui.serviceName" -}}
{{ include "partsui.fullname" . }}-svc
{{- end }}
