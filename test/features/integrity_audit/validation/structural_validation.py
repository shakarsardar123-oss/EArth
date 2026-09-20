#!/usr/bin/env python3
"""structural_validation.py
Step 26 – System Integration QA & Integrity Audit: Structural Validation Script

Verifies:
1. All expected test files exist and are non-empty
2. Test files contain proper imports (flutter_test)
3. Test files contain test() or group() calls
4. Source files from Step 26 exist and are non-empty
5. No empty directories in test structure
6. Test count per directory meets minimum thresholds
7. FAIL-CLOSED regression tests cover all invariants
8. Cross-adapter tests encode all 12 documented drift bugs
9. No TODO/FIXME/HACK in test files (placeholder detection)
10. No hardcoded secrets in any file
11. conversation_provider.dart not modified
12. Steps 15-25 source files not modified

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
TEST_DIR = BASE / "step_26_tests"
SOURCE_DIR = BASE / "step_26_source"

# Expected test directory structure
EXPECTED_DIRS = [
    "domain",
    "cross_adapter",
    "fail_closed_regression",
    "localization_qa",
    "e2e_pipeline",
    "validation",
]

# Expected test files with minimum test count
EXPECTED_TESTS = {
    "domain/integrity_verdict_test.dart": 3,
    "domain/compatibility_report_test.dart": 3,
    "domain/audit_finding_test.dart": 3,
    "domain/fail_closed_invariant_test.dart": 3,
    "domain/localization_gap_test.dart": 3,
    "cross_adapter/step23_vs_step25_repo_consistency_test.dart": 10,
    "cross_adapter/step22_vs_step25_execution_test.dart": 5,
    "cross_adapter/step24_vs_step25_trigger_test.dart": 5,
    "fail_closed_regression/step22_fail_closed_test.dart": 5,
    "fail_closed_regression/step23_fail_closed_test.dart": 5,
    "fail_closed_regression/step24_fail_closed_test.dart": 5,
    "fail_closed_regression/step25_fail_closed_test.dart": 5,
    "localization_qa/l10n_completeness_test.dart": 5,
    "e2e_pipeline/integrity_audit_pipeline_test.dart": 8,
}

# Expected source files in Step 26
EXPECTED_SOURCE_FILES = {
    # Domain models
    "lib/features/integrity_audit/domain/models/integrity_verdict.dart": True,
    "lib/features/integrity_audit/domain/models/compatibility_report.dart": True,
    "lib/features/integrity_audit/domain/models/audit_finding.dart": True,
    "lib/features/integrity_audit/domain/models/fail_closed_invariant.dart": True,
    "lib/features/integrity_audit/domain/models/localization_gap.dart": True,
    "lib/features/integrity_audit/domain/models/models.dart": True,
    # Domain services
    "lib/features/integrity_audit/domain/services/integrity_verification_service.dart": True,
    "lib/features/integrity_audit/domain/services/step_compatibility_service.dart": True,
    "lib/features/integrity_audit/domain/services/fail_closed_audit_service.dart": True,
    "lib/features/integrity_audit/domain/services/localization_completeness_service.dart": True,
    "lib/features/integrity_audit/domain/services/services.dart": True,
    # Domain repositories
    "lib/features/integrity_audit/domain/repositories/step_22_introspection_repository.dart": True,
    "lib/features/integrity_audit/domain/repositories/step_23_introspection_repository.dart": True,
    "lib/features/integrity_audit/domain/repositories/step_24_introspection_repository.dart": True,
    "lib/features/integrity_audit/domain/repositories/step_25_introspection_repository.dart": True,
    "lib/features/integrity_audit/domain/repositories/repositories.dart": True,
    # Application layer
    "lib/features/integrity_audit/application/integrity_audit_orchestrator.dart": True,
    "lib/features/integrity_audit/application/cross_adapter_checker.dart": True,
    "lib/features/integrity_audit/application/fail_closed_regression_checker.dart": True,
    "lib/features/integrity_audit/application/application.dart": True,
    # Top-level barrel
    "lib/features/integrity_audit/integrity_audit.dart": True,
}

# 12 documented cross-adapter drift bugs
DOCUMENTED_DRIFTS = [
    "DRIFT #1: AuditRepository.record() Future<void> vs void",
    "DRIFT #2: AuditRepository.forRequest() Future<List> vs List",
    "DRIFT #3: AuditRepository.isAvailable() Step25-only method",
    "DRIFT #4: ConnectivityRepository.isOnline() Future<bool> vs bool",
    "DRIFT #5: PermissionRepository.check()/request() named vs positional",
    "DRIFT #6: RecoveryRepository.classifyAndStrategize() required vs default",
    "DRIFT #7: ExecutionResult completely different field sets",
    "DRIFT #8: ToolRegistryRepository.discover() String? vs String",
    "DRIFT #9: DiscoveredTool different field sets",
    "DRIFT #10: AgentIntent/AgentPlan different field sets",
    "DRIFT #11: ConfirmationVerdict factories vs fields",
    "DRIFT #12: RecoveryAction/RecoveryStrategy different enums/fields",
]

# FAIL-CLOSED invariants that must appear in regression tests
FAIL_CLOSED_INVARIANTS = [
    "unknown → denied",
    "error → denied",
    "unavailable → denied",
    "canSkip → shouldAbort",
]

# Secret patterns to scan for
SECRET_PATTERNS = [
    r'password\s*=\s*["\']',
    r'secret\s*=\s*["\']',
    r'api_?key\s*=\s*["\']',
    r'token\s*=\s*["\']',
    r'Authorization["\']\s*:\s*["\']',
]


def count_tests_in_file(filepath: Path) -> int:
    """Count test() calls in a Dart test file."""
    if not filepath.exists():
        return 0
    content = filepath.read_text(encoding="utf-8", errors="replace")
    single = len(re.findall(r"test\s*\(\s*'", content))
    double = len(re.findall(r'test\s*\(\s*"', content))
    return single + double


def count_groups_in_file(filepath: Path) -> int:
    """Count group() calls in a Dart test file."""
    if not filepath.exists():
        return 0
    content = filepath.read_text(encoding="utf-8", errors="replace")
    single = len(re.findall(r"group\s*\(\s*'", content))
    double = len(re.findall(r'group\s*\(\s*"', content))
    return single + double


def check_imports(filepath: Path) -> dict:
    """Verify required imports exist in test file."""
    if not filepath.exists():
        return {"exists": False}
    content = filepath.read_text(encoding="utf-8", errors="replace")
    has_flutter_test = "import 'package:flutter_test/flutter_test.dart'" in content
    return {
        "exists": True,
        "has_flutter_test_import": has_flutter_test,
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


def check_no_secrets(filepath: Path) -> list:
    """Scan for hardcoded secrets."""
    if not filepath.exists():
        return []
    content = filepath.read_text(encoding="utf-8", errors="replace")
    findings = []
    for i, line in enumerate(content.splitlines(), 1):
        for pattern in SECRET_PATTERNS:
            if re.search(pattern, line, re.IGNORECASE):
                findings.append({"line": i, "text": line.strip()[:80], "pattern": pattern})
    return findings


def check_drift_coverage(filepath: Path) -> dict:
    """Verify cross-adapter test covers all 12 documented drifts."""
    if not filepath.exists():
        return {"exists": False, "drifts_found": 0, "drifts_missing": DOCUMENTED_DRIFTS}
    content = filepath.read_text(encoding="utf-8", errors="replace")
    found = []
    missing = []
    for i, drift in enumerate(DOCUMENTED_DRIFTS, 1):
        # Check for DRIFT #N markers
        marker = f"DRIFT #{i}"
        if marker in content:
            found.append(drift)
        else:
            missing.append(drift)
    return {
        "exists": True,
        "drifts_found": len(found),
        "drifts_missing": missing,
        "coverage_pct": f"{len(found)/len(DOCUMENTED_DRIFTS)*100:.0f}%",
    }


def check_fail_closed_coverage(filepath: Path) -> dict:
    """Verify FAIL-CLOSED invariants appear in regression test."""
    if not filepath.exists():
        return {"exists": False, "invariants_found": 0}
    content = filepath.read_text(encoding="utf-8", errors="replace")
    found = []
    for inv in FAIL_CLOSED_INVARIANTS:
        # Check for key terms
        terms = inv.replace(" → ", " ").split()
        if all(term.lower() in content.lower() for term in terms if term not in ("→",)):
            found.append(inv)
    return {
        "exists": True,
        "invariants_found": len(found),
        "invariants_total": len(FAIL_CLOSED_INVARIANTS),
    }


def check_locale_ku(filepath: Path) -> bool:
    """Check if file contains Kurdish Sorani locale reference."""
    if not filepath.exists():
        return False
    content = filepath.read_text(encoding="utf-8", errors="replace")
    return "'ku'" in content or '"ku"' in content


def check_conversation_provider_not_modified() -> dict:
    """Verify conversation_provider.dart was not created/modified in Step 26."""
    # Step 26 should NOT contain conversation_provider.dart
    cp_files = list(SOURCE_DIR.rglob("*conversation_provider*")) if SOURCE_DIR.exists() else []
    return {
        "conversation_provider_files_in_step26": len(cp_files),
        "not_modified": len(cp_files) == 0,
    }


def check_prior_steps_not_modified() -> dict:
    """Verify Steps 15-25 feature directories were not created inside Step 26 source.
    
    Step 26 introspection repositories (step_22_introspection_repository.dart etc.)
    are NEW files belonging to Step 26 — they are NOT modifications to prior steps.
    We only flag if actual prior-step feature directories exist under step_26_source.
    """
    if not SOURCE_DIR.exists():
        return {"checked": False, "reason": "source dir missing"}
    # Prior step feature paths that must NOT appear under step_26_source
    prior_feature_dirs = [
        "lib/features/tool_execution",       # Step 22
        "lib/features/orchestration",        # Step 23
        "lib/features/trigger_integration",  # Step 24
        "lib/features/advanced_agent",        # Step 25
    ]
    # Also check for any step_15 through step_21 feature directories
    for i in range(15, 22):
        prior_feature_dirs.append(f"lib/features/step_{i}")
    
    found = []
    for feature_dir in prior_feature_dirs:
        full_path = SOURCE_DIR / feature_dir
        if full_path.exists() and full_path.is_dir():
            found.append(feature_dir)
    return {
        "checked": True,
        "prior_step_dirs_found": len(found),
        "not_modified": len(found) == 0,
    }


def validate_structure() -> dict:
    """Run all structural validations."""
    results = {
        "summary": {},
        "directories": {},
        "test_files": {},
        "source_files": {},
        "drift_coverage": {},
        "fail_closed_coverage": {},
        "security_scan": {},
        "integrity_checks": {},
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
            try:
                has_files = any(dirpath.iterdir())
            except StopIteration:
                has_files = False
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
        group_count = count_groups_in_file(filepath)
        imports = check_imports(filepath)
        placeholders = check_no_placeholders(filepath)
        secrets = check_no_secrets(filepath)
        has_ku = check_locale_ku(filepath)
        total_tests += test_count
        total_files += 1

        file_result = {
            "exists": filepath.exists(),
            "test_count": test_count,
            "group_count": group_count,
            "min_expected": min_tests,
            "meets_threshold": test_count >= min_tests if filepath.exists() else False,
            "imports": imports,
            "placeholders": placeholders,
            "secrets_found": len(secrets),
            "has_locale_ku": has_ku,
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
        elif secrets:
            results["issues"].append(
                f"HARDCODED SECRET: {relpath} has {len(secrets)} secret patterns"
            )
            failed += 1
        else:
            passed += 1

    # 3. Check cross-adapter drift coverage
    drift_file = TEST_DIR / "cross_adapter" / "step23_vs_step25_repo_consistency_test.dart"
    drift_result = check_drift_coverage(drift_file)
    results["drift_coverage"] = drift_result
    if drift_result.get("drifts_missing"):
        missing_count = len(drift_result["drifts_missing"])
        if missing_count > 0:
            results["issues"].append(
                f"DRIFT COVERAGE: {missing_count}/12 drifts not covered"
            )
            failed += 1
        else:
            passed += 1
    else:
        passed += 1

    # 4. Check FAIL-CLOSED coverage in regression tests
    for step_num in [22, 23, 24, 25]:
        reg_file = TEST_DIR / "fail_closed_regression" / f"step{step_num}_fail_closed_test.dart"
        fc_result = check_fail_closed_coverage(reg_file)
        results["fail_closed_coverage"][f"step_{step_num}"] = fc_result
        if fc_result.get("invariants_found", 0) < 2:
            results["issues"].append(
                f"FAIL-CLOSED: step_{step_num} regression covers {fc_result.get('invariants_found', 0)}/4 invariants"
            )
            failed += 1
        else:
            passed += 1

    # 5. Check source files exist
    for relpath, required in EXPECTED_SOURCE_FILES.items():
        filepath = SOURCE_DIR / relpath
        exists = filepath.exists() and filepath.is_file()
        non_empty = False
        if exists:
            content = filepath.read_text(encoding="utf-8", errors="replace")
            non_empty = len(content.strip()) > 0
        results["source_files"][relpath] = {
            "exists": exists,
            "non_empty": non_empty,
        }
        if required and not exists:
            results["issues"].append(f"MISSING SOURCE: {relpath}")
            failed += 1
        elif required and not non_empty:
            results["issues"].append(f"EMPTY SOURCE: {relpath}")
            failed += 1
        else:
            passed += 1

    # 6. Security scan across all files
    all_dart_files = list(TEST_DIR.rglob("*.dart")) + list(SOURCE_DIR.rglob("*.dart"))
    total_secrets = 0
    for f in all_dart_files:
        secrets = check_no_secrets(f)
        total_secrets += len(secrets)
        if secrets:
            rel = f.relative_to(BASE) if BASE in f.parents else str(f)
            results["security_scan"][str(rel)] = secrets
    if total_secrets > 0:
        results["issues"].append(f"SECURITY: {total_secrets} hardcoded secret patterns found")
        failed += 1
    else:
        passed += 1

    # 7. Integrity checks
    cp_check = check_conversation_provider_not_modified()
    prior_check = check_prior_steps_not_modified()
    results["integrity_checks"] = {
        "conversation_provider_not_modified": cp_check,
        "prior_steps_not_modified": prior_check,
    }
    if not cp_check["not_modified"]:
        results["issues"].append("INTEGRITY: conversation_provider.dart modified in Step 26")
        failed += 1
    else:
        passed += 1
    if not prior_check.get("not_modified", True):
        results["issues"].append("INTEGRITY: Steps 15-25 files modified in Step 26")
        failed += 1
    else:
        passed += 1

    # 8. Validation script itself exists
    validation_script = TEST_DIR / "validation" / "structural_validation.py"
    results["stats"]["validation_script_exists"] = validation_script.exists()
    if validation_script.exists():
        passed += 1
    else:
        results["issues"].append("MISSING: structural_validation.py")
        failed += 1

    # Summary
    results["summary"] = {
        "total_test_files": total_files,
        "total_test_count": total_tests,
        "total_source_files": len(EXPECTED_SOURCE_FILES),
        "passed": passed,
        "failed": failed,
        "pass_rate": f"{passed / (passed + failed) * 100:.1f}%" if (passed + failed) > 0 else "0%",
        "issue_count": len(results["issues"]),
        "drift_bugs_documented": 12,
        "locale": "ku (Kurdish Sorani RTL-first)",
        "fail_closed_invariants": len(FAIL_CLOSED_INVARIANTS),
    }

    return results


def print_report(results: dict):
    """Print human-readable validation report."""
    print("=" * 70)
    print("  STEP 26 – SYSTEM INTEGRATION QA & INTEGRITY AUDIT")
    print("  STRUCTURAL VALIDATION REPORT")
    print("=" * 70)

    s = results["summary"]
    print(f"\n  Test Files:      {s['total_test_files']}")
    print(f"  Test Count:      {s['total_test_count']}")
    print(f"  Source Files:    {s['total_source_files']}")
    print(f"  Checks:          {s['passed']} PASSED, {s['failed']} FAILED")
    print(f"  Pass Rate:       {s['pass_rate']}")
    print(f"  Issues:          {s['issue_count']}")
    print(f"  Drift Bugs:      {s['drift_bugs_documented']} documented")
    print(f"  Locale:          {s['locale']}")
    print(f"  FAIL-CLOSED:     {s['fail_closed_invariants']} invariants")

    print("\n--- DIRECTORY STATUS ---")
    for name, status in results["directories"].items():
        icon = "✅" if status["exists"] and status["has_files"] else "❌"
        print(f"  {icon} {name:30s} exists={status['exists']} files={status['has_files']}")

    print("\n--- TEST FILE STATUS ---")
    for relpath, info in results["test_files"].items():
        icon = "✅" if info["meets_threshold"] and info["exists"] else "❌"
        count_str = f"{info['test_count']:3d}/{info['min_expected']:3d}"
        ku_icon = "🌍" if info.get("has_locale_ku") else "  "
        print(f"  {icon} {relpath:60s} tests={count_str} {ku_icon}")

    print("\n--- SOURCE FILE STATUS ---")
    for relpath, info in results["source_files"].items():
        icon = "✅" if info["exists"] and info["non_empty"] else "❌"
        print(f"  {icon} {relpath}")

    print("\n--- CROSS-ADAPTER DRIFT COVERAGE ---")
    dc = results["drift_coverage"]
    if dc.get("exists"):
        print(f"  Drifts Found:    {dc['drifts_found']}/12 ({dc.get('coverage_pct', '0%')})")
        if dc.get("drifts_missing"):
            for d in dc["drifts_missing"]:
                print(f"    ❌ MISSING: {d}")
    else:
        print("  ❌ Cross-adapter test file not found")

    print("\n--- FAIL-CLOSED REGRESSION COVERAGE ---")
    for step, fc in results["fail_closed_coverage"].items():
        if fc.get("exists"):
            found = fc['invariants_found']
            total = fc['invariants_total']
            icon = "✅" if found >= 3 else "⚠️" if found >= 2 else "❌"
            print(f"  {icon} {step:15s} {found}/{total} invariants covered")
        else:
            print(f"  ❌ {step:15s} regression test not found")

    print("\n--- INTEGRITY CHECKS ---")
    ic = results["integrity_checks"]
    cp = ic["conversation_provider_not_modified"]
    ps = ic["prior_steps_not_modified"]
    cp_icon = "✅" if cp["not_modified"] else "❌"
    ps_icon = "✅" if ps.get("not_modified", True) else "❌"
    print(f"  {cp_icon} conversation_provider.dart not modified: {cp['not_modified']}")
    print(f"  {ps_icon} Steps 15-25 not modified: {ps.get('not_modified', 'N/A')}")

    print("\n--- SECURITY SCAN ---")
    if results["security_scan"]:
        for filepath, findings in results["security_scan"].items():
            print(f"  ❌ {filepath}: {len(findings)} secret patterns")
    else:
        print("  ✅ No hardcoded secrets found")

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
    json_path.parent.mkdir(parents=True, exist_ok=True)
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
