#!/usr/bin/env bash
# bootstrap-kubeconfigs.sh
# Extracts in-cluster & external kubeconfigs for control planes (WDS, ITS)
# and for each WEC cluster; creates Secrets in the WDS hosting cluster.

set -euo pipefail

function usage() {
  cat <<EOF
Usage: $0 \
  --host-context   <kubeconfig context of host/WDS cluster> \
  --wds            <WDS controlplane name> \
  --its            <ITS controlplane name> \
  --wec-clusters   <comma-separated WEC context names>
EOF
  exit 1
}

# Parse args
HOST_CTX="" WDS_NAME="" ITS_NAME="" WEC_CTXS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-context) HOST_CTX="$2"; shift;;
    --wds)          WDS_NAME="$2";  shift;;
    --its)          ITS_NAME="$2";  shift;;
    --wec-clusters) WEC_CTXS="$2";  shift;;
    *) echo "Unknown arg: $1"; usage;;
  esac
  shift
done
[[ -z $HOST_CTX || -z $WDS_NAME || -z $ITS_NAME || -z $WEC_CTXS ]] && usage

# Switch kubectl context to host/WDS cluster
kubectl config use-context "$HOST_CTX"

# Helper: fetch and decode a kubeconfig from a ControlPlane
# $1: CP name; $2: secretRef field name ("key" or "inClusterKey"); $3: output file
function dump_controlplane_kubeconfig() {
  local cp="$1" refField="$2" dest="$3"

  # Get the secret name and namespace
  local secretName
  secretName=$(kubectl get controlplane "$cp" \
    -o=jsonpath='{.status.secretRef.name}')
  local secretNS
  secretNS=$(kubectl get controlplane "$cp" \
    -o=jsonpath='{.status.secretRef.namespace}')

  # Get the actual data key (e.g., "kubeconfig", "config", etc.)
  local dataKey
  dataKey=$(kubectl get controlplane "$cp" \
    -o=jsonpath="{.status.secretRef.${refField}}")

  # Extract and decode
  kubectl get secret "$secretName" -n "$secretNS" \
    -o=jsonpath="{.data.$dataKey}" \
    | base64 -d >"$dest"
  echo "Wrote $cp/$refField ($dataKey) → $dest"
}

# 1. Create namespace for secrets (if missing)
kubectl create namespace "${WDS_NAME}-system" >/dev/null 2>&1 || true

# 2. Dump WDS and ITS kubeconfigs using dynamic key lookup
dump_controlplane_kubeconfig "$WDS_NAME" inClusterKey "wds-incluster.kubeconfig"
dump_controlplane_kubeconfig "$WDS_NAME" key          "wds-external.kubeconfig"
dump_controlplane_kubeconfig "$ITS_NAME" inClusterKey "its-incluster.kubeconfig"
dump_controlplane_kubeconfig "$ITS_NAME" key          "its-external.kubeconfig"

# 3. For each WEC cluster, dump external kubeconfig via client kubeconfig
IFS=',' read -ra CLIST <<<"$WEC_CTXS"
for ctx in "${CLIST[@]}"; do
  outfile="${ctx}-external.kubeconfig"
  kubectl --context "$ctx" config view --minify --raw >"$outfile"
  echo "Wrote WEC $ctx external → $outfile"
done

# 4. Create/update Secrets in WDS namespace
function apply_kubeconfig_secret() {
  local name="$1" file="$2"
  kubectl -n "${WDS_NAME}-system" create secret generic "$name" \
    --from-file=kubeconfig="$file" \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "Secret/$name created/updated"
}

apply_kubeconfig_secret wds-incluster   wds-incluster.kubeconfig
apply_kubeconfig_secret wds-external    wds-external.kubeconfig
apply_kubeconfig_secret its-incluster   its-incluster.kubeconfig
apply_kubeconfig_secret its-external    its-external.kubeconfig
for ctx in "${CLIST[@]}"; do
  apply_kubeconfig_secret "wec-${ctx}-external" "${ctx}-external.kubeconfig"
done

echo
echo "✅ All kubeconfig Secrets are ready in namespace: ${WDS_NAME}-system"
echo "Proceed with: make deploy"
