#!/usr/bin/env bash

set -euo pipefail

DEFAULT_RG="rg-routewell"

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -g, --resource-group NAME   Delete a single resource group (default: ${DEFAULT_RG})
  -p, --prefix PREFIX         Delete all resource groups whose names start with PREFIX
  -h, --help                  Show this help message

Examples:
  $0
  $0 -g rg-routewell
  $0 -p rg-routewell
EOF
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    -g|--resource-group)
      if [[ $# -lt 2 ]]; then
        echo "Missing resource group name." >&2
        usage
        exit 1
      fi
      RESOURCE_GROUP="$2"
      DELETE_PREFIX=""
      shift 2
      ;;
    -p|--prefix)
      if [[ $# -lt 2 ]]; then
        echo "Missing prefix value." >&2
        usage
        exit 1
      fi
      DELETE_PREFIX="$2"
      RESOURCE_GROUP=""
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
else
  RESOURCE_GROUP="$DEFAULT_RG"
  DELETE_PREFIX=""
fi

if [[ -n "$RESOURCE_GROUP" && -n "$DELETE_PREFIX" ]]; then
  echo "Cannot use both --resource-group and --prefix." >&2
  usage
  exit 1
fi

if [[ -n "$DELETE_PREFIX" ]]; then
  echo "Deleting all resource groups that start with: $DELETE_PREFIX"
  GROUPS_TO_DELETE=( $(az group list --query "[?starts_with(name, '${DELETE_PREFIX}')].name" -o tsv) )
  if [[ ${#GROUPS_TO_DELETE[@]} -eq 0 ]]; then
    echo "No resource groups found with prefix '${DELETE_PREFIX}'."
    exit 0
  fi
  for RG_NAME in "${GROUPS_TO_DELETE[@]}"; do
    echo "Deleting resource group: $RG_NAME"
    az group delete --name "$RG_NAME" --yes
  done
  exit 0
fi

if [[ -n "$RESOURCE_GROUP" ]]; then
  echo "Deleting resource group: $RESOURCE_GROUP"
  az group delete --name "$RESOURCE_GROUP" --yes
  exit 0
fi

usage
exit 1
