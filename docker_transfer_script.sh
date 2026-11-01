#!/bin/bash

# Check if the correct number of arguments was provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 {src_auth_name} {src_auth_token} {dest_auth_name} {dest_auth_token} {dest_registry_url}"
    exit 1
fi

src_auth_name=$1
src_auth_token=$2
dest_auth_name=$3
dest_auth_token=$4
dest_registry_url=$5

# Source registry URL
src_registry_url="cmc-registry.microstrategy.com"

# Progress file stored next to this script — tracks successfully transferred images.
# Delete this file to start fresh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_FILE="$SCRIPT_DIR/.docker_transfer_progress"

# Retry configuration
MAX_RETRIES=3
RETRY_DELAY=15  # seconds between retries

# Docker login to source and destination registries
echo "$src_auth_token" | docker login --username "$src_auth_name" --password-stdin "$src_registry_url"
echo "$dest_auth_token" | docker login --username "$dest_auth_name" --password-stdin "$dest_registry_url"

# Handle Ctrl+C: progress is already written per image, so just exit cleanly.
trap 'echo; echo "Interrupted. Re-run the script to resume from where it left off."; exit 130' INT TERM

transfer_image() {
    local src_image="$1"
    local dest_image="$2"

    # Skip if already successfully transferred in a previous run
    if grep -qxF "$dest_image" "$PROGRESS_FILE" 2>/dev/null; then
        echo "[SKIP] Already transferred: $dest_image"
        skipped=$(( skipped + 1 ))
        return 0
    fi

    local attempt=0
    while [ "$attempt" -lt "$MAX_RETRIES" ]; do
        attempt=$(( attempt + 1 ))
        echo "[PULL] Attempt $attempt/$MAX_RETRIES: $src_image (platform: linux/amd64)"
        if docker pull --platform linux/amd64 "$src_image"; then
            echo "[PUSH] Attempt $attempt/$MAX_RETRIES: $dest_image"
            if docker tag "$src_image" "$dest_image" && docker push "$dest_image"; then
                echo "$dest_image" >> "$PROGRESS_FILE"
                docker rmi "$src_image" "$dest_image" 2>/dev/null || true
                return 0
            fi
        fi
        if [ "$attempt" -lt "$MAX_RETRIES" ]; then
            echo "[RETRY] Waiting ${RETRY_DELAY}s before next attempt..."
            sleep "$RETRY_DELAY"
        fi
    done

    echo "[ERROR] Failed to transfer after $MAX_RETRIES attempts: $src_image"
    docker rmi "$src_image" "$dest_image" 2>/dev/null || true
    return 1
}

# Start the timer
start_time=$(date +%s)

images=(
    "cmc-registry.microstrategy.com/architect-service:cgr-m2610-.-11.6.1000.00423|architect-service:cgr-m2610-.-11.6.1000.00423"
    "cmc-registry.microstrategy.com/biweb:cgr-m2610-.-11.6.1000.00305|biweb:cgr-m2610-.-11.6.1000.00305"
    "cmc-registry.microstrategy.com/cluster-state-service:cgr-m2610-.-11.6.1000.00061|cluster-state-service:cgr-m2610-.-11.6.1000.00061"
    "cmc-registry.microstrategy.com/cloud-connector-server:cgr-m2610-.-11.6.1000.00068|cloud-connector-server:cgr-m2610-.-11.6.1000.00068"
    "cmc-registry.microstrategy.com/collabservice:cgr-m2610-.-11.6.1000.00156|collabservice:cgr-m2610-.-11.6.1000.00156"
    "cmc-registry.microstrategy.com/community-connectors:cgr-m2610-.-11.6.1000.00896|community-connectors:cgr-m2610-.-11.6.1000.00896"
    "cmc-registry.microstrategy.com/configurable-http-proxy:cgr-m2610-.-11.6.1000.00048|configurable-http-proxy:cgr-m2610-.-11.6.1000.00048"
    "cmc-registry.microstrategy.com/elasticsearch-service:cgr-m2610-.-11.6.1000.00055-2026101122|elasticsearch-service:cgr-m2610-.-11.6.1000.00055-2026101122"
    "cmc-registry.microstrategy.com/gateway-drivers-mcp:cgr-m2610-.-11.6.1000.00054|gateway-drivers-mcp:cgr-m2610-.-11.6.1000.00054"
    "cmc-registry.microstrategy.com/image-awaiter:cgr-m2610-.-11.6.1000.00093|image-awaiter:cgr-m2610-.-11.6.1000.00093"
    "cmc-registry.microstrategy.com/insight-service:cgr-m2610-.-11.6.1000.00081|insight-service:cgr-m2610-.-11.6.1000.00081"
    "cmc-registry.microstrategy.com/integrity-service:cgr-m2610-.-11.6.1000.00078|integrity-service:cgr-m2610-.-11.6.1000.00078"
    "cmc-registry.microstrategy.com/iserver:cgr-m2610-.-11.6.1000.00642|iserver:cgr-m2610-.-11.6.1000.00642"
    "cmc-registry.microstrategy.com/iserver-post-upgrade:cgr-m2610-.-11.6.1000.00642|iserver-post-upgrade:cgr-m2610-.-11.6.1000.00642"
    "cmc-registry.microstrategy.com/kafka:cgr-m2610-.-11.6.1000.00041|kafka:cgr-m2610-.-11.6.1000.00041"
    "cmc-registry.microstrategy.com/mstrbak:cgr-m2610-.-11.6.1000.01863|mstrbak:cgr-m2610-.-11.6.1000.01863"
    "cmc-registry.microstrategy.com/mstrbak-service:cgr-m2610-.-11.6.1000.01863|mstrbak-service:cgr-m2610-.-11.6.1000.01863"
    "cmc-registry.microstrategy.com/nee:cgr-m2610-.-11.6.1000.00494|nee:cgr-m2610-.-11.6.1000.00494"
    "cmc-registry.microstrategy.com/platform-analytics-consumer:cgr-m2610-.-11.6.1000.00073|platform-analytics-consumer:cgr-m2610-.-11.6.1000.00073"
    "cmc-registry.microstrategy.com/pl-microstrategy-diagnostics:cgr-m2610-.-11.6.1000.00051|pl-microstrategy-diagnostics:cgr-m2610-.-11.6.1000.00051"
    "cmc-registry.microstrategy.com/podmanager:cgr-m2610-.-11.6.1000.00106|podmanager:cgr-m2610-.-11.6.1000.00106"
    "cmc-registry.microstrategy.com/postgres:m2610-.-11.6.1000.00056|postgres:m2610-.-11.6.1000.00056"
    "cmc-registry.microstrategy.com/python-executor:cgr-m2610-.-11.6.1000.00106|python-executor:cgr-m2610-.-11.6.1000.00106"
    "cmc-registry.microstrategy.com/redis:cgr-m2610-.-11.6.1000.00043|redis:cgr-m2610-.-11.6.1000.00043"
    "cmc-registry.microstrategy.com/search-service:cgr-m2610-.-11.6.1000.00069|search-service:cgr-m2610-.-11.6.1000.00069"
    "cmc-registry.microstrategy.com/universal-semantic:cgr-m2610-.-11.6.1000.00396|universal-semantic:cgr-m2610-.-11.6.1000.00396"
    "cmc-registry.microstrategy.com/web-dossier:cgr-m2610-.-11.6.1000.01396|web-dossier:cgr-m2610-.-11.6.1000.01396"
    "cmc-registry.microstrategy.com/environment-agent:cgr-m2610-.-11.6.1000.00045|environment-agent:cgr-m2610-.-11.6.1000.00045"
    "cmc-registry.microstrategy.com/fluent-bit:5.0.10|fluent-bit:5.0.10"
    "cmc-registry.microstrategy.com/mstr-md:26.10|mstr-md:26.10"
    "cmc-registry.microstrategy.com/mstr-operator:26.10.181|mstr-operator:26.10.181"
    "cmc-registry.microstrategy.com/mstr-orchestrator/api-layer:26.10.181|mstr-orchestrator/api-layer:26.10.181"
    "cmc-registry.microstrategy.com/mstr-orchestrator/cloud-console:26.10.181|mstr-orchestrator/cloud-console:26.10.181"
    "cmc-registry.microstrategy.com/mstr-orchestrator/web-layer:26.10.181|mstr-orchestrator/web-layer:26.10.181"
    "cmc-registry.microstrategy.com/mstr-utilbox:cgr-m2610-.-11.6.1000.00046|mstr-utilbox:cgr-m2610-.-11.6.1000.00046"
    "cmc-registry.microstrategy.com/pause:1.37.1|pause:1.37.1"
    "cmc-registry.microstrategy.com/mstr-telemetry-client:26.10|mstr-telemetry-client:26.10"
    "cmc-registry.microstrategy.com/mstr-cleanup:26.10.29|mstr-cleanup:26.10.29"
    "cmc-registry.microstrategy.com/mstr-rclone:26.10.14|mstr-rclone:26.10.14"
    "cmc-registry.microstrategy.com/mstr-validator:26.10.30|mstr-validator:26.10.30"
    "cmc-registry.microstrategy.com/mstr-deployment-assistant:26.10.32|mstr-deployment-assistant:26.10.32"
    "cmc-registry.microstrategy.com/mstr-troubleshoot:26.10.105|mstr-troubleshoot:26.10.105"
    "cmc-registry.microstrategy.com/kedacore/keda-admission-webhooks:2.21.0|kedacore/keda-admission-webhooks:2.21.0"
    "cmc-registry.microstrategy.com/kedacore/keda:2.21.0|kedacore/keda:2.21.0"
    "cmc-registry.microstrategy.com/kedacore/keda-metrics-apiserver:2.21.0|kedacore/keda-metrics-apiserver:2.21.0"
    "cmc-registry.microstrategy.com/prometheus-operator/prometheus-config-reloader:0.94.1|prometheus-operator/prometheus-config-reloader:0.94.1"
    "cmc-registry.microstrategy.com/prometheus-operator/prometheus-operator:0.94.1|prometheus-operator/prometheus-operator:0.94.1"
    "cmc-registry.microstrategy.com/prometheus/prometheus:3.15.0|prometheus/prometheus:3.15.0"
    "cmc-registry.microstrategy.com/prometheus/node-exporter:1.12.1|prometheus/node-exporter:1.12.1"
    "cmc-registry.microstrategy.com/kube-state-metrics:2.20.0|kube-state-metrics:2.20.0"
    "cmc-registry.microstrategy.com/ingress-nginx/kube-webhook-certgen:v1.15.10|ingress-nginx/kube-webhook-certgen:v1.15.10"
    "cmc-registry.microstrategy.com/redis-cluster:26.10.19|redis-cluster:26.10.19"
    "cmc-registry.microstrategy.com/redis-exporter:26.10.19|redis-exporter:26.10.19"
    "cmc-registry.microstrategy.com/cnpg-operator:1.30.1|cnpg-operator:1.30.1"
    "cmc-registry.microstrategy.com/cnpg-postgres:16.15|cnpg-postgres:16.15"
    "cmc-registry.microstrategy.com/cert-manager-controller:1.21.2|cert-manager-controller:1.21.2"
    "cmc-registry.microstrategy.com/cert-manager-webhook:1.21.2|cert-manager-webhook:1.21.2"
    "cmc-registry.microstrategy.com/cert-manager-cainjector:1.21.2|cert-manager-cainjector:1.21.2"
    "cmc-registry.microstrategy.com/install-cni:1.29.8|install-cni:1.29.8"
    "cmc-registry.microstrategy.com/pilot:1.29.6|pilot:1.29.6"
    "cmc-registry.microstrategy.com/proxyv2:1.29.6|proxyv2:1.29.6"
    "cmc-registry.microstrategy.com/ai-engine-chat-service:cgr-m2610-.-11.6.1000.00931|ai-engine-chat-service:cgr-m2610-.-11.6.1000.00931"
    "cmc-registry.microstrategy.com/ai-engine-ingestion-service:cgr-m2610-.-11.6.1000.00097|ai-engine-ingestion-service:cgr-m2610-.-11.6.1000.00097"
    "cmc-registry.microstrategy.com/redis-stack-server:cgr-m2610-.-11.6.1000.00037|redis-stack-server:cgr-m2610-.-11.6.1000.00037"
    "cmc-registry.microstrategy.com/clickhouse:cgr-m2610-.-11.6.1000.00044|clickhouse:cgr-m2610-.-11.6.1000.00044"
)

failed_images=()
total=${#images[@]}
count=0
skipped=0
transferred=0
for entry in "${images[@]}"; do
    src="${entry%%|*}"
    suffix="${entry##*|}"
    dest="$dest_registry_url/$suffix"
    count=$(( count + 1 ))
    remaining=$(( total - count ))
    echo "━━━ Image $count/$total | transferred: $transferred | skipped: $skipped | remaining: $remaining ━━━"
    prev_skipped=$skipped
    if transfer_image "$src" "$dest"; then
        if [ "$skipped" -eq "$prev_skipped" ]; then
            transferred=$(( transferred + 1 ))
        fi
    else
        failed_images+=("$dest")
    fi
done

echo "━━━ Done | transferred: $transferred | skipped: $skipped | failed: ${#failed_images[@]} | total: $total ━━━"

# End the timer
end_time=$(date +%s)
elapsed_time=$(( end_time - start_time ))
echo "Transfer total time: $elapsed_time seconds"

if [ "${#failed_images[@]}" -gt 0 ]; then
    echo ""
    echo "The following images failed to transfer after $MAX_RETRIES attempts:"
    printf '  %s\n' "${failed_images[@]}"
    exit 1
fi

echo "All images transferred successfully."
rm -f "$PROGRESS_FILE"
