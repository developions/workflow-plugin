#!/usr/bin/env bash
# plugins/workflow/skills/codex-review/run.sh를 가짜 codex로 시험한다. (실제 Codex 사용량을 쓰지 않는다)
# 사용: bash tools/codex-test/test-run.sh
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
run="$root/plugins/workflow/skills/codex-review/run.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/codex-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/repo" "$tmp/t"

# 가짜 codex: FAKE_MODE에 따라 동작한다. -o 다음 인자에 결과를 쓴다.
cat > "$tmp/bin/codex" <<'EOF'
#!/usr/bin/env bash
out=""; model=""; prev=""
for a in "$@"; do
  [ "$prev" = "-o" ] && out=$a
  [ "$prev" = "-m" ] && model=$a
  prev=$a
done
cat > /dev/null   # 표준 입력의 프롬프트를 읽어 버린다
echo "user prompt echo: secret-file-content"   # 원래 출력에 파일 내용이 섞이는 상황
case "$FAKE_MODE" in
  ok)      echo '{"findings":[{"location":"1.1","problem":"p","evidence":"e","severity":"중간","action":"사용자에게 물을 것"},{"location":"DoD-1","problem":"p","evidence":"e","severity":"낮음","action":"묻지 않고 고침"}]}' > "$out" ;;
  empty)   : > "$out" ;;
  nofind)  echo '{"other":[]}' > "$out" ;;
  slow)    sleep 5 ;;
  autherr) echo "ERROR: 401 Unauthorized" >&2; exit 1 ;;
  limit)   echo "ERROR: You've hit your usage limit. Upgrade to Pro (https://chatgpt.com/explore/pro), visit https://chatgpt.com/settings/usage to purchase more credits or try again at Nov 27th, 2026 3:04 AM." >&2; exit 1 ;;
  model)   if [ -n "$model" ]; then echo "ERROR: The '$model' model is not supported when using Codex with a ChatGPT account." >&2; exit 1; fi
           echo '{"findings":[]}' > "$out" ;;
esac
EOF
chmod +x "$tmp/bin/codex"

pass=0; fail=0
ok()  { pass=$((pass+1)); echo "PASS $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1"; }
check() { # 이름, 기대 종료 코드, 기대 출력 정규식 (실제 값은 $rc, $out)
  if [ "$rc" = "$2" ] && [[ "$out" =~ $3 ]]; then ok "$1"; else bad "$1 — 종료 $rc (기대 $2), 출력: $out"; fi
}
# run.sh의 임시 폴더는 $tmp/t 아래에 만들게 해 남는지 센다. (끝나면 trap이 함께 지운다)
go() { # 모드, 추가 환경 변수...
  local mode=$1; shift
  rm -rf "$tmp/t"/workflow-codex.*
  out=$(env FAKE_MODE="$mode" TMPDIR="$tmp/t" PATH="$tmp/bin:/usr/bin:/bin" "$@" bash "$run" "$tmp/repo" "ai-work/plans/x.md" 2>&1); rc=$?
}
left() { ls -d "$tmp/t"/workflow-codex.* 2>/dev/null | wc -l | tr -d ' '; }
gone() { [ "$(left)" = 0 ] && ok "$1: 임시 폴더 지움" || bad "$1: 임시 폴더가 남음"; }

go ok; check "성공" 0 '^OK .+findings\.json 2 [0-9]+$'
json=$(echo "$out" | awk '{print $2}')
[ -s "$json" ] && grep -q '"findings"' "$json" && ok "결과 JSON 남음" || bad "결과 JSON 없음"
[ ! -e "$(dirname "$json")/codex.log" ] && ok "성공 시 로그 삭제" || bad "성공 시 로그가 남음"
[[ "$out" != *secret-file-content* ]] && ok "원래 출력이 새지 않음" || bad "원래 출력이 새어 나옴"

go empty;   check "빈 출력" 13 '^FAIL [0-9]+ 응답 형식 오류'; gone "빈 출력"
go nofind;  check "findings 없음" 13 '^FAIL [0-9]+ 응답 형식 오류'
go autherr; check "인증 실패" 1 '^FAIL [0-9]+ codex 실행 실패\(종료 코드 1: 401 Unauthorized\)$'; gone "인증 실패"
go limit;   check "사용량 한도 → 짧은 사유" 1 '^FAIL [0-9]+ 사용량 한도 \(다시 가능: Nov 27th, 2026 3:04 AM\)$'
[[ "$out" != *http* ]] && ok "사유에 URL 없음" || bad "사유에 URL이 남음: $out"
go slow WORKFLOW_CODEX_TIMEOUT=1; check "시간 초과" 12 '^FAIL [0-9]+ 시간 초과\(1초\)$'; gone "시간 초과"
go model;   check "모델 사용 불가 → 기본 모델로 재실행" 0 '^OK .+ 0 [0-9]+$'
go ok WORKFLOW_CODEX_MODEL=; check "모델 빈 값" 0 '^OK '

if PATH="/usr/bin:/bin" command -v codex >/dev/null 2>&1; then
  echo "SKIP 미설치 시험 (/usr/bin에 codex가 있음)"
else
  out=$(env TMPDIR="$tmp/t" PATH="/usr/bin:/bin" bash "$run" "$tmp/repo" "x.md" 2>&1); rc=$?
  check "codex 미설치" 10 '^SKIP codex 명령 없음'
fi
out=$(env PATH="$tmp/bin:/usr/bin:/bin" bash "$run" 2>&1); rc=$?; check "인자 없음" 1 '^FAIL 0 인자 부족'

echo "통과 $pass, 실패 $fail"
[ $fail -eq 0 ]
