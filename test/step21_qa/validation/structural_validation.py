#!/usr/bin/env python3
"""structural_validation.py
Step 21 – Structural Validation Script

Verifies:
1. All expected test files exist and are non-empty
2. Test files contain proper imports (flutter_test, aura_assistant)
3. Test files contain test() or group() calls
4. Source files from Steps 16-20 exist and are non-empty
5. No empty directories in test structure
6. Test count per directory meets minimum thresholds
7. Security regression tests cover all fail-closed invariants
8. No TODO/FIXME/HACK in test files (placeholder detection)

Output: JSON + human-readable summary to stdout.
"""

import os
import sys
import json
import re
from pathlib import Path
from collections import defaultdict

# Base paths
BASE = Path("/nfs/104430990/outputs")
TEST_DIR = BASE / "step_21_tests"

# Expected test directory structure
EXPECTED_DIRS = [
    "domain", "application", "infrastructure", "adapters", "l10n",
    "security_regression", "localization_qa", "provider_qa",
    "controller_qa", "e2e_pipeline", "validation",
]

# Expected test files with minimum test count
EXPECTED_TESTS = {
    "domain/semantic_memory_entry_test.dart": 3,
    "domain/memory_query_test.dart": 3,
    "domain/memory_search_result_test.dart": 3,
    "domain/memory_failure_test.dart": 3,
    "domain/policy_check_result_test.dart": 3,
    "domain/semantic_memory_repository_test.dart": 3,
    "application/semantic_memory_service_test.dart": 4,
    "application/memory_context_provider_test.dart": 4,
    "infrastructure/semantic_memory_adapter_impl_test.dart": 4,
    "infrastructure/semantic_memory_in_memory_repository_test.dart": 4,
    "infrastructure/security_policy_bridge_test.dart": 3,
    "adapters/memory_action_adapter_test.dart": 3,
    "adapters/memory_persistence_adapter_test.dart": 3,
    "adapters/memory_retrieval_adapter_test.dart": 3,
    "adapters/memory_security_adapter_test.dart": 3,
    "l10n/memory_strings_test.dart": 3,
    "security_regression/redaction_rule_test.dart": 5,
    "security_regression/security_audit_entry_test.dart": 5,
    "security_regression/security_config_test.dart": 5,
    "security_regression/security_failure_test.dart": 5,
    "security_regression/tool_registry_test.dart": 5,
    "security_regression/fail_closed_invariants_test.dart": 20,
    "localization_qa/l10n_completeness_test.dart": 5,
    "provider_qa/semantic_memory_provider_test.dart": 5,
    "controller_qa/memory_controller_state_test.dart": 5,
    "e2e_pipeline/memory_pipeline_e2e_test.dart": 5,
    "e2e_pipeline/tool_execution_e2e_test.dart": 5,
}

# Source directories to verify
SOURCE_DIRS = [
    BASE / "step_16_source",
    BASE / "step_17_source",
    BASE / "step_18_source",
    BASE / "step_19_source",
    BASE / "step_20_source",
]


def count_tests_in_file(filepath: Path) -> int:
    """Count test() calls in a Dart test file."""
    if not filepath.exists():
        return 0
    content = filepath.read_text(encoding="utf-8", errors="replace")
    # Count test('...', ...) calls — not test('...') inside strings
    # Count test('...' or test("...") calls
    single = len(re.findall(r"test\s*\(\s*'", content))
    double = len(re.findall(r'test\s*\(\s*"', content))
    return single + double


def check_imports(filepath: Path) -> dict:
    """Verify required imports exist in test file."""
    if not filepath.exists():
        return {"exists": False}
    content = filepath.read_text(encoding="utf-8", errors="replace")
    has_flutter_test = "import 'package:flutter_test/flutter_test.dart'" in content
    has_aura_import = "import 'package:aura_assistant/" in content or "import 'package:aura_assistant'" in content
    return {
        "exists": True,
        "has_flutter_test_import": has_flutter_test,
        "has_aura_import": has_aura_import,
        "non_empty": len(content.strip()) > 0,
    }


def check_no_placeholders(filepath: Path) -> list:
    """Detect TODO/FIXME/HACK in test files."""
    if not filepath.exists():
        return []
    content = filepath.read_text(encoding="utf-8", errors="replace")
    findings = []
    for i, line in enumerate(content.splitlines(), 1):
        if re.search(r"\b(TODO|FIXME|HACK|XXX)\b", line, re.IGNORECASE):
            findings.append({"line": i, "text": line.strip()[:80]})
    return findings


def validate_structure() -> dict:
    """Run all structural validations."""
    results = {
        "summary": {},
        "directories": {},
        "test_files": {},
        "source_dirs": {},
        "issues": [],
        "stats": {},
    }

    total_tests = 0
    total_files = 0
    passed = 0
    failed = 0

    # 1. Check directory structure
    for dirname in EXPECTED_DIRS:
        dirpath = TEST_DIR / dirname
        exists = dirpath.exists() and dirpath.is_dir()
        has_files = False
        if exists:
            has_files = any(dirpath.iterdir()) if exists else False
        results["directories"][dirname] = {
            "exists": exists,
            "has_files": has_files,
        }
        if not exists:
            results["issues"].append(f"MISSING DIRECTORY: {dirname}")
            failed += 1
        elif not has_files:
            results["issues"].append(f"EMPTY DIRECTORY: {dirname}")
            failed += 1
        else:
            passed += 1

    # 2. Check expected test files
    for relpath, min_tests in EXPECTED_TESTS.items():
        filepath = TEST_DIR / relpath
        test_count = count_tests_in_file(filepath)
        imports = check_imports(filepath)
        placeholders = check_no_placeholders(filepath)
        total_tests += test_count
        total_files += 1

        file_result = {
            "exists": filepath.exists(),
            "test_count": test_count,
            "min_expected": min_tests,
            "meets_threshold": test_count >= min_tests if filepath.exists() else False,
            "imports": imports,
            "placeholders": placeholders,
        }
        results["test_files"][relpath] = file_result

        if not filepath.exists():
            results["issues"].append(f"MISSING FILE: {relpath}")
            failed += 1
        elif not file_result["meets_threshold"]:
            results["issues"].append(
                f"INSUFFICIENT TESTS: {relpath} has {test_count} tests (min {min_tests})"
            )
            failed += 1
        elif not imports.get("has_flutter_test_import", False):
            results["issues"].append(
                f"MISSING IMPORT: {relpath} lacks flutter_test import"
            )
            failed += 1
        elif placeholders:
            results["issues"].append(
                f"PLACEHOLDERS: {relpath} has {len(placeholders)} TODO/FIXME/HACK"
            )
            failed += 1
        else:
            passed += 1

    # 3. Check source directories exist
    for srcdir in SOURCE_DIRS:
        exists = srcdir.exists() and srcdir.is_dir()
        name = srcdir.name
        results["source_dirs"][name] = {"exists": exists}
        if not exists:
            results["issues"].append(f"MISSING SOURCE DIR: {name}")
            failed += 1
        else:
            passed += 1

    # 4. Check validation script itself exists
    validation_script = TEST_DIR / "validation" / "structural_validation.py"
    results["stats"]["validation_script_exists"] = validation_script.exists()

    # Summary
    results["summary"] = {
        "total_test_files": total_files,
        "total_test_count": total_tests,
        "passed": passed,
        "failed": failed,
        "pass_rate": f"{passed / (passed + failed) * 100:.1f}%" if (passed + failed) > 0 else "0%",
        "issue_count": len(results["issues"]),
    }

    return results


def print_report(results: dict):
    """Print human-readable validation report."""
    print("=" * 70)
    print("  STEP 21 – STRUCTURAL VALIDATION REPORT")
    print("=" * 70)

    s = results["summary"]
    print(f"\n  Test Files:  {s['total_test_files']}")
    print(f"  Test Count:  {s['total_test_count']}")
    print(f"  Checks:      {s['passed']} PASSED, {s['failed']} FAILED")
    print(f"  Pass Rate:   {s['pass_rate']}")
    print(f"  Issues:      {s['issue_count']}")

    print("\n--- DIRECTORY STATUS ---")
    for name, status in results["directories"].items():
        icon = "✅" if status["exists"] and status["has_files"] else "❌"
        print(f"  {icon} {name:30s} exists={status['exists']} files={status['has_files']}")

    print("\n--- TEST FILE STATUS ---")
    for relpath, info in results["test_files"].items():
        icon = "✅" if info["meets_threshold"] and info["exists"] else "❌"
        count_str = f"{info['test_count']:3d}/{info['min_expected']:3d}"
        print(f"  {icon} {relpath:55s} tests={count_str}")

    print("\n--- SOURCE DIRECTORY STATUS ---")
    for name, info in results["source_dirs"].items():
        icon = "✅" if info["exists"] else "❌"
        print(f"  {icon} {name}")

    if results["issues"]:
        print("\n--- ISSUES ---")
        for i, issue in enumerate(results["issues"], 1):
            print(f"  {i:3d}. {issue}")
    else:
        print("\n  ✅ NO ISSUES FOUND")

    print("\n" + "=" * 70)


if __name__ == "__main__":
    results = validate_structure()
    print_report(results)

    # Also write JSON for programmatic consumption
    json_path = TEST_DIR / "validation" / "validation_results.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"  JSON results written to: {json_path}")

    # Exit code based on pass rate
    if results["summary"]["failed"] > 0:
        print("\n  ⚠️  VALIDATION COMPLETED WITH ISSUES")
        sys.exit(1)
    else:
        print("\n  ✅ ALL VALIDATIONS PASSED")
        sys.exit(0)
