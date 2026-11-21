---
description: workflow-usecase-plan으로 생성한 usecase를 Playwright MCP로 실행하고 결과를 계획서에 실시간 체크한다
argument-hint: "@ai-work/usecases/YYMMDD/HHMISS_xxx.md [UC-01,UC-03 처럼 일부만 실행 가능]"
---

# workflow-usecase-do

`workflow-usecase-plan`으로 생성한 usecase 계획서를 **Playwright MCP**로 실행하고, 각 단계 결과를 계획서에 실시간으로 체크한다.

## 입력

```
$ARGUMENTS
```

- mention(`@경로`)으로 지정된 usecase 계획서를 실행한다.
- 지정이 없으면 `ai-work/usecases/` 하위 최신 계획서를 찾아 AskUserQuestion으로 대상이 맞는지 확인한다.
- `UC-01,UC-03`처럼 UC ID가 주어지면 해당 UC만 실행한다. 없으면 전체 실행한다.

## 절대 규칙

- 브라우저 조작은 반드시 Playwright MCP 도구(`browser_navigate`, `browser_snapshot`, `browser_click`, `browser_type`, `browser_fill_form`, `browser_select_option`, `browser_press_key`, `browser_wait_for`, `browser_handle_dialog`, `browser_file_upload`, `browser_take_screenshot`, `browser_network_requests`, `browser_console_messages`, `browser_evaluate` 등)로 수행한다.
- **애매한 사항은 직접 결정하지 않는다.** 다음 경우 AskUserQuestion으로 확인한다.
  - 사전 조건(서버 기동, 계정 정보 등)이 충족되지 않았거나 값이 `실행 시 입력`으로 되어 있을 때
  - 계획서의 대상 요소가 화면에서 발견되지 않거나 여러 개라 특정이 어려울 때
  - 실제 화면 동작이 기대결과와 다른데 그것이 버그인지 계획서 오류인지 판단이 필요할 때
  - 데이터 삭제/결제/메일 발송 등 되돌리기 어려운 동작을 실행해야 할 때
- 계정 비밀번호 등 민감 정보는 결과 기록이나 스크린샷 파일명에 남기지 않는다.

## 상태 표기 규칙

| 표기 | 의미 |
|------|------|
| `[ ]` | 작업항목 (대기 / 미실행) |
| `[~]` | 진행중 |
| `[V]` | 작업완료 (검증 통과) |
| `[X]` | 실패 (기대결과 불일치 또는 실행 오류) |

- **전체진행률** = `[V]` 단계 수 / 전체 단계 수 × 100 (정수 %). `[X]`는 진행률에 포함하지 않는다.
- **작업상태**: 대기 / 진행 / 완료 (실행이 끝났지만 `[X]`가 있으면 `완료(실패 N건)`으로 표시)
- UC별 상태도 동일 규칙으로 갱신한다.

## 처리 절차

### 1. 준비
1. usecase 계획서를 읽고 Base URL, 사전 조건, 실행 대상 UC를 확인한다.
2. Base URL에 접속 가능한지 확인한다. 접속 불가면 AskUserQuestion으로 서버 기동 방법/대기 여부를 확인한다.
3. 증적 저장 경로: usecase 파일과 같은 디렉토리의 `screenshots/HHMISS_[usecase파일명]/` (실행 시각 기준)
4. 필요하면 `browser_resize`로 계획서의 해상도를 맞춘다.
5. 계획서 상단 `작업상태`를 `진행`으로 바꾸고 `최종 갱신`을 갱신한다.

### 2. 단계 실행 (UC 순서대로, 단계 순서대로)
각 단계마다 다음을 **반드시 순서대로** 수행한다.

1. 계획서의 해당 단계 상태를 `[ ]` → `[~]` 로 변경한다. (실행 전에 파일 갱신)
2. 요소를 다루기 전 `browser_snapshot`으로 화면 구조를 확인하고, 계획서의 대상(role + 이름)에 해당하는 ref를 찾는다.
3. 액션에 대응하는 Playwright MCP 도구를 실행한다.
4. 기대결과를 검증한다. (snapshot 텍스트, URL, network 응답, console 오류 등)
5. 결과에 따라 상태를 갱신한다.
   - 통과: `[~]` → `[V]`
   - 실패: `[~]` → `[X]`, 해당 단계 행의 기대결과 칸 뒤에 `→ 실제: ...`를 덧붙이고 `browser_take_screenshot`으로 실패 화면을 저장한다.
6. 전체진행률, 진행률 바, UC별 진행률/상태, 최종 갱신 시각을 재계산하여 파일에 반영한다.

- 한 단계가 실패하면 같은 UC의 이후 단계는 선행 조건이 깨졌는지 판단한다. 계속 진행이 의미 없으면 남은 단계는 `[ ]`(미실행)로 두고 다음 UC로 넘어간다. 판단이 애매하면 AskUserQuestion으로 확인한다.
- 요소를 못 찾는 경우 `browser_wait_for`로 짧게 대기 후 1회 재시도한 다음 실패 처리한다.

### 3. 종료 처리
1. 각 UC 종료 시 `browser_console_messages`로 console error 유무를 확인하여 비고에 기록한다.
2. 전체 실행이 끝나면 `browser_close`로 브라우저를 닫는다.
3. 계획서 `4. 실행 결과` 표에 한 행을 추가한다.

```markdown
| YYYY-MM-DD HH:MI:SS | 통과 N | 실패 N | 미실행 N | 실패 UC: UC-02(3단계), 증적: screenshots/HHMISS_xxx/ |
```

4. 실패 항목이 있으면 아래 섹션을 추가한다.

```markdown
## 6. 실패 상세 (YYYY-MM-DD HH:MI:SS)
| UC | 단계 | 기대결과 | 실제결과 | 추정 원인 | 증적 |
|----|------|----------|----------|-----------|------|
```

5. `작업 이력`에 실행 이력을 추가한다.
6. 원본 작업계획서(usecase 계획서의 `원본 작업계획서` 항목)에 대응하는 완료 기준/테스트 항목이 있고 해당 UC가 모두 통과했다면, 원본 계획서 항목을 `[V]`로 갱신할지 AskUserQuestion으로 확인한 후 반영하고 진행률을 재계산한다.

## 완료 보고
- 실행한 usecase 계획서 경로
- UC별 결과 (통과/실패/미실행)
- 전체진행률
- 실패 항목 요약과 추정 원인, 증적 경로
- 실패가 있으면 수정 후 `/workflow:workflow-usecase-do @<경로> UC-xx`로 재실행하도록 안내한다.
