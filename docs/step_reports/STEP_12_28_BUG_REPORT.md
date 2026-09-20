# AURA Steps 12–28 Bug Report

**Project:** AURA Assistant v0.13.0+13  
**Scope:** Steps 12–28 ONLY (Steps 1–11 and 6 main sections NOT touched)  
**Date:** 2026-08-31  
**Method:** Structural audit — Flutter/Dart SDK NOT available  
**Total Confirmed Bugs:** 10 (IDs: #1, #2, #3, #5, #6, #7, #8, #9, #10, #11)  
**Note:** Bug #4 was never assigned — do NOT renumber.

---

## BUG #1 — Barrel File Missing Export

**Severity:** LOW (compile-warning, potential runtime import failure)  
**Step:** 20  
**File:** `tool_registry/domain/services/services.dart`  
**Category:** Barrel completeness

### Description
The barrel file `services.dart` does NOT export `tool_execution_gate.dart`, even though `tool_execution_gate.dart` exists in the same `domain/services/` directory. Other service files (`tool_confirmation_service.dart`) ARE exported.

### Impact
- Any file trying to import `tool_execution_gate.dart` via the barrel import `package:aura_assistant/features/tool_registry/domain/services/services.dart` will fail to resolve `ToolExecutionGate`.
- Direct imports still work, but this breaks the convention that barrel files are the single import point.

### Fix
Add the missing export to `services.dart`:
```dart
export 'tool_execution_gate.dart';
```

---

## BUG #2 — Duplicate ToolExecutionGate (Domain vs Application)

**Severity:** HIGH (conflicting contracts — callers may use wrong version)  
**Step:** 20  
**Files:**  
- `tool_registry/domain/services/tool_execution_gate.dart`  
- `tool_registry/application/tool_execution_gate.dart`  

**Category:** Duplicate class / conflicting API

### Description
Two classes named `ToolExecutionGate` exist with incompatible signatures:

| Aspect | Domain version | Application version |
|---|---|---|
| Params | 3 positional params | 7+ named params |
| Return type | `Result<T>` | `ToolResult<T>` (= `Result<T, ToolFailure>`) |
| Methods | `canExecute`, `execute`, `recordResult` | `canExecute`, `execute`, `recordResult`, `validateAndExecute`, `executeWithConfirmation`, `executeWithConfirmationAndTimeout`, `isToolPermitted`, etc. |
| isToolPermitted | ❌ Not present | ✅ Present |
| validateAndExecute | ❌ Not present | ✅ Present |
| Confirmation integration | ❌ None | ✅ Full confirmation flow |

### Impact
- The domain version is a minimal stub; the application version is the full-featured gate.
- If any consumer imports the domain version, they miss confirmation, validation, and `ToolResult<T>` typing.
- Barrel file (BUG #1) only exports domain version currently.

### Fix
**Keep the application version as canonical** (more complete, correct return type `ToolResult<T>`).  
Add a re-export from the barrel so that `services.dart` points to the application version.  
Mark the domain version as `@Deprecated` or remove it entirely.

---

## BUG #3 — Duplicate ToolExecutorRegistry (Infrastructure root vs executors/)

**Severity:** MEDIUM (inconsistent API — `byRiskLevel` param type differs)  
**Step:** 22  
**Files:**  
- `tool_execution/infrastructure/tool_executor_registry.dart` (root)  
- `tool_execution/infrastructure/executors/tool_executor_registry.dart` (executors/)  

**Category:** Duplicate class / type mismatch

### Description
Two classes named `ToolExecutorRegistry` with different `byRiskLevel` signatures:

| Aspect | Root version | Executors/ version (canonical) |
|---|---|---|
| `byRiskLevel` param | `String riskLevel` | `ToolRiskLevel riskLevel` |
| Consistency with Tool model | ✅ Tool.riskLevel is `String` | ❌ Tool.riskLevel is `String` but param is `ToolRiskLevel` enum |
| Completeness | Minimal | More complete (canonical) |

### Impact
- The executors/ version's `byRiskLevel(ToolRiskLevel)` will ALWAYS fail when comparing `t.riskLevel == riskLevel` because `t.riskLevel` is `String` and `riskLevel` is `ToolRiskLevel` enum → See BUG #10.
- The root version's `byRiskLevel(String)` is type-consistent with `Tool.riskLevel` but is less complete.

### Fix
**Keep infrastructure/executors/ as canonical** (more complete).  
Change the `byRiskLevel` parameter type from `ToolRiskLevel` to `String` in the executors/ version to match `Tool.riskLevel` type, OR add a `riskLevelString` getter to Tool. Remove the root duplicate.

---

## BUG #5 — Step 24 vs Step 25 TriggerType/Verdict/Request Complete Incompatibility

**Severity:** CRITICAL (bridge between steps completely broken)  
**Steps:** 24 ↔ 25  
**Category:** Cross-step interface incompatibility

### Description
Step 24 and Step 25 define completely different trigger types, authorization verdicts, and request models:

**TriggerType enum:**
| Step 24 | Step 25 |
|---|---|
| `quickSettings` | `voiceCommand` |
| `assistantLongPress` | `schedule` |
| `homeLongPress` | `event` |
| `notificationAction` | `proximity` |
| `inApp` | `gesture` |
| `unknown` | `unknown` |

Only `unknown` overlaps — the other 5 values are completely different.

**TriggerAuthorizationVerdict:**
| Aspect | Step 24 | Step 25 |
|---|---|---|
| Fields | `authorized`, `reason?`, `policyId?` | `authorized`, `reason?`, `triggerType?` |
| Denied factory | `.denied({reason?, policyId?})` | `.denied({reason?})` |
| Authorized factory | `.authorized({policyId?})` | `.allowed({required TriggerType type, reason?})` |

**TriggerRequest:**
| Field | Step 24 | Step 25 |
|---|---|---|
| ID | `requestId` | `id` |
| Type | `triggerType` | `type` |
| Source | `source` | ❌ Not present |
| Timestamp | `timestamp` | `timestamp` |
| Payload | `textPayload?` | `payload` (different type) |
| Voice | `isVoiceInput` | ❌ Not present |
| Metadata | `metadata` | ❌ Not present |
| Locale | `locale='ku'` | ❌ Not present |

**Repository:**
| Method | Step 24 | Step 25 |
|---|---|---|
| `authorize` | `Future<Verdict>` | `Future<Verdict>` |
| `isAvailable` | `Future<bool>` (async) | `bool` (sync) |
| `isTriggerTypePermitted` | `Future<bool>` (async) | `bool` (sync) |

**Step24TriggerAdapter** (in Step 25) uses Step 25's OWN types (`voiceCommand`, `schedule`, `event`) — NOT Step 24's types. The bridge is completely broken.

### Impact
- No Step 25 code can correctly interpret Step 24 trigger events.
- The adapter silently maps Step 25 types to Step 25 types instead of Step 24 → Step 25.
- Async/sync mismatches in repository methods mean callers expecting `Future<bool>` get `bool` and vice versa.

### Fix
1. Step24TriggerAdapter must import Step 24's `TriggerType`, `TriggerAuthorizationVerdict`, and `TriggerRequest` and translate them to Step 25's types.
2. Map each Step 24 trigger type to the closest Step 25 equivalent (e.g., `notificationAction` → `event`, `inApp` → `event`).
3. Fix the `isAvailable` / `isTriggerTypePermitted` async/sync mismatch.
4. Add `locale` field to Step 25's `TriggerRequest` or handle in adapter.

---

## BUG #6 — TranslationResult.denied Factory Param Mismatch

**Severity:** MEDIUM (runtime crash — 4 call sites will fail to compile)  
**Step:** 22  
**Category:** API contract violation

### Description
`TranslationResult.denied` factory requires `{required String requestId, String? reason}` but 4 call sites invoke `TranslationResult.denied()` with NO arguments.

### Call Sites
Files calling `TranslationResult.denied()` without the required `requestId`:
- `tool_output_normalizer.dart` (3 occurrences)
- `tool_execution_engine.dart` (1 occurrence)

### Fix
Either:
1. Make `requestId` optional in the factory: `TranslationResult.denied({String? requestId, String? reason})`  
2. OR update all 4 call sites to pass the required `requestId` parameter.

---

## BUG #7 — ScreenTarget Missing copyWith Method

**Severity:** MEDIUM (runtime crash when called)  
**Step:** 22  
**Category:** Missing method

### Description
`ScreenTarget` class has NO `copyWith` method, but `StubVisionRepository.verifyTarget` calls `target.copyWith(verified: false)`. This will fail at compile time or runtime.

### Fix
Add `copyWith` to `ScreenTarget`:
```dart
ScreenTarget copyWith({
  String? id,
  String? name,
  Rect? bounds,
  bool? verified,
  double? confidence,
}) {
  return ScreenTarget(
    id: id ?? this.id,
    name: name ?? this.name,
    bounds: bounds ?? this.bounds,
    verified: verified ?? this.verified,
    confidence: confidence ?? this.confidence,
  );
}
```

---

## BUG #8 — ToolConfirmationService Abstract vs Concrete Mismatch

**Severity:** HIGH (abstract contract not implementable — violates Liskov)  
**Step:** 20  
**Files:**  
- `domain/services/tool_confirmation_service.dart` (abstract)  
- `infrastructure/default_tool_confirmation_service.dart` (concrete)  

**Category:** Interface implementation violation

### Description
The abstract `ToolConfirmationService` and concrete `DefaultToolConfirmationService` have incompatible `requestConfirmation` signatures:

| Aspect | Abstract | Concrete |
|---|---|---|
| First param | `{required ToolDefinition definition` | `ToolDefinition definition` (positional) |
| params | `required Map<String, dynamic> params` | ❌ Missing |
| reason | `String? reason` | ❌ Missing |
| timeout | `Duration? timeout` | ❌ Missing |
| message | ❌ Not present | `String? message` (extra) |

`DefaultToolConfirmationService implements ToolConfirmationService` but its `requestConfirmation` signature does NOT match the abstract method. This means:
- The `params` map (what the tool will do) is never passed.
- The `reason` for confirmation is never passed.
- The `timeout` for the dialog is never passed.
- Instead, an ad-hoc `message` parameter is used that the abstract doesn't define.

### Workaround Note
`Step20ConfirmationAdapter` (in Step 22) works around this by wrapping calls, but does NOT fix the abstract/concrete mismatch itself.

### Fix
Update `DefaultToolConfirmationService.requestConfirmation` to match the abstract signature:
```dart
@override
Future<ConfirmationResult> requestConfirmation({
  required ToolDefinition definition,
  required Map<String, dynamic> params,
  String? reason,
  Duration? timeout,
}) async { ... }
```
Map the internal `message` parameter from `reason` or format from `params`.

---

## BUG #9 — Step 26 Application Layer Phantom API References

**Severity:** CRITICAL (audit system itself broken — cannot compile)  
**Step:** 26  
**Files:**  
- `application/integrity_audit_orchestrator.dart`  
- `application/cross_adapter_checker.dart`  
- `domain/models/compatibility_report.dart` (partially correct)  

**Category:** Phantom API / non-existent factory references

### Description
Multiple files in Step 26's application layer reference factories and enum values that do NOT exist in the domain models:

**Phantom references:**

| File | Reference | Actual API |
|---|---|---|
| `integrity_audit_orchestrator.dart` | `IntegrityStatus.denied` | ❌ Enum only has `compatible`, `incompatible`, `missing` — NO `denied` |
| `integrity_audit_orchestrator.dart` | `IntegrityVerdict.failClosed(step:, reason:, locale:)` | Actual: `failClosed({referenceStep, comparedStep, interfaceName?, memberName?, driftDescription?})` |
| `integrity_audit_orchestrator.dart` | `IntegrityVerdict.compatible(step:, locale:)` | Actual: `compatible({referenceStep, comparedStep, interfaceName, memberName})` |
| `cross_adapter_checker.dart` | `IntegrityVerdict.failClosed(step:, reason:, locale:)` | Same wrong params as above |
| `cross_adapter_checker.dart` | `IntegrityVerdict.driftDetected(step:, driftCount:, locale:)` | ❌ Factory DOES NOT EXIST AT ALL |
| `compatibility_report.dart` | `IntegrityVerdict.failClosed({referenceStep:, comparedStep:})` | ✅ This one IS correct |

### Impact
- The integrity audit orchestrator and cross-adapter checker CANNOT compile.
- The audit system that validates cross-step compatibility is itself broken.
- This is the most severe bug because it undermines the entire integrity checking mechanism.

### Fix
1. Remove all references to `IntegrityStatus.denied` — use `IntegrityStatus.incompatible` instead.
2. Fix all `IntegrityVerdict.failClosed(...)` calls to use actual params: `{referenceStep, comparedStep, interfaceName?, memberName?, driftDescription?}`.
3. Fix all `IntegrityVerdict.compatible(...)` calls to use actual params: `{referenceStep, comparedStep, interfaceName, memberName}`.
4. Remove `IntegrityVerdict.driftDetected(...)` calls entirely — this factory does not exist. Use `IntegrityVerdict.incompatible(...)` with a drift description instead.

---

## BUG #10 — ToolExecutorRegistry Type Mismatch (String vs Enum comparison)

**Severity:** HIGH (runtime logic failure — byRiskLevel always returns empty)  
**Step:** 22  
**File:** `tool_execution/infrastructure/executors/tool_executor_registry.dart`  
**Category:** Type mismatch / logic error

### Description
In the executors/ version of `ToolExecutorRegistry`, the `byRiskLevel(ToolRiskLevel riskLevel)` method compares `t.riskLevel == riskLevel`, where `t.riskLevel` is `String` (per the `Tool` interface) and `riskLevel` is `ToolRiskLevel` enum. This comparison always evaluates to `false` because `String != ToolRiskLevel` in Dart, meaning `byRiskLevel` ALWAYS returns an empty list.

The root version uses `byRiskLevel(String riskLevel)` which is type-consistent with `Tool.riskLevel` but is the less complete version.

### Fix
Change the parameter type in the executors/ version to `String`:
```dart
List<Tool> byRiskLevel(String riskLevel) =>
    _tools.where((t) => t.riskLevel == riskLevel).toList();
```
This is consistent with both the `Tool` interface and the root version.

---

## BUG #11 — Step 23 vs Step 25 ToolExecutionRepository Async/Sync Mismatch

**Severity:** HIGH (interface contract violation — claimed "exact match" is false)  
**Steps:** 23 ↔ 25  
**Category:** Cross-step interface incompatibility

### Description
Step 25's `ToolExecutionRepository` interface comment claims "Exact signature match from Step 23" but the signatures differ:

| Method | Step 23 | Step 25 |
|---|---|---|
| `cancel()` | `Future<void>` (async) | `void` (sync) |
| `isAvailable()` | `Future<bool>` (async) | `bool` (sync) |

Additionally, `ExecutionResult` models differ:

| Field | Step 23 | Step 25 |
|---|---|---|
| Success | `succeeded` (bool) | `success` (bool) |
| Data | `outputData?` (Map?) | `data` (Map, non-null) |
| Error code | `errorCode?` | ❌ Not present |
| Error message | `errorMessage?` | `error?` (String?) |
| Denied | `wasDenied` (bool) | ❌ Not present |
| Cancelled | `wasCancelled` (bool) | ❌ Not present |
| Factories | `.success`, `.denied({required reason})`, `.cancelled`, `.failed` | ❌ None |
| Execution time | ❌ Not present | `executionTime?` |

### Impact
- Step22ExecutionAdapter implements Step 25's interface, NOT Step 23's — async/sync mismatch means callers expecting `Future<void> cancel()` get `void cancel()`.
- Step 25's `ExecutionResult` cannot represent `wasDenied` or `wasCancelled` states — security-relevant information is lost.
- The comment "Exact signature match from Step 23" is misleading.

### Fix
1. Update Step 25's `ToolExecutionRepository` to match Step 23's async signatures for `cancel()` and `isAvailable()`.
2. Add `wasDenied` and `wasCancelled` fields (or equivalent factories) to Step 25's `ExecutionResult`.
3. Fix the misleading comment.

---

## Bug Summary

| ID | Severity | Step | Category | Status |
|---|---|---|---|---|
| #1 | LOW | 20 | Barrel completeness | Fix ready |
| #2 | HIGH | 20 | Duplicate class | Fix ready |
| #3 | MEDIUM | 22 | Duplicate class / type mismatch | Fix ready |
| #5 | CRITICAL | 24↔25 | Cross-step incompatibility | Fix ready |
| #6 | MEDIUM | 22 | API contract violation | Fix ready |
| #7 | MEDIUM | 22 | Missing method | Fix ready |
| #8 | HIGH | 20 | Interface violation | Fix ready |
| #9 | CRITICAL | 26 | Phantom API references | Fix ready |
| #10 | HIGH | 22 | Type mismatch | Fix ready |
| #11 | HIGH | 23↔25 | Async/sync mismatch | Fix ready |

**Total: 10 confirmed bugs** (2 CRITICAL, 4 HIGH, 3 MEDIUM, 1 LOW)

---

## Out-of-Scope Items (NOT Bugs)

- **Step 28 MethodChannel gaps:** Environment limitation (Flutter SDK unavailable), not source bugs.
- **conversation_provider.dart:** Must NOT be modified per project constraints — not audited.
- **Steps 1–11:** Out of scope — not audited.
- **6 main sections:** Out of scope — not audited.
- **No hardcoded secrets found.**
- **Step 27 feature barrel:** `advanced_agent` and `screen_target_detection` not in features.dart barrel — this is by design (they are accessed via Step 25/22 respectively), not a bug.
