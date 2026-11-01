#!/bin/bash

# Check arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 {auth_name} {auth_token} [--images service1,service2]"
    exit 1
fi

auth_name=$1
auth_token=$2
shift 2

requested_images_csv=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --images)
            if [ -z "$2" ]; then
                echo "[ERROR] --images requires a comma-separated value, e.g. --images architecture-service,iserver"
                exit 1
            fi
            requested_images_csv="$2"
            shift 2
            ;;
        *)
            echo "[ERROR] Unknown argument: $1"
            echo "Usage: $0 {auth_name} {auth_token} [--images service1,service2]"
            exit 1
            ;;
    esac
done

# Registry URL
registry_url="cmc-registry.microstrategy.com"

# Progress file stored next to this script — tracks successfully pulled images.
# Delete this file to start fresh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_FILE="$SCRIPT_DIR/.docker_pull_progress"

# Retry configuration
MAX_RETRIES=3
RETRY_DELAY=15  # seconds between retries

# Docker login
echo "$auth_token" | docker login --username "$auth_name" --password-stdin "$registry_url"

# Handle Ctrl+C: progress is already written per image, so just exit cleanly.
trap 'echo; echo "Interrupted. Re-run the script to resume from where it left off."; exit 130' INT TERM

pull_image() {
    local image="$1"

    # Skip if already successfully pulled in a previous run
    if grep -qxF "$image" "$PROGRESS_FILE" 2>/dev/null; then
        echo "[SKIP] Already pulled: $image"
        skipped=$(( skipped + 1 ))
        return 0
    fi

    local attempt=0
    while [ "$attempt" -lt "$MAX_RETRIES" ]; do
        attempt=$(( attempt + 1 ))
        echo "[PULL] Attempt $attempt/$MAX_RETRIES: $image (platform: linux/amd64)"
        if docker pull --platform linux/amd64 "$image"; then
            echo "$image" >> "$PROGRESS_FILE"
            return 0
        fi
        if [ "$attempt" -lt "$MAX_RETRIES" ]; then
            echo "[RETRY] Waiting ${RETRY_DELAY}s before next attempt..."
            sleep "$RETRY_DELAY"
        fi
    done

    echo "[ERROR] Failed to pull after $MAX_RETRIES attempts: $image"
    return 1
}

# Start the timer
start_time=$(date +%s)

images=(
    "architect-service|cmc-registry.microstrategy.com/architect-service:cgr-m2610-.-11.6.1000.00423"
    "biweb|cmc-registry.microstrategy.com/biweb:cgr-m2610-.-11.6.1000.00305"
    "cluster-state-service|cmc-registry.microstrategy.com/cluster-state-service:cgr-m2610-.-11.6.1000.00061"
    "cloud-connector-server|cmc-registry.microstrategy.com/cloud-connector-server:cgr-m2610-.-11.6.1000.00068"
    "collabservice|cmc-registry.microstrategy.com/collabservice:cgr-m2610-.-11.6.1000.00156"
    "community-connectors|cmc-registry.microstrategy.com/community-connectors:cgr-m2610-.-11.6.1000.00896"
    "configurable-http-proxy|cmc-registry.microstrategy.com/configurable-http-proxy:cgr-m2610-.-11.6.1000.00048"
    "elasticsearch-service|cmc-registry.microstrategy.com/elasticsearch-service:cgr-m2610-.-11.6.1000.00055-2026101122"
    "gateway-drivers-mcp|cmc-registry.microstrategy.com/gateway-drivers-mcp:cgr-m2610-.-11.6.1000.00054"
    "image-awaiter|cmc-registry.microstrategy.com/image-awaiter:cgr-m2610-.-11.6.1000.00093"
    "insight-service|cmc-registry.microstrategy.com/insight-service:cgr-m2610-.-11.6.1000.00081"
    "integrity-service|cmc-registry.microstrategy.com/integrity-service:cgr-m2610-.-11.6.1000.00078"
    "iserver|cmc-registry.microstrategy.com/iserver:cgr-m2610-.-11.6.1000.00642"
    "iserver-post-upgrade|cmc-registry.microstrategy.com/iserver-post-upgrade:cgr-m2610-.-11.6.1000.00642"
    "kafka|cmc-registry.microstrategy.com/kafka:cgr-m2610-.-11.6.1000.00041"
    "mstrbak|cmc-registry.microstrategy.com/mstrbak:cgr-m2610-.-11.6.1000.01863"
    "mstrbak-service|cmc-registry.microstrategy.com/mstrbak-service:cgr-m2610-.-11.6.1000.01863"
    "nee|cmc-registry.microstrategy.com/nee:cgr-m2610-.-11.6.1000.00494"
    "platform-analytics-consumer|cmc-registry.microstrategy.com/platform-analytics-consumer:cgr-m2610-.-11.6.1000.00073"
    "pl-microstrategy-diagnostics|cmc-registry.microstrategy.com/pl-microstrategy-diagnostics:cgr-m2610-.-11.6.1000.00051"
    "podmanager|cmc-registry.microstrategy.com/podmanager:cgr-m2610-.-11.6.1000.00106"
    "postgres|cmc-registry.microstrategy.com/postgres:m2610-.-11.6.1000.00056"
    "python-executor|cmc-registry.microstrategy.com/python-executor:cgr-m2610-.-11.6.1000.00106"
    "redis|cmc-registry.microstrategy.com/redis:cgr-m2610-.-11.6.1000.00043"
    "search-service|cmc-registry.microstrategy.com/search-service:cgr-m2610-.-11.6.1000.00069"
    "universal-semantic|cmc-registry.microstrategy.com/universal-semantic:cgr-m2610-.-11.6.1000.00396"
    "web-dossier|cmc-registry.microstrategy.com/web-dossier:cgr-m2610-.-11.6.1000.01396"
    "environment-agent|cmc-registry.microstrategy.com/environment-agent:cgr-m2610-.-11.6.1000.00045"
    "fluent-bit|cmc-registry.microstrategy.com/fluent-bit:5.0.10"
    "mstr-md|cmc-registry.microstrategy.com/mstr-md:26.10"
    "mstr-operator|cmc-registry.microstrategy.com/mstr-operator:26.10.181"
    "mstr-orchestrator/api-layer|cmc-registry.microstrategy.com/mstr-orchestrator/api-layer:26.10.181"
    "mstr-orchestrator/cloud-console|cmc-registry.microstrategy.com/mstr-orchestrator/cloud-console:26.10.181"
    "mstr-orchestrator/web-layer|cmc-registry.microstrategy.com/mstr-orchestrator/web-layer:26.10.181"
    "mstr-utilbox|cmc-registry.microstrategy.com/mstr-utilbox:cgr-m2610-.-11.6.1000.00046"
    "pause|cmc-registry.microstrategy.com/pause:1.37.1"
    "mstr-telemetry-client|cmc-registry.microstrategy.com/mstr-telemetry-client:26.10"
    "mstr-cleanup|cmc-registry.microstrategy.com/mstr-cleanup:26.10.29"
    "mstr-rclone|cmc-registry.microstrategy.com/mstr-rclone:26.10.14"
    "mstr-validator|cmc-registry.microstrategy.com/mstr-validator:26.10.30"
    "mstr-deployment-assistant|cmc-registry.microstrategy.com/mstr-deployment-assistant:26.10.32"
    "mstr-troubleshoot|cmc-registry.microstrategy.com/mstr-troubleshoot:26.10.105"
    "kedacore/keda-admission-webhooks|cmc-registry.microstrategy.com/kedacore/keda-admission-webhooks:2.21.0"
    "kedacore/keda|cmc-registry.microstrategy.com/kedacore/keda:2.21.0"
    "kedacore/keda-metrics-apiserver|cmc-registry.microstrategy.com/kedacore/keda-metrics-apiserver:2.21.0"
    "prometheus-operator/prometheus-config-reloader|cmc-registry.microstrategy.com/prometheus-operator/prometheus-config-reloader:0.94.1"
    "prometheus-operator/prometheus-operator|cmc-registry.microstrategy.com/prometheus-operator/prometheus-operator:0.94.1"
    "prometheus/prometheus|cmc-registry.microstrategy.com/prometheus/prometheus:3.15.0"
    "prometheus/node-exporter|cmc-registry.microstrategy.com/prometheus/node-exporter:1.12.1"
    "kube-state-metrics|cmc-registry.microstrategy.com/kube-state-metrics:2.20.0"
    "ingress-nginx/kube-webhook-certgen|cmc-registry.microstrategy.com/ingress-nginx/kube-webhook-certgen:v1.15.10"
    "redis-cluster|cmc-registry.microstrategy.com/redis-cluster:26.10.19"
    "redis-exporter|cmc-registry.microstrategy.com/redis-exporter:26.10.19"
    "cnpg-operator|cmc-registry.microstrategy.com/cnpg-operator:1.30.1"
    "cnpg-postgres|cmc-registry.microstrategy.com/cnpg-postgres:16.15"
    "cert-manager-controller|cmc-registry.microstrategy.com/cert-manager-controller:1.21.2"
    "cert-manager-webhook|cmc-registry.microstrategy.com/cert-manager-webhook:1.21.2"
    "cert-manager-cainjector|cmc-registry.microstrategy.com/cert-manager-cainjector:1.21.2"
    "install-cni|cmc-registry.microstrategy.com/install-cni:1.29.8"
    "pilot|cmc-registry.microstrategy.com/pilot:1.29.6"
    "proxyv2|cmc-registry.microstrategy.com/proxyv2:1.29.6"
    "ai-engine-chat-service|cmc-registry.microstrategy.com/ai-engine-chat-service:cgr-m2610-.-11.6.1000.00931"
    "ai-engine-ingestion-service|cmc-registry.microstrategy.com/ai-engine-ingestion-service:cgr-m2610-.-11.6.1000.00097"
    "redis-stack-server|cmc-registry.microstrategy.com/redis-stack-server:cgr-m2610-.-11.6.1000.00037"
    "clickhouse|cmc-registry.microstrategy.com/clickhouse:cgr-m2610-.-11.6.1000.00044"
)

selected_images=()
missing_services=()
if [ -n "$requested_images_csv" ]; then
    IFS=',' read -r -a requested_services <<< "$requested_images_csv"
    for requested_service in "${requested_services[@]}"; do
        requested_service="$(echo "$requested_service" | xargs)"
        [ -z "$requested_service" ] && continue
        found=0
        for entry in "${images[@]}"; do
            service_name="${entry%%|*}"
            image_ref="${entry##*|}"
            if [ "$service_name" = "$requested_service" ]; then
                selected_images+=("$image_ref")
                found=1
                break
            fi
        done
        if [ "$found" -eq 0 ]; then
            missing_services+=("$requested_service")
        fi
    done

    if [ "${#missing_services[@]}" -gt 0 ]; then
        echo "[WARN] These services were not found and will be skipped:"
        printf '  %s\n' "${missing_services[@]}"
    fi

    if [ "${#selected_images[@]}" -eq 0 ]; then
        echo "[ERROR] No valid services matched --images list."
        exit 1
    fi
else
    for entry in "${images[@]}"; do
        selected_images+=("${entry##*|}")
    done
fi

failed_images=()
total=${#selected_images[@]}
count=0
skipped=0
pulled=0
for image in "${selected_images[@]}"; do
    count=$(( count + 1 ))
    remaining=$(( total - count ))
    echo "━━━ Image $count/$total | pulled: $pulled | skipped: $skipped | remaining: $remaining ━━━"
    prev_skipped=$skipped
    if pull_image "$image"; then
        if [ "$skipped" -eq "$prev_skipped" ]; then
            pulled=$(( pulled + 1 ))
        fi
    else
        failed_images+=("$image")
    fi
done

echo "━━━ Done | pulled: $pulled | skipped: $skipped | failed: ${#failed_images[@]} | total: $total ━━━"

# End the timer
end_time=$(date +%s)
elapsed_time=$(( end_time - start_time ))
echo "Pull total time: $elapsed_time seconds"

if [ "${#failed_images[@]}" -gt 0 ]; then
    echo ""
    echo "The following images failed to pull after $MAX_RETRIES attempts:"
    printf '  %s\n' "${failed_images[@]}"
    exit 1
fi

echo "All images pulled successfully."
rm -f "$PROGRESS_FILE"
