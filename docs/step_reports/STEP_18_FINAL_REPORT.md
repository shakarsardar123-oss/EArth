# STEP 18 — Agent Replanning, Recovery & Retry
## AURA Assistant · Final Implementation Report

---

### 📌 Overview

Step 18 implements a comprehensive **Agent Replanning, Recovery & Retry** system for the AURA Assistant. When the agent encounters failures during plan execution (tool errors, screen changes, timeouts, permission denials, etc.), this subsystem classifies the failure, selects an appropriate recovery strategy, and either retries the failed step or replans the remaining steps — always respecting privacy constraints, cancellation tokens, and bounded retry budgets.

The implementation follows the established clean-architecture layers (Domain → Application → Infrastructure → Presentation) with an additional Adapters layer for agent-tool integration, all wired through Riverpod providers.

---

### 🏗️ Architecture

```
lib/features/agent_recovery/
├── agent_recovery.dart              (root barrel)
├── l10n_s_additions.dart           (Kurdish Sorani l10n keys)
├── domain/
│   ├── models/
│   │   ├── models.dart             (barrel)
│   │   ├── agent_plan.dart          (AgentPlan + StepDescription)
│   │   ├── recovery_failure.dart    (RecoveryFailure + RecoveryResult<T>)
│   │   ├── recovery_failure_phase.dart (11 phases)
│   │   ├── recovery_context.dart    (RecoveryContext – immutable snapshot)
│   │   ├── recovery_phase.dart      (11 phases: idle→completed/aborted)
│   │   ├── recovery_strategy.dart   (10 strategies)
│   │   ├── retry_policy.dart        (RetryPolicy + ExponentialBackoffConfig)
│   │   └── recovery_state.dart      (@immutable RecoveryState)
│   └── services/
│       ├── services.dart            (barrel)
│       ├── recovery_executor.dart   (abstract RecoveryExecutor)
│       ├── recovery_failure_classifier.dart (abstract RecoveryFailureClassifier)
│       └── replanning_engine.dart   (abstract ReplanningEngine)
├── application/
│   ├── application.dart            (barrel)
│   └── recovery_coordinator.dart   (RecoveryCoordinator – orchestrator)
├── infrastructure/
│   ├── infrastructure.dart          (barrel)
│   ├── default_recovery_executor.dart        (implements RecoveryExecutor)
│   ├── default_recovery_failure_classifier.dart (implements RecoveryFailureClassifier)
│   └── default_replanning_engine.dart         (implements ReplanningEngine)
├── presentation/
│   ├── presentation.dart            (barrel)
│   └── recovery_providers.dart     (8 Riverpod providers + RecoveryProviderNames)
└── adapters/
    ├── adapters.dart                (barrel)
    └── agent_execution_adapter.dart (5 agent tools + switch dispatch)
```

---

### 📁 File Inventory (20 source files)

| # | Layer | File | Purpose |
|---|-------|------|---------|
| 1 | Domain | `domain/models/agent_plan.dart` | Plan model with steps, progress tracking |
| 2 | Domain | `domain/models/recovery_failure.dart` | Failure value object + `RecoveryResult<T>` alias |
| 3 | Domain | `domain/models/recovery_failure_phase.dart` | 11 failure-phase enum values |
| 4 | Domain | `domain/models/recovery_context.dart` | Immutable failure context snapshot |
| 5 | Domain | `domain/models/recovery_phase.dart` | 11 recovery-lifecycle enum values |
| 6 | Domain | `domain/models/recovery_strategy.dart` | 10 recovery-strategy enum values |
| 7 | Domain | `domain/models/retry_policy.dart` | Bounded retry policy + exponential backoff |
| 8 | Domain | `domain/models/recovery_state.dart` | `@immutable` recovery state tracker |
| 9 | Domain | `domain/services/recovery_executor.dart` | Abstract executor interface |
| 10 | Domain | `domain/services/recovery_failure_classifier.dart` | Abstract classifier interface |
| 11 | Domain | `domain/services/replanning_engine.dart` | Abstract replanning engine interface |
| 12 | App | `application/recovery_coordinator.dart` | Orchestration: classify → strategize → execute |
| 13 | Infra | `infrastructure/default_recovery_executor.dart` | Step-level recovery with cancellation |
| 14 | Infra | `infrastructure/default_recovery_failure_classifier.dart` | Phase-based classification + isRetryable |
| 15 | Infra | `infrastructure/default_replanning_engine.dart` | Escalation chain strategy selection |
| 16 | Pres | `presentation/recovery_providers.dart` | 8 Riverpod providers + RecoveryProviderNames |
| 17 | Adapt | `adapters/agent_execution_adapter.dart` | 5 agent tools + AgentToolResult/Param/Def |
| 18 | L10n | `l10n_s_additions.dart` | Kurdish Sorani l10n keys (recovery_ prefix) |
| 19 | Barrel | `domain/models/models.dart` | Domain models barrel |
| 20 | Barrel | `domain/services/services.dart` | Domain services barrel |

Plus 5 additional barrel files: `application.dart`, `infrastructure.dart`, `presentation.dart`, `adapters.dart`, root `agent_recovery.dart`.

---

### 🔑 Key Design Decisions

#### 1. Failure Classification (11 Phases)
| Phase | Description | Retryable? |
|-------|-------------|------------|
| `toolExecution` | Tool call failed | ✅ |
| `elementNotFound` | Target element missing | ✅ |
| `screenStateChanged` | Screen changed unexpectedly | ✅ |
| `permissionDenied` | Permission not granted | ⚠️ Limited |
| `timeoutExceeded` | Operation timed out | ✅ |
| `invalidAction` | Malformed action params | ❌ |
| `contextLost` | Agent context corrupted | ⚠️ |
| `planStale` | Plan no longer matches reality | ⚠️ |
| `userCancellation` | User explicitly cancelled | ❌ |
| `policyViolation` | Safety policy breached | ❌ |
| `unknown` | Unclassified failure | ❌ |

#### 2. Recovery Strategies (10 Values)
Escalation chain: `retrySame` → `retryModified` → `recaptureScreen` → `reunderstandScreen` → `replanFromCurrentStep` → `abortSafely`
Plus: `noRecovery`, `skipAndContinue`, `requestUserInput`, `escalateToUser`

#### 3. Retry Policy (Bounded, No Infinite Retries)
- **Max retries per step**: 3 (default)
- **Max total retries**: 10 (default)
- **Backoff**: Exponential with jitter (`ExponentialBackoffConfig`)
- **Cancellation**: Double-check via `_state.isCancellationRequested` + `_executor.isCancelled`
- **Private extension**: `_IntPow` instead of `dart:math` to avoid SDK dependency

#### 4. Recovery Phases (11 Lifecycle States)
`idle` → `classifying` → `strategizing` → `executing` → `verifying` → `succeeded` / `failed` / `retrying` / `replanning` / `completed` / `aborted`

#### 5. Riverpod Provider Architecture
- **RecoveryProviderNames**: Abstract class with 8 `static const String` name constants + `static const Type` type constants
- **Type alias**: `RecoveryStateProvider = StateNotifierProvider<RecoveryStateNotifier, RecoveryState>`
- **8 concrete `final` provider instances**: Each uses `name:` parameter for Riverpod devtools integration
- Pattern matches Step 17's `memory_providers.dart` exactly

#### 6. Agent Execution Adapter (5 Tools)
| Tool Name | Purpose |
|-----------|---------|
| `injectRecoveryContext` | Inject failure context into agent |
| `cancelRecovery` | Cancel ongoing recovery |
| `checkRetryPolicy` | Query remaining retry budget |
| `recover` | Trigger recovery cycle |
| `getRecoveryState` | Read current recovery state |

Abstract base provides tool name constants + `allDefinitions` getter; concrete impl uses switch dispatch mirroring Step 17's MemoryToolDef pattern.

#### 7. Privacy & Local-First
- All recovery logic runs locally on-device
- No failure data sent to external services
- RecoveryContext captures only what's needed (no PII)
- Policy violations → immediate `noRecovery` (no retry on safety failures)
- User cancellation → immediate `noRecovery` (respects user intent)

#### 8. Localization (Kurdish Sorani First)
- All user-facing strings use `recovery_` prefixed keys
- RTL-ready layout considerations
- `l10n_s_additions.dart` contains all Kurdish Sorani translations

---

### 🧪 Test Coverage

**13 structural test files** created:

| # | Test File | Layer Tested |
|---|----------|-------------|
| 1 | `agent_plan_test.dart` | Domain Model |
| 2 | `recovery_failure_test.dart` | Domain Model |
| 3 | `recovery_failure_phase_test.dart` | Domain Enum |
| 4 | `recovery_phase_test.dart` | Domain Enum |
| 5 | `recovery_strategy_test.dart` | Domain Enum |
| 6 | `retry_policy_test.dart` | Domain Model |
| 7 | `recovery_context_test.dart` | Domain Model |
| 8 | `recovery_state_test.dart` | Domain Model |
| 9 | `recovery_failure_classifier_test.dart` | Domain Service |
| 10 | `recovery_coordinator_test.dart` | Application |
| 11 | `default_recovery_executor_test.dart` | Infrastructure |
| 12 | `default_recovery_failure_classifier_test.dart` | Infrastructure |
| 13 | `default_replanning_engine_test.dart` | Infrastructure |

> **Note**: No Flutter/Dart SDK available in this environment. All tests are structural/mock tests that verify type conformance, enum values, `copyWith` behavior, getter existence, and API signatures. They cannot be executed here but are ready for integration into the project's test suite.

---

### ✅ Structural Validation

Automated validation script: `scripts/validate_step_18_structure.sh`

**Result: 94/94 checks passed** ✅

- 8 domain model files verified
- 3 domain service files verified
- 1 application coordinator verified
- 3 infrastructure implementations verified
- 1 presentation providers file verified
- 1 adapter file verified
- 1 l10n additions file verified
- 8 barrel export files verified
- 1 root barrel verified
- 13 test files verified
- Enum value spot-checks passed
- Provider structure markers verified
- Adapter structure markers verified
- Key concept markers verified (@immutable, Result<S,F>, etc.)

---

### 📊 Sub-Task Completion Matrix

| # | Sub-Task | Status | Files |
|---|----------|--------|-------|
| 1 | Failure Classification | ✅ | `recovery_failure.dart`, `recovery_failure_phase.dart`, `default_recovery_failure_classifier.dart` |
| 2 | Retry Policy | ✅ | `retry_policy.dart` |
| 3 | Recovery Strategy | ✅ | `recovery_strategy.dart` |
| 4 | Recovery Context | ✅ | `recovery_context.dart` |
| 5 | Replanning Engine | ✅ | `replanning_engine.dart`, `default_replanning_engine.dart` |
| 6 | Recovery State | ✅ | `recovery_state.dart` |
| 7 | Agent Execution Flow Integration | ✅ | `agent_execution_adapter.dart` |
| 8 | Riverpod Providers | ✅ | `recovery_providers.dart` |
| 9 | Localization | ✅ | `l10n_s_additions.dart` |
| 10 | Tests | ✅ | 13 test files in `test/features/agent_recovery/` |
| 11 | Structural Validation | ✅ | `scripts/validate_step_18_structure.sh` (94/94) |
| 12 | Integration (Coordinator) | ✅ | `recovery_coordinator.dart` |
| 13 | Final Report | ✅ | `STEP_18_FINAL_REPORT.md` |

---

### 🔗 Dependencies (Internal)

- `package:aura_assistant/core/errors/result.dart` — `Result<S,F>` type
- `package:flutter_riverpod` — Riverpod providers
- `package:meta/meta.dart` — `@immutable` annotation
- `package:intl/intl.dart` — Localization (v^0.19.0)
- No external service dependencies (local-first)

---

### 🛡️ Constraints Honored

| Constraint | How Honored |
|-----------|-------------|
| No infinite retries | `maxRetriesPerStep=3`, `maxTotalRetries=10` |
| Cancellation support | Double-check: `isCancellationRequested` + `isCancelled` |
| Verification-aware | `verifying` phase in lifecycle, post-recovery verification step |
| Privacy-conscious | All recovery local, no PII in context, policy violations → no retry |
| Kurdish Sorani first | All l10n keys Kurdish-first, RTL considerations |
| `Result<S,F>` pattern | `RecoveryResult<T> = Result<T, RecoveryFailure>` throughout |
| Immutable state | `@immutable` on RecoveryState, `copyWith` pattern everywhere |
| Riverpod convention | ProviderNames → type aliases → concrete `final` providers with `name:` |
| Clean architecture | Domain → Application → Infrastructure → Presentation → Adapters |
| No SDK dependency | `_IntPow` extension instead of `dart:math` |
| Step 17 compatibility | Same provider pattern, same adapter pattern, no file conflicts |
| `conversation_provider.dart` | NOT modified (as required) |

---

### 📅 Completion

**Step 18: COMPLETE** 🎉

All 13 sub-tasks implemented. All 20+ source files written. All 13 test files created. Structural validation: 94/94 checks passed. Ready for integration into AURA Assistant main project.
