#!/usr/bin/env bash
# validate-howto.sh — post-generation quality check for a Reltio HOWTO
#
# Usage:
#   bash scripts/validate-howto.sh howtos/HOWTO-[slug].md
#
# Checks (mirrors the 16-point validation checklist in STRUCTURE-GUIDE.md):
#   1.  Title starts with "# HOWTO: "
#   2.  ## Overview section present
#   3.  ## Contents section present
#   4.  ## N. Glossary section present (last numbered section)
#   5.  Exactly one "---" before the Disclaimer (not between every section)
#   6.  Disclaimer footer present with timestamp + topic count
#   7.  Zero occurrences of "Reltio Data Cloud" or "Reltio Connected Cloud"
#   8.  flowchart direction is LR, never TD (if Mermaid present)
#   9.  No empty link targets: [text]() or [text](#TODO)
#   10. No #TODO or #tbd anchors
#   11. HTML file exists
#
# Exit code 0 = all checks pass; non-zero = failures found.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="${1:-}"

if [[ -z "$FILE" ]]; then
  echo "Usage: bash scripts/validate-howto.sh howtos/HOWTO-[slug].md" >&2
  exit 1
fi

if [[ ! -f "$REPO_ROOT/$FILE" ]]; then
  echo "ERROR: File not found: $REPO_ROOT/$FILE" >&2
  exit 1
fi

MD="$REPO_ROOT/$FILE"
SLUG=$(basename "$FILE" .md)
HTML="$REPO_ROOT/howtos-html/${SLUG}.html"
PASS=0
FAIL=0

check() {
  local label="$1" result="$2" hint="$3"
  if [[ "$result" == "ok" ]]; then
    printf "  ✅  %s\n" "$label"
    ((PASS++)) || true
  else
    printf "  ❌  %s — %s\n" "$label" "$hint"
    ((FAIL++)) || true
  fi
}

echo ""
echo "Validating: $FILE"
echo "────────────────────────────────────────────"

# 1. Title
grep -q "^# HOWTO: " "$MD" \
  && check "Title starts with '# HOWTO: '" "ok" "" \
  || check "Title starts with '# HOWTO: '" "fail" "First line must be '# HOWTO: [verb phrase]'"

# 2. Overview
grep -q "^## Overview" "$MD" \
  && check "## Overview section present" "ok" "" \
  || check "## Overview section present" "fail" "Missing '## Overview' section"

# 3. Contents
grep -q "^## Contents" "$MD" \
  && check "## Contents section present" "ok" "" \
  || check "## Contents section present" "fail" "Missing '## Contents' section"

# 4. Glossary (last numbered section)
grep -q "^## [0-9]*\. Glossary" "$MD" \
  && check "## N. Glossary section present" "ok" "" \
  || check "## N. Glossary section present" "fail" "Missing '## N. Glossary' as the last numbered section"

# 5. Single --- before Disclaimer only
RULE_COUNT=$(grep -c "^---$" "$MD" || true)
if [[ "$RULE_COUNT" -eq 1 ]]; then
  check "Exactly one '---' horizontal rule" "ok" ""
else
  check "Exactly one '---' horizontal rule" "fail" "Found ${RULE_COUNT} '---' lines; should be exactly 1 (before Disclaimer)"
fi

# 6. Disclaimer footer
grep -q "AI-generated from the Reltio documentation snapshot" "$MD" \
  && check "Disclaimer footer present" "ok" "" \
  || check "Disclaimer footer present" "fail" "Missing AI-generated disclaimer footer"

# 7. Brand name violations
if grep -qiE "Reltio Data Cloud|Reltio Connected Cloud" "$MD"; then
  VIOLATIONS=$(grep -icE "Reltio Data Cloud|Reltio Connected Cloud" "$MD" || true)
  check "No deprecated brand names" "fail" "Found ${VIOLATIONS} occurrence(s) of 'Reltio Data Cloud'/'Reltio Connected Cloud' — replace with 'Reltio Context Intelligence Platform'"
else
  check "No deprecated brand names" "ok" ""
fi

# 8. Mermaid flowchart direction
if grep -q "flowchart" "$MD"; then
  if grep -q "flowchart TD" "$MD"; then
    check "Mermaid uses flowchart LR (not TD)" "fail" "Change 'flowchart TD' to 'flowchart LR'"
  else
    check "Mermaid uses flowchart LR (not TD)" "ok" ""
  fi
else
  check "Mermaid direction (no diagram — skipped)" "ok" ""
fi

# 9 & 10. Empty/TODO links
if grep -qE '\]\(\)|#TODO|#tbd' "$MD"; then
  BAD=$(grep -cE '\]\(\)|#TODO|#tbd' "$MD" || true)
  check "No empty or #TODO link targets" "fail" "Found ${BAD} empty/TODO link(s) — fill or remove"
else
  check "No empty or #TODO link targets" "ok" ""
fi

# 11. HTML file exists
[[ -f "$HTML" ]] \
  && check "HTML file exists: howtos-html/${SLUG}.html" "ok" "" \
  || check "HTML file exists: howtos-html/${SLUG}.html" "fail" "Run: node generate-html.js $FILE"

echo "────────────────────────────────────────────"
echo "  Passed: ${PASS}   Failed: ${FAIL}"
echo ""

[[ "$FAIL" -eq 0 ]] && echo "✅  All checks passed." && exit 0
echo "❌  ${FAIL} check(s) failed. Fix the issues above before committing." && exit 1
