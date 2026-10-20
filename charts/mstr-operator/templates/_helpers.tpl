{{/*
Generate Password With Numeric/Alphabet chars
The complexity is following the mci-tools generatePassword.
at least 1 uppercase letter
at least 1 lowercase letter
at least 1 number
*/}}
{{- define "common.generateRandomPassword" -}}
{{- $upper := upper (randAlpha 1) -}}
{{- $lower := lower (randAlpha 1) -}}
{{- $num := randNumeric 1 -}}
{{- $rest := randAlphaNum 7 -}}
{{- $tempResult := printf "%s%s%s%s" $upper $lower $num $rest -}}
{{- $pwd := shuffle $tempResult -}}
{{- printf "%s" $pwd -}}
{{- end -}}

{{/*
Generate clusterName with 8 random Numeric/Alphabet chars.
*/}}
{{- define "common.generateRandomClusterName" -}}
{{- $randomStr := randAlphaNum 8 | lower -}}
{{- printf "cluster-%s" $randomStr -}}
{{- end -}}

{{- define "common.generateRandomCron" -}}
{{- $minute := randInt 0 59 }}
{{- $hour := randInt 0 23 }}
{{- printf "%02d %02d * * *" $minute $hour }}
{{- end -}}

{{- define "common.initContainerResources" -}}
resources:
  requests:
    memory: 256Mi
    {{- if .Values.customizations.cpuResourcesEnabled }}
    cpu: 50m
    {{- end }}
  limits:
    memory: 512Mi
    {{- if .Values.customizations.cpuResourcesEnabled }}
    cpu: 200m
    {{- end }}
{{- end -}}

{{- define "common.volumePermissions" -}}
- args:
    - chown 1000:1000 /tmp;
      if [ -d /tmp/operator/config ]; then
        chown -R 1000:1000 /tmp/operator/config;
      fi;
      if [ -d /tmp/operator/helm ]; then
        chown -R 1000:1000 /tmp/operator/helm;
      fi;
  command:
    - /bin/sh
    - -c
  image: {{.Values.global.image.registry}}/mstr-utilbox:{{.Values.global.mstrUtilboxTag}}
  imagePullPolicy: {{.Values.global.image.imagePullPolicy}}
  name: volume-permissions
  env:
  - name: CLUSTER_NAME
    valueFrom:
      configMapKeyRef:
        key: name
        name: mstr-operator-config
  {{- include "common.initContainerResources" . | nindent 2 }}
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      add:
        - CHOWN
      drop:
        - ALL
    runAsGroup: 0
    runAsUser: 0
    seccompProfile:
      type: RuntimeDefault
  volumeMounts:
    - mountPath: /tmp
      name: operator-volume
      subPathExpr: $(CLUSTER_NAME)
{{- end -}}

{{- define "common.isOpenshiftCluster" -}}
{{- $isOpenshift := false -}}
{{- if or (.Values.global.openshift.enabled) (.Capabilities.APIVersions.Has "security.openshift.io/v1") -}}
{{- $isOpenshift = true -}}
{{- end -}}
{{- $isOpenshift -}}
{{- end -}}

{{/*
Detect whether a cluster uses OpenShift Service Mesh
*/}}
{{- define "common.isOpenshiftServiceMesh" -}}
{{- $isOpenshift := false -}}
{{- if or (.Values.global.openshiftServiceMesh.enabled) (and (.Capabilities.APIVersions.Has "security.openshift.io/v1") (.Capabilities.APIVersions.Has "maistra.io/v2")) -}}
{{- $isOpenshift = true -}}
{{- end -}}
{{- $isOpenshift -}}
{{- end -}}

{{/*
Generate or resolve cluster name.
Priority:
  1. ConfigMap "mstr-operator-config" -> key "name"
  2. Secret "mstr-operator-cluster" -> key "name" (base64 decoded)
  3. Generate random name using common.generateRandomClusterName
*/}}
{{- define "common.resolveClusterName" -}}
{{- $namespace := .Release.Namespace -}}
{{- $cmName := "mstr-operator-config" -}}
{{- $secretName := "mstr-operator-cluster" -}}

{{- /* lookup ConfigMap */}}
{{- $existingCM := (lookup "v1" "ConfigMap" $namespace $cmName) -}}
{{- if and $existingCM $existingCM.data (index $existingCM.data "name") -}}
  {{- index $existingCM.data "name" -}}

{{- /* lookup Secret */}}
{{- else -}}
  {{- $existingSecret := (lookup "v1" "Secret" $namespace $secretName) -}}
  {{- if and $existingSecret $existingSecret.data (index $existingSecret.data "name") -}}
    {{- index $existingSecret.data "name" | b64dec -}}

  {{- /* default */}}
  {{- else -}}
    {{- include "common.generateRandomClusterName" . -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
The effective host-network switch of network diagnosis. Unset follows the capability switch, so turning
the capability on offers the view; an explicit false narrows the installation, and that view is then not
planned at all — no host-network Pod is created, and this chart does not widen the SCC for it. A switch
set while the capability itself is off widens nothing either.
`default` cannot be used here: it treats false as empty and would silently ignore the narrowing.
*/}}
{{- define "common.networkDiagnose.hostNetworkEnabled" -}}
{{- $diagnose := .Values.apilayer.networkDiagnose -}}
{{- $wanted := true -}}
{{- if not (kindIs "invalid" $diagnose.hostNetworkEnabled) -}}{{- $wanted = $diagnose.hostNetworkEnabled -}}{{- end -}}
{{- and $diagnose.enabled $wanted -}}
{{- end -}}

{{/* The effective privileged switch, resolved exactly like the host-network one above. */}}
{{- define "common.networkDiagnose.privilegedEnabled" -}}
{{- $diagnose := .Values.apilayer.networkDiagnose -}}
{{- $wanted := true -}}
{{- if not (kindIs "invalid" $diagnose.privilegedEnabled) -}}{{- $wanted = $diagnose.privilegedEnabled -}}{{- end -}}
{{- and $diagnose.enabled $wanted -}}
{{- end -}}