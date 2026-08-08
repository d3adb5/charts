{{/*
Expand the name of the chart.
*/}}
{{- define "mediamtx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mediamtx.fullname" -}}
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
{{- define "mediamtx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mediamtx.labels" -}}
helm.sh/chart: {{ include "mediamtx.chart" . }}
{{ include "mediamtx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mediamtx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mediamtx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Full image reference, honoring image.variant.
*/}}
{{- define "mediamtx.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- if .Values.image.variant }}
{{- printf "%s:%s-%s" .Values.image.repository $tag .Values.image.variant }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}
{{- end }}

{{/*
Name of the Secret holding the internal users' passwords, whichever way it is
provided (existing / sealed / generated).
*/}}
{{- define "mediamtx.authSecretName" -}}
{{- .Values.auth.existingSecret | default (printf "%s-auth" (include "mediamtx.fullname" .)) }}
{{- end }}

{{/*
Every listener the chart knows about, as a YAML list of

  - name:     container/Service port name
    port:     port number
    protocol: TCP or UDP
    kind:     "http" (routable through an Ingress) or "raw"
    expose:   whether to publish it on the LoadBalancer Service ("raw" only)

This is the single source of truth for container ports, both Services and the
Ingress backend, so a protocol is only ever enabled in one place.
*/}}
{{- define "mediamtx.ports" -}}
{{- $p := .Values.protocols -}}
{{- $ports := list -}}
{{- if $p.rtsp.enabled -}}
  {{- $ports = append $ports (dict "name" "rtsp" "port" (int $p.rtsp.port) "protocol" "TCP" "kind" "raw" "expose" (default false $p.rtsp.expose)) -}}
  {{/* UDP transports need the RTP/RTCP pair alongside the control port. */}}
  {{- $transports := default (list "tcp") .Values.mtxConfig.rtspTransports -}}
  {{- if or (has "udp" $transports) (has "multicast" $transports) -}}
    {{- $ports = append $ports (dict "name" "rtp" "port" (int $p.rtsp.rtpPort) "protocol" "UDP" "kind" "raw" "expose" (default false $p.rtsp.expose)) -}}
    {{- $ports = append $ports (dict "name" "rtcp" "port" (int $p.rtsp.rtcpPort) "protocol" "UDP" "kind" "raw" "expose" (default false $p.rtsp.expose)) -}}
  {{- end -}}
{{- end -}}
{{- if $p.rtmp.enabled -}}
  {{- $ports = append $ports (dict "name" "rtmp" "port" (int $p.rtmp.port) "protocol" "TCP" "kind" "raw" "expose" (default false $p.rtmp.expose)) -}}
{{- end -}}
{{- if $p.srt.enabled -}}
  {{- $ports = append $ports (dict "name" "srt" "port" (int $p.srt.port) "protocol" "UDP" "kind" "raw" "expose" (default false $p.srt.expose)) -}}
{{- end -}}
{{- if $p.webrtc.enabled -}}
  {{/* Signalling/WHIP/WHEP is plain HTTP and belongs behind the Ingress... */}}
  {{- $ports = append $ports (dict "name" "webrtc" "port" (int $p.webrtc.port) "protocol" "TCP" "kind" "http" "expose" false) -}}
  {{/* ...while media itself flows over the ICE port, which cannot be. */}}
  {{- if $p.webrtc.icePort -}}
    {{- $ports = append $ports (dict "name" "webrtc-ice" "port" (int $p.webrtc.icePort) "protocol" "UDP" "kind" "raw" "expose" (default false $p.webrtc.expose)) -}}
  {{- end -}}
{{- end -}}
{{- if $p.moq.enabled -}}
  {{/* MoQ mandates TLS, so it terminates in MediaMTX rather than the Ingress. */}}
  {{- $ports = append $ports (dict "name" "moq-h2" "port" (int $p.moq.port) "protocol" "TCP" "kind" "raw" "expose" (default false $p.moq.expose)) -}}
  {{- $ports = append $ports (dict "name" "moq-h3" "port" (int $p.moq.port) "protocol" "UDP" "kind" "raw" "expose" (default false $p.moq.expose)) -}}
{{- end -}}
{{- if $p.hls.enabled -}}
  {{- $ports = append $ports (dict "name" "hls" "port" (int $p.hls.port) "protocol" "TCP" "kind" "http" "expose" false) -}}
{{- end -}}
{{- if $p.api.enabled -}}
  {{- $ports = append $ports (dict "name" "api" "port" (int $p.api.port) "protocol" "TCP" "kind" "http" "expose" false) -}}
{{- end -}}
{{- if $p.metrics.enabled -}}
  {{- $ports = append $ports (dict "name" "metrics" "port" (int $p.metrics.port) "protocol" "TCP" "kind" "http" "expose" false) -}}
{{- end -}}
{{- if $p.playback.enabled -}}
  {{- $ports = append $ports (dict "name" "playback" "port" (int $p.playback.port) "protocol" "TCP" "kind" "http" "expose" false) -}}
{{- end -}}
{{- if $p.pprof.enabled -}}
  {{- $ports = append $ports (dict "name" "pprof" "port" (int $p.pprof.port) "protocol" "TCP" "kind" "http" "expose" false) -}}
{{- end -}}
{{- toYaml $ports }}
{{- end }}

{{/*
The subset of mediamtx.ports that lands on the LoadBalancer Service.
*/}}
{{- define "mediamtx.rawPorts" -}}
{{- $out := list -}}
{{- range include "mediamtx.ports" . | fromYamlArray -}}
{{- if and (eq .kind "raw") .expose -}}
{{- $out = append $out . -}}
{{- end -}}
{{- end -}}
{{- toYaml $out }}
{{- end }}

{{/*
The subset of mediamtx.ports that lands on the HTTP Service.
*/}}
{{- define "mediamtx.httpPorts" -}}
{{- $out := list -}}
{{- range include "mediamtx.ports" . | fromYamlArray -}}
{{- if eq .kind "http" -}}
{{- $out = append $out . -}}
{{- end -}}
{{- end -}}
{{- toYaml $out }}
{{- end }}

{{/*
authInternalUsers, built from auth.users (password supplied at runtime through
MTX_AUTHINTERNALUSERS_<i>_PASS) followed by any explicitly anonymous entries.
Order matters: the index of a user here is the index used in the env var name.
*/}}
{{- define "mediamtx.authInternalUsers" -}}
{{- $users := list -}}
{{- range .Values.auth.users -}}
  {{- $permissions := list -}}
  {{- range .permissions -}}
    {{- if kindIs "string" . -}}
      {{- $permissions = append $permissions (dict "action" .) -}}
    {{- else -}}
      {{- $permissions = append $permissions . -}}
    {{- end -}}
  {{- end -}}
  {{- $entry := dict "user" .name "permissions" $permissions -}}
  {{- with .ips -}}
    {{- $_ := set $entry "ips" . -}}
  {{- end -}}
  {{- $users = append $users $entry -}}
{{- end -}}
{{- range .Values.auth.anonymous -}}
  {{- $permissions := list -}}
  {{- range .permissions -}}
    {{- if kindIs "string" . -}}
      {{- $permissions = append $permissions (dict "action" .) -}}
    {{- else -}}
      {{- $permissions = append $permissions . -}}
    {{- end -}}
  {{- end -}}
  {{- $entry := dict "user" "any" "permissions" $permissions -}}
  {{- with .ips -}}
    {{- $_ := set $entry "ips" . -}}
  {{- end -}}
  {{- $users = append $users $entry -}}
{{- end -}}
{{- toYaml $users }}
{{- end }}

{{/*
The configuration keys the chart owns, derived from .Values.protocols and
.Values.auth. Anything not listed here comes from .Values.mtxConfig.
*/}}
{{- define "mediamtx.generatedConfig" -}}
{{- $p := .Values.protocols }}
authInternalUsers:
  {{- include "mediamtx.authInternalUsers" . | nindent 2 }}
rtsp: {{ $p.rtsp.enabled }}
{{- if $p.rtsp.enabled }}
rtspAddress: ":{{ $p.rtsp.port }}"
rtpAddress: ":{{ $p.rtsp.rtpPort }}"
rtcpAddress: ":{{ $p.rtsp.rtcpPort }}"
{{- end }}
rtmp: {{ $p.rtmp.enabled }}
{{- if $p.rtmp.enabled }}
rtmpAddress: ":{{ $p.rtmp.port }}"
{{- end }}
srt: {{ $p.srt.enabled }}
{{- if $p.srt.enabled }}
srtAddress: ":{{ $p.srt.port }}"
{{- end }}
webrtc: {{ $p.webrtc.enabled }}
{{- if $p.webrtc.enabled }}
webrtcAddress: ":{{ $p.webrtc.port }}"
webrtcLocalUDPAddress: "{{ if $p.webrtc.icePort }}:{{ $p.webrtc.icePort }}{{ end }}"
{{- with $p.webrtc.additionalHosts }}
webrtcAdditionalHosts:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
moq: {{ $p.moq.enabled }}
{{- if $p.moq.enabled }}
moqHTTP2Address: ":{{ $p.moq.port }}"
moqHTTP3Address: ":{{ $p.moq.port }}"
{{- end }}
hls: {{ $p.hls.enabled }}
{{- if $p.hls.enabled }}
hlsAddress: ":{{ $p.hls.port }}"
{{- end }}
api: {{ $p.api.enabled }}
{{- if $p.api.enabled }}
apiAddress: ":{{ $p.api.port }}"
{{- end }}
metrics: {{ $p.metrics.enabled }}
{{- if $p.metrics.enabled }}
metricsAddress: ":{{ $p.metrics.port }}"
{{- end }}
playback: {{ $p.playback.enabled }}
{{- if $p.playback.enabled }}
playbackAddress: ":{{ $p.playback.port }}"
{{- end }}
pprof: {{ $p.pprof.enabled }}
{{- if $p.pprof.enabled }}
pprofAddress: ":{{ $p.pprof.port }}"
{{- end }}
{{- end }}

{{/*
The complete mediamtx.yml: generated keys win over mtxConfig, which supplies
everything else.
*/}}
{{- define "mediamtx.config" -}}
{{- $generated := include "mediamtx.generatedConfig" . | fromYaml -}}
{{- toYaml (merge $generated (deepCopy .Values.mtxConfig)) }}
{{- end }}

{{/*
Fail early on value combinations that would otherwise produce a server that
rejects everything, or a pod that never starts.
*/}}
{{- define "mediamtx.validate" -}}
{{- $auth := .Values.auth -}}
{{- if and $auth.existingSecret $auth.sealed -}}
  {{- fail "auth.existingSecret and auth.sealed are mutually exclusive" -}}
{{- end -}}
{{- if not (or $auth.users $auth.anonymous) -}}
  {{- fail "auth.users and auth.anonymous are both empty: MediaMTX would deny every request. Define at least one user." -}}
{{- end -}}
{{- range $auth.users -}}
  {{- if not .name -}}
    {{- fail "every entry in auth.users needs a name" -}}
  {{- end -}}
  {{- if not .permissions -}}
    {{- fail (printf "auth user %q has no permissions" .name) -}}
  {{- end -}}
  {{- if and $auth.sealed (not (hasKey $auth.sealed .name)) -}}
    {{- fail (printf "auth.sealed has no encrypted password for user %q" .name) -}}
  {{- end -}}
{{- end -}}
{{- $names := list -}}
{{- range include "mediamtx.ports" . | fromYamlArray -}}
  {{- $names = append $names .name -}}
{{- end -}}
{{- range $probe := list .Values.livenessProbe .Values.readinessProbe -}}
  {{- with $probe -}}
    {{- with .tcpSocket -}}
      {{- if and (kindIs "string" .port) (not (has .port $names)) -}}
        {{- fail (printf "probe references port %q, which no enabled protocol provides (available: %s)" .port (join ", " $names)) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end }}
