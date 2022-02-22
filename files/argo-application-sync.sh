#!/bin/bash

# functions
function getNotSynced() {
  oc get applications  --insecure-skip-tls-verify -o jsonpath='{.items[*].status.sync}' --kubeconfig="${KUBECONFIG}" | jq 'select(.status != "Synced")' -c | wc -l
}

function getNotHealthy() {
  oc get applications -o --insecure-skip-tls-verify jsonpath='{.items[*].status.health}' --kubeconfig="${KUBECONFIG}" | jq 'select(.status != "Healthy")' -c | wc -l
}

function waitForSync() {
  # Wait for all Applications to finish syncing
  echo "waiting for applications to be synced"
  while test "${not_synced}" -gt 0 && test "${loops}" -lt 50; do
    not_synced=$(getNotSynced)
    if test "${not_synced}" -gt 0; then
      echo "Loop ${loops}: waiting for ${not_synced} applications to finish syncing";
      sleep 60
      loops=$((loops+1))
      if test "${loops}" -gt 50; then
        echo "Applications not in synced state after 50 Minutes. Exiting!"
        exit 1
      fi
    else
      echo "applications synced"
      sync_ok=true
    fi
  done;
}

function waitForHealthy() {
  # Wait for all Applications to finish rollout and reporting healthy state
  if [ "${sync_ok}" == true ];then
    echo "waiting for applications to be healthy"

    while test "${not_healthy}" -gt 0 && test "${loops}" -lt 50; do
      not_synced=$(getNotHealthy)
      if test "${not_healthy}" -gt 0; then
        echo "Loop ${loops}: waiting for ${not_healthy} applications to be healthy";
        sleep 60
        loops=$((loops+1))
        if test "${loops}" -gt 50; then
          echo "Applications not synced after 50 Minutes. Exiting!"
          health_ok=false
        fi
      else
        health_ok=true
      fi
    done;
  fi
}

function main() {
  KUBECONFIG=$1

  # init
  not_synced=$(getNotSynced)
  sync_ok=false
  loops=0

  # Initial Check
  if test "${not_synced}" -eq 0; then
    sync_ok=true
  fi

  waitForSync

  not_healthy=$(getNotHealthy)
  health_ok=false
  loops=0

  # Initial Check
  if test "${not_healthy}" -eq 0; then
    health_ok=true
  fi

  waitForHealthy

  if [ "${health_ok}" == true ]; then
    echo "Applications are Synced and Healthy. Exiting."
    exit 0
  else
    echo "Sync status: ${sync_ok}"
    echo "Health status: ${health_ok}"
    echo "Operations not finished in time. Exiting"
    exit 1
  fi
}

main "${1}"
