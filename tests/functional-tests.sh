#!/bin/bash

### Variables

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Global variable to track if any test failed
TEST_FAILED=0
# Variable to store error message
ERROR_MESSAGE=""

expected_subscription_ids=(
    "1019153f631bb82e7fc4984dc1f0f2af9e95a7c29df743f7b4dcc2b975857409"
    "18b6ff2ebf73574d30a39e1ee58efa3b7e8f1b35a4f9e6abd41690ab87bd15c7"
    "a2194bd3f35268f50a48066a5da428fdc5f136fcf30c468fcf480a1ed0aaa4a1"
)

### Functions

# Check if Chia wallet is synced. Do not proceed unless wallet is synced.
is_wallet_synced () {
    i=0
    while ! chia rpc wallet get_sync_status | jq .synced ; do
        echo -e "${RED}●${NC} Chia wallet is not synced - trying again in 5 seconds"
        sleep 5
        if (( $i > 12 )); then
            fail_test "Wallet sync timeout of 60 seconds exceeded."
            return
        fi
        ((i++))
    done

    echo -e "${GREEN}●${NC} Chia wallet is synced - proceeding"
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

        if [ "$total_mirrors" -eq 0 ]; then
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
        response=$(curl -s http://127.0.0.1:31310/heath | jq -r '.message')

        if [ "$response" = "OK" ]; then
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

        if [ "$subscription_count" -eq 0 ]; then
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
    if [ $TEST_FAILED -eq 1 ]; then
        echo -e "\n${RED}Test failed: $ERROR_MESSAGE${NC}\n"
        exit 1
    fi
}

# Function to handle test failures
fail_test () {
    TEST_FAILED=1
    ERROR_MESSAGE="$1"
    pm2 logs core-registry-cadt --nostream --lines 500
    cleanup
}

# Test if we are subscribed to all expected store IDs
test_subscriptions () {
    local TIMEOUT_SECONDS=300
    local CHECK_INTERVAL=5
    local MAX_ATTEMPTS=$((TIMEOUT_SECONDS / CHECK_INTERVAL))

    echo "Testing DataLayer subscriptions... (this can take up to $TIMEOUT_SECONDS seconds)"
    echo "[DEBUG] Will check every $CHECK_INTERVAL seconds, up to $MAX_ATTEMPTS times"
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

        if [ $missing_subs -eq 0 ]; then
            echo -e "\n${GREEN}=========================================="
            echo "✓ All expected subscriptions found - TEST PASSED"
            echo "===========================================${NC}\n"
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
    response=$(curl -s --location --request GET "$ENDPOINT" --header 'Content-Type: application/json')

    if [ $? -ne 0 ]; then
        echo "[DEBUG] curl request failed"
        fail_test "Failed to fetch organizations from $ENDPOINT"
        return 1
    }

    echo "[DEBUG] Organizations response:"
    echo "$response"

    # Count organizations with isHome=true
    home_orgs=$(echo "$response" | jq '[.[] | select(.isHome == true)] | length')

    if [ "$home_orgs" -eq 0 ]; then
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
    local TIMEOUT_SECONDS=1800  # 30 minutes
    local CHECK_INTERVAL=30
    local MAX_ATTEMPTS=$((TIMEOUT_SECONDS / CHECK_INTERVAL))
    local CREATE_ENDPOINT="http://localhost:31310/v1/organizations/create"
    local org_uid

    echo "Testing home organization creation... (this can take up to 30 minutes)"

    # First verify no home org exists
    if ! check_home_org; then
        fail_test "Found existing home organization when none should exist"
        return
    fi

    # Create home organization
    echo "[DEBUG] Creating home organization..."
    local response
    response=$(curl -s --location -g --request POST "$CREATE_ENDPOINT" \
        --header 'Content-Type: application/json' \
        --data-raw '{
            "name": "Automated Testing Org",
            "icon": "https://www.chia.net/wp-content/uploads/2023/01/chia-logo-dark.svg"
        }')

    echo "[DEBUG] Create organization response:"
    echo "$response"

    # Check if creation was successful
    if ! echo "$response" | jq -e '.success == true' > /dev/null; then
        fail_test "Failed to create organization: $(echo "$response" | jq -r '.message // "Unknown error"')"
        return
    }

    # Store the orgUid
    org_uid=$(echo "$response" | jq -r '.orgUid')
    echo "[DEBUG] Organization created with UID: $org_uid"

    # Wait for organization to be set as home org
    echo "Waiting for organization to be set as home organization..."
    i=0
    while true; do
        echo "[DEBUG] Check attempt $((i+1)) of $MAX_ATTEMPTS"

        # Get current organizations
        response=$(curl -s --location --request GET 'http://localhost:31310/v1/organizations' \
            --header 'Content-Type: application/json')

        # Check if our org exists and is home org
        if echo "$response" | jq -e --arg uid "$org_uid" \
            '.[$uid] and .[$uid].isHome == true' > /dev/null; then
            echo -e "\n${GREEN}=========================================="
            echo "✓ Home organization successfully created and verified - TEST PASSED"
            echo "===========================================${NC}\n"
            break
        fi

        if (( $i >= $MAX_ATTEMPTS )); then
            echo -e "\n${RED}Organization creation results after $TIMEOUT_SECONDS seconds:${NC}"
            echo "Expected orgUid: $org_uid"
            echo "Current organizations state:"
            echo "$response" | jq '.'
            fail_test "Organization creation verification timeout of $TIMEOUT_SECONDS seconds exceeded."
            return
        fi

        echo -e "${RED}●${NC} Organization not yet set as home org - checking again in $CHECK_INTERVAL seconds"
        sleep $CHECK_INTERVAL
        ((i++))
    done
}

# Test 3: Delete home organization
test_delete_home_org () {
    local TIMEOUT_SECONDS=300
    local CHECK_INTERVAL=15
    local MAX_ATTEMPTS=$((TIMEOUT_SECONDS / CHECK_INTERVAL))
    local DELETE_ENDPOINT="http://localhost:31310/v1/organizations"
    local response
    local org_uid

    echo "Testing home organization deletion... (this can take up to 5 minutes)"

    # First get the current home org UID
    response=$(curl -s --location --request GET "$DELETE_ENDPOINT" \
        --header 'Content-Type: application/json')

    # Find any home org that exists
    org_uid=$(echo "$response" | jq -r 'to_entries[] | select(.value.isHome == true) | .key')

    if [ -z "$org_uid" ]; then
        fail_test "No home organization found to delete"
        return
    fi

    echo "[DEBUG] Found home organization with UID: $org_uid"

    # Delete the home organization
    echo "[DEBUG] Deleting home organization..."
    response=$(curl -s --location --request DELETE "$DELETE_ENDPOINT/$org_uid")

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
        response=$(curl -s --location --request GET "$DELETE_ENDPOINT" \
            --header 'Content-Type: application/json')

        # Check if any home orgs exist
        if echo "$response" | jq -e 'to_entries[] | select(.value.isHome == true) | length == 0' > /dev/null; then
            echo -e "\n${GREEN}=========================================="
            echo "✓ Home organization successfully deleted and verified - TEST PASSED"
            echo "===========================================${NC}\n"
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
        sleep $CHECK_INTERVAL
        ((i++))
    done
}

#~~~ Start Chia ~~~ #

chia start wallet data
sleep 5

# call function to check if wallet it synced
is_wallet_synced

chia wallet show

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

# Test 3: Delete home organization
test_delete_home_org

# If we got here with no failures, run cleanup and exit successfully
cleanup

#~~~~ upload logs to artifacts here ~~~~#
#cat ~/.chia/mainnet/log/debug.log
