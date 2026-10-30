#!/usr/bin/env bash
# Jornada móvel real no emulador/dispositivo contra a CoopVote API real (Compose isolado).
# Pré-requisitos: Flutter + Android SDK, Docker, um dispositivo/emulador em `adb devices`
# (alcança o host em 10.0.2.2) e o repositório coopvote-api ao lado deste.
# Uso: tool/journey/run.sh [device-serial] [dir-evidencias]
set -euo pipefail
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_DIR="${COOPVOTE_API_DIR:-$APP_DIR/../coopvote-api}"
DEVICE="${1:-emulator-5554}"
EVIDENCE="${2:-$APP_DIR/build/journey}"
PROJECT="${COMPOSE_PROJECT:-coopvote-jornada}"
API_PORT="${API_PORT:-18080}"; DB_PORT="${DB_PORT:-15432}"; CONTROL_PORT="${CONTROL_PORT:-18099}"
mkdir -p "$EVIDENCE"

( cd "$API_DIR" && API_PORT=$API_PORT DB_PORT=$DB_PORT AUTH_LOCAL_SEED=true \
    CALLBACK_BASE_URL="http://10.0.2.2:$API_PORT" docker compose -p "$PROJECT" up -d --build --wait )
python3 "$APP_DIR/tool/journey/control_server.py" --api-dir "$API_DIR" --project "$PROJECT" \
  --device "$DEVICE" --evidence "$EVIDENCE" --port "$CONTROL_PORT" --api-port "$API_PORT" --db-port "$DB_PORT" \
  > "$EVIDENCE/control.log" 2>&1 &
CONTROL_PID=$!
trap 'kill $CONTROL_PID 2>/dev/null || true; adb -s "$DEVICE" shell settings put system font_scale 1.0 >/dev/null 2>&1 || true; ( cd "$API_DIR" && docker compose -p "$PROJECT" down -v >/dev/null 2>&1 ) || true' EXIT

( cd "$APP_DIR" && flutter test integration_test/journey_test.dart -d "$DEVICE" \
    --dart-define=COOPVOTE_ENTRY_URL="http://10.0.2.2:$API_PORT/api/v1/mobile" \
    --dart-define=COOPVOTE_ALLOW_HTTP=true \
    --dart-define=COOPVOTE_CONTROL_URL="http://10.0.2.2:$CONTROL_PORT" ) 2>&1 | tee "$EVIDENCE/journey.log"
