#!/usr/bin/env bash
# Step 24 — Structural Validation Script
# FAIL-CLOSED: UNKNOWN=DENY, ERROR=DENY, UNAVAILABLE=DENY
# Kurdish Sorani RTL first (locale='ku')
#
# This script:
#   1. Counts source and test files
#   2. Strips Dart comment lines before scanning for banned patterns
#   3. Scans for forbidden claims (runtime test, unit test passed, fake execution)
#   4. Validates Kurdish-first defaults in source
#   5. Validates FAIL-CLOSED keywords in source
#   6. Checks that no Steps 15-23 files are modified
#   7. Checks that conversation_provider.dart is not modified
#
# No Flutter/Dart SDK — structural validation only.

set -euo pipefail

WORKDIR="/nfs/104430990/outputs"
SOURCE_DIR="${WORKDIR}/step_24_source"
TEST_DIR="${WORKDIR}/step_24_tests"
PASS=0
FAIL=0
ERRORS=()

info()  { echo "[INFO]  $*"; }
pass()  { PASS=$((PASS+1)); echo "[PASS]  $*"; }
fail()  { FAIL=$((FAIL+1)); ERRORS+=("$*"); echo "[FAIL]  $*"; }

# ── 1. File counts ──────────────────────────────────────────────────────
info "=== File Counts ==="

DART_COUNT=$(find "${SOURCE_DIR}" -name '*.dart' | wc -l)
info "Source .dart files: ${DART_COUNT}"
if [ "${DART_COUNT}" -ge 28 ]; then
    pass "Source .dart file count >= 28 (${DART_COUNT})"
else
    fail "Source .dart file count < 28 (${DART_COUNT})"
fi

TOTAL_SOURCE=$(find "${SOURCE_DIR}" -type f | wc -l)
info "Total source files (incl. kt/xml): ${TOTAL_SOURCE}"
if [ "${TOTAL_SOURCE}" -ge 30 ]; then
    pass "Total source files >= 30 (${TOTAL_SOURCE})"
else
    fail "Total source files < 30 (${TOTAL_SOURCE})"
fi

TEST_COUNT=$(find "${TEST_DIR}" -name '*.dart' | wc -l)
info "Test .dart files: ${TEST_COUNT}"
if [ "${TEST_COUNT}" -ge 19 ]; then
    pass "Test file count >= 19 (${TEST_COUNT})"
else
    fail "Test file count < 19 (${TEST_COUNT})"
fi

KOTLIN_COUNT=$(find "${SOURCE_DIR}" -name '*.kt' | wc -l)
info "Kotlin files: ${KOTLIN_COUNT}"
if [ "${KOTLIN_COUNT}" -ge 2 ]; then
    pass "Kotlin file count >= 2 (${KOTLIN_COUNT})"
else
    fail "Kotlin file count < 2 (${KOTLIN_COUNT})"
fi

XML_COUNT=$(find "${SOURCE_DIR}" -name '*.xml' | wc -l)
info "XML manifest snippets: ${XML_COUNT}"
if [ "${XML_COUNT}" -ge 1 ]; then
    pass "XML manifest snippet present (${XML_COUNT})"
else
    fail "No XML manifest snippets found"
fi

# ── 2. Strip Dart comments and scan for banned patterns ─────────────────
info "=== Banned Pattern Scan (comment-stripped) ==="

# Create temp dir for stripped files
STRIPPED_DIR=$(mktemp -d)
trap 'rm -rf "${STRIPPED_DIR}"' EXIT

# Strip Dart comment lines (// and ///)
# Remove lines that are only comments (start with optional whitespace then //)
strip_dart_comments() {
    local src_file="$1"
    local rel_path="${src_file#${SOURCE_DIR}/}"
    local dst_file="${STRIPPED_DIR}/${rel_path}"
    mkdir -p "$(dirname "${dst_file}")"
    grep -vP '^\s*//' "${src_file}" > "${dst_file}" 2>/dev/null || true
}

while IFS= read -r -d '' f; do
    strip_dart_comments "${f}"
done < <(find "${SOURCE_DIR}" -name '*.dart' -print0)

# Also strip test file comments
while IFS= read -r -d '' f; do
    rel="${f#${TEST_DIR}/}"
    dst="${STRIPPED_DIR}/tests/${rel}"
    mkdir -p "$(dirname "${dst}")"
    grep -vP '^\s*//' "${f}" > "${dst}" 2>/dev/null || true
done < <(find "${TEST_DIR}" -name '*.dart' -print0)

# Banned patterns — never claim runtime test results
BANNED_PATTERNS=(
    'runtime test'
    'unit test passed'
    'all tests passed'
    'test suite passed'
    'flutter test'
    'test run completed'
    'executed successfully'
    'ran without errors'
    'coverage report'
    '100% coverage'
)

for pattern in "${BANNED_PATTERNS[@]}"; do
    MATCHES=$(grep -ril "${pattern}" "${STRIPPED_DIR}" 2>/dev/null || true)
    if [ -z "${MATCHES}" ]; then
        pass "No banned pattern: '${pattern}'"
    else
        fail "Banned pattern found: '${pattern}' in: ${MATCHES}"
    fi
done

# ── 3. Kurdish Sorani first validation ──────────────────────────────────
info "=== Kurdish Sorani RTL First ==="

# Check TriggerRequest defaults locale='ku'
REQUEST_FILE=$(find "${SOURCE_DIR}" -path '*/domain/entities/trigger_request.dart' | head -1)
if [ -n "${REQUEST_FILE}" ]; then
    if grep -qP "locale.*ku" "${REQUEST_FILE}"; then
        pass "TriggerRequest defaults locale to 'ku'"
    else
        fail "TriggerRequest does not default locale to 'ku'"
    fi
else
    fail "trigger_request.dart not found"
fi

# Check localization service defaults to ku
LOC_SERVICE=$(find "${SOURCE_DIR}" -path '*/trigger_localization_service.dart' | head -1)
if [ -n "${LOC_SERVICE}" ]; then
    if grep -qP 'ku|kurdish|sorani|ئاورا' "${LOC_SERVICE}"; then
        pass "Localization service contains Kurdish Sorani references"
    else
        fail "Localization service missing Kurdish Sorani references"
    fi
else
    fail "trigger_localization_service.dart not found"
fi

# Check localization keys for Kurdish markers
LOC_KEYS=$(find "${SOURCE_DIR}" -path '*/trigger_localization_keys.dart' | head -1)
if [ -n "${LOC_KEYS}" ]; then
    if grep -q 'ckb_IQ' "${LOC_KEYS}"; then
        pass "STT locale ckb_IQ present in localization keys"
    else
        fail "STT locale ckb_IQ missing from localization keys"
    fi
    if grep -q 'ku_IQ' "${LOC_KEYS}"; then
        pass "TTS locale ku_IQ present in localization keys"
    else
        fail "TTS locale ku_IQ missing from localization keys"
    fi
    if grep -qP "appLocale.*ku" "${LOC_KEYS}"; then
        pass "appLocale=ku present in localization keys"
    else
        fail "appLocale=ku missing from localization keys"
    fi
    if grep -q 'ئاورا' "${LOC_KEYS}"; then
        pass "Kurdish app name ئاورا present in localization keys"
    else
        fail "Kurdish app name ئاورا missing from localization keys"
    fi
else
    fail "trigger_localization_keys.dart not found"
fi

# ── 4. FAIL-CLOSED keyword validation ───────────────────────────────────
info "=== FAIL-CLOSED Design Validation ==="

# Check for FAIL-CLOSED markers in source
FAIL_CLOSED_FILES=$(grep -rl 'FAIL.CLOSED\|fail.closed\|UNKNOWN=DENY\|ERROR=DENY\|UNAVAILABLE=DENY' "${SOURCE_DIR}" 2>/dev/null || true)
if [ -n "${FAIL_CLOSED_FILES}" ]; then
    FC_COUNT=$(echo "${FAIL_CLOSED_FILES}" | wc -l)
    pass "FAIL-CLOSED markers found in ${FC_COUNT} source files"
else
    fail "No FAIL-CLOSED markers found in source files"
fi

# Check that TriggerType.unknown is handled
TRIGGER_TYPE_FILE=$(find "${SOURCE_DIR}" -path '*/trigger_type.dart' | head -1)
if [ -n "${TRIGGER_TYPE_FILE}" ]; then
    if grep -q 'unknown' "${TRIGGER_TYPE_FILE}"; then
        pass "TriggerType.unknown enum value exists"
    else
        fail "TriggerType.unknown enum value missing"
    fi
else
    fail "trigger_type.dart not found"
fi

# Check that SecurityBridgeAdapter handles unavailable
SECURITY_BRIDGE=$(find "${SOURCE_DIR}" -path '*/security_bridge_adapter.dart' | head -1)
if [ -n "${SECURITY_BRIDGE}" ]; then
    if grep -qP 'setSecurityAvailable|_isAvailable|isAvailable' "${SECURITY_BRIDGE}"; then
        pass "SecurityBridgeAdapter has availability control"
    else
        fail "SecurityBridgeAdapter missing availability control"
    fi
else
    fail "security_bridge_adapter.dart not found"
fi

# ── 5. No Steps 15-23 modifications ─────────────────────────────────────
info "=== Steps 15-23 Isolation Check ==="

STEP_REFS=$(grep -rl 'step_1[5-9]\|step_2[0-3]' "${SOURCE_DIR}" 2>/dev/null || true)
if [ -z "${STEP_REFS}" ]; then
    pass "No references to Steps 15-23 in source"
else
    fail "Found references to Steps 15-23: ${STEP_REFS}"
fi

# ── 6. conversation_provider.dart not modified ──────────────────────────
info "=== conversation_provider.dart Isolation ==="

CONV_PROVIDER=$(find "${SOURCE_DIR}" -name 'conversation_provider.dart' | head -1)
if [ -z "${CONV_PROVIDER}" ]; then
    pass "conversation_provider.dart not present in step_24_source (good)"
else
    fail "conversation_provider.dart found in step_24_source — must not be modified"
fi

# ── 7. Source signature checks ──────────────────────────────────────────
info "=== Source Signature Checks ==="

# TriggerType enum values
if grep -q 'quickSettings' "${TRIGGER_TYPE_FILE}" 2>/dev/null; then
    pass "TriggerType.quickSettings exists"
else
    fail "TriggerType.quickSettings missing"
fi

if grep -q 'assistantLongPress' "${TRIGGER_TYPE_FILE}" 2>/dev/null; then
    pass "TriggerType.assistantLongPress exists"
else
    fail "TriggerType.assistantLongPress missing"
fi

if grep -q 'homeLongPress' "${TRIGGER_TYPE_FILE}" 2>/dev/null; then
    pass "TriggerType.homeLongPress exists"
else
    fail "TriggerType.homeLongPress missing"
fi

# Platform channel name
PLATFORM_FILE=$(find "${SOURCE_DIR}" -name 'method_channel_constants.dart' | head -1)
if [ -n "${PLATFORM_FILE}" ]; then
    if grep -q 'com.aura.assistant/trigger_integration' "${PLATFORM_FILE}"; then
        pass "Platform channel name correct"
    else
        fail "Platform channel name incorrect"
    fi
else
    fail "method_channel_constants.dart not found"
fi

# Kotlin TileService
KT_TILE=$(find "${SOURCE_DIR}" -name 'AuraQuickSettingsTileService.kt' | head -1)
if [ -n "${KT_TILE}" ]; then
    if grep -q 'TileService' "${KT_TILE}"; then
        pass "Kotlin TileService extends TileService"
    else
        fail "Kotlin TileService does not extend TileService"
    fi
else
    fail "AuraQuickSettingsTileService.kt not found"
fi

# Flutter plugin
KT_PLUGIN=$(find "${SOURCE_DIR}" -name 'TriggerIntegrationPlugin.kt' | head -1)
if [ -n "${KT_PLUGIN}" ]; then
    if grep -q 'FlutterPlugin\|MethodCallHandler' "${KT_PLUGIN}"; then
        pass "Kotlin plugin implements FlutterPlugin/MethodCallHandler"
    else
        fail "Kotlin plugin missing FlutterPlugin implementation"
    fi
else
    fail "TriggerIntegrationPlugin.kt not found"
fi

# AndroidManifest snippet
MANIFEST_SNIPPET=$(find "${SOURCE_DIR}" -name 'AndroidManifest_snippet.xml' | head -1)
if [ -n "${MANIFEST_SNIPPET}" ]; then
    if grep -q 'BIND_QUICK_SETTINGS_TILE' "${MANIFEST_SNIPPET}"; then
        pass "AndroidManifest contains BIND_QUICK_SETTINGS_TILE permission"
    else
        fail "AndroidManifest missing BIND_QUICK_SETTINGS_TILE permission"
    fi
else
    fail "AndroidManifest_snippet.xml not found"
fi

# ── 8. Test structure validation ────────────────────────────────────────
info "=== Test Structure Validation ==="

DOMAIN_TESTS=$(find "${TEST_DIR}" -path '*/domain/*_test.dart' | wc -l)
if [ "${DOMAIN_TESTS}" -ge 5 ]; then
    pass "Domain tests present (${DOMAIN_TESTS})"
else
    fail "Domain tests insufficient (${DOMAIN_TESTS})"
fi

APP_TESTS=$(find "${TEST_DIR}" -path '*/application/*_test.dart' | wc -l)
if [ "${APP_TESTS}" -ge 5 ]; then
    pass "Application tests present (${APP_TESTS})"
else
    fail "Application tests insufficient (${APP_TESTS})"
fi

INFRA_TESTS=$(find "${TEST_DIR}" -path '*/infrastructure/*_test.dart' | wc -l)
if [ "${INFRA_TESTS}" -ge 4 ]; then
    pass "Infrastructure tests present (${INFRA_TESTS})"
else
    fail "Infrastructure tests insufficient (${INFRA_TESTS})"
fi

PRES_TESTS=$(find "${TEST_DIR}" -path '*/presentation/*_test.dart' | wc -l)
if [ "${PRES_TESTS}" -ge 2 ]; then
    pass "Presentation tests present (${PRES_TESTS})"
else
    fail "Presentation tests insufficient (${PRES_TESTS})"
fi

INT_TESTS=$(find "${TEST_DIR}" -path '*/integration/*_test.dart' | wc -l)
if [ "${INT_TESTS}" -ge 3 ]; then
    pass "Integration tests present (${INT_TESTS})"
else
    fail "Integration tests insufficient (${INT_TESTS})"
fi

BARREL_TESTS=$(find "${TEST_DIR}" -name 'barrel_export_test.dart' | wc -l)
if [ "${BARREL_TESTS}" -ge 1 ]; then
    pass "Barrel export test present"
else
    fail "Barrel export test missing"
fi

# ── 9. No SDK/runtime claims in test files ──────────────────────────────
info "=== Test File Claim Validation ==="

while IFS= read -r -d '' f; do
    # Strip comments from test files
    STRIPPED=$(grep -vP '^\s*//' "${f}" 2>/dev/null || true)
    for pattern in "${BANNED_PATTERNS[@]}"; do
        if echo "${STRIPPED}" | grep -qi "${pattern}"; then
            fail "Banned pattern '${pattern}' in test file: ${f}"
        fi
    done
done < <(find "${TEST_DIR}" -name '*.dart' -print0)

if [ "${FAIL}" -eq 0 ]; then
    pass "No banned patterns found in any test file"
fi

# ── Summary ─────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "  Step 24 Validation Summary"
echo "========================================"
echo "  PASSED: ${PASS}"
echo "  FAILED: ${FAIL}"
echo "========================================"

if [ "${FAIL}" -eq 0 ]; then
    echo "  ✅ ALL CHECKS PASSED"
    exit 0
else
    echo "  ❌ ${FAIL} CHECK(S) FAILED"
    echo ""
    echo "Failed checks:"
    for err in "${ERRORS[@]}"; do
        echo "  - ${err}"
    done
    exit 1
fi
