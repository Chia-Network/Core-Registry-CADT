#!/bin/bash

# Exit on undefined variable
set -u

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print usage
print_usage() {
    echo "Usage: $0 <cadt-host> [options]"
    echo ""
    echo "Arguments:"
    echo "  cadt-host   The CADT server hostname (e.g., localhost:31310)"
    echo ""
    echo "Options:"
    echo "  --api-key <key>        The API key for authentication (optional)"
    echo "  --dry-run              Show what would be done without actually doing it"
    echo "  --projects-only        Push only projects (skip units)"
    echo "  --units-only           Push only units (skip projects)"
    echo "  --stage-only           Only stage data, do not commit from staging"
    echo "  --projects-json <path> Path to projects JSON file"
    echo "  --units-json <path>    Path to units JSON file"
    echo "  --help                 Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 localhost:31310"
    echo "  $0 localhost:31310 --api-key my-api-key"
    echo "  $0 localhost:31310 --api-key my-api-key --dry-run"
    echo "  $0 localhost:31310 --projects-only"
    echo "  $0 localhost:31310 --units-only"
    echo "  $0 localhost:31310 --stage-only"
    echo "  $0 localhost:31310 --projects-json /path/to/projects.json"
    echo "  $0 localhost:31310 --units-json /path/to/units.json"
}

# Function to check if jq is installed
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        print_status $RED "Error: jq is required but not installed."
        echo "Please install jq to continue."
        exit 1
    fi
}

# Function to validate JSON file
validate_json_file() {
    local json_file=$1
    local file_type=$2

    if [[ ! -f "$json_file" ]]; then
        print_status $RED "Error: $file_type JSON file not found at $json_file"
        exit 1
    fi

    if ! jq empty "$json_file" 2>/dev/null; then
        print_status $RED "Error: Invalid JSON in $json_file"
        exit 1
    fi

    print_status $GREEN "✓ $file_type JSON file validated successfully"
}

# Function to make API call with error handling
make_api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4

    print_status $BLUE "Making $method request to $endpoint..." >&2
    if [[ -n "$description" ]]; then
        print_status $BLUE "Description: $description" >&2
    fi

    # Ensure endpoint starts with /v1 and construct full URL properly
    local full_url
    if [[ "$endpoint" == /* ]]; then
        # Endpoint already starts with /, just concatenate
        full_url="$BASE_URL$endpoint"
    else
        # Endpoint doesn't start with /, add it
        full_url="$BASE_URL/$endpoint"
    fi

    local curl_cmd="curl -s --location --request $method '$full_url'"

    # Add API key header if provided
    if [[ -n "$API_KEY" ]]; then
        curl_cmd="$curl_cmd --header 'x-api-key: $API_KEY'"
    fi

    # Add content type and data for POST/PUT requests
    if [[ "$method" == "POST" || "$method" == "PUT" ]]; then
        curl_cmd="$curl_cmd --header 'Content-Type: application/json'"
        if [[ -n "$data" ]]; then
            curl_cmd="$curl_cmd --data-raw '$data'"
        fi
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        print_status $YELLOW "[DRY RUN] Would execute: $curl_cmd" >&2
        # Return a mock response for dry run mode
        if [[ "$endpoint" == "/v1/organizations" ]]; then
            echo '{"mock-org-uid":{"orgUid":"mock-org-uid","isHome":true}}'
        else
            echo '{"success":true,"message":"Mock response for dry run"}'
        fi
        return 0
    fi

    local response
    response=$(eval "$curl_cmd")
    local curl_exit_code=$?

    # Check if the request was successful
    if [[ $curl_exit_code -ne 0 ]]; then
        print_status $RED "Error: Failed to make $method request to $endpoint (curl exit code: $curl_exit_code)" >&2
        return 1
    fi

    # Check for error in response
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local error_msg=$(echo "$response" | jq -r '.error // .message // "Unknown error"')
        print_status $RED "API Error: $error_msg" >&2
        print_status $RED "Full API response:" >&2
        echo "$response" | jq '.' >&2
        # Print details/errors if present
        if echo "$response" | jq -e '.details' >/dev/null 2>&1; then
            print_status $RED "Details:" >&2
            echo "$response" | jq '.details' >&2
        fi
        if echo "$response" | jq -e '.errors' >/dev/null 2>&1; then
            print_status $RED "Errors:" >&2
            echo "$response" | jq '.errors' >&2
        fi
        return 1
    fi

    # Check for success field
    if echo "$response" | jq -e '.success == false' >/dev/null 2>&1; then
        local error_msg=$(echo "$response" | jq -r '.message // "Unknown error"')
        print_status $RED "API Error: $error_msg" >&2
        print_status $RED "Full API response:" >&2
        echo "$response" | jq '.' >&2
        # Print details/errors if present
        if echo "$response" | jq -e '.details' >/dev/null 2>&1; then
            print_status $RED "Details:" >&2
            echo "$response" | jq '.details' >&2
        fi
        if echo "$response" | jq -e '.errors' >/dev/null 2>&1; then
            print_status $RED "Errors:" >&2
            echo "$response" | jq '.errors' >&2
        fi
        return 1
    fi

    print_status $GREEN "✓ $method request successful" >&2
    # Return only the response, not the debug messages
    echo "$response"
    return 0
}

# Function to check if CADT server is reachable
check_server_health() {
    print_status $BLUE "Checking CADT server health..."

    local curl_cmd="curl -s --location --request GET '$BASE_URL/health'"

    # Add API key header if provided
    if [[ -n "$API_KEY" ]]; then
        curl_cmd="$curl_cmd --header 'x-api-key: $API_KEY'"
    fi

    local health_response
    health_response=$(eval "$curl_cmd" 2>/dev/null || echo "{}")

    if echo "$health_response" | jq -e '.message == "OK"' >/dev/null 2>&1; then
        print_status $GREEN "✓ CADT server is healthy"
        return 0
    else
        print_status $RED "Error: CADT server is not responding or unhealthy"
        print_status $RED "Response: $health_response"
        return 1
    fi
}

# Function to check if home organization exists
check_home_organization() {
    print_status $BLUE "Checking for home organization..."

    local org_response
    org_response=$(make_api_call "GET" "/v1/organizations" "" "Get organizations")

    if [[ $? -ne 0 ]]; then
        print_status $RED "Error: Failed to get organizations"
        return 1
    fi

    print_status $BLUE "DEBUG: Organizations response: $org_response"

    # If response is empty, just {}, or just [], treat as no orgs
    if [[ -z "$org_response" ]] || [[ "$org_response" == "{}" ]] || [[ "$org_response" == "[]" ]]; then
        print_status $RED "Error: No home organization found. Please create a home organization first."
        exit 1
    fi

    # Try to parse as object; if fails, treat as no orgs
    if ! echo "$org_response" | jq -e 'type == "object"' >/dev/null 2>&1; then
        print_status $RED "Error: No home organization found. Please create a home organization first."
        exit 1
    fi

    # Count organizations with isHome=true
    local home_orgs=$(echo "$org_response" | jq '[to_entries[] | select(.value.isHome == true)] | length')
    if [[ $? -ne 0 ]]; then
        print_status $RED "Error: No home organization found. Please create a home organization first."
        exit 1
    fi

    print_status $BLUE "DEBUG: Found $home_orgs home organizations"

    if (( home_orgs == 0 )); then
        print_status $RED "Error: No home organization found. Please create a home organization first."
        exit 1
    else
        print_status $GREEN "✓ Found $home_orgs home organization(s)"
        # Optionally print the orgUids of home orgs for debugging
        echo "$org_response" | jq -r '.[] | select(.isHome == true) | .orgUid'
        return 0
    fi
}

# Function to clean staging area
clean_staging() {
    print_status $BLUE "Cleaning staging area..."

    make_api_call "DELETE" "/v1/staging/clean" "" "Clean staging area"

    if [[ $? -eq 0 ]]; then
        print_status $GREEN "✓ Staging area cleaned"
    else
        print_status $YELLOW "Warning: Failed to clean staging area (this might be expected if staging was already empty)"
    fi
}

# Function to push a single project
push_project() {
    local project_data=$1
    local project_name=$2

    print_status $BLUE "Pushing project: $project_name"

    local response
    response=$(make_api_call "POST" "/v1/projects" "$project_data" "Create project: $project_name")

    if [[ $? -eq 0 ]]; then
        local uuid=$(echo "$response" | jq -r '.uuid // empty')
        if [[ -n "$uuid" ]]; then
            print_status $GREEN "✓ Project staged successfully with UUID: $uuid"
            echo "$uuid" >> "$STAGED_PROJECT_UUIDS_FILE"
        else
            print_status $YELLOW "Warning: No UUID returned for project: $project_name"
        fi
        return 0
    else
        print_status $RED "Failed to push project: $project_name"
        return 1
    fi
}

# Function to push a single unit
push_unit() {
    local unit_data=$1
    local unit_identifier=$2

    print_status $BLUE "Pushing unit: $unit_identifier"

    local response
    response=$(make_api_call "POST" "/v1/units" "$unit_data" "Create unit: $unit_identifier")

    if [[ $? -eq 0 ]]; then
        local uuid=$(echo "$response" | jq -r '.uuid // empty')
        if [[ -n "$uuid" ]]; then
            print_status $GREEN "✓ Unit staged successfully with UUID: $uuid"
            echo "$uuid" >> "$STAGED_UNIT_UUIDS_FILE"
        else
            print_status $YELLOW "Warning: No UUID returned for unit: $unit_identifier"
        fi
        return 0
    else
        print_status $RED "Failed to push unit: $unit_identifier"
        return 1
    fi
}

# Function to commit all staged items
commit_staged_items() {
    print_status $BLUE "Committing all staged items..."

    # Collect all staged UUIDs from both files
    local all_staged_uuids=()

    # Read project UUIDs if file exists and has content
    if [[ -f "$STAGED_PROJECT_UUIDS_FILE" ]] && [[ -s "$STAGED_PROJECT_UUIDS_FILE" ]]; then
        while IFS= read -r uuid; do
            if [[ -n "$uuid" ]]; then
                all_staged_uuids+=("$uuid")
            fi
        done < "$STAGED_PROJECT_UUIDS_FILE"
    fi

    # Read unit UUIDs if file exists and has content
    if [[ -f "$STAGED_UNIT_UUIDS_FILE" ]] && [[ -s "$STAGED_UNIT_UUIDS_FILE" ]]; then
        while IFS= read -r uuid; do
            if [[ -n "$uuid" ]]; then
                all_staged_uuids+=("$uuid")
            fi
        done < "$STAGED_UNIT_UUIDS_FILE"
    fi

    if [[ ${#all_staged_uuids[@]} -eq 0 ]]; then
        print_status $YELLOW "No staged items to commit"
        return 0
    fi

    print_status $BLUE "Committing ${#all_staged_uuids[@]} staged items..."

    # Build the commit request with all UUIDs
    local ids_param=""
    for uuid in "${all_staged_uuids[@]}"; do
        if [[ -z "$ids_param" ]]; then
            ids_param="?ids=$uuid"
        else
            ids_param="$ids_param&ids=$uuid"
        fi
    done

    local response
    response=$(make_api_call "POST" "/v1/staging/commit$ids_param" "" "Commit all staged items")

    if [[ $? -eq 0 ]]; then
        print_status $GREEN "✓ All staged items committed successfully"
        print_status $GREEN "Response: $(echo "$response" | jq -r '.message // "Success"')"
    else
        print_status $RED "Failed to commit staged items"
        return 1
    fi
}

# Function to verify staging
verify_staging() {
    print_status $BLUE "Verifying staging..."

    local staging_response
    staging_response=$(make_api_call "GET" "/v1/staging" "" "Get staging status")

    if [[ $? -eq 0 ]]; then
        local staging_count=$(echo "$staging_response" | jq 'length')
        print_status $GREEN "✓ Found $staging_count items in staging"

        if [[ "$staging_count" -gt 0 ]]; then
            echo "Staging details:"
            echo "$staging_response" | jq -r '.[] | "  - \(.table): \(.action) (\(.uuid))"'
        fi
    else
        print_status $RED "Failed to verify staging"
        return 1
    fi
}

# Function to find a file in common locations
find_file() {
    local filename=$1
    local file_type=$2

    # If a custom path was provided, use it
    if [[ -n "$3" ]]; then
        if [[ -f "$3" ]]; then
            print_status $BLUE "Using specified $file_type file: $3" >&2
            echo "$3"
            return 0
        else
            print_status $RED "Error: Specified $file_type file not found: $3" >&2
            return 1
        fi
    fi

    # Check relative paths in order of preference
    local search_paths=(
        "../test-data/generic-test-data/$filename"  # From script directory
        "./tests/test-data/generic-test-data/$filename"  # From project root
    )

    for path in "${search_paths[@]}"; do
        if [[ -f "$path" ]]; then
            print_status $BLUE "Found $file_type file at: $path" >&2
            echo "$path"
            return 0
        fi
    done

    print_status $RED "Error: Could not find $file_type file ($filename) in any of the expected locations:" >&2
    for path in "${search_paths[@]}"; do
        print_status $RED "  - $path" >&2
    done
    print_status $RED "Please specify the path using --${file_type,,}-json option" >&2
    return 1
}

# Main script logic
main() {
    # Initialize variables
    local CADT_HOST=""
    local API_KEY=""
    local DRY_RUN="false"
    local PROJECTS_ONLY="false"
    local UNITS_ONLY="false"
    local STAGE_ONLY="false"
    local PROJECTS_JSON=""
    local UNITS_JSON=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --api-key)
                if [[ -z "$2" ]] || [[ "$2" == --* ]]; then
                    print_status $RED "Error: --api-key requires a value"
                    print_usage
                    exit 1
                fi
                API_KEY="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --projects-only)
                PROJECTS_ONLY="true"
                shift
                ;;
            --units-only)
                UNITS_ONLY="true"
                shift
                ;;
            --stage-only)
                STAGE_ONLY="true"
                shift
                ;;
            --projects-json)
                if [[ -z "$2" ]]; then
                    print_status $RED "Error: --projects-json requires a value"
                    print_usage
                    exit 1
                fi
                PROJECTS_JSON="$2"
                shift 2
                ;;
            --units-json)
                if [[ -z "$2" ]]; then
                    print_status $RED "Error: --units-json requires a value"
                    print_usage
                    exit 1
                fi
                UNITS_JSON="$2"
                shift 2
                ;;
            --help)
                print_usage
                exit 0
                ;;
            -*)
                print_status $RED "Unknown option: $1"
                print_usage
                exit 1
                ;;
            *)
                if [[ -z "$CADT_HOST" ]]; then
                    CADT_HOST="$1"
                else
                    print_status $RED "Too many arguments"
                    print_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$CADT_HOST" ]]; then
        print_status $RED "Error: CADT host is required"
        print_usage
        exit 1
    fi

    # Accept both host[:port] and full URLs (http:// or https://)
    # Remove trailing slash for consistency
    CADT_HOST_CLEAN="${CADT_HOST%/}"

    # Extract protocol if present
    if [[ "$CADT_HOST_CLEAN" =~ ^https?:// ]]; then
        BASE_URL="$CADT_HOST_CLEAN"
    else
        BASE_URL="http://$CADT_HOST_CLEAN"
    fi

    # Validate format: must not contain double slashes (except after protocol) or backslashes
    if [[ "$CADT_HOST_CLEAN" =~ ://.*// ]] || [[ "$CADT_HOST_CLEAN" == *"\\"* ]]; then
        print_status $RED "Error: Invalid CADT host format: $CADT_HOST"
        print_status $RED "CADT host should be in format: hostname[:port] or full URL (e.g., localhost:31310 or https://host:port)"
        print_usage
        exit 1
    fi

    STAGED_PROJECT_UUIDS_FILE="/tmp/staged_project_uuids.txt"
    STAGED_UNIT_UUIDS_FILE="/tmp/staged_unit_uuids.txt"

    # Clean up any existing UUID files
    rm -f "$STAGED_PROJECT_UUIDS_FILE" "$STAGED_UNIT_UUIDS_FILE"

    # Discover JSON files if not provided
    if [[ "$UNITS_ONLY" != "true" ]]; then
        PROJECTS_JSON=$(find_file "10-projects.json" "Projects" "$PROJECTS_JSON")
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
    fi

    if [[ "$PROJECTS_ONLY" != "true" ]]; then
        UNITS_JSON=$(find_file "10-units.json" "Units" "$UNITS_JSON")
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
    fi

    print_status $GREEN "=== CADT Test Data Push Script ==="
    print_status $BLUE "CADT Host: $CADT_HOST"
    if [[ -n "$API_KEY" ]]; then
        print_status $BLUE "API Key: ${API_KEY:0:8}..."
    else
        print_status $YELLOW "No API key provided - using unauthenticated requests"
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status $YELLOW "DRY RUN MODE - No actual changes will be made"
    fi
    if [[ "$PROJECTS_ONLY" == "true" ]]; then
        print_status $YELLOW "PROJECTS ONLY MODE - Will skip units"
    fi
    if [[ "$UNITS_ONLY" == "true" ]]; then
        print_status $YELLOW "UNITS ONLY MODE - Will skip projects"
    fi
    if [[ "$STAGE_ONLY" == "true" ]]; then
        print_status $YELLOW "STAGE ONLY MODE - Data has been left in staging and not committed."
    fi
    if [[ "$UNITS_ONLY" != "true" ]]; then
        print_status $BLUE "Projects file: $PROJECTS_JSON"
    fi
    if [[ "$PROJECTS_ONLY" != "true" ]]; then
        print_status $BLUE "Units file: $UNITS_JSON"
    fi
    echo ""

    # Check dependencies
    check_dependencies

    # Check server health
    if ! check_server_health; then
        exit 1
    fi

    # Check for home organization
    if ! check_home_organization; then
        exit 1
    fi

    # Clean staging area
    clean_staging

    # Process projects (unless units-only mode)
    if [[ "$UNITS_ONLY" != "true" ]]; then
        print_status $GREEN "=== Processing Projects ==="

        # Validate projects JSON file
        validate_json_file "$PROJECTS_JSON" "Projects"

        # Read and process projects JSON file
        local projects_file="$PROJECTS_JSON"
        local project_count=$(jq 'length' "$projects_file")

        print_status $BLUE "Found $project_count projects to push"
        echo ""

        # Push each project
        local project_success_count=0
        local project_failure_count=0

        for i in $(seq 0 $((project_count - 1))); do
            print_status $BLUE "Processing project $((i + 1)) of $project_count..."
            local project_data=$(jq -c ".[$i]" "$projects_file")
            local project_name=$(echo "$project_data" | jq -r '.projectName')

            if push_project "$project_data" "$project_name"; then
                ((project_success_count++))
                print_status $GREEN "✓ Project $((i + 1)) processed successfully"
            else
                ((project_failure_count++))
                print_status $RED "✗ Project $((i + 1)) failed"
            fi

            echo ""
        done

        print_status $GREEN "=== Projects Push Summary ==="
        print_status $GREEN "Successfully pushed: $project_success_count projects"
        if [[ $project_failure_count -gt 0 ]]; then
            print_status $RED "Failed to push: $project_failure_count projects"
        fi
        echo ""
    fi

    # Process units (unless projects-only mode)
    if [[ "$PROJECTS_ONLY" != "true" ]]; then
        print_status $GREEN "=== Processing Units ==="

        # Validate units JSON file
        validate_json_file "$UNITS_JSON" "Units"

        # Read and process units JSON file
        local units_file="$UNITS_JSON"
        local unit_count=$(jq 'length' "$units_file")

        print_status $BLUE "Found $unit_count units to push"
        echo ""

        # Push each unit
        local unit_success_count=0
        local unit_failure_count=0

        for i in $(seq 0 $((unit_count - 1))); do
            print_status $BLUE "Processing unit $((i + 1)) of $unit_count..."
            local unit_data=$(jq -c ".[$i]" "$units_file")
            local unit_identifier="Unit $((i + 1)) - $(echo "$unit_data" | jq -r '.projectLocationId // "Unknown"')"

            if push_unit "$unit_data" "$unit_identifier"; then
                ((unit_success_count++))
                print_status $GREEN "✓ Unit $((i + 1)) processed successfully"
            else
                ((unit_failure_count++))
                print_status $RED "✗ Unit $((i + 1)) failed"
            fi

            echo ""
        done

        print_status $GREEN "=== Units Push Summary ==="
        print_status $GREEN "Successfully pushed: $unit_success_count units"
        if [[ $unit_failure_count -gt 0 ]]; then
            print_status $RED "Failed to push: $unit_failure_count units"
        fi
        echo ""
    fi

    # Verify staging
    verify_staging
    echo ""

    # Commit staged items (unless --stage-only)
    if [[ "$STAGE_ONLY" == "true" ]]; then
        print_status $YELLOW "STAGE ONLY MODE - Data has been left in staging and not committed."
    else
        local total_success=0
        if [[ "$UNITS_ONLY" != "true" ]]; then
            total_success=$((total_success + project_success_count))
        fi
        if [[ "$PROJECTS_ONLY" != "true" ]]; then
            total_success=$((total_success + unit_success_count))
        fi

        if [[ $total_success -gt 0 ]]; then
            print_status $BLUE "=== Committing Staged Items ==="

            # Commit all staged items in a single operation
            if ! commit_staged_items; then
                print_status $RED "Failed to commit staged items"
                exit 1
            fi

            print_status $GREEN "✓ All operations completed successfully!"
        else
            print_status $YELLOW "No items were successfully pushed, skipping commit"
        fi
    fi

    # Clean up
    rm -f "$STAGED_PROJECT_UUIDS_FILE" "$STAGED_UNIT_UUIDS_FILE"

    print_status $GREEN "=== Script completed ==="
}

# Run main function with all arguments
main "$@"
