#!/bin/bash
set -Eeuo pipefail
trap 'echo "Failed at line $LINENO" >&2' ERR

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$ROOT/logs"

# Command-line switches
NO_AGENT_RECOLLECT=false

for arg in "$@"; do
    case "$arg" in
        no_agent_recollect|--no-agent-recollect)
            NO_AGENT_RECOLLECT=true
            ;;
        *)
            echo "ERROR: Unknown argument: $arg" >&2
            echo "Usage: $0 [no_agent_recollect|--no-agent-recollect]" >&2
            exit 1
            ;;
    esac
done

# Detect Windows (Git Bash / MSYS2 / Cygwin)
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        IS_WINDOWS=true
        NATIVE_IMAGE="native-image.cmd"
        ;;
    *)
        IS_WINDOWS=false
        NATIVE_IMAGE="native-image"
        ;;
esac

echo "Platform: $(uname -s)"
echo "Native Image executable: $NATIVE_IMAGE"
echo "Agent recollection: $([[ "$NO_AGENT_RECOLLECT" == true ]] && echo disabled || echo enabled)"

cd "$ROOT"

if [[ "$IS_WINDOWS" == true ]]; then
    echo "Building with Windows Maven configuration..."
    mvn -Dmaven.repo.local='D:\MavenCache\repository' \
        -Dmaven.test.skip=true \
        -Dcheckstyle.skip \
        package
else
    echo "Building with default Maven configuration..."
    mvn clean package -DskipTests
fi

cd "$ROOT/Mustang-CLI/target"

JAR=$(ls Mustang-CLI-*.jar 2>/dev/null \
      | grep -Ev 'sources|javadoc|original' | head -n1 || true)

[[ -n "$JAR" ]] || {
    echo "ERROR: Mustang CLI JAR not found" >&2
    exit 1
}

# --------------------------------------------------
# Native Image agent configuration collection
# --------------------------------------------------

if [[ "$NO_AGENT_RECOLLECT" == false ]]; then

    echo "Collecting Native Image agent configuration..."

    set +e
    CMD="java -agentlib:native-image-agent=config-merge-dir=$ROOT/mynative-image -jar $JAR" \
        "$ROOT/runAllCliOpts.sh"
    RUN_EXIT=$?
    set -e

    case $RUN_EXIT in
        0) echo "All CLI actions passed" ;;
        1) echo "WARNING: some CLI actions failed (see $ROOT/logs/all-actions.log), continuing" >&2 ;;
        *) echo "ERROR: runAllCliOpts.sh setup failed (exit $RUN_EXIT)" >&2; exit 1 ;;
    esac

else
    echo "Skipping Native Image agent configuration collection."
fi

# --------------------------------------------------
# Native Image compilation
# --------------------------------------------------

START=$(date +%s)

# Create Native Image argument file
NATIVE_ARGS="$ROOT/native-image.args"

cat > "$NATIVE_ARGS" <<'EOF'
--add-modules=java.xml
-H:+UnlockExperimentalVMOptions
-H:IncludeResources=.*\.(xsd|xml|xsl|xslt)$
-H:+ReportExceptionStackTraces
-H:ConfigurationFileDirectories=../../mynative-image
-H:+AddAllCharsets
--no-fallback
-O3
-H:Name=Mustang-CLI
EOF

if [[ "$IS_WINDOWS" == true ]]; then
    echo "Building Windows native executable..."

    MSYS_NO_PATHCONV=1 \
    MSYS2_ARG_CONV_EXCL='*' \
    "$NATIVE_IMAGE" @"$(cygpath -w "$NATIVE_ARGS")" \
        -jar "$(basename "$JAR")"
else
    echo "Building Linux native executable..."

    "$NATIVE_IMAGE" @"$NATIVE_ARGS" \
        -jar "$(basename "$JAR")"
fi

END=$(date +%s)
ELAPSED=$((END - START))

printf 'native-image took %dm %02ds\n' \
    $((ELAPSED / 60)) $((ELAPSED % 60)) \
    | tee -a "$ROOT/logs/build-time.log"

# --------------------------------------------------
# Execute native CLI
# --------------------------------------------------

cd "$ROOT"
if [[ "$IS_WINDOWS" == true ]]; then
    NATIVE_EXECUTABLE=$(find "$ROOT/Mustang-CLI/target" \
        -maxdepth 1 -type f -iname 'Mustang-CL*.exe' | head -n1)

    [[ -n "$NATIVE_EXECUTABLE" ]] || {
        echo "ERROR: Native Windows executable not found" >&2
        exit 1
    }
else
    NATIVE_EXECUTABLE="$ROOT/Mustang-CLI/target/Mustang-CLI"

    [[ -f "$NATIVE_EXECUTABLE" ]] || {
        echo "ERROR: Native executable not found: $NATIVE_EXECUTABLE" >&2
        exit 1
    }
fi

echo "Running native executable: $NATIVE_EXECUTABLE"

set +e
OUTLOG_DIR="logscli/" \
CMD="$NATIVE_EXECUTABLE" \
    "$ROOT/runAllCliOpts.sh"
set -e

printf 'whole script took %s seconds\n' "$SECONDS" \
    | tee -a "$ROOT/logs/build-time.log"

# Takes ~8 minutes total on c5ad.2xlarge
