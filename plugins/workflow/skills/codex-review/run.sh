#!/usr/bin/env bash
# Codex CLI로 작업계획서를 읽기 전용 교차 리뷰한다. (workflow-plan-review가 부른다)
# 사용: run.sh <저장소 루트> <계획서 경로(저장소 기준)>
# 출력은 한 줄뿐이다. Codex의 원래 출력(읽은 파일 내용이 섞인다)은 임시 폴더의 로그로만 보내고,
# 끝나면 로그를 지운다. (실패해도 사유 한 줄만 출력하고 임시 폴더를 지운다)
#   OK <결과 JSON 경로> <지적 수> <초>     — 결과 JSON이 든 임시 폴더는 읽은 쪽이 지운다
#   SKIP <사유>
#   FAIL <초> <사유>
# 종료 코드: 0 성공 / 10 codex 명령 없음 / 12 시간 초과 / 13 응답 형식 오류 / 1 그 밖 실패(인증·사용량·설정 등)
# 환경 변수: WORKFLOW_CODEX_MODEL(기본 gpt-6.2-astra, 빈 값이면 Codex 설정의 기본 모델),
#            WORKFLOW_CODEX_EFFORT(기본 high), WORKFLOW_CODEX_TIMEOUT(초, 기본 480)
set -u

here=$(cd "$(dirname "$0")" && pwd)
plugin=$(cd "$here/../.." && pwd)
repo=${1:-}
plan=${2:-}
if [ -z "$repo" ] || [ -z "$plan" ]; then
  echo "FAIL 0 인자 부족 (사용: run.sh <저장소 루트> <계획서 경로>)"
  exit 1
fi
if ! command -v codex >/dev/null 2>&1; then
  echo "SKIP codex 명령 없음"
  exit 10
fi

# Windows(Git Bash)에서는 Codex에 넘기는 경로를 C:/... 형식으로 바꾼다.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

model=${WORKFLOW_CODEX_MODEL-gpt-6.2-astra}
effort=${WORKFLOW_CODEX_EFFORT:-high}
limit=${WORKFLOW_CODEX_TIMEOUT:-480}

work=$(mktemp -d "${TMPDIR:-/tmp}/workflow-codex.XXXXXX") || { echo "FAIL 0 임시 폴더를 만들 수 없음"; exit 1; }
out="$work/findings.json"
log="$work/codex.log"
prompt="$work/prompt.md"

tpl=$(cat "$here/prompts/plan-review.md")
tpl=${tpl//'{{REPO}}'/$(native "$repo")}
tpl=${tpl//'{{PLAN}}'/$plan}
tpl=${tpl//'{{PLUGIN}}'/$(native "$plugin")}
printf '%s\n' "$tpl" > "$prompt"

timer=()
if command -v timeout >/dev/null 2>&1; then timer=(timeout "$limit")
elif command -v gtimeout >/dev/null 2>&1; then timer=(gtimeout "$limit")
fi

run_codex() {
  rm -f "$out"
  ${timer[@]+"${timer[@]}"} codex exec -C "$(native "$repo")" -s read-only --skip-git-repo-check --ephemeral \
    -c model_reasoning_effort="$effort" "$@" \
    --output-schema "$(native "$here/findings.schema.json")" -o "$(native "$out")" - < "$prompt" >> "$log" 2>&1
}

start=$(date +%s)
if [ -n "$model" ]; then
  run_codex -m "$model"; rc=$?
  # 지정한 모델을 이 계정에서 쓸 수 없으면 Codex 설정의 기본 모델로 한 번만 다시 한다.
  if [ $rc -ne 0 ] && [ $rc -ne 124 ] && grep -qiE "model is not supported|model .*not found|unknown model|does not exist" "$log"; then
    echo "--- $model 사용 불가, 기본 모델로 다시 실행 ---" >> "$log"
    run_codex; rc=$?
  fi
else
  run_codex; rc=$?
fi
sec=$(( $(date +%s) - start ))

# 실패: 사유 한 줄만 출력하고 임시 폴더(로그 포함)를 지운다.
fail() { echo "FAIL $sec $2"; rm -rf "$work"; exit "$1"; }
# Codex 오류를 짧은 사유로 줄인다. (안내 문구·URL은 뺀다)
reason_of() {
  if grep -qi "usage limit" "$log"; then
    local when
    when=$(grep -m1 -oiE "try again at [^.]*" "$log")
    echo "사용량 한도${when:+ (다시 가능: ${when#*again at })}"
    return
  fi
  local line
  line=$(grep -m1 -E "^ERROR" "$log" | sed -E 's#https?://[^ )]*##g; s/^ERROR:? *//' | cut -c1-150)
  echo "codex 실행 실패(종료 코드 $rc${line:+: $line})"
}

if [ $rc -eq 124 ]; then fail 12 "시간 초과(${limit}초)"; fi
if [ $rc -ne 0 ]; then fail 1 "$(reason_of)"; fi
if [ ! -s "$out" ] || ! grep -q '"findings"' "$out"; then fail 13 "응답 형식 오류(빈 출력 또는 findings 없음)"; fi

n=$(grep -o '"location"' "$out" | wc -l | tr -d ' ')
rm -f "$log" "$prompt"
echo "OK $(native "$out") $n $sec"
exit 0
