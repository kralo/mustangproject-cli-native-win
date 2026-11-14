#!/bin/bash
# Calls every Mustang-CLI action once. Used for the native-image agent run and
# as a smoke test of the native binary.
# Set OUTLOG_DIR to the directory for logs and generated output, e.g.
#   OUTLOG_DIR=/x/logs CMD="java -agentlib:native-image-agent=config-merge-dir=/x/mynative-image -jar /x/Mustang-CLI.jar" ./runAllCliOpts.sh
#   OUTLOG_DIR=/x/logs CMD="/x/Mustang-CLI" ./runAllCliOpts.sh
# Exit code: 0 if all actions passed, 1 if any failed, 2 on setup errors.
set -Euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RES="${RES:-$ROOT/consolidated_resources/}"
VALIDATE_DIR="${VALIDATE_DIR:-$RES}"
OUTLOG_DIR="${OUTLOG_DIR:-$ROOT/logs}"
OUT="$OUTLOG_DIR/all-actions-out"
LOG="${LOG:-$OUTLOG_DIR/all-actions.log}"
CMD="${CMD:-$ROOT/Mustang-CLI/target/Mustang-CLI}"

# collect from different subdirs
mkdir -p $ROOT/consolidated_resources/
cp -r $ROOT/Mustang-CLI/src/test/resources/. $ROOT/consolidated_resources/cli/
cp -r $ROOT/library/src/test/resources/. $ROOT/consolidated_resources/library/
cp -r $ROOT/validator/src/test/resources/.  $ROOT/consolidated_resources/valid/

rm -rf "$OUT"; mkdir -p "$OUT" "$OUTLOG_DIR"
: > "$LOG"

# ---- input discovery ----
first() { sort | head -n1; }
PDF="$(find "$RES" -type f -iname '*.pdf' | grep -Ei 'zugferd|factur|ZF' | first || true)"
PDF="$(find "$RES" -type f -iname '*8_01_Physiotherapeut_fx.pdf' | grep -Ei 'zugferd|factur|ZF' | first || true)"
[[ -n "$PDF" ]] || PDF="$(find "$RES" -type f -iname '*.pdf' | first || true)"

CII="$(grep -rl --include='*.xml' 'CrossIndustryInvoice' "$RES" 2>/dev/null | first || true)"
#CII="$(grep -rl --include='*.xml' 'CrossIndustryInvoice' "$RES" 2>/dev/null | first || true)"
CII="$(find "$RES" -type f -iname '*23_01_Sachversicherung_berechneter_Steuersatz.xml' | first || true)"

CII1="$(grep -rl --include='*.xml' 'CrossIndustryDocument' "$RES" 2>/dev/null | first || true)"
[[ -n "$CII1" ]] || CII1="$CII"

if [[ -z "$PDF" || -z "$CII" ]]; then
    echo "ERROR: no PDF or CII XML found under $RES" >&2
    exit 2
fi
echo "PDF=$PDF"; echo "CII=$CII"; echo "CII v1=$CII1"
echo "CMD=$CMD"; echo "Log: $LOG"
echo "Output directory: $OUT"

PASS=0; FAIL=0; FAILED=()

# run <name> <stdin file or -> <accepted exit codes> <args...>
run() {
    local name="$1" stdin="$2" accepted="$3"; shift 3
    local start=$SECONDS rc
    [[ "$stdin" == "-" ]] && stdin=/dev/null
    echo "=== $name: $*" | tee -a "$LOG"
    # unquoted on purpose: CMD may contain "java -agentlib:... -jar x.jar"
    $CMD "$@" < "$stdin" >> "$LOG" 2>&1
    rc=$?
    if [[ " $accepted " == *" $rc "* ]]; then
        echo "    OK   (exit $rc, $((SECONDS - start))s)" | tee -a "$LOG"
        PASS=$((PASS + 1))
    else
        echo "    FAIL (exit $rc, $((SECONDS - start))s)" | tee -a "$LOG"
        FAIL=$((FAIL + 1)); FAILED+=("$name")
    fi
}

# stdin for "metrics -l": file list, then a blank line starts processing
LIST="$OUT/filelist.txt"
printf '%s\n\n' "$PDF" > "$LIST"

# ---- info ----
run help      - "0 1 2" --help
run license   - "0 2"   --action license

# ---- metrics ----
run metrics-dir      - "0 2"   --action metrics -d "$RES" --disable-file-logging
run metrics-dir-all  - "0 2"   --action metrics -d "$RES" -i --disable-file-logging
run metrics-stdin    "$LIST" "0 2" --action metrics -l --disable-file-logging

# ---- validate ----
run validate-pdf       - "0 2" --action validate --source "$PDF"
run validate-xml       - "0 2" --action validate --source "$CII"
run validate-opts      - "0 2" --action validate --source "$CII" --no-notices --no-arithmetic-check --fail-on-warnings --logAppend "smoke"
run validate-log-pdf   - "0 2" --action validate --source "$PDF" --log-as-pdf

#run validateExpValid   - "0 2" --action validateExpectValid -d "$VALIDATE_DIR/ZF252_Beispiele/3. EN16931/" --no-notices --fail-on-warnings
run validateExpValid   - "0 2" --action validateExpectValid -d "$VALIDATE_DIR" --no-notices --fail-on-warnings
#run validateExpInvalid - "0 2" --action validateExpectInvalid -d "$VALIDATE_DIR" --no-notices --fail-on-warnings

# ---- extract / a3only ----
run extract - "0 2" --action extract --source "$PDF" --out "$OUT/extracted.xml"
run a3only  - "0 2" --action a3only  --source "$PDF" --out "$OUT/a3only.pdf"

# ---- combine (all params given, so it never prompts) ----
run combine-zf2 - "0 2" --action combine --source "$PDF" --source-xml "$CII" \
    --format zf --version 2 --profile EN16931 --out "$OUT/combine-zf2.pdf" \
    --attachments "" --no-additional-attachments
run combine-fx  - "0 2" --action combine --source "$PDF" --source-xml "$CII" \
    --format fx --version 2 --profile EN16931 --out "$OUT/combine-fx.pdf" \
    --attachments "" --no-additional-attachments -i
run combine-zf1 - "0 2" --action combine --source "$PDF" --source-xml "$CII1" \
    --format zf --version 1 --profile COMFORT --out "$OUT/combine-zf1.pdf" \
    --attachments "" --no-additional-attachments -i

# ---- convert ----
run ubl         - "0 2" --action ubl --source "$CII" --out "$OUT/ubl.xml"
run ubl-ids     - "0 2" --action ubl --source "$CII" --out "$OUT/ubl-ids.xml" \
    --profileID 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0' \
    --customizationID 'urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0'
run upgrade     - "0 2" --action upgrade --source "$CII1" --out "$OUT/upgraded.xml"
for lang in en fr de; do
    run "visualize-$lang" - "0 2" --action visualize --language "$lang" --source "$CII" --out "$OUT/visualized-$lang.html"
done
run pdf         - "0 2" --action pdf --source "$CII" --out "$OUT/from-xml.pdf"

echo | tee -a "$LOG"
echo "Passed: $PASS  Failed: $FAIL" | tee -a "$LOG"
if (( FAIL > 0 )); then
    echo "Failed actions: ${FAILED[*]}" | tee -a "$LOG"
    exit 1
fi
