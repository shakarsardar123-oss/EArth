# AURA Phase 2: Orchestration Adapters — Progress Report

**Date:** 2026-09-16  
**Status:** Step 0 (INSPECT) COMPLETE — Adapter Classification Map Ready  
**Previous:** Phase 0 (Baseline Map) ✅ | Phase 1 (Semantic Memory) ✅  

---

## 1. Step 0 Inspection Summary

All 12 orchestration adapters, all domain interfaces, all domain value objects/entities, orchestrator, use cases, providers, localization, presentation layer, and ALL core real services have been read and analyzed.

### Remaining Search Items — NOW RESOLVED

| Item | Result |
|------|--------|
| Connectivity provider | **FOUND** — `DeviceServiceImpl` in `lib/core/device/device_service_impl.dart` uses `connectivity_plus`, provides `isConnected()` and `onConnectivityChanged` Stream. |
| Audit/logging service | **PARTIAL** — `AuditLogger` in tool_execution (tool-execution-phase-specific, not general audit). `FailClosedAuditService` in integrity_audit (invariant auditing, not general event logging). No general-purpose audit event store exists. |
| App providers | Previously read in Phase 1 — Riverpod wiring understood. |

---

## 2. Complete Adapter Classification Map

| # | Adapter | Class | Real Service | Notes |
|---|---------|-------|-------------|-------|
| 1 | **AgentEngineAdapter** | **C** | AgentEngine | `understand()` and `plan()` are PRIVATE. `run()` is monolithic. Cannot decompose. BLOCKED pending public API. |
| 2 | **ToolRegistryAdapter** | **A** | ToolRegistry | Direct mapping: `get()`→lookup, `all`→list, `isAllowed()`→isToolAllowed, `openAISchemas`→getToolSchemas |
| 3 | **ToolExecutionAdapter** | **A/B** | AgentExecutor | `executeTool()` maps directly. `executeStep()` maps. `CancellationToken` needs wiring. `executePlan()` overlaps with orchestrator. |
| 4 | **MemoryAdapter** | **A** | MemoryManager | `recall()`→lookup, `store()`→record. Phase 1 already wired onMemoryEnrichment/onMemoryCapture. |
| 5 | **PermissionAdapter** | **B** | PermissionService + ContextualPermissionHelper | Type conversion: PermissionVerdict ↔ Result<bool, PermissionFailure>. Rationale UI flow available. |
| 6 | **SecurityAdapter** | **B** | ToolSecurityGate (composite) | Must extract security-boundary-only portion. Permission+Confirmation have own adapters. `checkSecurityBoundaries()`→check. |
| 7 | **ConfirmationAdapter** | **B** | ConfirmationGuard + AgentConfirmationManager | Tool-level (ConfirmationGuard) maps to `checkAndObtain()`. Plan-level (AgentConfirmationManager) for intent confirmation. Type conversion needed. |
| 8 | **VoiceAdapter** | **A** | VoiceServiceImpl | Direct: `startListening()`→startListening, `speak()`→speak, `stopListening()`→stopListening, `stopSpeaking()`→stopSpeaking. Locale mapping needed. |
| 9 | **ScreenAdapter** | **C/D** | ScreenUnderstandingEngine | Engine provides SCREEN ANALYSIS (read content). Domain `executeAction()` implies SCREEN ACTIONS (tap/scroll/type). No screen automation service found. BLOCKED. |
| 10 | **ConnectivityAdapter** | **A** | DeviceServiceImpl | Direct: `isConnected()`→isOnline(), `onConnectivityChanged`→onConnectivityChanged. Simple async adapter. |
| 11 | **AuditAdapter** | **D** | NONE | No general audit event store exists. AuditLogger is tool-phase-specific. FailClosedAuditService is invariant-specific. In-memory list is global mutable state violation. BLOCKED — needs new AuditEventStore service. |
| 12 | **RecoveryAdapter** | **B** | AgentRecovery + AgentReplanning | `decide()`→decideRecoveryAction with RecoveryStrategy→RecoveryAction enum mapping. `shouldReplan()`→shouldReplan. Type conversion needed. |

### Class Definitions
- **A** = Direct wiring (adapter → real service with simple type conversion)
- **B** = Partial wiring (some methods map, others need type conversion or composite wrapping)
- **C** = BLOCKED pending public API on real service
- **D** = BLOCKED — no real service exists

---

## 3. Critical Impedance Mismatches

### 3.1 AgentIntent: Core vs Orchestration Domain
| Aspect | Core AgentIntent | Orchestration Domain AgentIntent |
|--------|-----------------|-------------------------------|
| Location | `lib/core/agent/` | `lib/features/orchestration/domain/` |
| ID | No ID field | timestamp-based ID |
| Action type | `IntentActionType` enum | Simple String action |
| Entities | `List<IntentEntity>` | No entities |
| Confidence | `double confidence` | No confidence |
| **Solution** | Map core→domain in adapter; create domain AgentIntent from core fields |

### 3.2 RecoveryStrategy: Core vs Orchestration Domain
| Core RecoveryStrategy | Orchestration RecoveryAction | Mapping |
|----------------------|---------------------------|--------|
| retry | retry | Direct |
| retryWithModification | replan | Map (modified approach = replan) |
| skip | escalate | Map (skip → needs escalation) |
| replan | replan | Direct |
| abort | abort | Direct |

### 3.3 ToolRiskLevel: Core Enum vs Domain String
| Core Enum Value | Domain String |
|----------------|---------------|
| ToolRiskLevel.none | "none" |
| ToolRiskLevel.low | "low" |
| ToolRiskLevel.medium | "medium" |
| ToolRiskLevel.high | "high" |
| ToolRiskLevel.critical | "critical" |

**Conversion:** `.name` for enum→string, `ToolRiskLevel.values.byName()` for string→enum.

### 3.4 SecurityAdapter: Composite Gate Decomposition
ToolSecurityGate is a COMPOSITE:
1. **Boundary check** → SecurityAdapter (security boundaries)
2. **Validation** → ToolExecutionAdapter (tool validation)
3. **Permission check** → PermissionAdapter (permission verdict)
4. **Risk assessment** → ConfirmationAdapter (risk-based confirmation)
5. **Confirmation** → ConfirmationAdapter (user confirmation)

The adapter must extract ONLY the boundary-check portion to avoid duplicating what Permission and Confirmation adapters already handle.

### 3.5 ScreenAdapter: Analysis vs Action
- **ScreenUnderstandingEngine** provides: `analyzeFrame()` → screen content analysis (READ screen)
- **Domain ScreenRepository** expects: `executeAction()` → tap/scroll/type (ACT on screen)
- These are DIFFERENT concerns. `analyzeScreen()` maps to engine. `executeAction()` has NO implementation.
- **Decision:** Wire `analyzeScreen()` to engine. Document `executeAction()` as BLOCKED.

### 3.6 VoiceAdapter Locale Mapping
| Orchestration Hardcode | Real Service Default | Resolution |
|----------------------|---------------------|------------|
| ckb_IQ (STT) | 'ku' (STT) | Accept locale parameter, map ckb_IQ→ku |
| ku (TTS) | 'ku' (TTS) | Direct match |

---

## 4. BLOCKED Adapters — Detailed Rationale

### 4.1 AgentEngineAdapter (Class C — API Blocked)
**Blocker:** `AgentEngine._understand()` and `AgentEngine._planner` are private. The public `run()` method is monolithic (entire lifecycle: understand→plan→execute→verify→recover). The orchestration domain needs decomposed access to `understand()` and `plan()` separately.

**Required API additions to AgentEngine:**
```dart
// Future additions needed:
Future<AgentIntent> understand(String userInput, AgentContext context);
Future<AgentPlan> plan(AgentIntent intent, AgentContext context);
```

**Workaround:** Adapter can implement `understand()` by calling `AgentEngine.run()` and extracting early results via the `state` stream, but this is fragile and not recommended.

### 4.2 ScreenAdapter — executeAction() (Class C/D — No Service)
**Blocker:** No screen automation service (tap/scroll/type) exists in the codebase. `ScreenUnderstandingEngine` only provides screen analysis (reading/understanding screen content).

**Required new service:** `ScreenActionService` with methods like `tap(x, y)`, `scroll(direction)`, `typeText(text)` — would require Android Accessibility Service or equivalent platform channel.

**Partial wiring:** `analyzeScreen()` CAN be wired to `ScreenUnderstandingEngine.analyzeFrame()`.

### 4.3 AuditAdapter (Class D — No Service)
**Blocker:** No general-purpose audit event store exists. Current audit facilities are domain-specific:
- `AuditLogger` (tool_execution) — only records ToolExecutionPhase events
- `FailClosedAuditService` (integrity_audit) — only checks FAIL-CLOSED invariants

The current stub uses an in-memory `List<OrchestrationEvent>` which violates the no-global-mutable-state constraint.

**Required new service:** `AuditEventStore` (persistent, append-only) with `record(event)` and `query(filters)` methods. Could be backed by SQLite, Hive, or simple file logging.

---

## 5. Implementation Priority Order

### Phase 2A: Direct Wiring (A-Class) — Implement First
1. **ConnectivityAdapter** — Wire to DeviceServiceImpl
2. **ToolRegistryAdapter** — Wire to ToolRegistry
3. **VoiceAdapter** — Wire to VoiceServiceImpl
4. **MemoryAdapter** — Wire to MemoryManager

### Phase 2B: Partial Wiring (B-Class) — Type Conversion Required
5. **PermissionAdapter** — Wire to PermissionService + ContextualPermissionHelper
6. **RecoveryAdapter** — Wire to AgentRecovery + AgentReplanning
7. **ConfirmationAdapter** — Wire to ConfirmationGuard + AgentConfirmationManager
8. **SecurityAdapter** — Wire to ToolSecurityGate (boundary-only extraction)
9. **ToolExecutionAdapter** — Wire to AgentExecutor

### Phase 2C: BLOCKED — Document with Rationale
10. **AgentEngineAdapter** — Document as BLOCKED (private API)
11. **ScreenAdapter** — Partial wire (analyze only), document executeAction as BLOCKED
12. **AuditAdapter** — Document as BLOCKED (no service exists)

---

## 6. OrchestrationProviders Fix

**Current issue:** `OrchestrationProviders` takes concrete adapter types, not repository interfaces. This violates the dependency inversion principle — the orchestrator should depend on abstractions.

**Required change:**
```dart
// BEFORE (current):
OrchestrationProviders({
  required AgentEngineAdapter agentEngineAdapter,
  required ToolRegistryAdapter toolRegistryAdapter,
  // ...
})

// AFTER (Phase 2):
OrchestrationProviders({
  required AgentEngineRepository agentEngineRepository,
  required ToolRegistryRepository toolRegistryRepository,
  // ...
})
```

This allows swapping implementations (real adapters, test doubles) without modifying the provider.

---

## 7. Key Constraints Preserved

- ✅ Phase 1 semantic memory wiring untouched (onMemoryEnrichment/onMemoryCapture)
- ✅ No architecture rebuild — all 12 adapters preserved
- ✅ No real services replaced with mocks
- ✅ No new Flutter SDK usage required
- ✅ All verification is static/code review
- ✅ No global mutable state (AuditAdapter in-memory list flagged for removal)
- ✅ No duplicate implementations
- ✅ FAIL-CLOSED patterns preserved in all adapters
- ✅ RTL/Sorani localization preserved
- ✅ Security pipeline preserved (boundary→validation→permission→risk→confirmation)

---

## 8. Type Mapping Quick Reference

```
Core Result<bool, PermissionFailure>  →  PermissionVerdict (allowed/denied/unknown)
Core RecoveryStrategy enum           →  RecoveryAction (retry/abort/escalate/replan)
Core ToolRiskLevel enum              →  String (domain)
Core AgentIntent                     →  Orchestration AgentIntent (field mapping)
Core ToolResult.isSuccess/data       →  Domain execution result types
DeviceServiceImpl.isConnected()      →  ConnectivityRepository.isOnline()
DeviceChannelResult                  →  Connectivity status mapping
```

---

## 9. Next Steps

1. **Implement Phase 2A adapters** (Connectivity, ToolRegistry, Voice, Memory)
2. **Implement Phase 2B adapters** (Permission, Recovery, Confirmation, Security, ToolExecution)
3. **Document Phase 2C blockers** in adapter code with `// BLOCKED:` comments
4. **Fix OrchestrationProviders** to accept interfaces
5. **Update Riverpod wiring** in app_providers.dart
6. **Final verification** — static code review of all changes

---

*Report generated by AURA Phase 2 analysis. All findings based on static code inspection.*
