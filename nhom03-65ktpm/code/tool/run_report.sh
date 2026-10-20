#!/usr/bin/env bash
# Chạy kiểm tra + build + triển khai và in báo cáo ra console.
# Dùng: ./tool/run_report.sh [--build] [--deploy]
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR" || exit 1

DEVICE="${DEVICE:-192.168.240.112:5555}"
APP_ID="com.example.code"
MAIN_ACTIVITY=".MainActivity"

DO_BUILD=0
DO_DEPLOY=0
case "${1:-}" in
  --build)
    DO_BUILD=1
    ;;
  --deploy)
    DO_BUILD=1
    DO_DEPLOY=1
    ;;
  --help | -h)
    echo "Dùng: $0 [--build] [--deploy]"
    exit 0
    ;;
esac

REPORT_DIR="$PROJECT_DIR/.run_reports"
mkdir -p "$REPORT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_LOG="$REPORT_DIR/run-$STAMP.log"
: >"$REPORT_LOG"

FAIL=0
OK_MARK="[ OK ]"
FAIL_MARK="[FAIL]"
SKIP_MARK="[ -- ]"

# Thông tin Git
BRANCH="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')"
COMMIT="$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo '-')"

# Thiết bị
DEVICE_STATE="$(adb -s "$DEVICE" get-state 2>/dev/null || echo offline)"
DEVICE_MODEL="-"
if [ "$DEVICE_STATE" = "device" ]; then
  DEVICE_MODEL="$(adb -s "$DEVICE" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
fi

ANALYZE_STATUS="$SKIP_MARK"
ANALYZE_DETAIL=""
TEST_STATUS="$SKIP_MARK"
TEST_DETAIL=""
BUILD_STATUS="$SKIP_MARK"
BUILD_DETAIL=""
DEPLOY_STATUS="$SKIP_MARK"
DEPLOY_DETAIL=""

# ---------- flutter analyze ----------
AN_LOG="$REPORT_DIR/analyze-$STAMP.log"
echo "=== flutter analyze ===" >>"$REPORT_LOG"
flutter analyze >"$AN_LOG" 2>&1
AN_EXIT=$?
cat "$AN_LOG" >>"$REPORT_LOG"
ERRORS="$(grep -c "error •" "$AN_LOG" 2>/dev/null || true)"
WARNINGS="$(grep -c "warning •" "$AN_LOG" 2>/dev/null || true)"
INFOS="$(grep -c "info •" "$AN_LOG" 2>/dev/null || true)"
ERRORS="${ERRORS:-0}"
WARNINGS="${WARNINGS:-0}"
INFOS="${INFOS:-0}"
# flutter analyze trả mã khác 0 khi có cả warning/info; chỉ coi là lỗi khi có error.
if [ "$ERRORS" -gt 0 ]; then
  ANALYZE_STATUS="$FAIL_MARK"
  ANALYZE_DETAIL="$ERRORS lỗi, $WARNINGS cảnh báo, $INFOS info"
  FAIL=1
else
  ANALYZE_STATUS="$OK_MARK"
  ANALYZE_DETAIL="$ERRORS lỗi, $WARNINGS cảnh báo, $INFOS info"
fi

# ---------- flutter test ----------
TEST_LOG="$REPORT_DIR/test-$STAMP.log"
echo "=== flutter test ===" >>"$REPORT_LOG"
flutter test >"$TEST_LOG" 2>&1
TEST_EXIT=$?
cat "$TEST_LOG" >>"$REPORT_LOG"
PASSED="$(grep -oE '\+[0-9]+' "$TEST_LOG" | tail -1 | tr -d '+')"
if [ "$TEST_EXIT" -eq 0 ]; then
  TEST_STATUS="$OK_MARK"
  TEST_DETAIL="${PASSED:-?} test pass"
else
  TEST_STATUS="$FAIL_MARK"
  TEST_DETAIL="có test thất bại"
  FAIL=1
fi

# ---------- flutter build ----------
APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
if [ "$DO_BUILD" -eq 1 ]; then
  BUILD_LOG="$REPORT_DIR/build-$STAMP.log"
  echo "=== flutter build apk --debug ===" >>"$REPORT_LOG"
  flutter build apk --debug >"$BUILD_LOG" 2>&1
  BUILD_EXIT=$?
  cat "$BUILD_LOG" >>"$REPORT_LOG"
  if [ "$BUILD_EXIT" -eq 0 ] && [ -f "$APK" ]; then
    BUILD_STATUS="$OK_MARK"
    BUILD_DETAIL="app-debug.apk ($(du -h "$APK" | cut -f1))"
  else
    BUILD_STATUS="$FAIL_MARK"
    BUILD_DETAIL="build thất bại"
    FAIL=1
  fi
fi

# ---------- deploy lên thiết bị ----------
if [ "$DO_DEPLOY" -eq 1 ]; then
  DEPLOY_LOG="$REPORT_DIR/deploy-$STAMP.log"
  echo "=== deploy $DEVICE ===" >>"$REPORT_LOG"
  if [ "$DEVICE_STATE" != "device" ]; then
    DEPLOY_STATUS="$FAIL_MARK"
    DEPLOY_DETAIL="thiết bị $DEVICE không kết nối"
    FAIL=1
  elif [ ! -f "$APK" ]; then
    DEPLOY_STATUS="$FAIL_MARK"
    DEPLOY_DETAIL="không tìm thấy APK"
    FAIL=1
  else
    {
      adb -s "$DEVICE" install -r "$APK"
      adb -s "$DEVICE" shell am force-stop "$APP_ID"
      adb -s "$DEVICE" shell am start -n "$APP_ID/$MAIN_ACTIVITY"
    } >"$DEPLOY_LOG" 2>&1
    DEPLOY_EXIT=$?
    cat "$DEPLOY_LOG" >>"$REPORT_LOG"
    sleep 8
    PID="$(adb -s "$DEVICE" shell pidof "$APP_ID" 2>/dev/null | tr -d '\r')"
    if [ "$DEPLOY_EXIT" -eq 0 ] && [ -n "$PID" ]; then
      DEPLOY_STATUS="$OK_MARK"
      DEPLOY_DETAIL="đang chạy (PID $PID)"
    else
      DEPLOY_STATUS="$FAIL_MARK"
      DEPLOY_DETAIL="cài/chạy thất bại"
      FAIL=1
    fi
  fi
fi

# ---------- báo cáo console ----------
LINE="============================================================"
echo "$LINE"
echo " BÁO CÁO CHẠY - $(date '+%d/%m/%Y %H:%M:%S')"
echo "$LINE"
printf " %-10s %s\n" "Nhánh" "$BRANCH ($COMMIT)"
printf " %-10s %s\n" "Thiết bị" "$DEVICE - $DEVICE_MODEL ($DEVICE_STATE)"
echo "------------------------------------------------------------"
printf " %-10s %s %s\n" "Analyze" "$ANALYZE_STATUS" "$ANALYZE_DETAIL"
printf " %-10s %s %s\n" "Test" "$TEST_STATUS" "$TEST_DETAIL"
printf " %-10s %s %s\n" "Build" "$BUILD_STATUS" "$BUILD_DETAIL"
printf " %-10s %s %s\n" "Deploy" "$DEPLOY_STATUS" "$DEPLOY_DETAIL"
echo "------------------------------------------------------------"
echo " Log chi tiết: $REPORT_LOG"
if [ "$FAIL" -eq 0 ]; then
  echo " Kết quả: THÀNH CÔNG"
else
  echo " Kết quả: CÓ LỖI - xem log phía trên"
fi
echo "$LINE"

exit "$FAIL"
