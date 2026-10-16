"""Makes the full APK build cache the Git LFS objects (~290 MB of models), so
the GitHub LFS bandwidth quota is only used the first time (or when models
change). Run from the project root:  python3 tools/patch_build_yml.py"""
import sys

P = ".github/workflows/build.yml"
s = open(P, encoding="utf-8").read()
if "Restore LFS cache" in s:
    print("already patched")
    sys.exit(0)
old = """      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          lfs: true
"""
new = """      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          lfs: false

      # The LFS objects (models, ~290 MB) are cached between builds so the
      # GitHub LFS bandwidth quota is only used when the models change.
      - name: Create LFS file list
        run: git lfs ls-files -l | cut -d' ' -f1 | sort > .lfs-assets-id

      - name: Restore LFS cache
        uses: actions/cache@v4
        with:
          path: .git/lfs
          key: lfs-${{ hashFiles('.lfs-assets-id') }}-v1

      - name: Pull LFS objects
        run: git lfs pull
"""
if s.count(old) != 1:
    print("FAIL: checkout block not found exactly once, count =", s.count(old))
    sys.exit(1)
open(P, "w", encoding="utf-8").write(s.replace(old, new))
print("OK")
