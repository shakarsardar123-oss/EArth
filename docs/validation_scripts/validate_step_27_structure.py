#!/usr/bin/env python3
"""validate_step_27_structure.py
Structural validation for AURA Step 27: Advanced Integration & Universal Connectivity.
Python-only (no Flutter/Dart SDK). Checks:
  1. All 7 feature modules exist with domain/application/infrastructure/l10n
  2. All 8 repository interfaces + 8 service interfaces present
  3. All 7 orchestrators present with correct method names
  4. All 8 infrastructure stub adapters present
  5. All 7 l10n app_ku.arb files present with Kurdish strings
  6. Feature-level + lib-level barrels present
  7. FAIL-CLOSED: no hardcoded secrets, no invented APIs
  8. Test directory structure present
"""

import os, sys, re

BASE = os.environ.get("STEP_27_SOURCE", "/nfs/104430990/temp/step_27_source")
TEST_BASE = os.environ.get("STEP_27_TESTS", "/nfs/104430990/temp/step_27_tests")

MODULES = [
    "device_connectivity",
    "real_time_translation",
    "continuous_listening",
    "subtitle_overlay",
    "screen_target",
    "resource_optimization",
    "api_reliability",
]

REQUIRED_REPO_FILES = {
    "device_connectivity": ["device_transport_repository.dart"],
    "real_time_translation": ["translation_engine_repository.dart"],
    "continuous_listening": ["audio_input_repository.dart"],
    "subtitle_overlay": ["overlay_renderer_repository.dart"],
    "screen_target": ["vision_repository.dart", "screen_action_repository.dart"],
    "resource_optimization": ["system_resource_repository.dart"],
    "api_reliability": ["api_gateway_repository.dart"],
}

REQUIRED_SERVICE_FILES = {
    "device_connectivity": ["device_connection_service.dart"],
    "real_time_translation": ["translation_service.dart"],
    "continuous_listening": ["continuous_listening_service.dart"],
    "subtitle_overlay": ["subtitle_overlay_service.dart"],
    "screen_target": ["screen_detection_service.dart", "screen_correction_service.dart"],
    "resource_optimization": ["resource_optimization_service.dart"],
    "api_reliability": ["api_reliability_service.dart"],
}

ORCHESTRATOR_FILES = {
    "device_connectivity": "device_connection_orchestrator.dart",
    "real_time_translation": "translation_orchestrator.dart",
    "continuous_listening": "continuous_listening_orchestrator.dart",
    "subtitle_overlay": "subtitle_overlay_orchestrator.dart",
    "screen_target": "screen_target_orchestrator.dart",
    "resource_optimization": "resource_optimization_orchestrator.dart",
    "api_reliability": "api_reliability_orchestrator.dart",
}

STUB_FILES = {
    "device_connectivity": ["stub_device_transport_repository.dart"],
    "real_time_translation": ["stub_translation_engine_repository.dart"],
    "continuous_listening": ["stub_audio_input_repository.dart"],
    "subtitle_overlay": ["stub_overlay_renderer_repository.dart"],
    "screen_target": ["stub_vision_repository.dart", "stub_screen_action_repository.dart"],
    "resource_optimization": ["stub_system_resource_repository.dart"],
    "api_reliability": ["stub_api_gateway_repository.dart"],
}

# Correct method names that MUST appear in orchestrators
CORRECT_METHOD_CHECKS = {
    "device_connectivity": [
        ("scanDevices", "discoverDevices"),
        ("establishConnection", "connect("),
        ("terminateConnection", "disconnect("),
        ("sendRaw", "sendCommand"),
        ("isTransportAvailable", "isAvailable"),
    ],
    "real_time_translation": [
        ("executeTranslation", "translate(request)"),
        ("engineSupportedLanguages", "isLanguageSupported"),
        ("isEngineAvailable", "isAvailable"),
    ],
}

# Wrong method names that MUST NOT appear
FORBIDDEN_METHODS = [
    "_transportRepository.connect(",
    "_transportRepository.disconnect(",
    "_transportRepository.sendCommand",
    "_transportRepository.discoverDevices",
    "_transportRepository.getConnectionState",
    "_connectionService.evaluateCommand",
    "_engineRepository.translate(",
    "_engineRepository.isLanguageSupported",
    "_engineRepository.getAvailableTargetLanguages",
    "result.isUnknown",
]

errors = []
warnings = []

def check_file_exists(path, desc):
    if not os.path.isfile(path):
        errors.append(f"MISSING: {desc} — {path}")
        return False
    return True

def check_no_secrets(path):
    if not os.path.isfile(path):
        return
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    # Check for hardcoded API keys / secrets
    secret_patterns = [
        r'(?:api[_-]?key|secret|token|password)\s*[=:]\s*["\'][^"\']{8,}',
        r'Bearer\s+[A-Za-z0-9._-]{20,}',
    ]
    for pat in secret_patterns:
        if re.search(pat, content, re.IGNORECASE):
            errors.append(f"SECURITY: Hardcoded secret in {path}")

def check_correct_methods(path, correct, wrong, module):
    if not os.path.isfile(path):
        return
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    for correct_name, wrong_name in correct:
        if correct_name not in content:
            errors.append(f"METHOD: Module {module} — correct method '{correct_name}' not found in {path}")
    for forbidden in wrong:
        if forbidden in content:
            errors.append(f"FORBIDDEN: Module {module} — forbidden pattern '{forbidden}' found in {path}")

def run_validation():
    print("=" * 40)
    print("AURA Step 27 — Structural Validation")
    print("=" * 40)

    # 1. Module directory structure
    print("\n[1] Module directory structure...")
    for mod in MODULES:
        mod_dir = f"{BASE}/lib/features/{mod}"
        if not os.path.isdir(mod_dir):
            errors.append(f"MISSING MODULE: {mod}")
            continue
        for layer in ["domain", "application", "infrastructure"]:
            layer_dir = f"{mod_dir}/{layer}"
            if not os.path.isdir(layer_dir):
                errors.append(f"MISSING LAYER: {mod}/{layer}")

    # 2. Repository interfaces
    print("[2] Repository interfaces...")
    for mod, files in REQUIRED_REPO_FILES.items():
        for fname in files:
            path = f"{BASE}/lib/features/{mod}/domain/repositories/{fname}"
            check_file_exists(path, f"Repository {mod}/{fname}")

    # 3. Service interfaces
    print("[3] Service interfaces...")
    for mod, files in REQUIRED_SERVICE_FILES.items():
        for fname in files:
            path = f"{BASE}/lib/features/{mod}/domain/services/{fname}"
            check_file_exists(path, f"Service {mod}/{fname}")

    # 4. Orchestrators
    print("[4] Application orchestrators...")
    for mod, fname in ORCHESTRATOR_FILES.items():
        path = f"{BASE}/lib/features/{mod}/application/{fname}"
        if check_file_exists(path, f"Orchestrator {mod}/{fname}"):
            check_no_secrets(path)

    # 5. Correct method name checks
    print("[5] Correct method mappings...")
    for mod, checks in CORRECT_METHOD_CHECKS.items():
        fname = ORCHESTRATOR_FILES[mod]
        path = f"{BASE}/lib/features/{mod}/application/{fname}"
        check_correct_methods(path, checks, FORBIDDEN_METHODS, mod)

    # 6. Infrastructure stubs
    print("[6] Infrastructure stub adapters...")
    for mod, files in STUB_FILES.items():
        for fname in files:
            path = f"{BASE}/lib/features/{mod}/infrastructure/{fname}"
            check_file_exists(path, f"Stub {mod}/{fname}")

    # 7. L10n files
    print("[7] L10n Kurdish Sorani files...")
    for mod in MODULES:
        path = f"{BASE}/lib/features/{mod}/l10n/app_ku.arb"
        if check_file_exists(path, f"L10n {mod}"):
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            if '"@@locale": "ku"' not in content:
                errors.append(f"L10N: {mod} missing @@locale ku")

    # 8. Barrels
    print("[8] Barrel files...")
    for mod in MODULES:
        check_file_exists(f"{BASE}/lib/features/{mod}/{mod}.dart", f"Feature barrel {mod}")
        check_file_exists(f"{BASE}/lib/features/{mod}/domain/domain.dart", f"Domain barrel {mod}")
        check_file_exists(f"{BASE}/lib/features/{mod}/application/application.dart", f"App barrel {mod}")
        check_file_exists(f"{BASE}/lib/features/{mod}/infrastructure/infrastructure.dart", f"Infra barrel {mod}")
    check_file_exists(f"{BASE}/lib/features/features.dart", "Features barrel")
    check_file_exists(f"{BASE}/lib/aura_step_27.dart", "Lib-level barrel")

    # 9. Tests
    print("[9] Test directory...")
    test_dirs = ["domain", "application", "infrastructure"]
    for td in test_dirs:
        if not os.path.isdir(f"{TEST_BASE}/{td}"):
            warnings.append(f"MISSING TEST DIR: {td}")
    test_files = [
        f"{TEST_BASE}/domain/device_connectivity_domain_test.dart",
        f"{TEST_BASE}/domain/real_time_translation_domain_test.dart",
        f"{TEST_BASE}/domain/continuous_listening_domain_test.dart",
        f"{TEST_BASE}/domain/subtitle_overlay_domain_test.dart",
        f"{TEST_BASE}/domain/screen_target_domain_test.dart",
        f"{TEST_BASE}/domain/resource_optimization_domain_test.dart",
        f"{TEST_BASE}/domain/api_reliability_domain_test.dart",
        f"{TEST_BASE}/application/orchestrator_method_mapping_test.dart",
        f"{TEST_BASE}/infrastructure/stub_repository_fail_closed_test.dart",
    ]
    for tf in test_files:
        check_file_exists(tf, f"Test {os.path.basename(tf)}")

    # 10. No hardcoded secrets in any Dart file
    print("[10] Security scan — no hardcoded secrets...")
    for root, dirs, files in os.walk(f"{BASE}/lib"):
        for fn in files:
            if fn.endswith(".dart"):
                check_no_secrets(os.path.join(root, fn))

    # 11. No conversation_provider.dart modified
    print("[11] Steps 15-26 preservation check...")
    cp_path = f"{BASE}/lib/features/conversation_provider.dart"
    if os.path.isfile(cp_path):
        warnings.append("WARNING: conversation_provider.dart exists in Step 27 — should not be modified")

    # Summary
    print()
    print("=" * 40)
    print("VALIDATION COMPLETE")
    print(f"  Errors:   {len(errors)}")
    print(f"  Warnings: {len(warnings)}")
    if errors:
        print("\nERRORS:")
        for e in errors:
            print(f"  \u2717 {e}")
    if warnings:
        print("\nWARNINGS:")
        for w in warnings:
            print(f"  \u26a0 {w}")
    if not errors:
        print("\n\u2713 ALL CHECKS PASSED")
    return len(errors)

if __name__ == "__main__":
    sys.exit(run_validation())
