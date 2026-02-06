#!/opt/homebrew/bin/bash
# Compare line counts across SDKs in the ClodeMonster project
# Usage: ./scripts/compare_sdk_lines.sh [--detailed]

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DETAILED="${1:-}"

# Define SDKs to compare
# TypeScript files are deminified bundles: cli.js (full CLI) and sdk.mjs (SDK only)
declare -A SDK_PATHS=(
    ["TS SDK (sdk.mjs)"]="$PROJECT_ROOT/vendor/claude-agent-sdk-typescript-pkg"
    ["TS CLI (cli.js)"]="$PROJECT_ROOT/vendor/claude-agent-sdk-typescript-pkg"
    ["Python"]="$PROJECT_ROOT/vendor/claude-agent-sdk-python"
    ["ClaudeCodeSDK"]="$PROJECT_ROOT/ClaudeCodeSDK/Sources"
    ["NativeClaudeCodeSDK"]="$PROJECT_ROOT/NativeClaudeCodeSDK/Sources"
)

# Test paths for SDKs that have them
declare -A SDK_TEST_PATHS=(
    ["ClaudeCodeSDK"]="$PROJECT_ROOT/ClaudeCodeSDK/Tests"
    ["NativeClaudeCodeSDK"]="$PROJECT_ROOT/NativeClaudeCodeSDK/Tests"
)

# Define file patterns for each language
declare -A SDK_PATTERNS=(
    ["TS SDK (sdk.mjs)"]="sdk.mjs"
    ["TS CLI (cli.js)"]="cli.js"
    ["Python"]="*.py"
    ["ClaudeCodeSDK"]="*.swift"
    ["NativeClaudeCodeSDK"]="*.swift"
)

# Color codes
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

count_lines() {
    local path="$1"
    shift
    local patterns=("$@")
    local total=0

    if [[ ! -d "$path" ]]; then
        echo "0"
        return
    fi

    for pattern in "${patterns[@]}"; do
        local count=$(find "$path" -name "$pattern" -type f 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
        if [[ -n "$count" && "$count" =~ ^[0-9]+$ ]]; then
            total=$((total + count))
        fi
    done

    echo "$total"
}

count_files() {
    local path="$1"
    shift
    local patterns=("$@")
    local total=0

    if [[ ! -d "$path" ]]; then
        echo "0"
        return
    fi

    for pattern in "${patterns[@]}"; do
        local count=$(find "$path" -name "$pattern" -type f 2>/dev/null | wc -l | tr -d ' ')
        total=$((total + count))
    done

    echo "$total"
}

get_detailed_breakdown() {
    local path="$1"
    shift
    local patterns=("$@")

    if [[ ! -d "$path" ]]; then
        return
    fi

    for pattern in "${patterns[@]}"; do
        find "$path" -name "$pattern" -type f 2>/dev/null | while read -r file; do
            local lines=$(wc -l < "$file" | tr -d ' ')
            local relpath="${file#$PROJECT_ROOT/}"
            printf "    %6d  %s\n" "$lines" "$relpath"
        done
    done | sort -rn
}

echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}                    SDK Line Count Comparison                   ${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
echo ""

# Collect data
declare -A SDK_LINES
declare -A SDK_FILES
declare -A SDK_TEST_LINES
declare -A SDK_TEST_FILES

for sdk in "TS SDK (sdk.mjs)" "TS CLI (cli.js)" "Python" "ClaudeCodeSDK" "NativeClaudeCodeSDK"; do
    path="${SDK_PATHS[$sdk]}"
    IFS=' ' read -ra patterns <<< "${SDK_PATTERNS[$sdk]}"
    SDK_LINES[$sdk]=$(count_lines "$path" "${patterns[@]}")
    SDK_FILES[$sdk]=$(count_files "$path" "${patterns[@]}")

    # Count test lines if test path exists
    test_path="${SDK_TEST_PATHS[$sdk]:-}"
    if [[ -n "$test_path" && -d "$test_path" ]]; then
        SDK_TEST_LINES[$sdk]=$(count_lines "$test_path" "${patterns[@]}")
        SDK_TEST_FILES[$sdk]=$(count_files "$test_path" "${patterns[@]}")
    else
        SDK_TEST_LINES[$sdk]=0
        SDK_TEST_FILES[$sdk]=0
    fi
done

# Summary table
printf "${BOLD}%-25s %10s %10s %10s %10s${RESET}\n" "SDK" "Files" "Lines" "Test Files" "Test Lines"
echo "───────────────────────────────────────────────────────────────────────────"

for sdk in "TS SDK (sdk.mjs)" "TS CLI (cli.js)" "Python" "ClaudeCodeSDK" "NativeClaudeCodeSDK"; do
    lines=${SDK_LINES[$sdk]}
    files=${SDK_FILES[$sdk]}
    test_lines=${SDK_TEST_LINES[$sdk]}
    test_files=${SDK_TEST_FILES[$sdk]}
    printf "%-25s %10d %10d %10d %10d\n" "$sdk" "$files" "$lines" "$test_files" "$test_lines"
done

echo ""

# Code vs Test breakdown for Swift SDKs
echo -e "${BOLD}Code vs Test Breakdown (Swift SDKs):${RESET}"
echo "───────────────────────────────────────────────────────────────"
for sdk in "ClaudeCodeSDK" "NativeClaudeCodeSDK"; do
    lines=${SDK_LINES[$sdk]}
    test_lines=${SDK_TEST_LINES[$sdk]}
    total=$((lines + test_lines))
    if [[ $total -gt 0 ]]; then
        code_pct=$(echo "scale=1; $lines * 100 / $total" | bc)
        test_pct=$(echo "scale=1; $test_lines * 100 / $total" | bc)
        printf "%-25s  Code: %5d (%5s%%)  Tests: %5d (%5s%%)  Total: %5d\n" \
            "$sdk" "$lines" "$code_pct" "$test_lines" "$test_pct" "$total"
    fi
done

echo ""

# Comparison ratios
ts_sdk_lines=${SDK_LINES["TS SDK (sdk.mjs)"]}
ts_cli_lines=${SDK_LINES["TS CLI (cli.js)"]}
py_lines=${SDK_LINES["Python"]}
swift_lines=${SDK_LINES["ClaudeCodeSDK"]}
native_lines=${SDK_LINES["NativeClaudeCodeSDK"]}

echo -e "${BOLD}Comparisons (SDK-to-SDK):${RESET}"
echo "───────────────────────────────────────────────────────────────"

if [[ $py_lines -gt 0 && $ts_sdk_lines -gt 0 ]]; then
    ratio=$(echo "scale=2; $ts_sdk_lines / $py_lines" | bc)
    echo "TS SDK / Python:               $ratio x"
fi

if [[ $ts_sdk_lines -gt 0 && $swift_lines -gt 0 ]]; then
    ratio=$(echo "scale=2; $swift_lines / $ts_sdk_lines" | bc)
    pct=$(echo "scale=1; $swift_lines * 100 / $ts_sdk_lines" | bc)
    echo "ClaudeCodeSDK / TS SDK:        $ratio x ($pct%)"
fi

if [[ $py_lines -gt 0 && $swift_lines -gt 0 ]]; then
    ratio=$(echo "scale=2; $swift_lines / $py_lines" | bc)
    pct=$(echo "scale=1; $swift_lines * 100 / $py_lines" | bc)
    echo "ClaudeCodeSDK / Python:        $ratio x ($pct%)"
fi

if [[ $swift_lines -gt 0 && $native_lines -gt 0 ]]; then
    ratio=$(echo "scale=2; $native_lines / $swift_lines" | bc)
    pct=$(echo "scale=1; $native_lines * 100 / $swift_lines" | bc)
    echo "NativeClaudeCodeSDK / ClaudeCodeSDK: $ratio x ($pct%)"
fi

echo ""
echo -e "${BOLD}Note:${RESET} TS CLI includes bundled dependencies; TS SDK is the core library."

echo ""

# Detailed breakdown if requested
if [[ "$DETAILED" == "--detailed" ]]; then
    echo -e "${BOLD}Detailed Breakdown (by file, descending):${RESET}"
    echo "═══════════════════════════════════════════════════════════════"

    for sdk in "TS SDK (sdk.mjs)" "TS CLI (cli.js)" "Python" "ClaudeCodeSDK" "NativeClaudeCodeSDK"; do
        path="${SDK_PATHS[$sdk]}"
        IFS=' ' read -ra patterns <<< "${SDK_PATTERNS[$sdk]}"

        echo ""
        echo -e "${CYAN}$sdk:${RESET}"
        echo "───────────────────────────────────────────────────────────────"
        get_detailed_breakdown "$path" "${patterns[@]}" | head -20

        total_files=${SDK_FILES[$sdk]}
        if [[ $total_files -gt 20 ]]; then
            echo "    ... and $((total_files - 20)) more files"
        fi
    done
fi

echo ""
echo -e "${GREEN}Run with --detailed for per-file breakdown${RESET}"
