---
description: workflow-plan 작업계획서를 기반으로 Playwright MCP에서 실행 가능한 usecase 계획서(ai-work/usecases)를 생성한다
argument-hint: "@ai-work/plans/YYMMDD/HHMISS_xxx.md [추가 요청사항]"
---

# workflow-usecase-plan

`workflow-plan`으로 생성한 작업계획서를 mention으로 받아, **Playwright MCP로 실행 가능한 usecase 계획서**를 생성한다.

## 입력

```
$ARGUMENTS
```

- mention(`@경로`)으로 지정된 작업계획서를 기준으로 한다.
- 지정이 없으면 `ai-work/plans/` 하위 최신 계획서를 찾아 AskUserQuestion으로 대상이 맞는지 확인한다.
- mention 외 추가 텍스트는 usecase 작성 시 추가 요청사항으로 반영한다.

## 절대 규칙

- **애매한 사항은 직접 결정하지 않는다.** 다음과 같은 정보가 계획서/코드에서 확정되지 않으면 AskUserQuestion으로 확인한다.
  - 테스트 대상 Base URL (예: `http://localhost:8080`) 및 서버 기동 방법
  - 로그인 계정/권한 등 사전 조건 (비밀번호 등 민감 정보는 계획서에 평문으로 쓰지 않고 `환경변수명` 또는 `실행 시 입력`으로 표기)
  - 테스트 데이터, 브라우저 해상도, 포함할 시나리오 범위(정상/예외/권한)
- usecase의 각 단계는 Playwright MCP 도구로 **그대로 실행 가능한 수준**으로 구체적으로 쓴다. ("확인한다" 같은 모호한 표현 대신 무엇을, 어떤 값으로 확인하는지 명시)

## 처리 절차

1. 대상 작업계획서를 읽고 요구사항, 작업항목, 완료 기준, 영향 범위를 파악한다.
2. 관련 화면 소스(라우트, 템플릿/컴포넌트, 폼 필드, 버튼 라벨, API 엔드포인트)를 탐색하여 실제 URL 경로와 화면 요소(라벨/텍스트/role)를 확인한다.
3. 애매한 사항을 AskUserQuestion으로 확인한다.
4. 파일 경로 결정
   - Bash로 `date +%y%m%d` (YYMMDD), `date +%H%M%S` (HHMISS)를 구한다.
   - 경로: `ai-work/usecases/YYMMDD/HHMISS_[summary_snake_case].md` (summary는 원본 계획서의 summary를 우선 재사용)
   - 디렉토리가 없으면 생성한다.
5. 아래 템플릿으로 usecase 계획서를 작성한다.
6. 원본 작업계획서의 `작업 이력`에 usecase 계획서 생성 이력과 경로를 한 줄 추가한다.

## 상태 표기 규칙

| 표기 | 의미 |
|------|------|
| `[ ]` | 작업항목 (대기) |
| `[~]` | 진행중 |
| `[V]` | 작업완료 (검증 통과) |

- **전체진행률** = `[V]` 단계 수 / 전체 단계 수 × 100 (정수 %)
- **작업상태**: 대기(0%, 진행중 없음) / 진행(진행중 있음 또는 0~100% 사이) / 완료(100%)
- Usecase(UC)별로도 진행률과 상태를 표시한다.

## Playwright MCP 액션 표기

각 단계는 `액션` + `대상` + `값/기대결과` 형태로 쓴다. 액션은 다음 Playwright MCP 도구와 1:1로 대응시킨다.

| 액션 | MCP 도구 | 예시 |
|------|----------|------|
| navigate | browser_navigate | `navigate` `/login` |
| snapshot | browser_snapshot | 화면 요소 구조 확인 |
| click | browser_click | `click` button "로그인" |
| type | browser_type | `type` textbox "아이디" = `testuser` |
| fill_form | browser_fill_form | 여러 필드 일괄 입력 |
| select | browser_select_option | `select` combobox "구분" = `전체` |
| press | browser_press_key | `press` `Enter` |
| wait | browser_wait_for | `wait` text "저장되었습니다" |
| dialog | browser_handle_dialog | `dialog` accept |
| upload | browser_file_upload | `upload` 파일 경로 |
| assert | browser_snapshot / browser_evaluate | `assert` text "홍길동" 표시됨 |
| screenshot | browser_take_screenshot | 증적 저장 |
| network | browser_network_requests | `assert` `POST /api/xxx` 200 |
| console | browser_console_messages | `assert` console error 없음 |

- 대상은 가능한 한 **role + 접근 가능한 이름(라벨/텍스트)** 으로 지정한다. (예: button "저장", textbox "이메일")

## usecase 계획서 템플릿

```markdown
# [Usecase 제목]

| 항목 | 내용 |
|------|------|
| 작성일시 | YYYY-MM-DD HH:MI:SS |
| 원본 작업계획서 | `ai-work/plans/YYMMDD/HHMISS_xxx.md` |
| 작업 브랜치 | `feature/xxx` |
| Base URL | http://localhost:8080 |
| 브라우저/해상도 | chromium / 1920x1080 |
| 작업상태 | 대기 |
| 전체진행률 | 0% (0/N) |
| 최종 갱신 | YYYY-MM-DD HH:MI:SS |

## 진행률

`[□□□□□□□□□□] 0%`

## 1. 사전 조건
- 서버 기동: `실행 명령`
- 계정: 환경변수 `TEST_USER_ID` / `TEST_USER_PW` (또는 실행 시 입력)
- 테스트 데이터: ...

## 2. 작업계획서 매핑
| UC | 검증 대상 작업항목 / 완료 기준 |
|----|-------------------------------|
| UC-01 | Phase 1.2, 완료기준 1 |

## 3. Usecase

### UC-01. [시나리오명] — 대기 (0%)
- 목적: ...
- 유형: 정상 / 예외 / 권한

| 상태 | # | 액션 | 대상 | 값 / 기대결과 |
|------|---|------|------|---------------|
| [ ] | 1 | navigate | `/login` | 로그인 화면 표시 |
| [ ] | 2 | type | textbox "아이디" | `${TEST_USER_ID}` |
| [ ] | 3 | click | button "로그인" | - |
| [ ] | 4 | assert | text "메인" | 메인 화면으로 이동 |
| [ ] | 5 | screenshot | - | `UC-01_05.png` |

- 기대 결과 요약: ...

### UC-02. [시나리오명] — 대기 (0%)
...

## 4. 실행 결과
| 실행일시 | 통과 | 실패 | 미실행 | 비고 |
|----------|------|------|--------|------|

## 5. 작업 이력
| 일시 | 내용 |
|------|------|
| YYYY-MM-DD HH:MI:SS | usecase 계획서 생성 |
```

## 완료 보고
- 생성된 usecase 계획서 경로
- UC 수, 전체 단계 수
- 확정한 사전 조건(Base URL, 계정 처리 방식 등)
- 실행 방법: `/workflow:workflow-usecase-do @<usecase 경로>`
