# Step 20 Final Report: Tool Registry & Allowlist

**AURA Assistant – Step 20 Implementation Report**

| Field | Value |
|-------|-------|
| Step | 20 – Tool Registry & Allowlist |
| Package | `aura_assistant` |
| Import Prefix | `package:aura_assistant/` |
| Source Path | `lib/features/tool_registry/` |
| Total Files | 30 (28 source + 1 test + 1 l10n YAML) |
| Validation | Structural only (no Flutter/Dart SDK available) |
| Date | 2026-08-30 |

---

## 1. Executive Summary

Step 20 implements the **Tool Registry & Allowlist** feature for the AURA Assistant — a fail-closed, multi-gate execution pipeline that governs every tool invocation. The registry provides centralized tool registration, allowlist-based access control, and a 6-gate execution pipeline that integrates with the security (Step 19), permissions (Step 16), recovery (Step 18), and memory (Step 17) subsystems.

**Core design principle: Fail Closed.** At every decision point — unknown tool, missing allowlist entry, missing adapter, exception, timeout — the default answer is **denied**. This ensures that no tool can execute without passing every gate in the pipeline, and any ambiguity or error results in a safe denial rather than permissive execution.

The implementation spans 28 source files across 4 layers (domain, application, infrastructure, presentation), plus 1 test file with 26 scenarios and 1 l10n YAML providing Kurdish Sorani (RTL), English, and Arabic translations.

---

## 2. The 16 Capabilities

| # | Capability | Description | Key Files |
|---|-----------|-------------|----------|
| 1 | **Tool Registration** | Register tool definitions (single or bulk) with category, risk level, permissions, and confirmation policy. | `tool_registry_service.dart`, `default_tool_registry_service.dart` |
| 2 | **Tool Unregistration** | Remove tool definitions and associated allowlist entries. | `tool_registry_service.dart`, `default_tool_registry_service.dart` |
| 3 | **Allowlist Management** | Set, remove, and batch-update allowlist entries with source tracking (user/admin/autoApproved/unknown). | `tool_allowlist_entry.dart`, `default_tool_registry_service.dart` |
| 4 | **Tool Discovery (Search/Category/Risk)** | Search tools by query string, filter by category, or filter by risk level. Only allowed+enabled tools appear in results. | `tool_discovery_api.dart`, `default_tool_discovery_api.dart` |
| 5 | **6-Gate Execution Pipeline** | Sequential gate checks: Registry → Allowlist → Security → Permission → Confirmation → Execute. | `tool_execution_gate.dart`, `default_tool_execution_gate.dart` |
| 6 | **Security Adapter Integration** | Plug-in security adapter (Step 19). If absent: high/critical → fail closed, low/medium → skip. | `tool_security_adapter.dart` |
| 7 | **Permission Adapter Integration** | Plug-in permission adapter (Step 16). 10 default permission mappings. If absent + requiredPermissions → fail closed. | `tool_permission_adapter.dart` |
| 8 | **Confirmation Service** | User-facing confirmation with 4 policies (never/whenSensitive/always/unknown). Unknown policy → always (fail closed). | `tool_confirmation_service.dart`, `default_tool_confirmation_service.dart` |
| 9 | **Recovery Adapter Integration** | Plug-in recovery adapter (Step 18). On execution failure, attempts recovery + single retry. | `tool_recovery_adapter.dart` |
| 10 | **Memory Adapter Integration** | Plug-in memory adapter (Step 17). Provides context enrichment with key prefix `tool_registry:`. | `tool_memory_adapter.dart` |
| 11 | **Offline Mode** | Registry can go offline; status transitions, cached tools remain discoverable, `effectiveStatus` maps unknown → offline. | `tool_state.dart`, `default_tool_registry_service.dart` |
| 12 | **State Management (Riverpod)** | StateNotifier + broadcast stream + Riverpod providers (5 core, 4 adapter, 4 derived). | `tool_registry_state_notifier.dart`, `tool_registry_provider_names.dart` |
| 13 | **Existing Tool Adapters (11)** | Pre-built adapters for Voice/Screen/Vision/Device/Memory/Assistant/Recovery/Communication/Navigation/System/Media. 4 auto-approved. | `existing_tool_adapters.dart` |
| 14 | **Localization (l10n)** | Kurdish Sorani (RTL), English, Arabic. Key prefix `tool_registry_`. ~50+ keys covering all UI surfaces. | `tool_registry_l10n.yaml` |
| 15 | **Execution Result Tracking** | Recent executions list (capped at 100), with success/failure, output data, and timing. | `tool_execution_result.dart`, `default_tool_registry_service.dart` |
| 16 | **Pre-flight Readiness Check** | `checkReadiness()` validates the full gate pipeline before actual execution, returning a readiness verdict. | `default_tool_execution_gate.dart` |

---

## 3. File Inventory (30 Files)

### 3.1 Domain Layer (9 files)

| # | File Path | Purpose |
|---|-----------|--------|
| 1 | `lib/features/tool_registry/domain/models/models.dart` | Barrel export for domain models |
| 2 | `lib/features/tool_registry/domain/models/tool_category.dart` | `ToolCategory` enum (12 values) + `ToolRiskLevel` enum (5 values) |
| 3 | `lib/features/tool_registry/domain/models/confirmation_policy.dart` | `ConfirmationPolicy` enum (4 values) + `ConfirmationResult` + `AllowlistSource` enum |
| 4 | `lib/features/tool_registry/domain/models/tool_definition.dart` | `ToolDefinition` — tool metadata (id, name, category, risk, permissions, confirmation policy, enabled, executor) |
| 5 | `lib/features/tool_registry/domain/models/tool_allowlist_entry.dart` | `ToolAllowlistEntry` — allowlist state (toolId, isAllowed, source, reason) + `AllowlistSource` enum |
| 6 | `lib/features/tool_registry/domain/models/tool_failure.dart` | `ToolFailure` — structured failure (9 phases, isDenial always true, isFailClosedDenial for critical phases) |
| 7 | `lib/features/tool_registry/domain/models/tool_execution_result.dart` | `ToolExecutionResult` — execution outcome (toolId, success, output, failure, executionTimeMs) |
| 8 | `lib/features/tool_registry/domain/models/tool_state.dart` | `ToolState` — aggregate state (definitions map, allowlist entries, recent executions, status, offline) + `ToolRegistryStatus` enum |
| 9 | `lib/features/tool_registry/domain/services/services.dart` | Barrel export for domain services |
| 10 | `lib/features/tool_registry/domain/services/tool_registry_service.dart` | Abstract `ToolRegistryService` — register, unregister, allowlist, query, offline |
| 11 | `lib/features/tool_registry/domain/services/tool_confirmation_service.dart` | Abstract `ToolConfirmationService` — requestConfirmation |

### 3.2 Application Layer (3 files)

| # | File Path | Purpose |
|---|-----------|--------|
| 12 | `lib/features/tool_registry/application/application.dart` | Barrel export for application layer |
| 13 | `lib/features/tool_registry/application/tool_execution_gate.dart` | Abstract `ToolExecutionGate` — execute, checkReadiness, `ToolExecutionReadiness` enum |
| 14 | `lib/features/tool_registry/application/tool_discovery_api.dart` | Abstract `ToolDiscoveryApi` — discover, discoverByCategory, discoverByRiskLevel, getToolInfo, `DiscoveryResult`, `DiscoveredTool` |

### 3.3 Infrastructure Layer (12 files)

| # | File Path | Purpose |
|---|-----------|--------|
| 15 | `lib/features/tool_registry/infrastructure/infrastructure.dart` | Barrel export for infrastructure layer |
| 16 | `lib/features/tool_registry/infrastructure/default_tool_registry_service.dart` | `DefaultToolRegistryService` — in-memory maps, fail-closed defaults, bulk registration, execution tracking (cap 100) |
| 17 | `lib/features/tool_registry/infrastructure/default_tool_confirmation_service.dart` | `DefaultToolConfirmationService` — fail-closed confirmation (unavailable→denied, unknown policy→denied, timeout→denied, no UI→denied) |
| 18 | `lib/features/tool_registry/infrastructure/default_tool_execution_gate.dart` | `DefaultToolExecutionGate` — full 6-gate pipeline, pre-flight readiness, recovery+retry, memory context |
| 19 | `lib/features/tool_registry/infrastructure/default_tool_discovery_api.dart` | `DefaultToolDiscoveryApi` — only allowed+enabled tools appear; fail-closed (not found=null, failure=empty) |
| 20 | `lib/features/tool_registry/infrastructure/adapters/adapters.dart` | Barrel export for infrastructure adapters |
| 21 | `lib/features/tool_registry/infrastructure/adapters/tool_security_adapter.dart` | `ToolSecurityAdapter` abstract + `DefaultToolSecurityAdapter` (deny all) + `Step19SecurityAdapter` (translates to ActionMetadata, calls validateAction) + `ToolSecurityVerdict` enum |
| 22 | `lib/features/tool_registry/infrastructure/adapters/tool_permission_adapter.dart` | `ToolPermissionAdapter` abstract + `Step16PermissionAdapter` (10 default permission mappings) + `ToolPermissionResult` |
| 23 | `lib/features/tool_registry/infrastructure/adapters/tool_recovery_adapter.dart` | `ToolRecoveryAdapter` abstract + `Step18RecoveryAdapter` (builds recoveryContext, calls _recoveryCoordinator.recover) + `ToolRecoveryOutcome` |
| 24 | `lib/features/tool_registry/infrastructure/adapters/tool_memory_adapter.dart` | `ToolMemoryAdapter` abstract + `Step17MemoryAdapter` (key prefix `tool_registry:`, tag `tool_registry`) + `ToolMemoryResult` |
| 25 | `lib/features/tool_registry/infrastructure/adapters/existing_tool_adapters.dart` | 11 `ExistingToolAdapter` subclasses + `ExistingToolAdapters` factory (4 auto-approved, 7 not) |

### 3.4 Presentation Layer (3 files)

| # | File Path | Purpose |
|---|-----------|--------|
| 26 | `lib/features/tool_registry/presentation/presentation.dart` | Barrel export for presentation layer |
| 27 | `lib/features/tool_registry/presentation/tool_registry_state_notifier.dart` | `ToolRegistryStateNotifier` — StateNotifier with broadcast stream, all mutations → service → emit |
| 28 | `lib/features/tool_registry/presentation/tool_registry_provider_names.dart` | `ToolRegistryProviderNames` (abstract names/types) + `ToolRegistryProviders` (concrete Riverpod provider instances) |

### 3.5 Test & Localization (2 files)

| # | File Path | Purpose |
|---|-----------|--------|
| 29 | `test/features/tool_registry/tool_registry_test.dart` | 26 test scenarios covering all capabilities |
| 30 | `lib/features/tool_registry/l10n/tool_registry_l10n.yaml` | Kurdish Sorani (RTL), English, Arabic — ~50+ l10n keys |

---

## 4. Architecture

### 4.1 Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                          │
│  ToolRegistryStateNotifier  ·  ToolRegistryProviderNames       │
│  ToolRegistryProviders (Riverpod concrete providers)            │
│  Broadcast Stream<ToolState>                                   │
└──────────────┬──────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│                     APPLICATION LAYER                            │
│  ToolExecutionGate (abstract)  ·  ToolDiscoveryApi (abstract)  │
│  ToolExecutionReadiness  ·  DiscoveryResult  ·  DiscoveredTool │
└──────────────┬──────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│                    INFRASTRUCTURE LAYER                         │
│  DefaultToolRegistryService  ·  DefaultToolConfirmationService  │
│  DefaultToolExecutionGate   ·  DefaultToolDiscoveryApi          │
│  Adapters: Security · Permission · Recovery · Memory           │
│  ExistingToolAdapters (11 pre-built)                            │
└──────────────┬──────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│                      DOMAIN LAYER                               │
│  Models: ToolDefinition · ToolCategory · ToolRiskLevel         │
│          ToolAllowlistEntry · ConfirmationPolicy · ToolFailure  │
│          ToolExecutionResult · ToolState · ToolRegistryStatus  │
│  Services: ToolRegistryService · ToolConfirmationService       │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 The 6-Gate Execution Pipeline

Every tool invocation passes through a strict sequential pipeline. **If any gate denies, execution stops immediately with a `ToolFailure`**.

```
┌─────────┐    ┌──────────┐    ┌──────────┐    ┌────────────┐    ┌──────────────┐    ┌───────────┐
│  GATE 1 │───▶│  GATE 2  │───▶│  GATE 3  │───▶│   GATE 4   │───▶│   GATE 5    │───▶│  GATE 6   │
│Registry │    │Allowlist  │    │Security  │    │Permission  │    │Confirmation │    │Execute    │
└─────────┘    └──────────┘    └──────────┘    └────────────┘    └──────────────┘    └───────────┘

Gate 1 – Registry Check:
  • Is tool registered AND enabled?
  • FAIL: not registered → deny, disabled → deny

Gate 2 – Allowlist Check:
  • Does allowlist entry exist with isAllowed=true?
  • FAIL: no entry → deny (fail closed), isAllowed=false → deny

Gate 3 – Security Adapter Check:
  • If adapter present → call check()
  • If adapter absent + risk high/critical → fail closed
  • If adapter absent + risk low/medium → skip gate
  • FAIL: adapter returns denied/failClosed → deny

Gate 4 – Permission Adapter Check:
  • If adapter present + tool has requiredPermissions → check each
  • If adapter absent + tool has requiredPermissions → fail closed
  • If tool has no requiredPermissions → skip gate
  • FAIL: any permission denied → deny

Gate 5 – Confirmation Service:
  • Request user confirmation based on tool's ConfirmationPolicy
  • never → auto-approve; always → require confirmation
  • whenSensitive → require if high/critical risk
  • unknown → always require (fail closed)
  • FAIL: user denies, timeout, no UI callback → deny

Gate 6 – Execute:
  • Look up executor from tool definition
  • Inject memory context from adapter (if present)
  • Execute tool
  • On failure → attempt recovery via adapter + single retry
  • Timeout → fail closed
  • Any exception → attempt recovery, then deny
```

### 4.3 Pre-flight Readiness Check

Before actual execution, `checkReadiness(toolId)` walks through Gates 1–5 in dry-run mode, returning a `ToolExecutionReadiness` verdict:

- `ready` — all gates passed
- `notRegistered` — Gate 1 failed
- `notAllowed` — Gate 2 failed
- `securityDenied` — Gate 3 failed
- `permissionDenied` — Gate 4 failed
- `confirmationRequired` — Gate 5 would require confirmation
- `offline` — registry is offline
- `disabled` — tool is disabled

### 4.4 State Flow

```
nUser Action ──▶ StateNotifier ──▶ Service ──▶ State Update ──▶ Broadcast Stream
                                    │                                 │
                                    ▼                                 ▼
                              ToolState                          Riverpod Providers
                    (definitions, allowlist,              (registeredToolIds,
                     executions, status)                   allowedToolIds,
                                                     availableCategories,
                                                       isOffline)
```

---

## 5. Fail-Closed Guarantees

The Tool Registry enforces a **strict fail-closed policy** at every decision boundary. The table below documents every scenario where ambiguity, absence, or error results in a denial.

| # | Scenario | Component | Fail-Closed Behavior |
|---|----------|-----------|---------------------|
| 1 | Unknown tool (not registered) | Registry Service | **Denied** — no definition found |
| 2 | Tool registered but disabled | Registry Service | **Denied** — enabled=false |
| 3 | No allowlist entry for tool | Registry Service | **Denied** — default isAllowed=false |
| 4 | Allowlist entry with isAllowed=false | Allowlist Entry | **Denied** — explicit deny |
| 5 | Unknown allowlist source | Allowlist Entry | **Untrusted** — source=unknown → untrusted |
| 6 | Security adapter absent + high/critical risk | Execution Gate | **Denied** — fail closed (no adapter = no trust) |
| 7 | Security adapter absent + low/medium risk | Execution Gate | **Skip** — low risk, proceed without security check |
| 8 | Security adapter returns `failClosed` | Security Adapter | **Denied** — explicit fail-closed verdict |
| 9 | Security adapter returns `denied` | Security Adapter | **Denied** — explicit denial |
| 10 | Security adapter throws exception | Security Adapter | **Denied** — exception = denial |
| 11 | Permission adapter absent + tool has requiredPermissions | Execution Gate | **Denied** — no adapter, cannot validate permissions |
| 12 | Permission adapter present + any permission denied | Permission Adapter | **Denied** — not all granted |
| 13 | Permission adapter throws exception | Permission Adapter | **Denied** — fail closed |
| 14 | Confirmation policy unknown | Confirmation Service | **Denied** — unknown → always (fail closed) |
| 15 | No UI callback available | Confirmation Service | **Denied** — no way to prompt user |
| 16 | Confirmation timeout | Confirmation Service | **Denied** — timed out = denied |
| 17 | User denies confirmation | Confirmation Service | **Denied** — explicit user denial |
| 18 | Headless mode + confirmation required | Confirmation Service | **Denied** — no UI in headless mode |
| 19 | Execution timeout | Execution Gate | **Denied** — timeout = fail closed |
| 20 | Execution throws exception | Execution Gate | **Recovery attempted**, then **Denied** if recovery fails |
| 21 | Registry status unknown | Tool State | **Offline** — effectiveStatus(unknown → offline) |
| 22 | Discovery — tool not found | Discovery API | **null** — not found returns null |
| 23 | Discovery — failure during search | Discovery API | **Empty result** — failure = empty list |
| 24 | Tool unregistered | Registry Service | **Allowlist entry removed** — clean removal, no orphan entries |

---

## 6. Integrations with Steps 16–19

### 6.1 Step 19 — Security Integration

**Adapter:** `Step19SecurityAdapter` (extends `ToolSecurityAdapter`)

| Aspect | Detail |
|--------|--------|
| Class | `Step19SecurityAdapter` |
| Translation | Converts tool execution request → `ActionMetadata` (step 19's domain model) |
| Delegation | Calls `validateAction()` on Step 19's security service |
| Verdicts | `allowed` / `denied` / `failClosed` / `unknown` → `ToolSecurityVerdict` |
| Default | `DefaultToolSecurityAdapter` — denies all tools (defaultDenyAll) |
| Null behavior | `toolSecurityAdapterProvider` defaults to `null`; when null, Gate 3 applies risk-based fail-closed logic |

### 6.2 Step 16 — Permission Integration

**Adapter:** `Step16PermissionAdapter` (extends `ToolPermissionAdapter`)

| Aspect | Detail |
|--------|--------|
| Class | `Step16PermissionAdapter` |
| Default Mappings | 10 permission mappings covering core tool categories |
| Check | For each `requiredPermission` in tool definition, validates via Step 16's permission system |
| Result | `ToolPermissionResult` — allGranted / granted / denied / notDetermined lists |
| Null behavior | `toolPermissionAdapterProvider` defaults to `null`; when null + requiredPermissions present → fail closed |
| Exception | Any exception during permission check → fail closed |

### 6.3 Step 18 — Recovery Integration

**Adapter:** `Step18RecoveryAdapter` (extends `ToolRecoveryAdapter`)

| Aspect | Detail |
|--------|--------|
| Class | `Step18RecoveryAdapter` |
| Context | Builds `recoveryContext` map from tool metadata + execution params |
| Delegation | Calls `_recoveryCoordinator.recover(context, rawError, action: toolId)` |
| Outcome | `ToolRecoveryOutcome` — recovered / recoveredToolId / recoveryStrategy / message |
| Retry | After recovery, `_retryOnce` re-attempts execution with recovered tool ID (if different) |
| Null behavior | `toolRecoveryAdapterProvider` defaults to `null`; when null, execution failures are not recovered (direct denial) |

### 6.4 Step 17 — Memory Integration

**Adapter:** `Step17MemoryAdapter` (extends `ToolMemoryAdapter`)

| Aspect | Detail |
|--------|--------|
| Class | `Step17MemoryAdapter` |
| Key Prefix | `tool_registry:` |
| Tag | `tool_registry` |
| Context | Before execution, retrieves memory context for the tool |
| Storage | After execution, stores result/context back to Step 17's memory manager |
| Result | `ToolMemoryResult` — success / data / error |
| Null behavior | `toolMemoryAdapterProvider` defaults to `null`; when null, execution proceeds without memory context enrichment |

---

## 7. Domain Model Details

### 7.1 Enums

| Enum | Values | Count | Notes |
|------|--------|-------|-------|
| `ToolCategory` | voice, screen, vision, device, memory, assistant, recovery, communication, navigation, system, data, external | 12 | Matches l10n keys + test expectations |
| `ToolRiskLevel` | low, medium, high, critical, unknown | 5 | Test expects `values.length == 5`; source may also have `none` — see Known Issues |
| `ConfirmationPolicy` | never, whenSensitive, always, unknown | 4 | `unknown → always` (fail closed) |
| `AllowlistSource` | user, admin, autoApproved, unknown | 4 | `unknown → untrusted` |
| `ToolRegistryStatus` | initializing, ready, offline, error, unknown | 5 | `effectiveStatus`: unknown → offline |
| `ToolFailurePhase` | registration, allowlist, security, permission, confirmation, execution, discovery, recovery, offline | 9 | `recovery` replaces `unknown` from earlier analysis |
| `ToolSecurityVerdict` | allowed, denied, failClosed, unknown | 4 | From security adapter |
| `ToolExecutionReadiness` | ready, notRegistered, notAllowed, securityDenied, permissionDenied, confirmationRequired, offline, disabled | 8 | Pre-flight check outcomes |

### 7.2 Key Domain Models

**ToolDefinition**
- `toolId`, `name`, `description`, `category`, `effectiveCategory`, `riskLevel`, `requiredPermissions`, `confirmationPolicy`, `isEnabled`, `executor`, `metadata`

**ToolAllowlistEntry**
- `toolId`, `isAllowed` (default=false → fail closed), `addedBy` (AllowlistSource), `reason`, `addedAt`
- Computed: `isDenied` = `!isAllowed`, `isTrustedSource` (unknown source → untrusted)

**ToolFailure**
- `phase` (ToolFailurePhase), `message`, `toolId`
- `isDenial` — **always true** (all failures are denials)
- `isFailClosedDenial` — true for: allowlist, security, permission, unknown phases
- Factory constructors per phase: `registration()`, `allowlist()`, `security()`, `permission()`, `confirmation()`, `execution()`, `discovery()`, `recovery()`, `offline()`

**ToolExecutionResult**
- `toolId`, `success`, `output` (Map<String,dynamic>), `failure` (ToolFailure?), `executionTimeMs`
- Factory: `success()` / `failure()`

**ToolState**
- `definitions` (List<ToolDefinition>), `allowlistEntries` (List<ToolAllowlistEntry>), `recentExecutions` (List<ToolExecutionResult>), `status` (ToolRegistryStatus), `isOffline`, `availableToolCount`
- Methods: `isToolAllowed()`, `isToolEnabled()`, `canExecute()`, `toolsByCategory()`, `allowedButDisabled()`, `enabledButNotAllowed()`, `effectiveStatus()`
- `copyWith()` with `clearDefinitions`, `clearAllowlistEntries`, `clearRecentExecutions` bool flags

---

## 8. Existing Tool Adapters

The 11 pre-built `ExistingToolAdapter` subclasses provide ready-to-register tool definitions for the AURA Assistant's core capabilities:

| # | Adapter | Category | Auto-Approved | Risk Level |
|---|---------|----------|:-------------:|-----------|
| 1 | VoiceAdapter | voice | ✗ | medium |
| 2 | ScreenAdapter | screen | ✗ | medium |
| 3 | VisionAdapter | vision | ✗ | high |
| 4 | DeviceAdapter | device | ✗ | high |
| 5 | MemoryAdapter | memory | ✗ | medium |
| 6 | AssistantAdapter | assistant | ✓ | low |
| 7 | RecoveryAdapter | recovery | ✓ | low |
| 8 | CommunicationAdapter | communication | ✗ | medium |
| 9 | NavigationAdapter | navigation | ✓ | low |
| 10 | SystemAdapter | system | ✗ | critical |
| 11 | MediaAdapter | media | ✓ | low |

**Auto-approved** adapters (assistant, recovery, navigation, media) are automatically added to the allowlist with `AllowlistSource.autoApproved`. The remaining 7 require explicit allowlist approval before execution.

---

## 9. Riverpod Provider Architecture

### 9.1 Provider Names (Abstract)

`ToolRegistryProviderNames` defines static const String + Type pairs:

| Category | Provider Name | Type |
|----------|--------------|------|
| Core | `toolRegistryState` | `ToolRegistryStateNotifier` |
| Core | `toolRegistryService` | `ToolRegistryService` |
| Core | `toolConfirmationService` | `ToolConfirmationService` |
| Core | `toolExecutionGate` | `ToolExecutionGate` |
| Core | `toolDiscoveryApi` | `ToolDiscoveryApi` |
| Adapter | `toolSecurityAdapter` | `ToolSecurityAdapter` |
| Adapter | `toolPermissionAdapter` | `ToolPermissionAdapter` |
| Adapter | `toolRecoveryAdapter` | `ToolRecoveryAdapter` |
| Adapter | `toolMemoryAdapter` | `ToolMemoryAdapter` |
| Derived | `registeredToolIds` | `List<String>` |
| Derived | `allowedToolIds` | `List<String>` |
| Derived | `availableCategories` | `List<ToolCategory>` |
| Derived | `toolRegistryIsOffline` | `bool` |

### 9.2 Concrete Providers

`ToolRegistryProviders` provides the actual Riverpod `Provider`/`StateNotifierProvider` instances:

- **5 core providers**: service, confirmation service, execution gate, discovery API, state notifier
- **4 adapter providers**: security, permission, recovery, memory — all default to `null`
- **4 derived providers**: registeredToolIds, allowedToolIds, availableCategories, isOffline

The execution gate provider watches all adapter providers, passing them into `DefaultToolExecutionGate`. The state notifier provider watches all core services.

---

## 10. Localization

The l10n YAML provides translations in 3 languages:

| Language | Code | Direction |
|----------|------|----------|
| Kurdish Sorani | `ckb` | RTL |
| English | `en` | LTR |
| Arabic | `ar` | RTL |

**Key prefix:** `tool_registry_`

**Coverage (~50+ keys):**
- UI: title, description, search placeholder, refresh
- Status: ready, initializing, offline, error
- Allowlist: title, empty, allowed, denied, source labels
- Categories: all 12 categories (voice through external)
- Risk levels: low, medium, high, critical, unknown
- Confirmation policies: never, always, whenSensitive, unknown
- Execution gates: registry, allowlist, security, permission, confirmation, executor, disabled
- Discovery: title, empty, results (with {count} interpolation)
- Actions: register/unregister success, allowlist set, execution started/success/failed
- Fail-closed messaging: "Unknown tools are denied"
- Tool states: enabled, disabled, tool count (with {count} interpolation)
- Filters: category, risk
- Offline message, error message

---

## 11. Test Scenarios (26)

The test file `test/features/tool_registry/tool_registry_test.dart` defines 26 test scenarios:

| # | Scenario Group | Test Name | What It Validates |
|---|---------------|-----------|-------------------|
| 1 | Registration | tool registration registers a tool definition | Single tool registration |
| 2 | Registration | tool unregistration removes a tool definition | Tool removal + allowlist cleanup |
| 3 | Registration | bulk registration registers multiple tools | Batch registration |
| 4 | Allowlist | allowlist entry default is denied | isAllowed default = false (fail closed) |
| 5 | Allowlist | setting allowlist allows a tool | Explicit allow |
| 6 | Allowlist | removing allowlist denies a tool | Allowlist removal → deny |
| 7 | Allowlist | allowlist source tracking | Source attribution (user/admin/autoApproved/unknown) |
| 8 | Allowlist | batch allowlist entries | Bulk allowlist updates |
| 9 | Discovery | discover tools by query | Search-based discovery |
| 10 | Discovery | discover tools by category | Category filter |
| 11 | Discovery | discover tools by risk level | Risk-level filter |
| 12 | Discovery | discovery only returns allowed and enabled tools | Fail-closed: disallowed/disabled excluded |
| 13 | Execution | execution gate denies unregistered tools | Gate 1 fail |
| 14 | Execution | execution gate denies disallowed tools | Gate 2 fail |
| 15 | Execution | execution gate denies by security adapter | Gate 3 fail |
| 16 | Execution | execution gate denies by permission adapter | Gate 4 fail |
| 17 | Execution | execution gate denies by confirmation service | Gate 5 fail |
| 18 | Execution | execution gate executes when all gates pass | Full pipeline success |
| 19 | Security | security adapter absent with high risk fails closed | No adapter + high risk → deny |
| 20 | Security | security adapter absent with low risk proceeds | No adapter + low risk → skip |
| 21 | Permission | permission adapter absent with required permissions fails closed | No adapter + permissions → deny |
| 22 | Permission | permission adapter absent without required permissions proceeds | No adapter + no permissions → skip |
| 23 | Confirmation | unknown confirmation policy always requires confirmation | unknown → always (fail closed) |
| 24 | Confirmation | confirmation timeout denies execution | Timeout → deny |
| 25 | Recovery | execution failure triggers recovery | Recovery adapter invocation on failure |
| 26 | Offline | offline mode marks registry as offline | Status transition + effectiveStatus |

---

## 12. Validation Status

### 12.1 What Was Validated

| Method | Scope | Result |
|--------|-------|--------|
| Full source code reading | All 30 files read and analyzed | ✅ Complete |
| Structural analysis | Layer architecture, class hierarchy, enum values, method signatures | ✅ Complete |
| Cross-reference verification | Integration points with Steps 16–19 | ✅ Complete |
| Test scenario enumeration | 26 scenarios catalogued | ✅ Complete |
| Fail-closed audit | 24 fail-closed scenarios documented | ✅ Complete |
| File inventory | 30 files accounted for with paths | ✅ Complete |

### 12.2 What Was NOT Validated

| Method | Reason |
|--------|--------|
| Runtime test execution | **No Flutter/Dart SDK available** in the analysis environment |
| Compilation check | No SDK to run `dart analyze` or `flutter test` |
| Type system verification | Cannot confirm that concrete implementations satisfy abstract interfaces (known mismatches exist — see §13) |
| L10n code generation | Cannot verify `.arb` generation from YAML source |
| Riverpod provider wiring | Cannot confirm providers resolve at runtime |

**Important:** This report makes **no claims about runtime behavior, test pass/fail status, or compilation success**. All findings are based on structural code analysis only.

---

## 13. Known Issues

### 13.1 Signature Mismatches (Pre-existing in Source)

The following signature mismatches exist between abstract declarations and concrete implementations. These are **pre-existing issues in the source code** — documented here but **not fixed** per project rules.

| # | Abstract | Concrete | Mismatch |
|---|----------|-----------|----------|
| 1 | `ToolExecutionGate.execute({toolId, params})` — named parameters | `DefaultToolExecutionGate.execute(toolId, {params})` — positional + named | Named vs. positional `toolId` |
| 2 | `ToolSecurityAdapter.check(...)` (abstract) | `DefaultToolSecurityAdapter.validateToolExecution(...)` / `Step19SecurityAdapter.validateToolExecution(...)` | Method name: `check` vs. `validateToolExecution` |
| 3 | `ToolPermissionAdapter.check(...)` (abstract) | `Step16PermissionAdapter.checkPermissions(...)` | Method name: `check` vs. `checkPermissions` |
| 4 | `ToolRecoveryAdapter.recover(...)` parameter signatures | `Step18RecoveryAdapter.recover(...)` parameter list | Parameter count/names differ |

**Impact:** These mismatches would prevent compilation without adjustments. Since no Flutter SDK was available for verification, the exact resolution (override signatures vs. rename abstract methods) is not determined here.

### 13.2 Test File Discrepancies

The test file `tool_registry_test.dart` contains API usages that diverge from the source implementations:

| # | Test Code | Source Code | Discrepancy |
|---|-----------|-------------|-------------|
| 1 | `ToolFailure(phase: ..., message: '...')` — named constructor params | Source uses factory constructors per phase (e.g., `ToolFailure.registration(...)`) | Test instantiates directly; source uses factory constructors |
| 2 | `ToolExecutionResult(data: ..., errorMessage: ...)` | Source has `output` (Map) and `failure` (ToolFailure?) | Field names differ: `data` vs. `output`, `errorMessage` vs. `failure` |
| 3 | `ToolCategory.values` includes `data` and `external` | Source `ToolCategory` enum lists 12 values including `data` and `external` | These are actually consistent — test expects `values.length` matching source |
| 4 | Test constructs `ToolDefinition` with `ToolCategory.data` | Source `ToolCategory` has `data` value | Consistent |

**Impact:** Tests using the direct-constructor or wrong field-name patterns would not compile against the source as-is. This suggests the test file may target a slightly different version of the API.

### 13.3 `ToolRiskLevel.none` Ambiguity

- Source code analysis suggests `ToolRiskLevel` may have a `none` value in addition to `low/medium/high/critical/unknown`
- Test file expects `values.length == 5` (implying no `none` value)
- **Resolution:** The test file's expectation of 5 values likely reflects the intended design. The `none` value may be an artifact of an earlier design iteration.

---

## 14. Summary

Step 20 delivers a comprehensive, fail-closed Tool Registry & Allowlist system with:

- **30 files** across 4 architectural layers (domain, application, infrastructure, presentation)
- **16 capabilities** covering the full lifecycle of tool registration, discovery, access control, and execution
- **6-gate execution pipeline** with fail-closed guarantees at every gate
- **4 cross-step integrations** (Steps 16–19) via plug-in adapter architecture
- **26 test scenarios** covering all capabilities and fail-closed edge cases
- **11 pre-built tool adapters** (4 auto-approved, 7 requiring explicit allowlist approval)
- **Riverpod state management** with 13 provider definitions (5 core + 4 adapter + 4 derived)
- **3-language l10n** (Kurdish Sorani RTL, English, Arabic) with ~50+ keys
- **24 documented fail-closed scenarios** ensuring security-by-default

The architecture's fail-closed design means that **any ambiguity, absence, or error results in a denial** — ensuring that no tool can execute without explicit, validated authorization through every gate in the pipeline.

**Validation caveat:** All findings are based on structural code analysis. No Flutter/Dart SDK was available for runtime verification, compilation testing, or test execution. The known signature mismatches and test discrepancies documented in §13 would need resolution before compilation.
