# AURA Steps 12–28 Cross-Step Compatibility Map

**Project:** AURA Assistant v0.13.0+13  
**Scope:** Steps 12–28 ONLY  
**Date:** 2026-08-31  

---

## 1. Step Dependency Chain

```
Step 17 (On-Device NLP)
    └── (no upstream dependencies)

Step 18 (Game Detection Heuristics)
    └── Step 17 (NLP results)

Step 19 (Game Assistance Logic)
    ├── Step 17 (NLP)
    └── Step 18 (Detection)

Step 20 (Tool Registry & Allowlist)
    └── (no upstream dependencies within scope)

Step 22 (Tool Execution)
    ├── Step 20 (Tool definitions, ConfirmationService)
    └── (standalone execution engine)

Step 23 (Orchestration)
    ├── Step 20 (Tool registry)
    ├── Step 22 (Tool execution)
    ├── Step 24 (Trigger integration — via Step 25)
    ├── Step 25 (Advanced agent — via Step 25 adapters)
    └── Steps 17–19 (Voice, Memory, Game — via adapters)

Step 24 (Trigger Integration)
    └── (no upstream dependencies within scope)

Step 25 (Advanced Agent)
    ├── Step 17 (Voice/NLP — via step17_adapter)
    ├── Step 18 (Game Detection — via step18_adapter)
    ├── Step 19 (Game Assistance — via step19_adapter)
    ├── Step 20 (Tool Registry — via step20_tool_registry_adapter)
    ├── Step 22 (Tool Execution — via step22_execution_adapter)
    ├── Step 23 (Orchestration — via step23_orchestration_adapter)
    └── Step 24 (Trigger — via step24_trigger_adapter)

Step 26 (Integrity Audit)
    └── All Steps 17–25 (via step introspection repositories)

Step 27 (Settings & Preferences)
    └── (no upstream dependencies within scope)

Step 28 (Main App Shell)
    └── All Steps 17–27 (composition)
```

---

## 2. Adapter Compatibility Matrix

### Step 25 → Upstream Steps

| Adapter | Target Step | Interface Match | Param Match | Return Match | Async/Sync | Bug | Status |
|---|---|---|---|---|---|---|---|
| Step17VoiceAdapter | 17 | ✅ | ✅ | ✅ | ✅ | — | PASS |
| Step18GameDetectionAdapter | 18 | ✅ | ✅ | ✅ | ✅ | — | PASS |
| Step19GameAssistanceAdapter | 19 | ✅ | ✅ | ✅ | ✅ | — | PASS |
| Step20ToolRegistryAdapter | 20 | ⚠️ | ⚠️ | ⚠️ | ✅ | — | PARTIAL — uses Step 25's DiscoveredTool, no ToolRiskLevel→String conversion |
| Step22ExecutionAdapter | 22 | ⚠️ | ✅ | ⚠️ | ❌ | #11 | FAIL — cancel()/isAvailable() sync vs async, ExecutionResult model mismatch |
| Step23OrchestrationAdapter | 23 | ✅ | ✅ | ✅ | ✅ | — | PASS |
| Step24TriggerAdapter | 24 | ❌ | ❌ | ❌ | ❌ | #5 | FAIL — completely different types, async/sync mismatch |

### Step 22 → Step 20

| Bridge | Target | Interface Match | Bug | Status |
|---|---|---|---|---|
| Step20ConfirmationAdapter | 20 | ✅ (workaround) | #8 (root) | PASS — adapter works around abstract/concrete mismatch |

### Step 23 → Upstream Steps

| Adapter | Target Step | Interface Match | Bug | Status |
|---|---|---|---|---|
| ToolRegistryAdapter | 20 | ⚠️ | — | PARTIAL — fail-closed stubs |
| MemoryAdapter | — | ✅ | — | PASS |
| PermissionAdapter | — | ✅ | — | PASS |
| VoiceAdapter | — | ✅ | — | PASS |
| ToolExecutionAdapter | 22 | ✅ | — | PASS |
| ConfirmationAdapter | 20 | ⚠️ | — | PARTIAL — fail-closed stubs |
| SecurityAdapter | — | ✅ | — | PASS |

### Step 26 → All Steps

| Introspection Repo | Target Step | Interface Match | Bug | Status |
|---|---|---|---|---|
| Step 17–19 Repos | 17, 18, 19 | ✅ | — | PASS |
| Step 20 Repo | 20 | ✅ | — | PASS |
| Step 22 Repo | 22 | ✅ | — | PASS |
| Step 23 Repo | 23 | ✅ | — | PASS |
| Step 24 Repo | 24 | ✅ | — | PASS |
| Step 25 Repo | 25 | ✅ | — | PASS |

---

## 3. Type Compatibility Details

### ToolRiskLevel (Step 20) vs String (Steps 22, 23)

| Context | Type | Compatible? |
|---|---|---|
| Step 20 ToolDefinition.riskLevel | `ToolRiskLevel` (enum) | Source of truth for registry |
| Step 22 Tool.riskLevel | `String` | ❌ Mismatch with Step 20 |
| Step 23 DiscoveredTool.riskLevel | `String` | ❌ Mismatch with Step 20 |
| Step 22 ToolExecutorRegistry.byRiskLevel (root) | `String` param | ✅ Matches Tool.riskLevel |
| Step 22 ToolExecutorRegistry.byRiskLevel (executors/) | `ToolRiskLevel` param | ❌ Doesn't match Tool.riskLevel |
| Step 25 Step20ToolRegistryAdapter | Uses Step 25 DiscoveredTool | ❌ No ToolRiskLevel→String conversion |

### TriggerType (Step 24) vs TriggerType (Step 25)

| Step 24 Value | Step 25 Equivalent | Mapping |
|---|---|---|
| `quickSettings` | NONE | ❌ No mapping |
| `assistantLongPress` | `gesture` (closest) | ⚠️ Approximate |
| `homeLongPress` | `gesture` (closest) | ⚠️ Approximate |
| `notificationAction` | `event` (closest) | ⚠️ Approximate |
| `inApp` | `event` (closest) | ⚠️ Approximate |
| `unknown` | `unknown` | ✅ Direct |

### ExecutionResult (Step 23) vs ExecutionResult (Step 25)

| Field/Feature | Step 23 | Step 25 | Compatible? |
|---|---|---|---|
| Success field name | `succeeded` | `success` | ❌ Different name |
| Data field | `outputData?` (nullable Map) | `data` (non-null Map) | ❌ Different name and nullability |
| Error code | `errorCode?` | ❌ Not present | ❌ Missing in Step 25 |
| Error message | `errorMessage?` | `error?` | ❌ Different name |
| Denied flag | `wasDenied` | ❌ Not present | ❌ Missing in Step 25 |
| Cancelled flag | `wasCancelled` | ❌ Not present | ❌ Missing in Step 25 |
| Execution time | ❌ Not present | `executionTime?` | — Extra in Step 25 |
| Factory: .success | ✅ | ❌ | ❌ Missing in Step 25 |
| Factory: .denied(reason) | ✅ | ❌ | ❌ Missing in Step 25 |
| Factory: .cancelled | ✅ | ❌ | ❌ Missing in Step 25 |
| Factory: .failed | ✅ | ❌ | ❌ Missing in Step 25 |

### IntegrityVerdict (Step 26 Domain) — Actual API

| Factory | Required Params | Optional Params |
|---|---|---|
| `.compatible()` | `referenceStep`, `comparedStep`, `interfaceName`, `memberName` | — |
| `.incompatible()` | `referenceStep`, `comparedStep`, `interfaceName`, `memberName` | `driftDescription` |
| `.missing()` | `referenceStep`, `comparedStep`, `interfaceName`, `memberName` | `driftDescription` |
| `.failClosed()` | — | `referenceStep?`, `comparedStep?`, `interfaceName?`, `memberName?`, `driftDescription?` |

**IntegrityStatus enum:** `compatible`, `incompatible`, `missing` — NO `denied` value.

---

## 4. Async/Sync Compatibility

| Interface | Step | Method | Upstream Type | Downstream Type | Bug |
|---|---|---|---|---|---|
| TriggerAuthorizationRepository | 24 | `isAvailable()` | `Future<bool>` | — | — |
| TriggerRepository | 25 | `isAvailable()` | — | `bool` | #5 |
| TriggerAuthorizationRepository | 24 | `isTriggerTypePermitted()` | `Future<bool>` | — | — |
| TriggerRepository | 25 | `isTriggerTypePermitted()` | — | `bool` | #5 |
| ToolExecutionRepository | 23 | `cancel()` | `Future<void>` | — | — |
| ToolExecutionRepository | 25 | `cancel()` | — | `void` | #11 |
| ToolExecutionRepository | 23 | `isAvailable()` | `Future<bool>` | — | — |
| ToolExecutionRepository | 25 | `isAvailable()` | — | `bool` | #11 |

---

## 5. Risk Level Type Flow

```
Step 20: ToolDefinition.riskLevel = ToolRiskLevel (enum)
           ↓
Step 20→22 bridge: Step20ConfirmationAdapter (uses ToolRiskLevel enum correctly)
           ↓
Step 22: Tool.riskLevel = String  ← TYPE BREAK
           ↓
Step 22: ToolExecutorRegistry.byRiskLevel(ToolRiskLevel) → comparison fails ← BUG #10
           ↓
Step 23: DiscoveredTool.riskLevel = String  ← Consistent with Step 22
           ↓
Step 25: Step20ToolRegistryAdapter uses Step 25 DiscoveredTool  ← No conversion from enum
```

---

*End of Compatibility Map*
