#!/usr/bin/env python3
"""
validate_step_22_structure.py — Structural validation for Step 22 AURA Tool Execution Engine.

NO Flutter/Dart SDK — structural validation only.
NEVER claim runtime test results.

Checks:
1. All expected source files exist
2. All expected test files exist
3. All barrel/export files exist and export correct modules
4. Banned API patterns are NOT present in source files (comments excluded)
5. Required API patterns ARE present in source files
6. FAIL-CLOSED design patterns verified
7. Kurdini Sorani RTL locale='ku' verified
8. Tool count and structural integrity
"""

import os
import re
import sys
from pathlib import Path
from typing import List, Tuple, Dict

# ─── Configuration ───────────────────────────────────────────────────────────

BASE_DIR = Path(__file__).resolve().parent.parent
SOURCE_DIR = BASE_DIR / "step_22_source" / "lib" / "features" / "tool_execution"
TEST_DIR = BASE_DIR / "step_22_tests"

# Expected source files (relative to SOURCE_DIR)
EXPECTED_SOURCE_FILES = {
    # Domain Models
    "domain/models/exceptions.dart",
    "domain/models/tool_execution_context.dart",
    "domain/models/tool_input.dart",
    "domain/models/tool_output.dart",
    "domain/models/tool_execution_metadata.dart",
    "domain/models/models.dart",
    # Domain Services
    "domain/services/tool_interface.dart",
    "domain/services/recovery_tool.dart",
    "domain/services/services.dart",
    # Infrastructure
    "infrastructure/cancellation_token.dart",
    "infrastructure/tool_input_validator.dart",
    "infrastructure/tool_output_normalizer.dart",
    "infrastructure/audit_logger.dart",
    "infrastructure/tool_executor_registry.dart",
    "infrastructure/tool_providers.dart",
    "infrastructure/infrastructure.dart",
    # Executors
    "executors/device_tool.dart",
    "executors/screen_tool.dart",
    "executors/voice_tool.dart",
    "executors/memory_tool.dart",
    "executors/vision_tool.dart",
    "executors/media_tool.dart",
    "executors/assistant_tool.dart",
    "executors/communication_tool.dart",
    "executors/navigation_tool.dart",
    "executors/system_tool.dart",
    "executors/unknown_tool_handler.dart",
    "executors/executors.dart",
    # Application
    "application/tool_selection.dart",
    "application/tool_composition.dart",
    "application/background_execution.dart",
    "application/voice_first_execution.dart",
    "application/offline_capability.dart",
    "application/application.dart",
    # Adapters
    "adapters/step20_confirmation_adapter.dart",
    "adapters/step20_discovery_adapter.dart",
    "adapters/step20_gate_adapter.dart",
    "adapters/step18_retry_bridge.dart",
    "adapters/step19_security_bridge.dart",
    "adapters/adapters.dart",
    # Presentation
    "presentation/presentation.dart",
    # Top-level barrel
    "tool_execution.dart",
}

# Expected test files
EXPECTED_TEST_FILES = {
    # 9 fixed existing tests
    "tool_execution_context_test.dart",
    "tool_input_test.dart",
    "tool_output_test.dart",
    "tool_execution_metadata_test.dart",
    "cancellation_token_test.dart",
    "tool_input_validator_test.dart",
    "tool_output_normalizer_test.dart",
    "audit_logger_test.dart",
    "tool_executor_registry_test.dart",
    # 8 new tests
    "tool_selection_test.dart",
    "tool_composition_test.dart",
    "background_execution_test.dart",
    "voice_first_execution_test.dart",
    "offline_capability_test.dart",
    "step20_confirmation_adapter_test.dart",
    "step20_discovery_adapter_test.dart",
    "step20_gate_adapter_test.dart",
}

# Banned patterns — MUST NOT appear in source files (code lines only)
BANNED_PATTERNS = {
    # Wrong registry method names
    r'getTool\s*\(': "Use get() not getTool()",
    r'getAllTools\b': "Use allTools not getAllTools",
    r'getByCategory\s*\(': "Use byCategory() not getByCategory()",
    # Wrong enum usage
    r'ToolRiskLevel\b': "riskLevel is String, not ToolRiskLevel enum",
    # Wrong property names
    r'hasSensitiveData\b': "Use containsSensitiveData not hasSensitiveData",
    # Wrong output factory params
    r'ToolOutput\.failure\s*\(\s*message\s*:' : "ToolOutput.failure uses errorMessage, not message",
    r'ToolOutput\.denied\s*\(\s*errorMessage\s*:' : "ToolOutput.denied uses reason, not errorMessage",
    # Wrong severity
    r'ToolInputValidationSeverity\.critical\b': "No critical severity — use error/warning/info only",
    # Wrong context method
    r'recoveryAttempt\b': "Use retryAttempt not recoveryAttempt",
    r'currentRetry\b': "Use retryAttempt not currentRetry",
    # Wrong confirmation mode
    r'autoDeny\b': "Use denyAll not autoDeny",
    # Wrong memory context type
    r'memoryContext\s*:\s*Map\b': "memoryContext is String? not Map",
    # AuditEntry with phase
    r'AuditEntry\s*\([^)]*phase\s*:' : "AuditEntry has no phase param — uses action/description/timestamp",
}

# Required patterns — MUST appear in appropriate source files
# Using flexible patterns with re.DOTALL for multi-line matching
REQUIRED_PATTERNS: Dict[str, List[Tuple[str, str]]] = {
    "domain/models/tool_execution_context.dart": [
        (r"locale\s*=\s*'ku'", "Default locale must be 'ku' (Kurdini Sorani RTL)"),
        (r"cancel\s*\(\s*\)", "cancel() takes NO arguments"),
        (r"incrementRetry", "incrementRetry method must exist"),
        (r"retryAttempt", "retryAttempt property must exist"),
        (r"withSecurityClearance", "withSecurityClearance method must exist"),
        (r"throwIfCancelled", "throwIfCancelled method must exist"),
        (r"confirmationDenied", "confirmationDenied property must exist"),
    ],
    "domain/models/tool_output.dart": [
        (r"ToolOutput\.failClosed", "failClosed factory must exist"),
        (r"errorMessage", "failure uses errorMessage not message"),
        (r"denied[\s\S]*?reason", "denied uses reason param"),
        (r"cancelled[\s\S]*?message", "cancelled uses message param"),
        (r"containsSensitiveData", "containsSensitiveData property"),
        (r"suggestions", "suggestions list property"),
        (r"SensitiveDataCategory", "SensitiveDataCategory enum"),
    ],
    "domain/models/tool_input.dart": [
        (r"ToolInput\.valid", "ToolInput.valid factory"),
        (r"ToolInput\.invalid", "ToolInput.invalid factory"),
        (r"ToolInputValidationSeverity\.error", "error severity"),
        (r"ToolInputValidationSeverity\.warning", "warning severity"),
        # info is defined in the enum — check enum definition directly
        (r"\binfo\b[;,]", "info severity enum value"),
    ],
    "domain/models/tool_execution_metadata.dart": [
        (r"ToolExecutionPhase\.requested", "requested phase"),
        # Check enum values exist (bare names in enum body)
        (r"failClosed[\s,;]", "failClosed phase enum value"),
        (r"denied[\s,;]", "denied phase enum value"),
        (r"timedOut[\s,;]", "timedOut phase enum value"),
    ],
    "infrastructure/cancellation_token.dart": [
        (r"cancel\s*\(\s*\)", "cancel() takes NO arguments"),
    ],
    "infrastructure/tool_executor_registry.dart": [
        (r'\bget\s*\(', "get() method"),
        (r'\ballTools\b', "allTools property"),
        (r'\bbyCategory\s*\(', "byCategory() method"),
    ],
    "domain/services/tool_interface.dart": [
        (r'riskLevel', "riskLevel property (String)"),
        (r'cancel\s*\(\s*\)', "cancel() returns bool"),
    ],
}

# ─── Helpers ────────────────────────────────────────────────────────────────

def strip_comments(content: str) -> str:
    """Remove Dart doc-comment (///) and line-comment (//) lines before pattern matching.
    
    This prevents false positives where a doc comment mentions a banned pattern
    to explain the fix (e.g. '/// uses retryAttempt not recoveryAttempt').
    """
    lines = content.split('\n')
    code_lines = []
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith('///') or stripped.startswith('//'):
            continue
        code_lines.append(line)
    return '\n'.join(code_lines)


# ─── Validation Logic ────────────────────────────────────────────────────────

class ValidationResult:
    def __init__(self):
        self.passed: List[str] = []
        self.failed: List[str] = []
        self.warnings: List[str] = []

    def ok(self, msg: str):
        self.passed.append(msg)

    def fail(self, msg: str):
        self.failed.append(msg)

    def warn(self, msg: str):
        self.warnings.append(msg)

    @property
    def is_clean(self) -> bool:
        return len(self.failed) == 0

    def summary(self) -> str:
        lines = []
        lines.append("=" * 72)
        lines.append("STEP 22 STRUCTURAL VALIDATION REPORT")
        lines.append("=" * 72)
        lines.append(f"")
        lines.append(f"PASSED:   {len(self.passed)}")
        lines.append(f"FAILED:   {len(self.failed)}")
        lines.append(f"WARNINGS: {len(self.warnings)}")
        lines.append(f"")
        if self.failed:
            lines.append("── FAILURES ──────────────────────────────────────────")
            for f in self.failed:
                lines.append(f"  ✗ {f}")
            lines.append(f"")
        if self.warnings:
            lines.append("── WARNINGS ──────────────────────────────────────────")
            for w in self.warnings:
                lines.append(f"  ⚠ {w}")
            lines.append(f"")
        lines.append("── PASSED ───────────────────────────────────────────")
        for p in self.passed:
            lines.append(f"  ✓ {p}")
        lines.append(f"")
        lines.append("=" * 72)
        if self.is_clean:
            lines.append("RESULT: ALL CHECKS PASSED — STRUCTURAL VALIDATION CLEAN")
        else:
            lines.append(f"RESULT: {len(self.failed)} FAILURE(S) — MUST FIX BEFORE COMPLETION")
        lines.append("=" * 72)
        return "\n".join(lines)


def read_file(rel_path: str) -> str:
    full_path = SOURCE_DIR / rel_path
    if not full_path.exists():
        return ""
    return full_path.read_text(encoding="utf-8", errors="replace")


def read_test_file(filename: str) -> str:
    full_path = TEST_DIR / filename
    if not full_path.exists():
        return ""
    return full_path.read_text(encoding="utf-8", errors="replace")


def validate_source_files_exist(result: ValidationResult):
    """Check all expected source files exist."""
    for rel_path in EXPECTED_SOURCE_FILES:
        full_path = SOURCE_DIR / rel_path
        if full_path.exists():
            result.ok(f"Source exists: {rel_path}")
        else:
            result.fail(f"Source MISSING: {rel_path}")


def validate_test_files_exist(result: ValidationResult):
    """Check all expected test files exist."""
    for filename in EXPECTED_TEST_FILES:
        full_path = TEST_DIR / filename
        if full_path.exists():
            result.ok(f"Test exists: {filename}")
        else:
            result.fail(f"Test MISSING: {filename}")


def validate_barrel_exports(result: ValidationResult):
    """Check barrel files export correct modules."""
    barrel_checks = {
        "domain/models/models.dart": [
            "exceptions.dart",
            "tool_execution_context.dart",
            "tool_input.dart",
            "tool_output.dart",
            "tool_execution_metadata.dart",
        ],
        "domain/services/services.dart": [
            "tool_interface.dart",
            "recovery_tool.dart",
        ],
        "infrastructure/infrastructure.dart": [
            "cancellation_token.dart",
            "tool_input_validator.dart",
            "tool_output_normalizer.dart",
            "audit_logger.dart",
            "tool_executor_registry.dart",
            "tool_providers.dart",
        ],
        "executors/executors.dart": [
            "device_tool.dart",
            "screen_tool.dart",
            "voice_tool.dart",
            "memory_tool.dart",
            "vision_tool.dart",
            "media_tool.dart",
            "assistant_tool.dart",
            "communication_tool.dart",
            "navigation_tool.dart",
            "system_tool.dart",
            "unknown_tool_handler.dart",
        ],
        "application/application.dart": [
            "tool_selection.dart",
            "tool_composition.dart",
            "background_execution.dart",
            "voice_first_execution.dart",
            "offline_capability.dart",
        ],
        "adapters/adapters.dart": [
            "step20_confirmation_adapter.dart",
            "step20_discovery_adapter.dart",
            "step20_gate_adapter.dart",
            "step18_retry_bridge.dart",
            "step19_security_bridge.dart",
        ],
        "tool_execution.dart": [
            "models.dart",
            "services.dart",
            "infrastructure.dart",
            "executors.dart",
            "application.dart",
            "adapters.dart",
            "presentation.dart",
        ],
    }
    for barrel_path, exports in barrel_checks.items():
        content = read_file(barrel_path)
        if not content:
            result.fail(f"Barrel MISSING: {barrel_path}")
            continue
        for export_name in exports:
            if export_name in content:
                result.ok(f"Barrel {barrel_path} exports {export_name}")
            else:
                result.fail(f"Barrel {barrel_path} MISSING export: {export_name}")


def validate_no_banned_patterns(result: ValidationResult):
    """Check banned API patterns are NOT present in source files.
    
    STRIPS Dart comment lines (/// and //) before scanning to avoid
    false positives from doc comments that mention banned names to
    explain the correct API.
    """
    # Only check .dart source files (not barrel files)
    source_files_to_check = []
    for rel_path in EXPECTED_SOURCE_FILES:
        if rel_path.endswith(".dart") and not Path(rel_path).name == Path(rel_path).parent.name + ".dart":
            # Skip barrel files themselves
            parent = Path(rel_path).parent.name
            name = Path(rel_path).stem
            if name == parent or name == "tool_execution":
                continue
            source_files_to_check.append(rel_path)

    for rel_path in source_files_to_check:
        content = read_file(rel_path)
        if not content:
            continue
        # Strip comment lines before checking for banned patterns
        code_only = strip_comments(content)
        for pattern, description in BANNED_PATTERNS.items():
            matches = re.findall(pattern, code_only, re.MULTILINE | re.DOTALL)
            if matches:
                result.fail(f"BANNED in {rel_path}: {description} (pattern: {pattern})")
            else:
                result.ok(f"Clean in {rel_path}: no '{description}'")


def validate_required_patterns(result: ValidationResult):
    """Check required API patterns ARE present in appropriate source files.
    
    Uses re.DOTALL for multi-line factory constructors and flexible
    patterns that match both arrow syntax and brace syntax.
    """
    for rel_path, patterns in REQUIRED_PATTERNS.items():
        content = read_file(rel_path)
        if not content:
            result.fail(f"Cannot check required patterns — file MISSING: {rel_path}")
            continue
        for pattern, description in patterns:
            if re.search(pattern, content, re.DOTALL):
                result.ok(f"Required in {rel_path}: {description}")
            else:
                result.fail(f"MISSING in {rel_path}: {description} (pattern: {pattern})")


def validate_fail_closed_design(result: ValidationResult):
    """Check FAIL-CLOSED patterns across all executor files."""
    executor_files = [
        "executors/device_tool.dart",
        "executors/screen_tool.dart",
        "executors/voice_tool.dart",
        "executors/memory_tool.dart",
        "executors/vision_tool.dart",
        "executors/media_tool.dart",
        "executors/assistant_tool.dart",
        "executors/communication_tool.dart",
        "executors/navigation_tool.dart",
        "executors/system_tool.dart",
        "executors/unknown_tool_handler.dart",
    ]
    for rel_path in executor_files:
        content = read_file(rel_path)
        if not content:
            result.fail(f"FAIL-CLOSED check: executor MISSING {rel_path}")
            continue
        # Check that failClosed or denied is used on error paths
        has_fail_closed = 'failClosed' in content or 'denied' in content or 'fail_closed' in content
        if has_fail_closed:
            result.ok(f"FAIL-CLOSED pattern in {rel_path}")
        else:
            result.warn(f"No explicit FAIL-CLOSED pattern found in {rel_path} — verify error handling")


def validate_kurdini_locale(result: ValidationResult):
    """Check locale='ku' (Kurdini Sorani RTL) is default."""
    content = read_file("domain/models/tool_execution_context.dart")
    if not content:
        result.fail("Cannot verify Kurdini Sorani locale — file MISSING")
        return
    if "'ku'" in content or '"ku"' in content:
        result.ok("Default locale is 'ku' (Kurdini Sorani RTL)")
    else:
        result.fail("Default locale is NOT 'ku' — must be Kurdini Sorani RTL")


def validate_tool_execution_phase_count(result: ValidationResult):
    """Check exactly 12 ToolExecutionPhase values."""
    content = read_file("domain/models/tool_execution_metadata.dart")
    if not content:
        result.fail("Cannot verify ToolExecutionPhase count — file MISSING")
        return
    # Count enum values
    phase_names = [
        'requested', 'validating', 'confirming', 'sanitizing',
        'executing', 'normalizing', 'completed', 'failed',
        'cancelled', 'timedOut', 'denied', 'failClosed'
    ]
    found = 0
    for phase in phase_names:
        if phase in content:
            found += 1
    if found == 12:
        result.ok(f"All 12 ToolExecutionPhase values present")
    else:
        result.fail(f"Expected 12 ToolExecutionPhase values, found {found}/12")


def validate_tool_output_status_count(result: ValidationResult):
    """Check exactly 8 ToolOutputStatus values."""
    content = read_file("domain/models/tool_output.dart")
    if not content:
        result.fail("Cannot verify ToolOutputStatus count — file MISSING")
        return
    # Correct status names matching the actual enum
    status_names = [
        'success', 'failure', 'cancelled', 'denied',
        'timedOut', 'partial', 'empty', 'failClosed'
    ]
    found = 0
    for status in status_names:
        if status in content:
            found += 1
    if found == 8:
        result.ok(f"All 8 ToolOutputStatus values present")
    else:
        result.fail(f"Expected 8 ToolOutputStatus values, found {found}/8")


def validate_no_raw_newlines(result: ValidationResult):
    """Check no raw \n literals in adapter output messages."""
    adapter_files = [
        "adapters/step20_confirmation_adapter.dart",
        "adapters/step20_discovery_adapter.dart",
        "adapters/step20_gate_adapter.dart",
    ]
    for rel_path in adapter_files:
        content = read_file(rel_path)
        if not content:
            continue
        # Look for string literals containing \n (raw)
        raw_newline_pattern = r"'[^']*\\n[^']*'|\"[^\"]*\\n[^\"]*\""
        matches = re.findall(raw_newline_pattern, content)
        if matches:
            result.warn(f"Raw \\n found in string literals in {rel_path}: {matches[:3]}")
        else:
            result.ok(f"No raw \\n literals in {rel_path}")


def validate_test_file_quality(result: ValidationResult):
    """Basic quality checks on test files."""
    for filename in EXPECTED_TEST_FILES:
        content = read_test_file(filename)
        if not content:
            result.fail(f"Test file empty: {filename}")
            continue
        # Check test has at least one test() or group()
        if 'test(' in content or 'group(' in content:
            result.ok(f"Test file has test assertions: {filename}")
        else:
            result.fail(f"Test file has NO test() calls: {filename}")
        # Check it mentions structural validation disclaimer
        if 'structural' in content.lower() or 'validation only' in content.lower():
            result.ok(f"Test has structural validation disclaimer: {filename}")
        else:
            result.warn(f"Test may lack structural validation disclaimer: {filename}")


def count_total_files(result: ValidationResult):
    """Count and report total source and test files."""
    source_count = 0
    for rel_path in EXPECTED_SOURCE_FILES:
        if (SOURCE_DIR / rel_path).exists():
            source_count += 1
    test_count = 0
    for filename in EXPECTED_TEST_FILES:
        if (TEST_DIR / filename).exists():
            test_count += 1
    result.ok(f"Total source files: {source_count}/{len(EXPECTED_SOURCE_FILES)}")
    result.ok(f"Total test files: {test_count}/{len(EXPECTED_TEST_FILES)}")


# ─── Main ───────────────────────────────────────────────────────────────────

def main():
    print("\nSTEP 22 STRUCTURAL VALIDATION")
    print("=" * 72)
    print(f"Source dir: {SOURCE_DIR}")
    print(f"Test dir:   {TEST_DIR}")
    print(f"Expected source files: {len(EXPECTED_SOURCE_FILES)}")
    print(f"Expected test files:   {len(EXPECTED_TEST_FILES)}")
    print("=" * 72)
    print()

    result = ValidationResult()

    # 1. File existence
    print("[1/10] Checking source file existence...")
    validate_source_files_exist(result)

    print("[2/10] Checking test file existence...")
    validate_test_files_exist(result)

    # 2. Barrel exports
    print("[3/10] Checking barrel/export files...")
    validate_barrel_exports(result)

    # 3. Banned patterns
    print("[4/10] Checking banned API patterns (comments stripped)...")
    validate_no_banned_patterns(result)

    # 4. Required patterns
    print("[5/10] Checking required API patterns (DOTALL enabled)...")
    validate_required_patterns(result)

    # 5. FAIL-CLOSED design
    print("[6/10] Checking FAIL-CLOSED design patterns...")
    validate_fail_closed_design(result)

    # 6. Kurdini locale
    print("[7/10] Checking Kurdini Sorani RTL locale='ku'...")
    validate_kurdini_locale(result)

    # 7. Phase count
    print("[8/10] Checking ToolExecutionPhase count (12)...")
    validate_tool_execution_phase_count(result)

    # 8. Status count
    print("[9/10] Checking ToolOutputStatus count (8)...")
    validate_tool_output_status_count(result)

    # 9. Raw newlines
    print("[10/10] Checking no raw \\n in adapter strings...")
    validate_no_raw_newlines(result)

    # Bonus checks
    print("\n[BONUS] Checking test file quality...")
    validate_test_file_quality(result)

    print("[BONUS] Counting total files...")
    count_total_files(result)

    # Output report
    report = result.summary()
    print(report)

    # Write report to file
    report_path = BASE_DIR / "validation" / "validation_report.txt"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(report, encoding="utf-8")
    print(f"\nReport written to: {report_path}")

    return 0 if result.is_clean else 1


if __name__ == "__main__":
    sys.exit(main())
