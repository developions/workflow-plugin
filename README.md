# workflow plugin

작업계획서 생성 → 리뷰 → 구현 → Playwright MCP usecase 계획 → usecase 실행까지 이어지는 Claude Code 플러그인.

## 설치

```
/plugin marketplace add C:\intellij\workspace_workflow
/plugin install workflow@workspace-workflow
```

- 설치 후 Claude Code를 재시작하거나 `/reload-plugins`를 실행한다.
- 로컬 경로로 추가한 marketplace의 플러그인은 복사되지 않고 이 디렉토리에서 바로 로드된다. 커맨드 파일을 고친 뒤에는 재시작이나 `/reload-plugins`만 하면 된다.
- `workflow-usecase-do`는 Playwright MCP가 설치되어 있어야 한다.
- 다섯 커맨드 모두 `/`로 직접 입력했을 때만 실행된다. (`disable-model-invocation: true` — Claude가 대화 맥락만 보고 스스로 실행하지 않는다)

## 커맨드

| 커맨드 | 설명 | 산출물 |
|--------|------|--------|
| `/workflow:workflow-plan <요구사항>` | 요구사항 → 작업계획서 생성, git branch 추천/생성 | `ai-work/plans/YYMMDD/HHMISS_[summary].md` |
| `/workflow:workflow-plan-review @<계획서>` | 범위가 크거나 복잡한 계획서 리뷰·보완 | 계획서에 리뷰 결과 반영 |
| `/workflow:workflow-do @<계획서> [항목 ID 또는 Phase]` | 계획서 기준으로 구현(코딩), 항목마다 진행 상황 갱신 | 소스 변경, 계획서 진행률 갱신 |
| `/workflow:workflow-usecase-plan @<계획서>` | Playwright MCP용 usecase 계획서 생성 | `ai-work/usecases/YYMMDD/HHMISS_[summary].md` |
| `/workflow:workflow-usecase-do @<usecase> [UC-01,...]` | usecase를 Playwright MCP로 실행하고 결과 체크 | usecase 계획서 갱신, `<usecase 파일명>_evidence/<실행 YYMMDD_HHMISS>/` 증적 |

## 흐름

```
workflow-plan ─▶ (복잡하면) workflow-plan-review ─▶ workflow-do ─▶ workflow-usecase-plan ─▶ workflow-usecase-do
                                                     ▲                                          │
                                                     └──────────── 실패 시 수정 후 재실행 ─────────┘
```

- `workflow-do`는 구현 전에 계획서의 미결 사항(`(미결)` 표시, 비어 있거나 `미정`·`보류`인 결정, 조치가 `미결`인 리뷰 지적 등)을 찾아 AskUserQuestion으로 확정하고 계획서를 고친 뒤 진행한다. 보류한 사항에 걸린 항목은 그 실행에서 건너뛴다.
- `workflow-do`는 계획서의 `진행 관리 규칙`에 따라 항목마다 `[~]` → `[V]`로 갱신하며 구현한다. 중단된 경우 같은 커맨드로 이어서 진행한다. 커밋은 끝난 뒤 묻고, push는 하지 않는다.
- 소스 코드를 바꾸는 계획에는 마지막 Phase로 `코드 정리 및 리뷰`가 들어간다. `workflow-do`가 Claude Code의 `/simplify`로 코드를 정리하고, `/code-review medium`으로 리뷰한 뒤 지적 사항 중 반영할 것을 사용자가 고르게 한다.
- usecase 실패를 고칠 때도 `workflow-do`에 수정 내용을 추가 지시로 넣어 진행할 수 있다.
- `workflow-usecase-plan`은 구현 전에 먼저 써 둘 수도 있다. 이때 확인되지 않은 화면 요소에는 `(가정)`이 붙는다.
- `workflow-usecase-do`는 검증만 한다. 실패해도 소스를 고치지 않고 결과를 보고한다.

## 작업 브랜치

- `workflow-plan`이 만든(또는 고른) 브랜치가 계획서 상단 표의 `작업 브랜치`에 기록되고, 이후 모든 커맨드는 이 브랜치에서 실행된다.
- `workflow-plan-review`, `workflow-do`, `workflow-usecase-plan`은 시작할 때 현재 브랜치를 확인한다. 다르면 전환 / 중단을 묻는다. `workflow-plan-review`·`workflow-do`는 `현재 브랜치에서 진행`(계획서의 작업 브랜치를 바꾸고 이력 기록)도 고를 수 있다.
- `workflow-usecase-do`는 서버가 다른 코드로 떠 있을 수 있어 브랜치를 직접 바꾸지 않는다. 중단하거나, 계속하면 결과에 `브랜치 불일치`를 표시하고 원본 계획서에 반영하지 않는다.
- 전환이 실패하면(미커밋 변경 충돌 등) stash나 강제 전환 없이 중단한다.

## 설계안 비교

- 구현 방법이 갈리는 계획이면 `workflow-plan`이 서로 다른 전제(최소 변경 / 구조 개선 / 다른 축)로 설계안 2~3개를 만든다. 범위가 넓으면 Plan agent를 동시에 실행해 만든다.
- 사용자가 미리보기로 비교해 하나를 고르고, 선택하지 않은 안과 이유도 계획서 `2. 결정 사항` 아래 `설계안 비교`에 남긴다.
- `workflow-plan-review`는 선택한 안의 전제가 코드와 맞는지 점검하고, `workflow-do`는 전제가 깨지면 혼자 방향을 바꾸지 않고 대안을 다시 보여 주며 묻는다.

## 결정 사항 · 작업 이력

- 모든 커맨드는 사용자에게 물어 받은 답을 질문·선택지·선택 결과와 함께 작업계획서 `2. 결정 사항`에 한 행씩 남긴다. usecase 커맨드의 답도 원본 작업계획서에 남는다.
- 질문의 답이 아니라 대화창에 직접 입력한 지시·정정도 `<커맨드> · 대화 지시`로 남긴다. `/clear` 후에도 지시가 사라지지 않는다.
- 결정이 바뀌어도 기존 행은 지우지 않고 새 행을 추가해 이력을 보존한다.
- `8. 작업 이력`은 `일시 | 구분 | 내용` 형식이다. `workflow-do`는 시작(`do 시작`: 범위·브랜치·기준 커밋·진행률), 항목 완료(`항목`), Phase 완료(`Phase`), 종료(`do 종료`/`do 중단`: 완료·남은 항목, 변경 파일 수, 검증 결과)를 남긴다.

## git 처리

- 작업계획서와 usecase 계획서(`ai-work/plans`, `ai-work/usecases`의 `.md`)는 커밋 대상이다. 커맨드는 이 파일들을 `.gitignore`에 넣지 않는다.
- 스크린샷 증적 폴더는 git에서 제외한다. `workflow-usecase-do`가 증적 폴더를 만들 때 `.gitignore`에 `ai-work/**/*_evidence/` 줄이 없으면 추가한다.

## 상태 표기

| 표기 | 의미 |
|------|------|
| `[ ]` | 작업항목(대기) |
| `[~]` | 진행중 |
| `[V]` | 작업완료 |
| `[X]` | 실패 (usecase 실행 시에만 사용) |

- 전체진행률(%) = `[V]` 수 ÷ 전체 체크 항목 수 × 100, 소수점 버림
  - 작업계획서: 작업항목 + 완료 기준(`DoD-n`)
  - usecase 계획서: 전체 단계 수
- 작업상태: 대기(시작한 항목 없음) / 진행 / 완료(모든 항목 `[V]`)
- 애매한 사항은 모든 커맨드에서 AskUserQuestion으로 확답을 받는다.
