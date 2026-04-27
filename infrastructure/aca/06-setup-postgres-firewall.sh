#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_env "${1:-${ENV_FILE_DEFAULT}}"
if [[ -f "${SCRIPT_DIR}/aca.generated.env" ]]; then
  source "${SCRIPT_DIR}/aca.generated.env"
fi

require_cmd az

for name in SUBSCRIPTION_ID RESOURCE_GROUP POSTGRES_HOST; do
  require_env "${name}"
done

az_subscription_context

print_header "Setting up PostgreSQL firewall for Azure Container Apps"

POSTGRES_SERVER_NAME=$(echo "${POSTGRES_HOST}" | cut -d'.' -f1)
echo "PostgreSQL server: ${POSTGRES_SERVER_NAME}"

echo ""
echo "Option 1: Adding specific Container Apps Environment outbound IPs"
echo "Option 2: Allowing all Azure services (0.0.0.0)"
echo ""

read -p "Choose option (1/2): " choice

case "${choice}" in
  1)
    print_header "Getting Container Apps Environment outbound IPs"
    
    ACA_ENV_NAME="${ACA_ENV_NAME:-agriwizard-aca-env}"
    
    OUTBOUND_IPS=$(az containerapp env show \
      --name "${ACA_ENV_NAME}" \
      --resource-group "${RESOURCE_GROUP}" \
      --query properties.outboundIPs -o tsv 2>/dev/null || echo "")
    
    if [[ -z "${OUTBOUND_IPS}" ]]; then
      echo "[WARN] Could not get outbound IPs. Make sure ACA Environment exists."
      echo "[INFO] Falling back to allowing all Azure services..."
      choice=2
    else
      echo "Found outbound IPs: ${OUTBOUND_IPS}"
      
      for IP in ${OUTBOUND_IPS}; do
        RULE_NAME="allow-aca-${IP//./-}"
        echo "Adding firewall rule: ${RULE_NAME} for IP: ${IP}"
        
        az postgres server firewall-rule create \
          --resource-group "${RESOURCE_GROUP}" \
          --server-name "${POSTGRES_SERVER_NAME}" \
          --name "${RULE_NAME}" \
          --start-ip-address "${IP}" \
          --end-ip-address "${IP}" \
          --output none 2>/dev/null || echo "[INFO] Rule may already exist"
      done
    fi
    ;;
  2|"")
    print_header "Allowing all Azure services"
    
    az postgres server firewall-rule create \
      --resource-group "${RESOURCE_GROUP}" \
      --server-name "${POSTGRES_SERVER_NAME}" \
      --name "allow-all-azure-services" \
      --start-ip-address "0.0.0.0" \
      --end-ip-address "0.0.0.0" \
      --output none 2>/dev/null || echo "[INFO] Rule may already exist"
    
    echo "[INFO] Added rule to allow all Azure services"
    ;;
  *)
    echo "[ERROR] Invalid option"
    exit 1
    ;;
esac

print_header "Firewall setup complete"

echo ""
echo "Verifying firewall rules:"
az postgres server firewall-rule list \
  --resource-group "${RESOURCE_GROUP}" \
  --server-name "${POSTGRES_SERVER_NAME}" \
  --query "[].{Name:name, StartIP:startIpAddress, EndIP:endIpAddress}" \
  -o table

print_header "PostgreSQL firewall configuration complete"
