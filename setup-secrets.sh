# #!/usr/bin/env bash
# set -euo pipefail

# function usage() {
#   cat <<EOF
# Usage: $0 \
#   --host-context   <kubeconfig context of host/WDS cluster> \
#   --wds            <WDS controlplane name> \
#   --its            <ITS controlplane name> \
#   --wec-clusters   <comma-separated WEC context names>
# EOF
#   exit 1
# }

# # Parse args
# HOST_CTX="" WDS_NAME="" ITS_NAME="" WEC_CTXS=""
# while [[ $# -gt 0 ]]; do
#   case "$1" in
#     --host-context) HOST_CTX="$2"; shift;;
#     --wds)          WDS_NAME="$2";  shift;;
#     --its)          ITS_NAME="$2";  shift;;
#     --wec-clusters) WEC_CTXS="$2";  shift;;
#     *) echo "Unknown arg: $1"; usage;;
#   esac
#   shift
# done
# [[ -z $HOST_CTX || -z $WDS_NAME || -z $ITS_NAME || -z $WEC_CTXS ]] && usage

# # Switch to host cluster context
# kubectl config use-context "$HOST_CTX"

# # Helper to dump kubeconfig from a ControlPlane
# function dump_cp_cfg() {
#   local cp="$1" ref="$2" out="$3"
#   secretName=$(kubectl get controlplane "$cp" -o=jsonpath='{.status.secretRef.name}')
#   secretNS=$(kubectl get controlplane "$cp" -o=jsonpath='{.status.secretRef.namespace}')
#   dataKey=$(kubectl get controlplane "$cp" -o=jsonpath="{.status.secretRef.${ref}}")
#   kubectl get secret "$secretName" -n "$secretNS" -o=jsonpath="{.data.$dataKey}" \
#     | base64 -d >"$out"
#   echo "Dumped $cp/$ref → $out"
# }

# # Ensure namespace
# kubectl create ns latency-collector-system --dry-run=client -o yaml | kubectl apply -f -

# # Dump WDS & ITS configs
# dump_cp_cfg "$WDS_NAME" inClusterKey "wds-incluster.kubeconfig"
# dump_cp_cfg "$WDS_NAME" key          "wds-external.kubeconfig"
# dump_cp_cfg "$ITS_NAME" inClusterKey "its-incluster.kubeconfig"
# dump_cp_cfg "$ITS_NAME" key          "its-external.kubeconfig"

# # Dump each WEC external kubeconfig
# IFS=',' read -ra CLIST <<<"$WEC_CTXS"
# for ctx in "${CLIST[@]}"; do
#   kubectl --context "$ctx" config view --minify --raw >"${ctx}-external.kubeconfig"
#   echo "Dumped WEC $ctx → ${ctx}-external.kubeconfig"
# done

# # Apply secrets
# function apply_secret() {
#   local name="$1" file="$2"
#   kubectl -n latency-collector-system create secret generic "$name" \
#     --from-file=kubeconfig="$file" --dry-run=client -o yaml | kubectl apply -f -
#   echo "Secret/$name applied"
# }

# apply_secret wds-incluster   wds-incluster.kubeconfig
# apply_secret wds-external    wds-external.kubeconfig
# apply_secret its-incluster   its-incluster.kubeconfig
# apply_secret its-external    its-external.kubeconfig
# for ctx in "${CLIST[@]}"; do
#   apply_secret "wec-${ctx}-external" "${ctx}-external.kubeconfig"
# done

# echo "✅ Secrets ready in namespace latency-collector-system"


#!/usr/bin/env bash
# setup-secret.sh
# Extracts in‑cluster and external kubeconfigs from ControlPlane objects
# and creates corresponding Kubernetes Secrets in the given namespace.

set -euo pipefail

function usage() {
  cat <<EOF
Usage: $0 \
  --host-context   <kubectl context of host cluster> \
  --namespace      <target namespace> \
  --wds            <WDS ControlPlane name> \
  --its            <ITS ControlPlane name> \
  --wec            <comma-separated WEC context names>
EOF
  exit 1
}

HOST_CTX=""
NS=""
WDS_NAME=""
ITS_NAME=""
WEC_CTXS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-context) HOST_CTX="$2"; shift;;
    --namespace)    NS="$2";       shift;;
    --wds)          WDS_NAME="$2"; shift;;
    --its)          ITS_NAME="$2"; shift;;
    --wec)          WEC_CTXS="$2"; shift;;
    -h|--help)      usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
  shift
done

[[ -z $HOST_CTX || -z $NS || -z $WDS_NAME || -z $ITS_NAME || -z $WEC_CTXS ]] && usage

# Switch to host cluster
kubectl --context "$HOST_CTX" create ns "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Helper: dump one key from a ControlPlane secret
dump_cp_cfg() {
  local cp="$1" keyfield="$2" out="$3"
  secretName=$(kubectl get controlplane "$cp" -o=jsonpath='{.status.secretRef.name}')
  secretNS=$(kubectl get controlplane "$cp" -o=jsonpath='{.status.secretRef.namespace}')
  dataKey=$(kubectl get controlplane "$cp" -o=jsonpath="{.status.secretRef.${keyfield}}")
  kubectl get secret "$secretName" -n "$secretNS" \
    -o=jsonpath="{.data.$dataKey}" | base64 -d >"$out"
  echo "Dumped $cp/$keyfield → $out"
}

# Dump WDS & ITS configs
dump_cp_cfg "$WDS_NAME" inClusterKey "wds-incluster.kubeconfig"
dump_cp_cfg "$WDS_NAME" key          "wds-external.kubeconfig"
dump_cp_cfg "$ITS_NAME" inClusterKey "its-incluster.kubeconfig"
dump_cp_cfg "$ITS_NAME" key          "its-external.kubeconfig"

# Dump each WEC external kubeconfig
IFS=',' read -ra CLIST <<<"$WEC_CTXS"
for ctx in "${CLIST[@]}"; do
  kubectl --context "$ctx" config view --minify --raw >"${ctx}-external.kubeconfig"
  echo "Dumped WEC $ctx → ${ctx}-external.kubeconfig"
done

# Apply secrets into the namespace
apply_secret() {
  local name="$1" file="$2"
  kubectl -n "$NS" create secret generic "$name" \
    --from-file=kubeconfig="$file" --dry-run=client -o yaml \
    | kubectl apply -f -
  echo "Secret/$name applied"
}

apply_secret wds-incluster   wds-incluster.kubeconfig
apply_secret wds-external    wds-external.kubeconfig
apply_secret its-incluster   its-incluster.kubeconfig
apply_secret its-external    its-external.kubeconfig
for ctx in "${CLIST[@]}"; do
  apply_secret "wec-${ctx}-external" "${ctx}-external.kubeconfig"
done

echo "✅ Secrets ready in namespace $NS"
