#!/usr/bin/env bash
# plugins/workflow/skills/codex-review/run.sh를 가짜 codex로 시험한다. (실제 Codex 사용량을 쓰지 않는다)
# 사용: bash tools/codex-test/test-run.sh
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
run="$root/plugins/workflow/skills/codex-review/run.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/codex-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/repo"

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
  model)   if [ -n "$model" ]; then echo "ERROR: The '$model' model is not supported when using Codex with a ChatGPT account." >&2; exit 1; fi
           echo '{"findings":[]}' > "$out" ;;
esac
EOF
chmod +x "$tmp/bin/codex"

pass=0; fail=0
check() { # 이름, 기대 종료 코드, 기대 출력 정규식, 실제 종료 코드, 실제 출력
  if [ "$4" = "$2" ] && [[ "$5" =~ $3 ]]; then pass=$((pass+1)); echo "PASS $1"
  else fail=$((fail+1)); echo "FAIL $1 — 종료 $4 (기대 $2), 출력: $5"; fi
}
go() { # 모드, 추가 환경 변수..., 실행
  local mode=$1; shift
  out=$(env FAKE_MODE="$mode" PATH="$tmp/bin:/usr/bin:/bin" "$@" bash "$run" "$tmp/repo" "ai-work/plans/x.md" 2>&1); rc=$?
  # run.sh가 만든 임시 폴더만 기억해 두었다가 지운다 (OK는 둘째 칸, FAIL은 마지막 칸이 그 안의 파일)
  case "$out" in
    OK*)   made+=("$(dirname "$(echo "$out" | awk '{print $2}')")") ;;
    FAIL*) made+=("$(dirname "$(echo "$out" | awk '{print $NF}')")") ;;
  esac
}
made=()

go ok;      check "성공" 0 '^OK .+findings\.json 2 [0-9]+$' $rc "$out"
json=$(echo "$out" | awk '{print $2}'); [ -s "$json" ] && grep -q '"findings"' "$json" && echo "PASS 결과 JSON 남음" || { echo "FAIL 결과 JSON 없음"; fail=$((fail+1)); }
[ ! -e "$(dirname "$json")/codex.log" ] && echo "PASS 성공 시 로그 삭제" || { echo "FAIL 성공 시 로그가 남음"; fail=$((fail+1)); }
[[ "$out" != *secret-file-content* ]] && echo "PASS 원래 출력이 새지 않음" || { echo "FAIL 원래 출력이 새어 나옴"; fail=$((fail+1)); }
go empty;   check "빈 출력" 13 '^FAIL 응답 형식 오류' $rc "$out"
go nofind;  check "findings 없음" 13 '^FAIL 응답 형식 오류' $rc "$out"
go autherr; check "인증 실패" 1 '^FAIL codex 실행 실패\(종료 코드 1: ERROR: 401' $rc "$out"
go slow WORKFLOW_CODEX_TIMEOUT=1; check "시간 초과" 12 '^FAIL 시간 초과\(1초\)' $rc "$out"
go model;   check "모델 사용 불가 → 기본 모델로 재실행" 0 '^OK .+ 0 [0-9]+$' $rc "$out"
go ok WORKFLOW_CODEX_MODEL=; check "모델 빈 값" 0 '^OK ' $rc "$out"
out=$(env PATH="/usr/bin:/bin" bash "$run" "$tmp/repo" "x.md" 2>&1); rc=$?
command -v codex >/dev/null 2>&1 && PATH="/usr/bin:/bin" command -v codex >/dev/null 2>&1 && echo "SKIP 미설치 시험 (/usr/bin에 codex가 있음)" || check "codex 미설치" 10 '^SKIP codex 명령 없음' $rc "$out"
out=$(env PATH="$tmp/bin:/usr/bin:/bin" bash "$run" 2>&1); rc=$?; check "인자 없음" 1 '^FAIL 인자 부족' $rc "$out"

# run.sh가 만든 임시 폴더 정리 (실제로는 skill이 결과를 읽은 뒤 지운다)
for d in "${made[@]}"; do case "$d" in */workflow-codex.*) rm -rf "$d" ;; esac; done
echo "통과 $pass, 실패 $fail"
[ $fail -eq 0 ]
