---
description: workflow-plan 작업계획서를 기반으로 Playwright MCP에서 실행 가능한 usecase 계획서(ai-work/usecases)를 생성한다
argument-hint: "@ai-work/plans/YYMMDD/HHMISS_xxx.md [추가 요청사항]"
disable-model-invocation: true
---

# workflow-usecase-plan

`workflow-plan`으로 생성한 작업계획서를 mention으로 받아, **Playwright MCP로 실행 가능한 usecase 계획서**를 생성한다.

## 입력

```
$ARGUMENTS
```

- mention(`@경로`) 또는 경로로 지정된 작업계획서를 기준으로 한다. `@`를 뗀 경로의 파일을 직접 읽는다. (자동 첨부에 기대지 않는다)
- 지정이 없으면 `ai-work/plans/` 하위 최신 계획서를 찾아 AskUserQuestion으로 대상이 맞는지 확인한다.
- 경로 외 추가 텍스트는 usecase 작성 시 추가 요청사항으로 반영한다.

## 절대 규칙

- **애매한 사항은 직접 결정하지 않는다.** 다음과 같은 정보가 계획서/코드에서 확정되지 않으면 AskUserQuestion으로 확인한다.
  - 테스트 대상 Base URL (예: `http://localhost:8080`) 및 서버 기동 방법
  - 로그인 계정/권한 등 사전 조건
  - 테스트 데이터, 해상도, 포함할 시나리오 범위(정상/예외/권한)
  - 계획서에 화면으로 검증할 항목이 없을 때 계속 진행할지 여부
  - AskUserQuestion을 쓸 수 없는 환경(비대화형 실행 등)이면 추측으로 진행하지 말고, 질문 목록을 출력한 뒤 중단한다.
- 비밀번호 등 민감 정보는 계획서에 평문으로 쓰지 않는다. `${환경변수명}` 또는 `(실행 시 입력)`으로 표기한다.
- usecase의 각 단계는 Playwright MCP 도구로 **그대로 실행 가능한 수준**으로 구체적으로 쓴다. ("확인한다" 같은 모호한 표현 대신 무엇을, 어떤 값으로 확인하는지 명시)
- 이 커맨드는 **계획서 작성까지만** 수행한다. 브라우저를 실행하지 않는다.

## 처리 절차

1. 대상 작업계획서를 읽고 요구사항, 작업항목, 완료 기준, 영향 범위를 파악한다.
2. 관련 화면 소스(라우트, 템플릿/컴포넌트, 폼 필드, 버튼 라벨, API 엔드포인트)를 탐색하여 실제 URL 경로와 화면 요소(라벨/텍스트/role)를 확인한다.
   - 아직 구현되지 않은 화면은 계획서 내용을 기준으로 쓰되 대상 칸에 `(가정)`을 붙인다.
3. 애매한 사항을 AskUserQuestion으로 확인한다.
4. 파일 경로 결정
   - 현재 시각을 **한 번만** 조회해서 파일 경로와 문서의 일시에 같은 값을 쓴다.
     - Bash: `date '+%y%m%d %H%M%S %Y-%m-%d %H:%M:%S'`
     - PowerShell: `Get-Date -Format 'yyMMdd HHmmss yyyy-MM-dd HH:mm:ss'`
   - 경로: `ai-work/usecases/YYMMDD/HHMISS_[summary_snake_case].md` (프로젝트 루트 기준. summary는 원본 계획서 파일명의 summary를 우선 재사용)
   - 디렉토리가 없으면 생성한다.
5. 아래 규칙과 템플릿으로 usecase 계획서를 작성한다. 생성 시점에는 모든 단계가 `[ ]`이다.
6. 원본 작업계획서에 `8. 작업 이력` 표가 있으면 usecase 계획서 생성 이력과 경로를 한 줄 추가한다.

## 상태 표기 · 진행률 규칙

| 표기 | 의미 |
|------|------|
| `[ ]` | 작업항목 (대기 / 미실행) |
| `[~]` | 진행중 |
| `[V]` | 작업완료 (검증 통과) |
| `[X]` | 실패 (`workflow-usecase-do` 실행 시에만 기록) |

- **전체진행률** = `[V]` 단계 수 ÷ 전체 단계 수 × 100 (소수점 버림). `0% (0/N)`처럼 개수를 함께 쓴다.
- **진행률 바** = 10칸. 10%당 `■` 1칸(버림), 나머지는 `□`
- **작업상태**는 백분율이 아니라 개수로 판단한다.
  - 대기: `[V]`·`[~]`·`[X]`가 모두 0개
  - 완료: 모든 단계가 `[V]`
  - 진행: 그 외
- UC 제목에도 같은 규칙으로 그 UC의 상태와 진행률을 표시한다. (분모는 그 UC의 단계 수)

## Playwright MCP 액션 표기

각 단계는 `액션` + `대상` + `값 / 기대결과`로 쓴다. 액션은 Playwright MCP 도구 하나에 대응한다.

| 액션 | MCP 도구 | 표기 예 |
|------|----------|---------|
| navigate | browser_navigate | 대상 `/login` (Base URL 기준 경로) |
| back | browser_navigate_back | 대상 `-` |
| click | browser_click | 대상 button "로그인" |
| hover | browser_hover | 대상 menuitem "설정" |
| type | browser_type | 대상 textbox "아이디", 값 `testuser` |
| fill_form | browser_fill_form | 값 `아이디=testuser, 이름=홍길동` (여러 필드 일괄 입력) |
| select | browser_select_option | 대상 combobox "구분", 값 `전체` |
| press | browser_press_key | 값 `Enter` |
| wait | browser_wait_for | 대상 text "저장되었습니다" 나타남/사라짐 (최대 30초) |
| dialog | browser_handle_dialog | 값 `accept` 또는 `dismiss`. dialog를 띄우는 단계 **바로 다음**에 둔다 |
| upload | browser_file_upload | 값 파일 경로. 파일 선택창을 여는 click **바로 다음**에 둔다 |
| assert | browser_find / browser_snapshot / browser_evaluate | 대상 text "홍길동", 기대결과 `표시됨` |
| network | browser_network_requests | 대상 `POST /api/xxx`, 기대결과 `응답 200` |
| console | browser_console_messages | 기대결과 `error 없음` |
| screenshot | browser_take_screenshot | 값 `01-06.png` (파일명만 쓴다) |

- 대상은 가능한 한 **role + 접근 가능한 이름(라벨/텍스트)** 으로 지정한다. (예: button "저장", textbox "이메일")
- 표에 없는 동작(드래그, 탭 전환 등)은 해당 Playwright MCP 도구 이름에서 `browser_`를 뺀 것을 액션으로 쓴다. (예: `drag`, `tabs`)
- 단계 ID는 `UC번호-순번`(`01-01`)으로 문서 전체에서 유일하게 매긴다. 실행 중 행 단위로 상태를 고치므로 같은 내용의 행이 여러 UC에 있어도 구분되어야 한다.
- 스크린샷 파일명은 `단계ID.png`로 쓴다. 저장 디렉토리는 실행할 때 정해진다. (템플릿의 표기 규칙 참고)

## usecase 계획서 템플릿

```markdown
# [Usecase 제목]

| 항목 | 내용 |
|------|------|
| 작성일시 | YYYY-MM-DD HH:MI:SS |
| 원본 작업계획서 | `ai-work/plans/YYMMDD/HHMISS_xxx.md` |
| 작업 브랜치 | `feature/xxx` |
| Base URL | http://localhost:8080 |
| 해상도 | 1920x1080 |
| 작업상태 | 대기 |
| 전체진행률 | 0% (0/N) |
| 최종 갱신 | YYYY-MM-DD HH:MI:SS |

## 진행률

`[□□□□□□□□□□] 0%`

> **표기 규칙**
> - `[ ]` 작업항목(대기/미실행) · `[~]` 진행중 · `[V]` 작업완료(검증 통과) · `[X]` 실패
> - 전체진행률 = `[V]` 단계 수 ÷ 전체 단계 수 × 100, 소수점 버림. 진행률 바는 10%당 `■` 1칸.
> - 작업상태: 대기(`[V]`·`[~]`·`[X]` 모두 0개) / 완료(모든 단계 `[V]`) / 진행(그 외)
> - 실행은 `/workflow:workflow-usecase-do @<이 파일>`로 한다. 증적은 이 파일 경로에서 `.md`를 뺀 `..._evidence/<실행 YYMMDD_HHMISS>/`에 저장된다.

## 1. 사전 조건
- 서버 기동: `실행 명령`
- 계정: `${TEST_USER_ID}` / `${TEST_USER_PW}` (환경변수) 또는 `(실행 시 입력)`
- 테스트 데이터: ...

## 2. 작업계획서 매핑
| UC | 검증 대상 (작업계획서 항목 ID) |
|----|-------------------------------|
| UC-01 | 1.2, DoD-1 |

## 3. Usecase

### UC-01. [시나리오명] — 대기 (0%)
- 목적: ...
- 유형: 정상 / 예외 / 권한

| 상태 | 단계 | 액션 | 대상 | 값 / 기대결과 |
|------|------|------|------|---------------|
| [ ] | 01-01 | navigate | `/login` | 로그인 화면 표시 |
| [ ] | 01-02 | type | textbox "아이디" | `${TEST_USER_ID}` |
| [ ] | 01-03 | type | textbox "비밀번호" | `${TEST_USER_PW}` |
| [ ] | 01-04 | click | button "로그인" | - |
| [ ] | 01-05 | assert | text "메인" | 표시됨 |
| [ ] | 01-06 | screenshot | - | `01-06.png` |

- 기대 결과 요약: ...

### UC-02. [시나리오명] — 대기 (0%)
...

## 4. 실행 결과
| 실행일시 | 대상 | 통과 | 실패 | 미실행 | 증적 / 비고 |
|----------|------|------|------|--------|-------------|

## 5. 작업 이력
| 일시 | 내용 |
|------|------|
| YYYY-MM-DD HH:MI:SS | usecase 계획서 생성 |
```

### 템플릿 작성 지침
- **N**: 전체 단계 수(모든 UC의 단계 합)
- **작업 브랜치**: 원본 작업계획서의 값을 그대로 옮긴다.
- **2. 작업계획서 매핑**: 원본 계획서의 항목 ID(`1.2`, `DoD-1`)로 쓴다. 실행 후 통과 여부를 원본 계획서에 반영할 때 이 표를 쓴다.
- **표기 규칙 블록**은 빼지 않고 그대로 넣는다.

## 완료 보고
- 생성된 usecase 계획서 경로
- UC 수, 전체 단계 수
- 확정한 사전 조건(Base URL, 계정 처리 방식 등)
- `(가정)`으로 쓴 요소가 있으면 그 목록과, 구현 후 실제 화면 기준으로 고쳐야 한다는 점
- 실행 방법: 구현이 끝나고 서버가 기동된 상태에서 `/workflow:workflow-usecase-do @<usecase 경로>`
