#!/usr/bin/env bash
# Kiểm tra repo có tuân thủ quy định nộp bài hay không.
# Dùng: ./tool/check_submission.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")"
if [ -z "$REPO_DIR" ]; then
  echo "Không tìm thấy git repository."
  exit 1
fi
cd "$REPO_DIR" || exit 1

GROUP="nhom03-65ktpm"
EXPECTED_BRANCH="nhom/$GROUP"

FAIL=0
OK_MARK="[ OK ]"
FAIL_MARK="[FAIL]"

status_branch="$FAIL_MARK"
status_folder="$FAIL_MARK"
status_members="$FAIL_MARK"
status_scope="$OK_MARK"
status_junk="$OK_MARK"
status_size="$OK_MARK"

# 1. Nhánh làm việc
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" = "$EXPECTED_BRANCH" ]; then
  status_branch="$OK_MARK"
else
  FAIL=1
fi

# 2. Thư mục nhóm
if [ -d "$GROUP" ]; then
  status_folder="$OK_MARK"
else
  FAIL=1
fi

# 3. danhsachnhom.md
MEMBERS_NOTE=""
if [ -f "$GROUP/danhsachnhom.md" ]; then
  if grep -q "\[Cập nhật\]" "$GROUP/danhsachnhom.md"; then
    status_members="$FAIL_MARK"
    MEMBERS_NOTE="còn thông tin [Cập nhật]"
    FAIL=1
  else
    status_members="$OK_MARK"
    MEMBERS_NOTE="đã điền đủ thông tin"
  fi
else
  MEMBERS_NOTE="không tìm thấy tệp"
  FAIL=1
fi

# 4. Mọi thay đổi phải nằm trong thư mục nhóm
OUTSIDE=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  path="${line:3}"
  if [[ "$path" == *" -> "* ]]; then
    path="${path##* -> }"
  fi
  if [[ "$path" != "$GROUP/"* ]]; then
    OUTSIDE+=("$path")
  fi
done < <(git status --porcelain)
if [ "${#OUTSIDE[@]}" -gt 0 ]; then
  status_scope="$FAIL_MARK"
  FAIL=1
fi

# 5. Không track file rác / bí mật
JUNK="$(git ls-files | grep -E '(^|/)(build|\.dart_tool|node_modules)/|\.env($|\.)|\.jks$|keystore|(^|/)\.idea/|(^|/)\.vscode/' || true)"
if [ -n "$JUNK" ]; then
  status_junk="$FAIL_MARK"
  FAIL=1
fi

# 6. Không track file > 50MB
LARGE="$(git ls-files -z | while IFS= read -r -d '' f; do
  if [ -f "$f" ] && [ "$(stat -c%s "$f")" -gt 52428800 ]; then echo "$f"; fi
done)"
if [ -n "$LARGE" ]; then
  status_size="$FAIL_MARK"
  FAIL=1
fi

LINE="============================================================"
echo "$LINE"
echo " KIỂM TRA QUY ĐỊNH NỘP BÀI - $(date '+%d/%m/%Y %H:%M:%S')"
echo "$LINE"
echo " Nhánh làm việc   : $status_branch $BRANCH (cần: $EXPECTED_BRANCH)"
echo " Thư mục nhóm     : $status_folder $GROUP/"
echo " danhsachnhom.md  : $status_members $GROUP/danhsachnhom.md ($MEMBERS_NOTE)"
echo " Phạm vi thay đổi : $status_scope ${#OUTSIDE[@]} tệp ngoài thư mục nhóm"
echo " File rác bị track: $status_junk ${JUNK:-không có}"
echo " File > 50MB      : $status_size ${LARGE:-không có}"
echo "------------------------------------------------------------"
if [ "${#OUTSIDE[@]}" -gt 0 ]; then
  echo " Tệp ngoài thư mục nhóm:"
  printf "   - %s\n" "${OUTSIDE[@]}"
  echo "------------------------------------------------------------"
fi
if [ "$FAIL" -eq 0 ]; then
  echo " Kết quả: ĐẠT QUY ĐỊNH"
else
  echo " Kết quả: CHƯA ĐẠT - sửa các mục [FAIL] trước khi commit/push"
fi
echo "$LINE"

exit "$FAIL"
