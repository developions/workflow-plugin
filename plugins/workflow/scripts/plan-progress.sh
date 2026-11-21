#!/usr/bin/env bash
# plan-progress.sh — 작업계획서 / usecase 계획서의 진행 표시가 체크 표기와 맞는지 확인한다.
#
# 사용: bash plan-progress.sh [--fix] <작업계획서 또는 usecase 계획서 경로>
#
# - 체크 표기를 세어 맞는 값을 계산하고, 문서에 적힌 값과 비교한다.
#   작업계획서: `5. 작업 항목`·`6. 완료 기준`의 `- [ ]`·`- [~]`·`- [V]` 줄 (취소선 줄은 체크박스가 없어 빠진다)
#     편집기·GitHub에서 체크하면 생기는 `[x]`·`[X]`·`[v]`도 완료로 세고, 그 줄을 `[V]`로 고치라고 출력한다.
#     (빼고 세면 분모가 줄어 틀린 진행률을 맞는 값처럼 내기 때문이다. usecase 계획서의 `[X]`는 실패라 해당 없다)
#   usecase 계획서: `3. Usecase` 표의 첫 칸 `[ ]`·`[~]`·`[V]`·`[X]`
# - 비교하는 곳: 상단 표 `작업상태`·`전체진행률`, `진행률` 섹션의 진행률 바, Phase / UC 제목의 `— 상태 (P%)`
#   작업상태는 첫 단어만 비교한다. (`진행 (실패 1건, 미실행 2건)` 같은 사유는 그대로 둔다)
#   상단 표 값은 첫 `## ` 제목 앞의 표에서만 읽는다. 문서에 없는 곳(예전 형식)은 비교하지 않는다.
#   `최종 갱신` 시각은 확인하지 않는다.
# - 기본은 파일을 고치지 않는다.
# - `--fix`: 다른 곳을 맞는 값으로 고친다. (상단 표 전체진행률·작업상태, 진행률 바, Phase / UC 제목, 작업계획서의 `[x]`·`[X]`·`[v]` → `[V]`)
#   체크 표기의 상태(`[ ]`·`[~]`·`[V]`)와 `최종 갱신`은 고치지 않는다. usecase 계획서의 작업상태는 사유와 함께 부른 쪽이 정하므로 고치지 않고 출력만 한다.
#   줄 끝(CRLF/LF)은 그대로 둔다. (Windows Git Bash의 gawk는 텍스트 모드로 읽으면 CR을 지우므로 BINMODE=3으로 읽는다)
#
# 출력: 맞으면 `진행 표시 일치`, 다르면 `진행 표시 불일치 N곳`과 `적힌 값 → 맞는 값` 목록. (`--fix`면 고친 목록)
# 종료 코드: 0 = 확인함(일치·불일치 모두. 체크 표기를 먼저 고치고 부르므로 불일치는 정상 경로다),
#            1 = 실행 오류(경로 없음, 파일 없음). 이때만 커맨드가 직접 센다.

export LC_ALL=C

fix=0
file=""
for a in "$@"; do
  case "$a" in
    --fix) fix=1 ;;
    *) [ -z "$file" ] && file="$a" ;;
  esac
done
if [ -z "$file" ]; then
  echo "실행 오류: 계획서 경로가 없다. 사용: bash plan-progress.sh [--fix] <작업계획서 또는 usecase 계획서 경로>"
  exit 1
fi
if [ ! -f "$file" ]; then
  echo "실행 오류: 파일이 없다: $file"
  exit 1
fi

if grep -q '^## 3\. Usecase' "$file"; then
  kind=usecase
elif grep -q '^## 5\. ' "$file"; then
  kind=plan
else
  echo "확인 대상 아님: 작업계획서(## 5.)나 usecase 계획서(## 3. Usecase) 형식이 아니다: $file"
  exit 0
fi

tmp=""
if [ "$fix" = 1 ]; then
  tmp=$(mktemp) || { echo "실행 오류: 임시 파일을 만들 수 없다"; exit 1; }
fi

awk -v BINMODE=3 -v kind="$kind" -v file="$file" -v fix="$fix" -v out="$tmp" '
BEGIN { t = 0; v = 0; p = 0; x = 0; ng = 0; grp = 0; body = 0; nm = 0 }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function cell(line,   s) { s = line; sub(/^\|[^|]*\|/, "", s); sub(/\|[ \t]*$/, "", s); return trim(s) }
function pct(v, t) { return t > 0 ? int(v * 100 / t) : 0 }
function state(v, p, x, t) {
  if (t > 0 && v == t) return "완료"
  if (v == 0 && p == 0 && x == 0) return "대기"
  return "진행"
}
function bar(pc,   i, n, s) {
  n = int(pc / 10); s = ""
  for (i = 0; i < 10; i++) s = s (i < n ? "■" : "□")
  return s
}
# 마지막 " — " 의 시작 위치 (없으면 0). 바이트 단위(LC_ALL=C)로 센다.
function lastsep(s,   pos, i, sep) {
  sep = " — "; pos = 0
  while ((i = index(substr(s, pos + 1), sep)) > 0) pos += i
  return pos
}
# 표 행의 두 번째 칸을 v로 바꾼다
function setcell(i, v) {
  if (match(L[i], /^\|[^|]*\|/)) L[i] = substr(L[i], 1, RLENGTH) " " v " |"
}
function count(c) {
  t++
  if (c == "V") v++; else if (c == "~") p++; else if (c == "X") x++
  if (grp) {
    gt[grp]++
    if (c == "V") gv[grp]++; else if (c == "~") gp[grp]++; else if (c == "X") gx[grp]++
  }
}

{ cr[NR] = sub(/\r$/, ""); L[NR] = $0 }

/^[ \t]*```/ { fence = !fence; next }
fence { next }

/^## / {
  body = 1; sec = ""; prog = 0; grp = 0
  if (match($0, /^## [0-9]+\./)) sec = substr($0, 4, RLENGTH - 4)
  else if (index($0, "## 진행률") == 1) prog = 1
  next
}

!body && !hs && /^\|[ \t]*작업상태[ \t]*\|/ { hs = NR; w_state = cell($0); next }
!body && !hp && /^\|[ \t]*전체진행률[ \t]*\|/ { hp = NR; w_pct = cell($0); next }
prog && !hb && /^`\[/ { hb = NR; w_bar = trim($0); next }

/^### / && ((kind == "plan" && sec == "5") || (kind == "usecase" && sec == "3")) {
  ng++; gh[ng] = $0; gl[ng] = NR; gt[ng] = 0; gv[ng] = 0; gp[ng] = 0; gx[ng] = 0; grp = ng
  next
}

kind == "plan" && (sec == "5" || sec == "6") && /^[ \t]*[-*+] \[[ ~VvXx]\]([ \t]|$)/ {
  m = $0; sub(/^[ \t]*[-*+] \[/, "", m); c = substr(m, 1, 1)
  if (c == "v" || c == "x" || c == "X") { mk[++nm] = NR ": `[" c "]` → `[V]` (" trim($0) ")"; ml[nm] = NR; c = "V" }
  count(c); next
}

kind == "usecase" && sec == "3" && /^\|[ \t]*\[[ ~VX]\][ \t]*\|/ {
  m = $0; sub(/^\|[ \t]*\[/, "", m); count(substr(m, 1, 1)); next
}

END {
  label = (kind == "plan") ? "작업계획서" : "usecase 계획서"
  if (t == 0) { print "확인 대상 아님: " label "에 체크 항목이 없다: " file; exit 0 }

  P = pct(v, t); S = state(v, p, x, t)
  e_pct = P "% (" v "/" t ")"
  e_bar = "`[" bar(P) "] " P "%`"

  n = 0; keep = 0
  if (hs) {
    ws = w_state; sub(/[ \t(].*$/, "", ws)
    if (ws != S) {
      if (kind == "plan") {
        msg[++n] = "상단 표 작업상태: `" w_state "` → `" S substr(w_state, length(ws) + 1) "`"
        setcell(hs, S substr(w_state, length(ws) + 1))
      } else {
        msg[++n] = "상단 표 작업상태: `" w_state "` → `" S "`" (fix ? " (고치지 않음: 사유와 함께 부른 쪽이 고친다)" : "")
        keep++
      }
    }
  }
  if (hp && w_pct != e_pct) { msg[++n] = "상단 표 전체진행률: `" w_pct "` → `" e_pct "`"; setcell(hp, e_pct) }
  if (hb && w_bar != e_bar) { msg[++n] = "진행률 바: " w_bar " → " e_bar; L[hb] = e_bar }
  for (i = 1; i <= nm; i++) {
    msg[++n] = "체크 표기 줄 " mk[i]
    s = L[ml[i]]; sub(/\[[vxX]\]/, "[V]", s); L[ml[i]] = s
  }
  for (g = 1; g <= ng; g++) {
    if (gt[g] == 0) continue
    k = lastsep(gh[g])
    if (!k) continue
    eh = substr(gh[g], 1, k - 1) " — " state(gv[g], gp[g], gx[g], gt[g]) " (" pct(gv[g], gt[g]) "%)"
    if (gh[g] != eh) { msg[++n] = "제목: `" gh[g] "` → `" eh "`"; L[gl[g]] = eh }
  }

  r = t - v - p - x
  cnt = "[V] " v " · [~] " p " · [ ] " r
  if (kind == "usecase") cnt = cnt " · [X] " x
  print label " 체크 항목 " t "개 (" cnt ") → 전체진행률 " e_pct ", 작업상태 " S
  if (!hs && !hp && !hb) print "참고: 상단 표 작업상태·전체진행률과 진행률 바를 찾지 못해 제목만 비교했다. (예전 형식)"

  if (n == 0) { print "진행 표시 일치"; exit 0 }
  if (fix) {
    if (n > keep) {
      for (i = 1; i <= NR; i++) printf "%s%s\n", L[i], (cr[i] ? "\r" : "") > out
      close(out)
    }
    print "진행 표시 불일치 " n "곳 — 고쳤다. (`최종 갱신`은 고치지 않았다):"
    for (i = 1; i <= n; i++) print "- " msg[i]
    exit 0
  }
  if (nm) print "진행 표시 불일치 " n "곳 — 아래 `→` 오른쪽 값으로 고친다. (`체크 표기 줄`은 완료로 셌으니 표기만 `[V]`로 바꾸고, 다른 체크 표기는 그대로 둔다):"
  else print "진행 표시 불일치 " n "곳 — 체크 표기는 그대로 두고 아래 `→` 오른쪽 값으로 고친다:"
  for (i = 1; i <= n; i++) print "- " msg[i]
  exit 0
}
' "$file"
st=$?

if [ -n "$tmp" ]; then
  if [ "$st" = 0 ] && [ -s "$tmp" ]; then cat "$tmp" > "$file"; fi
  rm -f "$tmp"
fi
exit "$st"
