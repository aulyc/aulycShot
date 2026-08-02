#!/bin/bash
set -e

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

APP_NAME="aulycShot"
APP_OUTPUT_DIR="${AULYCSHOT_APP_OUTPUT_DIR:-.cache/build}"
if [[ "$APP_OUTPUT_DIR" != /* ]]; then
    APP_OUTPUT_DIR="$PROJECT_ROOT/$APP_OUTPUT_DIR"
fi
APP_BUNDLE="$APP_OUTPUT_DIR/$APP_NAME.app"

echo "==> [1/4] Building $APP_NAME..."
bash scripts/bundle.sh
echo "==> Build succeeded."

echo "==> [2/4] Killing running $APP_NAME..."
if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
    pkill -x "$APP_NAME"
    # Wait for process to exit (up to 5 seconds)
    for i in $(seq 1 50); do
        if ! pgrep -x "$APP_NAME" > /dev/null 2>&1; then
            echo "==> $APP_NAME terminated."
            break
        fi
        sleep 0.1
    done
    # Force kill if still running
    if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
        echo "==> Force killing $APP_NAME..."
        pkill -9 -x "$APP_NAME"
        sleep 0.5
    fi
else
    echo "==> $APP_NAME is not running, skipping kill."
fi

echo "==> [3/4] Launching local development build $APP_BUNDLE..."
open -n "$APP_BUNDLE"

echo "==> [4/4] Waiting for $APP_NAME to start..."
for i in $(seq 1 50); do
    PID="$(pgrep -x "$APP_NAME" | head -1 || true)"
    if [ -n "$PID" ]; then
        COMMAND="$(ps -p "$PID" -o command=)"
        if [ "$COMMAND" != "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]; then
            echo "==> ⚠️ Running process is not the local development build: $COMMAND"
            exit 1
        fi
        echo "==> ✅ $APP_NAME local development build is running (PID: $PID)."
        exit 0
    fi
    sleep 0.1
done

echo "==> ⚠️ $APP_NAME did not start within 5 seconds."
exit 1
