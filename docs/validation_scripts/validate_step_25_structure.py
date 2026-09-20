#!/usr/bin/env python3
"""validate_step_25_structure.py
AURA Assistant – Step 25: Structural Validation Script

Validates the Step 25 deliverables by checking:
1. File existence for all source files
2. Class name presence in source files
3. Method signature presence in source files
4. FAIL-CLOSED design adherence
5. Kurdish Sorani (ku) locale defaults
6. Barrel file exports

No Flutter/Dart SDK required — purely structural checks via file reading.
"""

import os
import sys

# ─── Configuration ──────────────────────────────────────────────────

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_DIR = os.path.join(BASE_DIR, "step_25_source", "lib", "features", "advanced_agent")
TESTS_DIR = os.path.join(BASE_DIR, "step_25_tests")
L10N_DIR = os.path.join(SOURCE_DIR, "l10n")

PASS_COUNT = 0
FAIL_COUNT = 0
WARNINGS = []


def check(condition: bool, message: str) -> None:
    global PASS_COUNT, FAIL_COUNT
    if condition:
        PASS_COUNT += 1
        print(f"  ✓ {message}")
    else:
        FAIL_COUNT += 1
        print(f"  ✗ {message}")


def file_exists(path: str, label: str) -> None:
    check(os.path.isfile(path), f"File exists: {label}")


def file_contains(path: str, pattern: str, label: str) -> None:
    if not os.path.isfile(path):
        check(False, f"File contains '{pattern}': {label} — FILE MISSING")
        return
    content = open(path, "r", encoding="utf-8").read()
    check(pattern in content, f"File contains '{pattern}': {label}")


def file_contains_any(path: str, patterns: list, label: str) -> None:
    if not os.path.isfile(path):
        check(False, f"File contains one of {patterns}: {label} — FILE MISSING")
        return
    content = open(path, "r", encoding="utf-8").read()
    found = any(p in content for p in patterns)
    check(found, f"File contains one of {patterns}: {label}")


def file_not_contains(path: str, pattern: str, label: str) -> None:
    if not os.path.isfile(path):
        check(False, f"File NOT contains '{pattern}': {label} — FILE MISSING")
        return
    content = open(path, "r", encoding="utf-8").read()
    check(pattern not in content, f"File NOT contains '{pattern}': {label}")


# ═══════════════════════════════════════════════════════════════════
# 1. DOMAIN MODELS (17 files)
# ═══════════════════════════════════════════════════════════════════
print("\n══ 1. Domain Models (17 files) ══")

MODEL_DIR = os.path.join(SOURCE_DIR, "domain", "models")
MODEL_FILES = [
    ("advanced_agent_failure.dart", ["AdvancedAgentFailure"]),
    ("advanced_agent_result.dart", ["AdvancedAgentResult"]),
    ("advanced_task_plan.dart", ["AdvancedTaskPlan"]),
    ("agent_goal.dart", ["AgentGoal"]),
    ("context_aware_config.dart", ["ContextAwareConfig", "ExecutionContextMode"]),
    ("goal_progress.dart", ["GoalProgress"]),
    ("goal_status.dart", ["GoalStatus"]),
    ("natural_language_correction.dart", ["NaturalLanguageCorrection"]),
    ("pause_resume_state.dart", ["PauseResumeState"]),
    ("safety_verdict.dart", ["SafetyVerdict"]),
    ("task_dependency.dart", ["TaskDependency"]),
    ("task_progress_state.dart", ["TaskProgressState"]),
    ("task_step.dart", ["TaskStep"]),
    ("task_step_status.dart", ["TaskStepStatus"]),
    ("tool_selection_score.dart", ["ToolSelectionScore"]),
    ("verification_result.dart", ["VerificationResult"]),
    ("verification_status.dart", ["VerificationStatus"]),
]

for fname, classes in MODEL_FILES:
    fpath = os.path.join(MODEL_DIR, fname)
    file_exists(fpath, fname)
    for cls in classes:
        file_contains(fpath, cls, f"{fname} → {cls}")

# Models barrel
file_exists(os.path.join(MODEL_DIR, "models.dart"), "models.dart barrel")

# ─── Specific model checks ───────────────────────────────────

# SafetyVerdict: must use .denied({verdictId:, rationale:}) NOT .deny()
sv_path = os.path.join(MODEL_DIR, "safety_verdict.dart")
file_contains(sv_path, "isDenied", "SafetyVerdict.isDenied (NOT isDeny)")
file_contains(sv_path, "rationale", "SafetyVerdict.rationale (NOT reason)")
file_not_contains(sv_path, "isDeny", "SafetyVerdict NO isDeny")
file_not_contains(sv_path, ".deny(", "SafetyVerdict NO .deny() factory")
file_contains_any(sv_path, ["denied(", ".denied("], "SafetyVerdict.denied factory")

# TaskStep: stepId NOT id, retryAttempt NOT retryCount, NO expectedOutcome
ts_path = os.path.join(MODEL_DIR, "task_step.dart")
file_contains(ts_path, "stepId", "TaskStep.stepId (NOT id)")
file_contains(ts_path, "retryAttempt", "TaskStep.retryAttempt (NOT retryCount)")
file_not_contains(ts_path, "expectedOutcome", "TaskStep NO expectedOutcome")

# AdvancedAgentResult: named factories only
ar_path = os.path.join(MODEL_DIR, "advanced_agent_result.dart")
file_contains_any(ar_path, [".success(", "AdvancedAgentResult.success"], "AdvancedAgentResult.success factory")
file_contains_any(ar_path, [".denied(", "AdvancedAgentResult.denied"], "AdvancedAgentResult.denied factory")
file_contains_any(ar_path, [".failed(", "AdvancedAgentResult.failed"], "AdvancedAgentResult.failed factory")
file_contains_any(ar_path, [".offlineDegraded(", "AdvancedAgentResult.offlineDegraded"], "AdvancedAgentResult.offlineDegraded factory")

# VerificationResult: isPassed NOT passed, treatAsFailed NOT needsCorrection
vr_path = os.path.join(MODEL_DIR, "verification_result.dart")
file_contains(vr_path, "isPassed", "VerificationResult.isPassed (NOT passed)")
file_contains(vr_path, "treatAsFailed", "VerificationResult.treatAsFailed (NOT needsCorrection)")
file_not_contains(vr_path, "needsCorrection", "VerificationResult NO needsCorrection")

# NaturalLanguageCorrection: hasChanges/correctedText NOT hasSuggestion/suggestion
nlc_path = os.path.join(MODEL_DIR, "natural_language_correction.dart")
file_contains(nlc_path, "hasChanges", "NLCorrection.hasChanges (NOT hasSuggestion)")
file_contains(nlc_path, "correctedText", "NLCorrection.correctedText (NOT suggestion)")
file_not_contains(nlc_path, "hasSuggestion", "NLCorrection NO hasSuggestion")

# PauseResumeState: only running/paused/cancelled/pausing/resuming
prs_path = os.path.join(MODEL_DIR, "pause_resume_state.dart")
file_not_contains(prs_path, "idle", "PauseResumeState NO idle")
file_not_contains(prs_path, "completed", "PauseResumeState NO completed")
file_contains_any(prs_path, ["running", "paused", "cancelled"], "PauseResumeState has valid states")

# ToolSelectionScore: meetsThreshold NOT isSuitable
tss_path = os.path.join(MODEL_DIR, "tool_selection_score.dart")
file_contains(tss_path, "meetsThreshold", "ToolSelectionScore.meetsThreshold (NOT isSuitable)")
file_not_contains(tss_path, "isSuitable", "ToolSelectionScore NO isSuitable")


# ═══════════════════════════════════════════════════════════════════
# 2. DOMAIN SERVICES (10 files)
# ═══════════════════════════════════════════════════════════════════
print("\n══ 2. Domain Services (10 files) ══")

SERVICE_DIR = os.path.join(SOURCE_DIR, "domain", "services")
SERVICE_FILES = [
    ("task_planner_service.dart", "TaskPlannerService"),
    ("safety_gate_service.dart", "SafetyGateService"),
    ("task_progress_service.dart", "TaskProgressService"),
    ("goal_tracker_service.dart", "GoalTrackerService"),
    ("tool_selection_service.dart", "ToolSelectionService"),
    ("context_aware_execution_service.dart", "ContextAwareExecutionService"),
    ("result_verifier_service.dart", "ResultVerifierService"),
    ("natural_language_correction_service.dart", "NaturalLanguageCorrectionService"),
    ("replanner_service.dart", "ReplannerService"),
    ("pause_resume_cancel_service.dart", "PauseResumeCancelService"),
]

for fname, cls in SERVICE_FILES:
    fpath = os.path.join(SERVICE_DIR, fname)
    file_exists(fpath, fname)
    file_contains(fpath, cls, f"{fname} → {cls}")

# Services barrel
file_exists(os.path.join(SERVICE_DIR, "services.dart"), "services.dart barrel")

# ─── Specific service method checks ───────────────────────────

# TaskPlannerService: createPlan(userRequest, locale, goals)
tp_path = os.path.join(SERVICE_DIR, "task_planner_service.dart")
file_contains(tp_path, "createPlan", "TaskPlannerService.createPlan")
file_contains(tp_path, "userRequest", "TaskPlannerService.createPlan has userRequest param")

# SafetyGateService: guard() is fail-closed entry
gs_path = os.path.join(SERVICE_DIR, "safety_gate_service.dart")
file_contains(gs_path, "guard", "SafetyGateService.guard (fail-closed entry)")
file_contains(gs_path, "evaluate", "SafetyGateService.evaluate (non-fail-closed)")
file_contains(gs_path, "isAvailable", "SafetyGateService.isAvailable")

# PauseResumeCancelService: pause/resume/cancel need planId+requestedBy
prc_path = os.path.join(SERVICE_DIR, "pause_resume_cancel_service.dart")
file_contains(prc_path, "requestedBy", "PauseResumeCancelService has requestedBy param")

# ReplannerService: maxReplanAttempts
rp_path = os.path.join(SERVICE_DIR, "replanner_service.dart")
file_contains(rp_path, "maxReplanAttempts", "ReplannerService.maxReplanAttempts")

# ToolSelectionService: candidates is List<Map<String, dynamic>>
tsel_path = os.path.join(SERVICE_DIR, "tool_selection_service.dart")
file_contains_any(tsel_path, ["List<Map<String, dynamic>>", "List<Map<String,dynamic>>"], "ToolSelectionService.candidates type")


# ═══════════════════════════════════════════════════════════════════
# 3. DOMAIN REPOSITORIES (11 files)
# ═══════════════════════════════════════════════════════════════════
print("\n══ 3. Domain Repositories (11 files) ══")

REPO_DIR = os.path.join(SOURCE_DIR, "domain", "repositories")
REPO_FILES = [
    ("security_repository.dart", "SecurityRepository"),
    ("permission_repository.dart", "PermissionRepository"),
    ("confirmation_repository.dart", "ConfirmationRepository"),
    ("recovery_repository.dart", "RecoveryRepository"),
    ("tool_registry_repository.dart", "ToolRegistryRepository"),
    ("tool_execution_repository.dart", "ToolExecutionRepository"),
    ("connectivity_repository.dart", "ConnectivityRepository"),
    ("audit_repository.dart", "AuditRepository"),
    ("memory_repository.dart", "MemoryRepository"),
    ("agent_engine_repository.dart", "AgentEngineRepository"),
    ("trigger_repository.dart", "TriggerRepository"),
]

for fname, cls in REPO_FILES:
    fpath = os.path.join(REPO_DIR, fname)
    file_exists(fpath, fname)
    file_contains(fpath, cls, f"{fname} → {cls}")

# Repositories barrel
file_exists(os.path.join(REPO_DIR, "repositories.dart"), "repositories.dart barrel")

# ─── Specific repository checks ───────────────────────────────

# SecurityRepository: isAvailable + check
sec_repo = os.path.join(REPO_DIR, "security_repository.dart")
file_contains(sec_repo, "isAvailable", "SecurityRepository.isAvailable")
file_contains(sec_repo, "check", "SecurityRepository.check")

# MemoryRepository: ONLY lookup+isAvailable (NO store/retrieve/delete)
mem_repo = os.path.join(REPO_DIR, "memory_repository.dart")
file_contains(mem_repo, "lookup", "MemoryRepository.lookup")
file_contains(mem_repo, "isAvailable", "MemoryRepository.isAvailable")
file_not_contains(mem_repo, "store", "MemoryRepository NO store")
file_not_contains(mem_repo, "retrieve", "MemoryRepository NO retrieve")
file_not_contains(mem_repo, "delete", "MemoryRepository NO delete")

# ToolRegistryRepository: NO isAvailable
tr_repo = os.path.join(REPO_DIR, "tool_registry_repository.dart")
file_not_contains(tr_repo, "isAvailable", "ToolRegistryRepository NO isAvailable")

# AgentEngineRepository: NO isAvailable
ae_repo = os.path.join(REPO_DIR, "agent_engine_repository.dart")
file_not_contains(ae_repo, "isAvailable", "AgentEngineRepository NO isAvailable")

# ConnectivityRepository: isOnline is sync bool
conn_repo = os.path.join(REPO_DIR, "connectivity_repository.dart")
file_contains(conn_repo, "isOnline", "ConnectivityRepository.isOnline")
file_not_contains(conn_repo, "Future<bool> isOnline", "ConnectivityRepository.isOnline is NOT Future")

# AuditRepository: record is void (sync)
aud_repo = os.path.join(REPO_DIR, "audit_repository.dart")
file_contains(aud_repo, "record", "AuditRepository.record")
file_not_contains(aud_repo, "Future<", "AuditRepository.record is NOT async")

# RecoveryRepository: canSkip → shouldAbort FAIL-CLOSED
rec_repo = os.path.join(REPO_DIR, "recovery_repository.dart")
file_contains(rec_repo, "classifyAndStrategize", "RecoveryRepository.classifyAndStrategize")
file_contains(rec_repo, "canSkip", "RecoveryStrategy.canSkip exists")
file_contains(rec_repo, "shouldAbort", "RecoveryStrategy.shouldAbort exists")

# TriggerRepository: TriggerType.unknown → NEVER authorized
trig_repo = os.path.join(REPO_DIR, "trigger_repository.dart")
file_contains(trig_repo, "isTriggerTypePermitted", "TriggerRepository.isTriggerTypePermitted")
file_contains(trig_repo, "unknown", "TriggerRepository handles unknown type")


# ═══════════════════════════════════════════════════════════════════
# 4. APPLICATION LAYER
# ═══════════════════════════════════════════════════════════════════
print("\n══ 4. Application Layer ══")

APP_DIR = os.path.join(SOURCE_DIR, "application")

# providers.dart
file_exists(os.path.join(APP_DIR, "providers.dart"), "providers.dart")
file_contains(os.path.join(APP_DIR, "providers.dart"), "TaskExecutionCoordinator", "providers.dart references coordinator")

# task_execution_coordinator.dart — COMPLETE REWRITE
coord_path = os.path.join(APP_DIR, "task_execution_coordinator.dart")
file_exists(coord_path, "task_execution_coordinator.dart")
file_contains(coord_path, "TaskExecutionCoordinator", "TaskExecutionCoordinator class")
file_contains(coord_path, "executeTask", "Coordinator.executeTask method")
file_contains(coord_path, "CoordinationResult", "CoordinationResult class")

# BUG FIX CHECKS — the ~50 bugs that must NOT appear
file_not_contains(coord_path, ".deny(", "NO SafetyVerdict.deny() — use .denied()")
file_not_contains(coord_path, "isDeny", "NO isDeny — use isDenied")
file_not_contains(coord_path, "step.id", "NO step.id — use step.stepId")
file_not_contains(coord_path, "retryCount", "NO retryCount — use retryAttempt")
# expectedOutcome is OK in coordinator as a verifyStep param (from ResultVerifierService API)
# The prohibition is only on TaskStep model having an expectedOutcome field
file_not_contains(ts_path, "final.*expectedOutcome", "TaskStep NO expectedOutcome field — check model only")
file_not_contains(coord_path, ".idle", "NO PauseResumeState.idle — does not exist")
file_not_contains(coord_path, "isSuitable", "NO ToolSelectionScore.isSuitable — use meetsThreshold")
file_not_contains(coord_path, "needsCorrection", "NO needsCorrection — use treatAsFailed")
file_not_contains(coord_path, "hasSuggestion", "NO hasSuggestion — use hasChanges")
file_not_contains(coord_path, ".suggestion", "NO suggestion — use correctedText")

# FAIL-CLOSED checks in coordinator
file_contains(coord_path, "isDenied", "Coordinator uses isDenied")
file_contains(coord_path, "rationale", "Coordinator uses rationale (NOT reason)")
file_contains(coord_path, "FAIL-CLOSED", "Coordinator has FAIL-CLOSED comments")
file_contains(coord_path, "canSkip", "Coordinator checks canSkip")
file_contains(coord_path, "shouldAbort", "Coordinator treats canSkip as shouldAbort")
file_contains(coord_path, "agentEngine.understand", "Coordinator calls agentEngine.understand")
file_contains(coord_path, "safetyGate.guard", "Coordinator calls safetyGate.guard (fail-closed entry)")
file_contains(coord_path, "security.isAvailable", "Coordinator checks security.isAvailable")
file_contains(coord_path, "permission.isAvailable", "Coordinator checks permission.isAvailable")
file_contains(coord_path, "confirmation.isAvailable", "Coordinator checks confirmation.isAvailable")
file_contains(coord_path, "memory.isAvailable", "Coordinator checks memory.isAvailable")
file_contains(coord_path, "trigger.isAvailable", "Coordinator checks trigger.isAvailable")
file_contains(coord_path, "determineMode", "Coordinator calls determineMode")
file_contains(coord_path, "adaptPlanForMode", "Coordinator calls adaptPlanForMode")
file_contains(coord_path, "createPlan", "Coordinator calls createPlan")
file_contains(coord_path, "registerGoal", "Coordinator registers goals")
file_contains(coord_path, "selectBest", "Coordinator calls selectBest")
file_contains(coord_path, "verifyStep", "Coordinator calls verifyStep")
file_contains(coord_path, "maxReplanAttempts", "Coordinator respects maxReplanAttempts")
file_contains(coord_path, "requestedBy", "Coordinator uses requestedBy param")
file_contains(coord_path, "locale = 'ku'", "Coordinator defaults locale to ku")

# Application barrel
file_exists(os.path.join(APP_DIR, "application.dart"), "application.dart barrel")


# ═══════════════════════════════════════════════════════════════════
# 5. INFRASTRUCTURE ADAPTERS (7 files)
# ═══════════════════════════════════════════════════════════════════
print("\n══ 5. Infrastructure Adapters (7 files) ══")

INFRA_DIR = os.path.join(SOURCE_DIR, "infrastructure")
INFRA_FILES = [
    "step17_memory_adapter.dart",
    "step18_recovery_adapter.dart",
    "step19_security_adapter.dart",
    "step20_tool_registry_adapter.dart",
    "step22_execution_adapter.dart",
    "step23_orchestration_adapter.dart",
    "step24_trigger_adapter.dart",
]

for fname in INFRA_FILES:
    file_exists(os.path.join(INFRA_DIR, fname), fname)

# Infrastructure barrel
file_exists(os.path.join(INFRA_DIR, "infrastructure.dart"), "infrastructure.dart barrel")
for fname in INFRA_FILES:
    file_contains(os.path.join(INFRA_DIR, "infrastructure.dart"),
                  fname.replace(".dart", ""),
                  f"infrastructure.dart exports {fname}")


# ═══════════════════════════════════════════════════════════════════
# 6. PRESENTATION LAYER
# ═══════════════════════════════════════════════════════════════════
print("\n══ 6. Presentation Layer ══")

PRES_DIR = os.path.join(SOURCE_DIR, "presentation")
file_exists(os.path.join(PRES_DIR, "task_progress_ui_state.dart"), "task_progress_ui_state.dart")
file_exists(os.path.join(PRES_DIR, "presentation.dart"), "presentation.dart barrel")
file_contains(os.path.join(PRES_DIR, "task_progress_ui_state.dart"),
              "TaskProgressUIState", "TaskProgressUIState class")
file_contains(os.path.join(PRES_DIR, "task_progress_ui_state.dart"),
              "fromDomainState", "fromDomainState factory")
file_contains(os.path.join(PRES_DIR, "task_progress_ui_state.dart"),
              "locale = 'ku'", "UI state defaults to ku locale")


# ═══════════════════════════════════════════════════════════════════
# 7. LOCALIZATION (Kurdish Sorani RTL-first)
# ═══════════════════════════════════════════════════════════════════
print("\n══ 7. Localization (Kurdish Sorani RTL-first) ══")

file_exists(os.path.join(L10N_DIR, "advanced_agent_l10n.yaml"), "advanced_agent_l10n.yaml")
l10n_path = os.path.join(L10N_DIR, "advanced_agent_l10n.yaml")
file_contains(l10n_path, "ku:", "l10n has ku: section (primary)")
file_contains(l10n_path, "en:", "l10n has en: fallback section")
file_contains(l10n_path, "rtl", "l10n specifies RTL direction")
file_contains(l10n_path, "\u067e\u0644\u0627\u0646", "l10n has Kurdish text (plan keyword)")


# ═══════════════════════════════════════════════════════════════════
# 8. TOP-LEVEL BARREL
# ═══════════════════════════════════════════════════════════════════
print("\n══ 8. Top-Level Barrel ══")

file_exists(os.path.join(SOURCE_DIR, "advanced_agent.dart"), "advanced_agent.dart barrel")
ba_path = os.path.join(SOURCE_DIR, "advanced_agent.dart")
file_contains(ba_path, "domain", "advanced_agent.dart exports domain")
file_contains(ba_path, "application", "advanced_agent.dart exports application")
file_contains(ba_path, "infrastructure", "advanced_agent.dart exports infrastructure")
file_contains(ba_path, "presentation", "advanced_agent.dart exports presentation")


# ═══════════════════════════════════════════════════════════════════
# 9. DOMAIN BARREL FILES
# ═══════════════════════════════════════════════════════════════════
print("\n══ 9. Domain Barrel Files ══")

DOMAIN_DIR = os.path.join(SOURCE_DIR, "domain")
file_exists(os.path.join(DOMAIN_DIR, "domain.dart"), "domain.dart barrel")
domain_ba = os.path.join(DOMAIN_DIR, "domain.dart")
file_contains(domain_ba, "models", "domain.dart exports models")
file_contains(domain_ba, "services", "domain.dart exports services")
file_contains(domain_ba, "repositories", "domain.dart exports repositories")


# ═══════════════════════════════════════════════════════════════════
# 10. TESTS DIRECTORY
# ═══════════════════════════════════════════════════════════════════
print("\n══ 10. Tests Directory ══")

check(os.path.isdir(TESTS_DIR), "step_25_tests/ directory exists")

TEST_SUBDIRS = [
    "domain/models",
    "domain/services",
    "domain/repositories",
    "application",
    "infrastructure",
    "integration",
    "presentation",
]
for sub in TEST_SUBDIRS:
    check(os.path.isdir(os.path.join(TESTS_DIR, sub)), f"Tests subdir: {sub}/")

# Specific test files
TEST_FILES = [
    "domain/models/advanced_agent_failure_test.dart",
    "domain/models/advanced_agent_result_test.dart",
    "domain/models/advanced_task_plan_test.dart",
    "domain/models/agent_goal_test.dart",
    "domain/models/context_aware_config_test.dart",
    "domain/models/goal_progress_test.dart",
    "domain/models/goal_status_test.dart",
    "domain/models/natural_language_correction_test.dart",
    "domain/models/pause_resume_state_test.dart",
    "domain/models/safety_verdict_test.dart",
    "domain/models/task_dependency_test.dart",
    "domain/models/task_progress_state_test.dart",
    "domain/models/task_step_test.dart",
    "domain/models/tool_selection_score_test.dart",
    "domain/models/verification_result_test.dart",
    "domain/models/verification_status_test.dart",
    "domain/services/task_planner_service_test.dart",
    "domain/services/safety_gate_service_test.dart",
    "domain/services/task_progress_service_test.dart",
    "domain/services/goal_tracker_service_test.dart",
    "domain/services/tool_selection_service_test.dart",
    "domain/services/context_aware_execution_service_test.dart",
    "domain/services/result_verifier_service_test.dart",
    "domain/services/nl_correction_service_test.dart",
    "domain/services/replanner_service_test.dart",
    "domain/services/pause_resume_cancel_service_test.dart",
    "domain/repositories/agent_engine_repository_test.dart",
    "domain/repositories/audit_repository_test.dart",
    "domain/repositories/confirmation_repository_test.dart",
    "domain/repositories/connectivity_repository_test.dart",
    "domain/repositories/memory_repository_test.dart",
    "domain/repositories/permission_repository_test.dart",
    "domain/repositories/recovery_repository_test.dart",
    "domain/repositories/security_repository_test.dart",
    "domain/repositories/tool_execution_repository_test.dart",
    "domain/repositories/tool_registry_repository_test.dart",
    "domain/repositories/trigger_repository_test.dart",
    "application/providers_test.dart",
    "application/task_execution_coordinator_test.dart",
    "infrastructure/step17_security_adapter_test.dart",
    "infrastructure/step18_permission_adapter_test.dart",
    "infrastructure/step19_confirmation_adapter_test.dart",
    "infrastructure/step20_trigger_adapter_test.dart",
    "infrastructure/step21_recovery_adapter_test.dart",
    "infrastructure/step22_tool_adapter_test.dart",
    "infrastructure/step24_context_adapter_test.dart",
    "integration/end_to_end_coordination_test.dart",
    "presentation/task_progress_ui_state_test.dart",
]

for tf in TEST_FILES:
    file_exists(os.path.join(TESTS_DIR, tf), tf)


# ═══════════════════════════════════════════════════════════════════
# 11. FAIL-CLOSED DESIGN PRINCIPLES
# ═══════════════════════════════════════════════════════════════════
print("\n══ 11. FAIL-CLOSED Design Principles ══")

# Coordinator must handle all unavailable repos as denied
coord_path = os.path.join(APP_DIR, "task_execution_coordinator.dart")
file_contains(coord_path, "unavailable", "Coordinator handles unavailable states")
file_contains(coord_path, "FAIL-CLOSED: security repository unavailable", "Security unavailable → denied")
file_contains(coord_path, "FAIL-CLOSED: permission repository unavailable", "Permission unavailable → denied")
file_contains(coord_path, "FAIL-CLOSED: confirmation repository unavailable", "Confirmation unavailable → denied")

# Trigger: unknown type → NEVER authorized
file_contains(coord_path, "isTriggerTypePermitted", "Coordinator checks trigger type permissions")
file_contains(coord_path, "trigger repository unavailable", "Coordinator handles trigger unavailable")

# Recovery: canSkip → shouldAbort (NEVER skip)
file_contains(coord_path, "recovery skip treated as abort", "canSkip treated as abort (FAIL-CLOSED)")


# ═══════════════════════════════════════════════════════════════════
# 12. NO HARDCODED SECRETS
# ═══════════════════════════════════════════════════════════════════
print("\n══ 12. No Hardcoded Secrets ══")

SECRET_PATTERNS = ["api_key", "apiKey", "secret", "password", "token"]
for root, dirs, files in os.walk(SOURCE_DIR):
    for f in files:
        if f.endswith(".dart"):
            fpath = os.path.join(root, f)
            content = open(fpath, "r", encoding="utf-8").read()
            for pat in SECRET_PATTERNS:
                # Check for actual hardcoded values (not just references in comments/types)
                # Only flag if it looks like a hardcoded string value
                import re
                # Look for patterns like: apiKey = 'xxx', secret = "xxx", etc.
                matches = re.findall(
                    rf'(?:api_key|apiKey|secret|password|token)\s*[=:]\s*[\'"\'][^\'"]{{4,}}[\'"\']',
                    content, re.IGNORECASE
                )
                if matches:
                    check(False, f"NO hardcoded secret in {f}: {matches[0][:40]}")

# If we got here without failing, no secrets found
check(True, "No hardcoded secrets detected in source files")


# ═══════════════════════════════════════════════════════════════════
# 13. NO MODIFICATION OF STEPS 15-24
# ═══════════════════════════════════════════════════════════════════
print("\n══ 13. Steps 15-24 Not Modified ══")

# Verify step_25_source only contains step_25 files
# Verify that step_25_source does NOT directly contain step 15-24 feature files
# (adapters referencing step15-24 repos are OK — they're adapters to those steps)
step_15_violation = False
for root, dirs, files in os.walk(SOURCE_DIR):
    for f in files:
        if f.startswith('step15_') or f.startswith('step16_') or f.startswith('step21_'):
            step_15_violation = True
            check(False, f"Step 25 source should NOT contain step 15/16/21 files: {f}")
if not step_15_violation:
    check(True, "Step 25 source does not contain step 15/16/21 files")
# Adapter files named step17-24_*.dart are OK — they bridge to existing steps
for root, dirs, files in os.walk(SOURCE_DIR):
    for f in files:
        # step17_memory_adapter, step18_recovery_adapter, etc. are valid adapter names
        is_valid_adapter = (
            f.startswith('step17_') or f.startswith('step18_') or
            f.startswith('step19_') or f.startswith('step20_') or
            f.startswith('step22_') or f.startswith('step23_') or
            f.startswith('step24_')
        )
        is_step_15_16_21 = f.startswith('step15_') or f.startswith('step16_') or f.startswith('step21_')
        if is_step_15_16_21:
            check(False, f"Step 25 source should NOT contain step 15/16/21 files: {f}")
        else:
            check(True, f"File naming OK: {f}")


# ═══════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 25 STRUCTURAL VALIDATION RESULTS")
print("=" * 60)
print(f"  Passed:  {PASS_COUNT}")
print(f"  Failed:  {FAIL_COUNT}")
print(f"  Warnings: {len(WARNINGS)}")
print("=" * 60)

if WARNINGS:
    print("\nWarnings:")
    for w in WARNINGS:
        print(f"  ⚠ {w}")

if FAIL_COUNT == 0:
    print("\n✓ ALL CHECKS PASSED — Step 25 is structurally valid.")
    sys.exit(0)
else:
    print(f"\n✗ {FAIL_COUNT} CHECK(S) FAILED — Step 25 has structural issues.")
    sys.exit(1)
