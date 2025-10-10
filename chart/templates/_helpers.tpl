{{/*
Define common labels used throughout the chart.
*/}}
{{- define "kube-news.labels" -}}
helm.sh/chart: {{ include "kube-news.chart" . }}
{{ include "kube-news.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels used by Deployments and Services.
*/}}
{{- define "kube-news.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kube-news.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the chart.
*/}}
{{- define "kube-news.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kube-news.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | trunc 63 | trimSuffix "-" -}}
{{- end -}}
