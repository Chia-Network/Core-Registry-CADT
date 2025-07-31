#!/bin/bash

# Exit on undefined variable
set -u

### Variables

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variable to track if any test failed
TEST_FAILED=0
# Variable to store error message
ERROR_MESSAGE=""
# Global variables for home organization details
HOME_ORG_UID=""
HOME_REGISTRY_ID=""

expected_subscription_ids=(
    "29fe490bde0186cb7a592450d12e78162a353b866beec3e51bd67394257e4f4f"
    "68ac700af4c9a8c937029114a0fbbdbd3be282ad2aaec4ebe8485efa1426d38f"
    "a32e8ba6f67a8c95a785b01f86f4c2604cf703318e223142fac3831478c3b089"
    "11f7e8eb5a2a32dd373c14a172d55f62608a3e240cdf01362ce9fa398d2ca378"
)

### Functions

# Check if Chia wallet is synced. Do not proceed unless wallet is synced.
is_wallet_synced () {
    local TIMEOUT_SECONDS=300  # 5 minutes
    local CHECK_INTERVAL=5
    local MAX_ATTEMPTS=$((TIMEOUT_SECONDS / CHECK_INTERVAL))

    i=0
    while true; do
        echo "[DEBUG] Running wallet sync status check..."
        local response=$(chia rpc wallet get_sync_status)
        echo "[DEBUG] Raw wallet sync response:"
        echo "$response"

        # Check if wallet is synced by comparing the synced field to true
        if echo "$response" | jq -e '.synced == true' > /dev/null; then
            echo -e "${GREEN}●${NC} Chia wallet is synced - proceeding"
            return 0
        else
            echo -e "${RED}●${NC} Chia wallet is not synced - trying again in $CHECK_INTERVAL seconds"
            sleep "$CHECK_INTERVAL"
            if (( i >= MAX_ATTEMPTS )); then
                fail_test "Wallet sync timeout of $TIMEOUT_SECONDS seconds exceeded."
                return 1
            fi
            ((i++))
        fi
    done
}

# Function to wait for transaction confirmation
wait_for_transaction() {
    local transaction_id="$1"
    local TIMEOUT_SECONDS=300  # 5 minutes
    local CHECK_INTERVAL=5     # 5 seconds
    local MAX_ATTEMPTS=$((TIMEOUT_SECONDS / CHECK_INTERVAL))

    i=0
    while true; do
        echo "[DEBUG] Check attempt $((i+1)) of $MAX_ATTEMPTS"

        # Get transaction status
        local response
        response=$(chia rpc wallet get_transaction "{\"transaction_id\": \"$transaction_id\"}")

        if [[ $? -ne 0 ]]; then
            echo "[DEBUG] Failed to get transaction status"
            echo "[DEBUG] Response: $response"
            fail_test "Failed to get transaction status. This usually means the transaction ID is invalid or empty."
            return 1
        fi

        echo "[DEBUG] Transaction response:"
        echo "$response"

        # Check if transaction is confirmed
        if echo "$response" | jq -e '.transaction.confirmed == true' > /dev/null; then
            echo -e "${GREEN}●${NC} Transaction $transaction_id confirmed successfully"
            return 0
        fi

        if (( i >= MAX_ATTEMPTS )); then
            fail_test "Transaction confirmation timeout of $TIMEOUT_SECONDS seconds exceeded. Transaction ID: $transaction_id"
            return 1
        fi

        echo -e "${RED}●${NC} Transaction not yet confirmed - checking again in $CHECK_INTERVAL seconds"
        sleep "$CHECK_INTERVAL"
        ((i++))
    done
}

# Function to check if wallet has sufficient balance
check_wallet_balance() {
    local wallet_id="$1"
    local min_balance="$2"
    local TIMEOUT_SECONDS=300  # 5 minutes
    local CHECK_INTERVAL=5     # 5 seconds
    local MAX_ATTEMPTS=$((TIMEOUT_SECONDS / CHECK_INTERVAL))

    echo "Checking wallet $wallet_id balance (will retry for up to $TIMEOUT_SECONDS seconds)..."

    i=0
    while true; do
        echo "[DEBUG] Balance check attempt $((i+1)) of $MAX_ATTEMPTS"

        local balance_response
        balance_response=$(chia rpc wallet get_wallet_balances "{\"wallet_ids\": [$wallet_id]}")
        if [[ $? -ne 0 ]]; then
            echo "[DEBUG] Failed to get wallet balance, will retry..."
            sleep "$CHECK_INTERVAL"
            if (( i >= MAX_ATTEMPTS )); then
                fail_test "Failed to get wallet balance after $TIMEOUT_SECONDS seconds"
                return
            fi
            ((i++))
            continue
        fi

        echo "[DEBUG] Balance response:"
        echo "$balance_response"

        # Extract the confirmed wallet balance
        local confirmed_balance
        confirmed_balance=$(echo "$balance_response" | jq -r ".wallet_balances[\"$wallet_id\"].confirmed_wallet_balance")
        if [[ $? -ne 0 ]]; then
            echo "[DEBUG] Failed to parse wallet balance, will retry..."
            sleep "$CHECK_INTERVAL"
            if (( i >= MAX_ATTEMPTS )); then
                fail_test "Failed to parse wallet balance after $TIMEOUT_SECONDS seconds"
                return
            fi
            ((i++))
            continue
        fi

        echo "Wallet $wallet_id confirmed balance: $confirmed_balance mojos"

        # Check if balance is sufficient
        if (( confirmed_balance >= min_balance )); then
            echo -e "${GREEN}●${NC} Wallet $wallet_id has sufficient balance ($confirmed_balance mojos)"
            return 0
        fi

        if (( i >= MAX_ATTEMPTS )); then
            fail_test "Wallet $wallet_id balance ($confirmed_balance mojos) is insufficient after $TIMEOUT_SECONDS seconds. Need at least $min_balance mojos."
            return
        fi

        echo -e "${RED}●${NC} Wallet $wallet_id balance ($confirmed_balance mojos) insufficient - checking again in $CHECK_INTERVAL seconds"
        sleep "$CHECK_INTERVAL"
        ((i++))
    done
}

# Check if any mirrors owned by us still exist. Wait until they're gone.
check_mirrors_removed () {
    i=0
    while true; do
        # Get all subscription IDs
        subscription_ids=$(chia rpc data_layer subscriptions | jq -r '.store_ids[]')
        total_mirrors=0

        # Check mirrors for each subscription
        for id in $subscription_ids; do
            mirror_count=$(chia rpc data_layer get_mirrors "{\"id\":\"$id\"}" | jq '[.mirrors[] | select(.ours == true)] | length')
            total_mirrors=$((total_mirrors + mirror_count))
        done

        if (( total_mirrors == 0 )); then
            echo -e "${GREEN}●${NC} No mirrors owned by us found - proceeding"
            break
        fi

        echo -e "${RED}●${NC} Found $total_mirrors mirrors owned by us across all subscriptions - waiting 10 seconds before checking again"
        sleep 10

        if (( $i > 29 )); then
            fail_test "Mirror removal timeout of 300 seconds exceeded."
            return
        fi
        ((i++))
    done
}

# Check if the health endpoint is responding with OK
check_health_endpoint () {
    i=0
    while true; do
        response=$(curl -s http://127.0.0.1:31310/health | jq -r '.message')

        if [[ "$response" == "OK" ]]; then
            echo "Health endpoint responding OK - proceeding"
            break
        fi

        echo "Health endpoint not responding OK (got: $response) - waiting 10 seconds before checking again"
        sleep 10

        if (( $i > 5 )); then
            echo "Health check timeout of 60 seconds exceeded. Exiting with error."
            exit 1
        fi
        ((i++))
    done
}

# Check if we are unsubscribed from all stores
check_unsubscribed () {
    i=0
    while true; do
        subscription_count=$(chia rpc data_layer subscriptions | jq '.store_ids | length')

        if (( subscription_count == 0 )); then
            echo -e "${GREEN}●${NC} Successfully unsubscribed from all stores"
            break
        fi

        echo -e "${RED}●${NC} Found $subscription_count remaining subscriptions - waiting 5 seconds before checking again"
        sleep 5

        if (( $i > 59 )); then
            fail_test "Unsubscribe timeout of 300 seconds exceeded. Still have $subscription_count subscriptions."
            return
        fi
        ((i++))
    done
}

# Cleanup function to ensure proper shutdown
cleanup () {
    echo -e "\n${GREEN}Running cleanup tasks...${NC}"

    # Save pm2 logs to file regardless of test outcome
    echo "Saving pm2 logs to file..."
    local log_file="core-registry-cadt.log"

    # Clear the log file first
    > "$log_file"

    # Get the full log history by reading the log files directly
    if pm2 describe core-registry-cadt > /dev/null 2>&1; then
        echo "PM2 process found, collecting all available logs..."

        # Get both stdout and error log paths
        local pm2_out_log=$(pm2 describe core-registry-cadt | grep -o '/.*out\.log' | head -1)
        local pm2_error_log=$(pm2 describe core-registry-cadt | grep -o '/.*error\.log' | head -1)

        if [[ -n "$pm2_out_log" && -f "$pm2_out_log" ]]; then
            echo "Copying stdout log from: $pm2_out_log"
            echo "=== STDOUT LOG ===" >> "$log_file"
            cat "$pm2_out_log" >> "$log_file"
            echo "" >> "$log_file"
        fi

        if [[ -n "$pm2_error_log" && -f "$pm2_error_log" ]]; then
            echo "Copying error log from: $pm2_error_log"
            echo "=== ERROR LOG ===" >> "$log_file"
            cat "$pm2_error_log" >> "$log_file"
            echo "" >> "$log_file"
        fi

        # Also try to get recent logs from pm2 logs command
        echo "=== RECENT PM2 LOGS ===" >> "$log_file"
        pm2 logs core-registry-cadt --nostream --lines 100 >> "$log_file" 2>&1
        echo "" >> "$log_file"

    else
        echo "PM2 process not found, getting recent logs only"
        echo "=== PM2 LOGS (PROCESS NOT FOUND) ===" >> "$log_file"
        pm2 logs core-registry-cadt --nostream --lines 100 >> "$log_file" 2>&1
    fi

    # Also capture any application logs from the CADT directory
    local cadt_log_dir="$HOME/.chia/mainnet/core-registry/cadt"
    if [[ -d "$cadt_log_dir" ]]; then
        echo "=== CADT APPLICATION LOGS ===" >> "$log_file"
        find "$cadt_log_dir" -name "*.log" -type f -exec cat {} \; >> "$log_file" 2>/dev/null || true
        echo "" >> "$log_file"
    fi

    echo "PM2 logs saved to: $log_file"

    # Stop the core-registry-cadt
    pm2 stop core-registry-cadt

    # Remove mirrors and subscriptions
    echo "Removing mirrors and subscriptions..."
    chia-tools data delete-mirrors --all
    chia-tools data unsub-all
    check_mirrors_removed
    check_unsubscribed

    # Stop chia
    echo "Stopping Chia..."
    chia stop all -d

    # If there was a test failure, output error and exit with error code
    if (( TEST_FAILED == 1 )); then
        echo -e "\n${RED}Test failed: $ERROR_MESSAGE${NC}\n"
        exit 1
    fi
}

# Function to handle test failures
fail_test () {
    TEST_FAILED=1
    ERROR_MESSAGE="$1"
    cleanup
}

# Test if we are subscribed to all expected store IDs
test_subscriptions () {
    local TIMEOUT_SECONDS=600
    local CHECK_INTERVAL=10
    local MAX_ATTEMPTS=$((TIMEOUT_SECONDS / CHECK_INTERVAL))

    echo "Testing DataLayer subscriptions... (this can take up to $TIMEOUT_SECONDS seconds)"
    echo "[DEBUG] Will check every $CHECK_INTERVAL seconds, up to $MAX_ATTEMPTS times"

    # Print out the expected subscription IDs we're looking for
    echo -e "\n${BLUE}Looking for these expected subscription IDs:${NC}"
    for id in "${expected_subscription_ids[@]}"; do
        echo -e "${BLUE}  - $id${NC}"
    done
    echo ""

    #check_health_endpoint



    i=0
    while true; do
        echo "[DEBUG] Check attempt $((i+1)) of $MAX_ATTEMPTS"


        # Get current subscriptions
        current_subscriptions=$(chia rpc data_layer subscriptions | jq -r '.store_ids[]')
        echo "[DEBUG] Current subscriptions response:"
        echo "$current_subscriptions"

        missing_subs=0
        found_ids=()
        missing_ids=()

        # Check each expected subscription
        for expected_id in "${expected_subscription_ids[@]}"; do
            if echo "$current_subscriptions" | grep -q "^$expected_id$"; then
                found_ids+=("$expected_id")
            else
                missing_ids+=("$expected_id")
                missing_subs=1
            fi
        done

        echo "[DEBUG] Found ${#found_ids[@]} subscriptions, missing ${#missing_ids[@]} subscriptions"

        if (( missing_subs == 0 )); then
            echo -e "\n${GREEN}=========================================="
            echo -e "✓ All expected subscriptions found - TEST PASSED"
            echo -e "===========================================${NC}\n"
            break
        fi

        if (( $i >= $MAX_ATTEMPTS )); then
            echo -e "\n${RED}Subscription test results after $TIMEOUT_SECONDS seconds:${NC}"
            echo -e "${GREEN}Found subscriptions:${NC}"
            for id in "${found_ids[@]}"; do
                echo -e "${GREEN}✓${NC} $id"
            done
            echo -e "\n${RED}Missing subscriptions:${NC}"
            for id in "${missing_ids[@]}"; do
                echo -e "${RED}✗${NC} $id"
            done
            fail_test "Subscription test timeout of $TIMEOUT_SECONDS seconds exceeded."
            return
        fi

        ((i++))
        sleep $CHECK_INTERVAL
    done
}

# Check if any home organizations exist
check_home_org () {
    local ENDPOINT="http://localhost:31310/v1/organizations"
    local response
    local home_orgs

    echo "[DEBUG] Checking for home organizations..."

    # Get organizations and store response
    response=$(make_api_call "curl -s --location --request GET '$ENDPOINT' --header 'Content-Type: application/json'")
    if [[ $? -ne 0 ]]; then
        echo "[DEBUG] curl request failed"
        fail_test "Failed to fetch organizations from $ENDPOINT"
        return 1
    fi

    echo "[DEBUG] Organizations response:"
    echo "$response"

    # If response is empty or just {}, no organizations exist
    if [[ -z "$response" ]] || [[ "$response" == "{}" ]]; then
        echo -e "${GREEN}●${NC} No home organizations found"
        return 0
    fi

    # Count organizations with isHome=true
    home_orgs=$(echo "$response" | jq '[.[] | select(.isHome == true)] | length')
    if [[ $? -ne 0 ]]; then
        echo "[DEBUG] Failed to parse organizations response with jq"
        fail_test "Failed to parse organizations response"
        return 1
    fi

    if (( home_orgs == 0 )); then
        echo -e "${GREEN}●${NC} No home organizations found"
        return 0
    else
        echo -e "${RED}●${NC} Found $home_orgs home organization(s)"
        # Get the orgUids of home orgs for debugging
        echo "[DEBUG] Home organization UIDs:"
        echo "$response" | jq -r '.[] | select(.isHome == true) | .orgUid'
        return 1
    fi
}

# Test 2: Create a home organization
test_create_home_org () {
    # First verify wallet is synced
    if ! is_wallet_synced; then
        return
    fi

    local TIMEOUT_SECONDS=900   # 15 minutes
    local CHECK_INTERVAL=30
    local MAX_ATTEMPTS=30
    local CREATE_ENDPOINT="http://localhost:31310/v1/organizations/create"

    echo "Testing home organization creation... (this can take up to 30 minutes)"

    # First verify no home org exists
    if ! check_home_org; then
        fail_test "Found existing home organization when none should exist"
        return
    fi

    # Create home organization
    echo "[DEBUG] Creating home organization..."
    local response
    response=$(make_api_call "curl -s --location -g --request POST '$CREATE_ENDPOINT' \
        --header 'Content-Type: application/json' \
        --data-raw '{
            \"name\": \"Automated Testing CI Org\",
            \"icon\": \"https://www.chia.net/wp-content/uploads/2023/01/chia-logo-dark.svg\"
        }'")

    echo "[DEBUG] Create organization response:"
    echo "$response"

    # Check if creation was successful
    if ! echo "$response" | jq -e '.success == true' > /dev/null; then
        fail_test "Failed to create organization: $(echo "$response" | jq -r '.message // "Unknown error"')"
        return
    fi

    # Wait for organization to be set as home org
    echo "Waiting for organization to be set as home organization..."
    i=0
    while true; do
        echo "[DEBUG] Check attempt $((i+1)) of $MAX_ATTEMPTS"

        # Show owned stores status
        echo "[DEBUG] Current owned stores:"
        chia data get_owned_stores

        # Get current organizations
        response=$(make_api_call "curl -s --location --request GET 'http://localhost:31310/v1/organizations' \
            --header 'Content-Type: application/json'")
        if [[ $? -ne 0 ]]; then
            fail_test "Failed to get organizations"
            return
        fi

        echo "[DEBUG] Organizations check response:"
        echo "$response" | jq '.'

        # Check if response is valid JSON
        if ! echo "$response" | jq empty > /dev/null 2>&1; then
            echo "[DEBUG] Invalid JSON response received"
            echo "[DEBUG] Response content: $response"
            sleep "$CHECK_INTERVAL"
            ((i++))
            continue
        fi

        # Count home organizations
        local home_org_count
        home_org_count=$(echo "$response" | jq '[to_entries[] | select(.value.isHome == true)] | length')

        # Check if there's more than one home org
        if (( home_org_count > 1 )); then
            fail_test "Multiple home organizations found. This should not happen."
            return
        fi

                # Find the home organization (if any)
        local home_org
        home_org=$(echo "$response" | jq -r 'to_entries[] | select(.value.isHome == true) | .key')

        # If no home organization is found, fail immediately
        if [[ -z "$home_org" || "$home_org" == "null" ]]; then
            echo -e "\n${RED}No home organization found in response${NC}"
            echo "Current organizations state:"
            echo "$response" | jq '.'
            fail_test "No home organization found. Organization creation may have failed."
            return
        fi

        # Check if it's still pending
        if [[ "$home_org" == "PENDING" ]]; then
            echo -e "${RED}●${NC} Home organization creation is still pending - checking again in $CHECK_INTERVAL seconds"
            sleep "$CHECK_INTERVAL"
            ((i++))

            # Check timeout after incrementing counter
            if (( $i >= $MAX_ATTEMPTS )); then
                echo -e "\n${RED}Organization creation results after $TIMEOUT_SECONDS seconds:${NC}"
                echo "Current organizations state:"
                echo "$response" | jq '.'
                fail_test "Organization creation verification timeout of $TIMEOUT_SECONDS seconds exceeded."
                return
            fi
            continue
        fi

        # Check if the home org is fully ready
        local is_subscribed
        local is_synced
        local org_uid
        local registry_id

        is_subscribed=$(echo "$response" | jq -r ".$home_org.subscribed")
        is_synced=$(echo "$response" | jq -r ".$home_org.synced")
        org_uid=$(echo "$response" | jq -r ".$home_org.orgUid")
        registry_id=$(echo "$response" | jq -r ".$home_org.registryId")

        if [[ "$is_subscribed" == "true" && "$is_synced" == "true" ]]; then
            echo -e "\n${GREEN}=========================================="
            echo -e "✓ Home organization successfully created and verified - TEST PASSED"
            echo -e "===========================================${NC}\n"
            echo "Home organization details:"
            echo "  orgUid: $org_uid"
            echo "  registryId: $registry_id"

            # Store these values in global variables for use outside the function
            HOME_ORG_UID="$org_uid"
            HOME_REGISTRY_ID="$registry_id"

            break
        else
            echo -e "${RED}●${NC} Home organization exists but not ready (subscribed: $is_subscribed, synced: $is_synced) - checking again in $CHECK_INTERVAL seconds"
            sleep "$CHECK_INTERVAL"
            ((i++))

            # Check timeout after incrementing counter
            if (( $i >= $MAX_ATTEMPTS )); then
                echo -e "\n${RED}Organization creation results after $TIMEOUT_SECONDS seconds:${NC}"
                echo "Current organizations state:"
                echo "$response" | jq '.'
                fail_test "Organization creation verification timeout of $TIMEOUT_SECONDS seconds exceeded."
                return
            fi
            continue
        fi
    done
}

# Test 3: Create and verify a project
test_create_project () {
    # First verify wallet is synced
    if ! is_wallet_synced; then
        return
    fi

    local TIMEOUT_SECONDS=60
    local CHECK_INTERVAL=10
    local MAX_ATTEMPTS=$((TIMEOUT_SECONDS / CHECK_INTERVAL))
    local PROJECTS_ENDPOINT="http://localhost:31310/v1/projects"
    local STAGING_ENDPOINT="http://localhost:31310/v1/staging"
    local response
    local project_uuid

    echo "Testing project creation... (this can take up to $TIMEOUT_SECONDS seconds)"

    # Create project
    echo "[DEBUG] Creating new project..."
    response=$(make_api_call "curl -s --location -g --request POST '$PROJECTS_ENDPOINT' \
        --header 'Content-Type: application/json' \
        --data-raw '{
            \"projectName\": \"Automated Testing Project\",
            \"projectId\": \"ATP1\",
            \"projectDeveloper\": \"functional-tests.sh\",
            \"program\": null,
            \"projectLink\": \"https://observer.climateactiondata.org/\",
            \"sector\": \"Agriculture; forestry and fishing\",
            \"projectType\": \"Agriculture, Forestry and other land use (AFOLU)\",
            \"projectStatus\": \"Completed\",
            \"projectStatusDate\": \"2025-01-28T05:00:00.000Z\",
            \"coveredByNDC\": \"Outside NDC\",
            \"ndcInformation\": null,
            \"currentRegistry\": \"American Carbon Registry (ACR)\",
            \"registryOfOrigin\": \"American Carbon Registry (ACR)\",
            \"originProjectId\": \"ATP1\",
            \"unitMetric\": \"tCO2e\",
            \"methodology\": \"ACR - Afforestation and Reforestation of Degraded Lands\",
            \"validationBody\": null,
            \"validationDate\": null,
            \"projectTags\": null,
            \"issuances\": [
                {
                    \"startDate\": \"2025-02-03T05:00:00.000Z\",
                    \"endDate\": \"2025-02-28T05:00:00.000Z\",
                    \"verificationApproach\": \"ATP-TEST\",
                    \"verificationBody\": \"ATP-Verification\",
                    \"verificationReportDate\": \"2025-02-14T05:00:00.000Z\"
                }
            ],
            \"projectLocations\": [
                {
                    \"country\": \"Zambia\",
                    \"geographicIdentifier\": \"123 Testing Ave\",
                    \"inCountryRegion\": \"\",
                    \"fileId\": \"\"
                }
            ]
        }'")

    echo "[DEBUG] Create project response:"
    echo "$response"

    # Check if creation was successful
    if ! echo "$response" | jq -e '.success == true' > /dev/null; then
        fail_test "Failed to create project: $(echo "$response" | jq -r '.message // "Unknown error"')"
        return
    fi

    # Store the UUID
    project_uuid=$(echo "$response" | jq -r '.uuid')
    echo "[DEBUG] Project created with UUID: $project_uuid"

    # Verify project appears in staging
    echo "Verifying project appears in staging..."
    i=0
    while true; do
        echo "[DEBUG] Check attempt $((i+1)) of $MAX_ATTEMPTS"

        # Get staging entries
        response=$(make_api_call "curl -s --location --request GET '$STAGING_ENDPOINT' \
            --header 'Content-Type: application/json'")
        if [[ $? -ne 0 ]]; then
            fail_test "Failed to get staging entries"
            return
        fi

        # Check if our project UUID exists in staging
        if echo "$response" | jq -e --arg uuid "$project_uuid" '.[] | select(.uuid == $uuid)' > /dev/null; then
            echo -e "\n${GREEN}=========================================="
            echo -e "✓ Project successfully created and found in staging - TEST PASSED"
            echo -e "===========================================${NC}\n"
            break
        fi

        if (( i >= MAX_ATTEMPTS )); then
            echo -e "\n${RED}Project creation results after $TIMEOUT_SECONDS seconds:${NC}"
            echo "Expected project UUID: $project_uuid"
            echo "Current staging state:"
            echo "$response" | jq '.'
            fail_test "Project staging verification timeout of $TIMEOUT_SECONDS seconds exceeded."
            return
        fi

        echo -e "${RED}●${NC} Project not yet found in staging - checking again in $CHECK_INTERVAL seconds"
        sleep "$CHECK_INTERVAL"
        ((i++))
    done
}

# Test 4: Add a unit
test_add_unit () {
    # First verify wallet is synced
    if ! is_wallet_synced; then
        return
    fi

    local UNITS_ENDPOINT="http://localhost:31310/v1/units"
    local response
    local unit_uuid

    echo "Testing unit creation..."

    # Create unit
    echo "[DEBUG] Creating new unit..."
    response=$(make_api_call "curl -s --location -g --request POST '$UNITS_ENDPOINT' \
        --header 'Content-Type: application/json' \
        --data-raw '{
            \"projectLocationId\": \"ID_USA\",
            \"unitOwner\": \"Chia\",
            \"countryJurisdictionOfOwner\": \"Andorra\",
            \"vintageYear\": 1998,
            \"unitType\": \"Removal - technical\",
            \"unitStatus\": \"Held\",
            \"unitBlockStart\": \"abc123\",
            \"unitBlockEnd\": \"bcd456\",
            \"unitCount\": 200,
            \"unitRegistryLink\": \"http://climateWarehouse.com/myRegistry\",
            \"correspondingAdjustmentDeclaration\": \"Unknown\",
            \"correspondingAdjustmentStatus\": \"Not Started\"
        }'")

    echo "[DEBUG] Create unit response:"
    echo "$response"

    # Check if creation was successful
    if ! echo "$response" | jq -e '.success == true' > /dev/null; then
        fail_test "Failed to create unit: $(echo "$response" | jq -r '.message // "Unknown error"')"
        return
    fi

    # Store the UUID for potential future use
    unit_uuid=$(echo "$response" | jq -r '.uuid')

    echo -e "\n${GREEN}=========================================="
    echo -e "✓ Unit successfully created with UUID: $unit_uuid - TEST PASSED"
    echo -e "===========================================${NC}\n"
}

# Test 5: Delete home organization
test_delete_home_org () {
    # First verify wallet is synced
    if ! is_wallet_synced; then
        return
    fi

    local TIMEOUT_SECONDS=300
    local CHECK_INTERVAL=15
    local MAX_ATTEMPTS=$((TIMEOUT_SECONDS / CHECK_INTERVAL))
    local DELETE_ENDPOINT="http://localhost:31310/v1/organizations"
    local response
    local org_uid

    echo "Testing home organization deletion... (this can take up to 5 minutes)"

    # First get the current home org UID
    response=$(make_api_call "curl -s --location --request GET '$DELETE_ENDPOINT' \
        --header 'Content-Type: application/json'")
    if [[ $? -ne 0 ]]; then
        fail_test "Failed to get organizations"
        return
    fi

    # Find any home org that exists
    org_uid=$(echo "$response" | jq -r 'to_entries[] | select(.value.isHome == true) | .key')

    if [[ -z "$org_uid" ]]; then
        fail_test "No home organization found to delete"
        return
    fi

    echo "[DEBUG] Found home organization with UID: $org_uid"

    # Delete the home organization
    echo "[DEBUG] Deleting home organization..."
    response=$(make_api_call "curl -s --location --request DELETE '$DELETE_ENDPOINT/$org_uid'")

    echo "[DEBUG] Delete organization response:"
    echo "$response"

    # Check if deletion was successful
    if ! echo "$response" | jq -e '.success == true' > /dev/null; then
        fail_test "Failed to delete organization: $(echo "$response" | jq -r '.message // "Unknown error"')"
        return
    fi

    # Verify organization is actually deleted
    echo "Verifying organization deletion..."
    i=0
    while true; do
        echo "[DEBUG] Check attempt $((i+1)) of $MAX_ATTEMPTS"

        # Get current organizations
        response=$(make_api_call "curl -s --location --request GET '$DELETE_ENDPOINT' \
            --header 'Content-Type: application/json'")
        if [[ $? -ne 0 ]]; then
            fail_test "Failed to get organizations"
            return
        fi

        # Check if any home orgs exist
        if echo "$response" | jq -e 'to_entries[] | select(.value.isHome == true) | length == 0' > /dev/null; then
            echo -e "\n${GREEN}=========================================="
            echo -e "✓ Home organization successfully deleted and verified - TEST PASSED"
            echo -e "===========================================${NC}\n"
            break
        fi

        if (( $i >= $MAX_ATTEMPTS )); then
            echo -e "\n${RED}Organization deletion results after $TIMEOUT_SECONDS seconds:${NC}"
            echo "Attempted to delete orgUid: $org_uid"
            echo "Current organizations state:"
            echo "$response" | jq '.'
            fail_test "Organization deletion verification timeout of $TIMEOUT_SECONDS seconds exceeded."
            return
        fi

        echo -e "${RED}●${NC} Organization still exists - checking again in $CHECK_INTERVAL seconds"
        sleep "$CHECK_INTERVAL"
        ((i++))
    done
}

# Helper function to make API calls with wallet sync check
make_api_call() {
    local TIMEOUT_SECONDS=300  # 5 minutes
    local CHECK_INTERVAL=5
    local MAX_ATTEMPTS=$((TIMEOUT_SECONDS / CHECK_INTERVAL))
    local i=0
    local response

    while true; do
        response=$(eval "$1")

        # First check if we got a response with the wallet error message
        if echo "$response" | grep -q "Your wallet is not available"; then
            echo "[DEBUG] Wallet not available, checking sync status..."
            if ! is_wallet_synced; then
                return 1
            fi

            if (( i >= MAX_ATTEMPTS )); then
                echo "[DEBUG] API call timeout after $TIMEOUT_SECONDS seconds"
                echo "$response"
                return 1
            fi

            ((i++))
            continue
        fi

        # If we get here, we got a response that wasn't the wallet error
        echo "$response"
        return 0
    done
}

# Function to split coins in the wallet
split_coins() {
    echo "=== Splitting coins in wallet ==="

    # First verify wallet is synced
    if ! is_wallet_synced; then
        return
    fi

    echo "Splitting largest coin into 30 coins of 0.000035 TXCH each..."

    # Run the chia-tools split command
    local split_result
    split_result=$(chia-tools coins split-largest -m 0 -n 30 -a 0.0003)
    if [[ $? -ne 0 ]]; then
        fail_test "Failed to split coins: $split_result"
        return
    fi

    echo "[DEBUG] Split coins response:"
    echo "$split_result"

    # Extract transaction ID from the log output
    # The output format is: TRANSACTION_ID=0eccadc2c16437df8d5047606b126e5e8d19cd8486b687471ae425a9779f568f
    local transaction_id
    transaction_id=$(echo "$split_result" | grep -o 'TRANSACTION_ID=[a-f0-9]*' | cut -d'=' -f2)
    if [[ $? -ne 0 ]]; then
        fail_test "Failed to parse transaction ID from split response"
        return
    fi

    if [[ -z "$transaction_id" ]]; then
        fail_test "No transaction ID found in split response"
        return
    fi

    # Add 0x prefix if not already present
    if [[ ! "$transaction_id" =~ ^0x ]]; then
        transaction_id="0x$transaction_id"
    fi

    echo "Split transaction ID: $transaction_id"

    # Wait for the split transaction to be confirmed
    wait_for_transaction "$transaction_id"

    # Show wallet balance after split
    echo "Showing wallet balance after coin split:"
    chia wallet show

    echo "=== Coin split completed successfully ==="
}

# Function to transfer funds to test wallet
transfer_funds_to_test_wallet() {
    echo "=== Transferring funds to test wallet ==="

    # Get wallet address and store it in test_wallet_address variable
    test_wallet_address=$(chia wallet get_address)
    if [[ $? -ne 0 ]]; then
        fail_test "Failed to get wallet address"
        return
    fi
    echo "Test wallet address: $test_wallet_address"

    # Get wallet fingerprint
    test_wallet_fingerprint=$(chia rpc wallet get_logged_in_fingerprint | jq -r '.fingerprint')
    if [[ $? -ne 0 ]]; then
        fail_test "Failed to get wallet fingerprint"
        return
    fi
    echo "Test wallet fingerprint: $test_wallet_fingerprint"

    # Create mnemonic.txt file with TXCH_MNEMONIC environment variable
    if [[ -z "$TXCH_MNEMONIC" ]]; then
        fail_test "TXCH_MNEMONIC environment variable is not set. Please set it with a valid 24-word mnemonic phrase containing TXCH funds for testing."
        return
    fi

    echo "$TXCH_MNEMONIC" > mnemonic.txt

    # Import wallet with TXCH
    chia keys add -f mnemonic.txt -l "txch-funds"
    if [[ $? -ne 0 ]]; then
        fail_test "Failed to import TXCH wallet. Check that TXCH_MNEMONIC contains a valid 24-word mnemonic phrase."
        return
    fi

    # Remove mnemonic.txt file
    rm -f mnemonic.txt

    # Get wallet fingerprints and store the one for the txch funds in txch_funds_wallet variable
    echo "[DEBUG] Getting all wallet fingerprints..."
    all_fingerprints_response=$(chia rpc wallet get_public_keys)
    if [[ $? -ne 0 ]]; then
        fail_test "Failed to get wallet fingerprints"
        return
    fi

    echo "[DEBUG] All fingerprints response:"
    echo "$all_fingerprints_response"

    # Check if response is empty or invalid
    if [[ -z "$all_fingerprints_response" ]]; then
        fail_test "Empty response from chia rpc wallet get_public_keys"
        return
    fi

    # Extract the fingerprint that doesn't match test_wallet_fingerprint
    txch_funds_fingerprint=$(echo "$all_fingerprints_response" | jq -r --arg exclude "$test_wallet_fingerprint" '.public_key_fingerprints[] | select(. != ($exclude | tonumber))')
    if [[ $? -ne 0 ]]; then
        fail_test "Failed to parse wallet fingerprints with jq"
        return
    fi

    # Check if we got a valid fingerprint
    if [[ -z "$txch_funds_fingerprint" ]]; then
        fail_test "No TXCH funds wallet fingerprint found"
        return
    fi

    echo "TXCH funds wallet fingerprint: $txch_funds_fingerprint"

    # Show balance of txch funds wallet
    echo "Showing wallet to switch to txch funds wallet"
    chia wallet show -f $txch_funds_fingerprint

    # call function to check if wallet it synced
    is_wallet_synced

    # Show balance of txch funds wallet
    echo "Showing balance now that we're sure the wallet is synced"
    chia wallet show -f $txch_funds_fingerprint

    # Transfer funds to test wallet
    echo "Sending transaction to transfer 0.001 TXCH to test wallet ${test_wallet_address}"
    transaction_id=$(chia rpc wallet send_transaction "{\"wallet_id\": 1, \"amount\": 9000000000, \"fee\": 0, \"memos\":[\"transfer to test wallet\"], \"address\": \"$test_wallet_address\"}" | jq -r '.transaction_id')
    if [[ $? -ne 0 ]]; then
        fail_test "Failed to send transaction"
        return
    fi

    echo "Transaction ID: $transaction_id"

    # Wait for the transaction to be confirmed
    wait_for_transaction "$transaction_id"

    # Show balance of txch funds wallet
    echo "Showing balance of txch funds wallet after transfer"
    chia wallet show -f $txch_funds_fingerprint

    # Show balance of test wallet
    echo "Showing balance of test wallet after transfer - may need to wait for sync"
    chia wallet show -f $test_wallet_fingerprint

    # Check if wallet balance is greater than 100000000 mojos
    check_wallet_balance 1 100000000

    # call function to check if wallet it synced
    is_wallet_synced

    # Show balance of test wallet
    echo "Showing balance of test wallet after sync"
    chia wallet show -f $test_wallet_fingerprint

    # Delete keys for txch funds wallet
    chia keys delete -f $txch_funds_fingerprint
    if [[ $? -ne 0 ]]; then
        fail_test "Failed to delete TXCH funds wallet keys"
        return
    fi

    echo "=== Funds transfer completed successfully ==="
}

#~~~ Start Chia ~~~ #

chia start wallet data data_layer_http
sleep 5

# call function to check if wallet it synced
is_wallet_synced

# Display wallet
chia wallet show

#~~~ Transfer funds to test wallet ~~~ #
transfer_funds_to_test_wallet

#~~~ Split coins ~~~ #
split_coins

# Display datalayer subscriptions
echo "Displaying datalayer subscriptions before starting core-registry-cadt"
chia data get_subscriptions

# start core-registry-cadt in the background
pm2 start npm --no-autorestart --name "core-registry-cadt" -- start

# Check health endpoint
#check_health_endpoint

#~~~ Run Tests ~~~ #

# Test 1: Verify that we are subscribed to all required DataLayer stores
test_subscriptions

# Test 2: Create a home organization
test_create_home_org

# Test 3: Create and verify a project
test_create_project

# Test 4: Add a unit
#test_add_unit

# Test 5: Delete home organization (do this last)
test_delete_home_org

# If we got here with no failures, run cleanup and exit successfully
cleanup

#~~~~ upload logs to artifacts here ~~~~#
#cat ~/.chia/mainnet/log/debug.log
