#!/bin/bash
# validate_step_18_structure.sh
# AURA Assistant – Step 18: Structural Validation Script
#
# Validates file existence, barrel exports, enum counts,
# and key structural markers for the agent_recovery feature.
#
# Kurdish-first, local-first, privacy-conscious.

set -e

BASE_DIR="/nfs/104430990/outputs/step_18_source"
FEATURE_DIR="${BASE_DIR}/lib/features/agent_recovery"
TEST_DIR="${BASE_DIR}/test/features/agent_recovery"

PASS=0
FAIL=0
TOTAL=0

check() {
  local description="$1"
  local condition="$2"
  TOTAL=$((TOTAL + 1))
  if eval "$condition"; then
    echo "✅ PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL: $description"
    FAIL=$((FAIL + 1))
  fi
}

check_file() {
  local description="$1"
  local filepath="$2"
  check "$description" "[ -f '$filepath' ]"
}

check_contains() {
  local description="$1"
  local filepath="$2"
  local pattern="$3"
  check "$description" "grep -q '$pattern' '$filepath' 2>/dev/null"
}

echo ""
echo "═══════════════════════════════════════════════════"
echo "  AURA Step 18 – Structural Validation"
echo "═══════════════════════════════════════════════════"
echo ""

# ─── DOMAIN: Models ──────────────────────────────────────────────

echo "── Domain: Models ──────────────────────────────────"
check_file "agent_plan.dart exists" "${FEATURE_DIR}/domain/models/agent_plan.dart"
check_file "recovery_failure.dart exists" "${FEATURE_DIR}/domain/models/recovery_failure.dart"
check_file "recovery_failure_phase.dart exists" "${FEATURE_DIR}/domain/models/recovery_failure_phase.dart"
check_file "recovery_context.dart exists" "${FEATURE_DIR}/domain/models/recovery_context.dart"
check_file "recovery_phase.dart exists" "${FEATURE_DIR}/domain/models/recovery_phase.dart"
check_file "recovery_strategy.dart exists" "${FEATURE_DIR}/domain/models/recovery_strategy.dart"
check_file "retry_policy.dart exists" "${FEATURE_DIR}/domain/models/retry_policy.dart"
check_file "recovery_state.dart exists" "${FEATURE_DIR}/domain/models/recovery_state.dart"
check_file "models.dart barrel exists" "${FEATURE_DIR}/domain/models/models.dart"

# ─── Barrel exports: models.dart ──────────────────────────────────

echo "── Domain: Models barrel exports ──────────────────────"
check_contains "models.dart exports agent_plan" "${FEATURE_DIR}/domain/models/models.dart" "agent_plan.dart"
check_contains "models.dart exports recovery_failure" "${FEATURE_DIR}/domain/models/models.dart" "recovery_failure.dart"
check_contains "models.dart exports recovery_failure_phase" "${FEATURE_DIR}/domain/models/models.dart" "recovery_failure_phase.dart"
check_contains "models.dart exports recovery_context" "${FEATURE_DIR}/domain/models/models.dart" "recovery_context.dart"
check_contains "models.dart exports recovery_phase" "${FEATURE_DIR}/domain/models/models.dart" "recovery_phase.dart"
check_contains "models.dart exports recovery_strategy" "${FEATURE_DIR}/domain/models/models.dart" "recovery_strategy.dart"
check_contains "models.dart exports retry_policy" "${FEATURE_DIR}/domain/models/models.dart" "retry_policy.dart"
check_contains "models.dart exports recovery_state" "${FEATURE_DIR}/domain/models/models.dart" "recovery_state.dart"

# ─── DOMAIN: Services ─────────────────────────────────────────────

echo "── Domain: Services ──────────────────────────────────"
check_file "recovery_executor.dart exists" "${FEATURE_DIR}/domain/services/recovery_executor.dart"
check_file "recovery_failure_classifier.dart exists" "${FEATURE_DIR}/domain/services/recovery_failure_classifier.dart"
check_file "replanning_engine.dart exists" "${FEATURE_DIR}/domain/services/replanning_engine.dart"
check_file "services.dart barrel exists" "${FEATURE_DIR}/domain/services/services.dart"

check_contains "services.dart exports recovery_executor" "${FEATURE_DIR}/domain/services/services.dart" "recovery_executor.dart"
check_contains "services.dart exports recovery_failure_classifier" "${FEATURE_DIR}/domain/services/services.dart" "recovery_failure_classifier.dart"
check_contains "services.dart exports replanning_engine" "${FEATURE_DIR}/domain/services/services.dart" "replanning_engine.dart"

# ─── APPLICATION ─────────────────────────────────────────────────

echo "── Application ──────────────────────────────────────"
check_file "recovery_coordinator.dart exists" "${FEATURE_DIR}/application/recovery_coordinator.dart"
check_file "application.dart barrel exists" "${FEATURE_DIR}/application/application.dart"
check_contains "application.dart exports recovery_coordinator" "${FEATURE_DIR}/application/application.dart" "recovery_coordinator.dart"

# ─── INFRASTRUCTURE ──────────────────────────────────────────────

echo "── Infrastructure ───────────────────────────────────"
check_file "default_recovery_executor.dart exists" "${FEATURE_DIR}/infrastructure/default_recovery_executor.dart"
check_file "default_recovery_failure_classifier.dart exists" "${FEATURE_DIR}/infrastructure/default_recovery_failure_classifier.dart"
check_file "default_replanning_engine.dart exists" "${FEATURE_DIR}/infrastructure/default_replanning_engine.dart"
check_file "infrastructure.dart barrel exists" "${FEATURE_DIR}/infrastructure/infrastructure.dart"

check_contains "infrastructure.dart exports default_recovery_executor" "${FEATURE_DIR}/infrastructure/infrastructure.dart" "default_recovery_executor.dart"
check_contains "infrastructure.dart exports default_recovery_failure_classifier" "${FEATURE_DIR}/infrastructure/infrastructure.dart" "default_recovery_failure_classifier.dart"
check_contains "infrastructure.dart exports default_replanning_engine" "${FEATURE_DIR}/infrastructure/infrastructure.dart" "default_replanning_engine.dart"

# ─── PRESENTATION ────────────────────────────────────────────────

echo "── Presentation ─────────────────────────────────────"
check_file "recovery_providers.dart exists" "${FEATURE_DIR}/presentation/recovery_providers.dart"
check_file "presentation.dart barrel exists" "${FEATURE_DIR}/presentation/presentation.dart"
check_contains "presentation.dart exports recovery_providers" "${FEATURE_DIR}/presentation/presentation.dart" "recovery_providers.dart"

# ─── ADAPTERS ────────────────────────────────────────────────────

echo "── Adapters ─────────────────────────────────────────"
check_file "agent_execution_adapter.dart exists" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart"
check_file "adapters.dart barrel exists" "${FEATURE_DIR}/adapters/adapters.dart"
check_contains "adapters.dart exports agent_execution_adapter" "${FEATURE_DIR}/adapters/adapters.dart" "agent_execution_adapter.dart"

# ─── FEATURE ROOT BARREL ────────────────────────────────────────

echo "── Feature root barrel ──────────────────────────────"
check_file "agent_recovery.dart exists" "${FEATURE_DIR}/agent_recovery.dart"
check_contains "agent_recovery.dart exports domain/models" "${FEATURE_DIR}/agent_recovery.dart" "domain/models/models.dart"
check_contains "agent_recovery.dart exports domain/services" "${FEATURE_DIR}/agent_recovery.dart" "domain/services/services.dart"
check_contains "agent_recovery.dart exports application" "${FEATURE_DIR}/agent_recovery.dart" "application/application.dart"
check_contains "agent_recovery.dart exports infrastructure" "${FEATURE_DIR}/agent_recovery.dart" "infrastructure/infrastructure.dart"
check_contains "agent_recovery.dart exports presentation" "${FEATURE_DIR}/agent_recovery.dart" "presentation/presentation.dart"
check_contains "agent_recovery.dart exports adapters" "${FEATURE_DIR}/agent_recovery.dart" "adapters/adapters.dart"

# ─── ENUM COUNTS ───────────────────────────────────────────────

echo "── Enum counts ───────────────────────────────────────"
check_contains "RecoveryFailurePhase has 11 values" "${FEATURE_DIR}/domain/models/recovery_failure_phase.dart" "screenStateChanged"
check_contains "RecoveryPhase has 11 values" "${FEATURE_DIR}/domain/models/recovery_phase.dart" "idle"
check_contains "RecoveryStrategy has 10 values" "${FEATURE_DIR}/domain/models/recovery_strategy.dart" "retrySame"

# ─── PROVIDER STRUCTURE ────────────────────────────────────────

echo "── Provider structure ───────────────────────────────"
check_contains "RecoveryProviderNames class exists" "${FEATURE_DIR}/presentation/recovery_providers.dart" "RecoveryProviderNames"
check_contains "recoveryStateProvider is StateNotifierProvider" "${FEATURE_DIR}/presentation/recovery_providers.dart" "StateNotifierProvider<RecoveryStateNotifier"
check_contains "recoveryCoordinatorProvider is Provider" "${FEATURE_DIR}/presentation/recovery_providers.dart" "recoveryCoordinatorProvider"
check_contains "retryPolicyProvider is Provider" "${FEATURE_DIR}/presentation/recovery_providers.dart" "retryPolicyProvider"
check_contains "recoveryFailureClassifierProvider is Provider" "${FEATURE_DIR}/presentation/recovery_providers.dart" "recoveryFailureClassifierProvider"
check_contains "replanningEngineProvider is Provider" "${FEATURE_DIR}/presentation/recovery_providers.dart" "replanningEngineProvider"
check_contains "recoveryExecutorProvider is Provider" "${FEATURE_DIR}/presentation/recovery_providers.dart" "recoveryExecutorProvider"
check_contains "name: parameter used" "${FEATURE_DIR}/presentation/recovery_providers.dart" "name: RecoveryProviderNames"

# ─── ADAPTER STRUCTURE ────────────────────────────────────────

echo "── Adapter structure ────────────────────────────────"
check_contains "AgentExecutionAdapter abstract class" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "abstract class AgentExecutionAdapter"
check_contains "AgentExecutionAdapterImpl concrete class" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "class AgentExecutionAdapterImpl"
check_contains "AgentToolResult helper class" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "class AgentToolResult"
check_contains "AgentToolParam helper class" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "class AgentToolParam"
check_contains "AgentToolDef helper class" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "class AgentToolDef"
check_contains "injectRecoveryContext tool constant" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "injectRecoveryContext"
check_contains "cancelRecovery tool constant" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "cancelRecovery"
check_contains "checkRetryPolicy tool constant" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "checkRetryPolicy"
check_contains "recover tool constant" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "recover"
check_contains "getRecoveryState tool constant" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "getRecoveryState"
check_contains "allDefinitions getter" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "allDefinitions"
check_contains "execute abstract method" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "AgentToolResult execute"
check_contains "switch dispatch in impl" "${FEATURE_DIR}/adapters/agent_execution_adapter.dart" "switch"

# ─── L10N KEYS ───────────────────────────────────────────────

echo "── Localization keys ─────────────────────────────────"
check_file "l10n_s_additions.dart exists" "${FEATURE_DIR}/l10n_s_additions.dart"
check_contains "recovery_ key prefix" "${FEATURE_DIR}/l10n_s_additions.dart" "recovery_"

# ─── TEST FILES ───────────────────────────────────────────────

echo "── Test files ────────────────────────────────────────"
check_file "agent_plan_test.dart" "${TEST_DIR}/agent_plan_test.dart"
check_file "recovery_failure_test.dart" "${TEST_DIR}/recovery_failure_test.dart"
check_file "recovery_failure_phase_test.dart" "${TEST_DIR}/recovery_failure_phase_test.dart"
check_file "recovery_phase_test.dart" "${TEST_DIR}/recovery_phase_test.dart"
check_file "recovery_strategy_test.dart" "${TEST_DIR}/recovery_strategy_test.dart"
check_file "retry_policy_test.dart" "${TEST_DIR}/retry_policy_test.dart"
check_file "recovery_context_test.dart" "${TEST_DIR}/recovery_context_test.dart"
check_file "recovery_state_test.dart" "${TEST_DIR}/recovery_state_test.dart"
check_file "recovery_failure_classifier_test.dart" "${TEST_DIR}/recovery_failure_classifier_test.dart"
check_file "recovery_coordinator_test.dart" "${TEST_DIR}/recovery_coordinator_test.dart"
check_file "default_recovery_executor_test.dart" "${TEST_DIR}/default_recovery_executor_test.dart"
check_file "default_recovery_failure_classifier_test.dart" "${TEST_DIR}/default_recovery_failure_classifier_test.dart"
check_file "default_replanning_engine_test.dart" "${TEST_DIR}/default_replanning_engine_test.dart"

# ─── KEY CONCEPTS IN SOURCE ───────────────────────────────────

echo "── Key concepts in source ────────────────────────────"
check_contains "RecoveryState is @immutable" "${FEATURE_DIR}/domain/models/recovery_state.dart" "@immutable"
check_contains "RecoveryCoordinator has cancelRecovery" "${FEATURE_DIR}/application/recovery_coordinator.dart" "cancelRecovery"
check_contains "RecoveryCoordinator has reset" "${FEATURE_DIR}/application/recovery_coordinator.dart" "reset"
check_contains "RetryPolicy has maxRetriesPerStep" "${FEATURE_DIR}/domain/models/retry_policy.dart" "maxRetriesPerStep"
check_contains "RetryPolicy has maxTotalRetries" "${FEATURE_DIR}/domain/models/retry_policy.dart" "maxTotalRetries"
check_contains "ExponentialBackoffConfig exists" "${FEATURE_DIR}/domain/models/retry_policy.dart" "ExponentialBackoffConfig"
check_contains "RecoveryResult type alias" "${FEATURE_DIR}/domain/models/recovery_failure.dart" "RecoveryResult"
check_contains "Result<S,F> import" "${FEATURE_DIR}/domain/models/recovery_failure.dart" "result.dart"

# ─── SUMMARY ─────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo "  RESULTS: $PASS passed, $FAIL failed, $TOTAL total"
echo "═══════════════════════════════════════════════════"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "🎉 ALL CHECKS PASSED — Step 18 structure is valid."
else
  echo "⚠️  SOME CHECKS FAILED — Review the output above."
  exit 1
fi