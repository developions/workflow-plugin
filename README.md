# workflow plugin

작업계획서 생성 → 리뷰 → Playwright MCP usecase 계획 → usecase 실행까지 이어지는 Claude Code 플러그인.

## 설치

```
/plugin marketplace add C:\intellij\workspace_workflow
/plugin install workflow@workspace-workflow
```

설치 후 Claude Code를 재시작(또는 `/reload-plugins`)한다. `workflow-usecase-do`는 Playwright MCP 플러그인이 설치되어 있어야 한다.

## 커맨드

| 커맨드 | 설명 | 산출물 |
|--------|------|--------|
| `/workflow:workflow-plan <요구사항>` | 요구사항 → 작업계획서 생성, git branch 추천/생성 | `ai-work/plans/YYMMDD/HHMISS_[summary].md` |
| `/workflow:workflow-plan-review @<계획서>` | 범위가 크거나 복잡한 계획서 리뷰·보완 | 계획서에 리뷰 결과 반영 |
| `/workflow:workflow-usecase-plan @<계획서>` | Playwright MCP용 usecase 계획서 생성 | `ai-work/usecases/YYMMDD/HHMISS_[summary].md` |
| `/workflow:workflow-usecase-do @<usecase>` | usecase를 Playwright MCP로 실행하고 결과 체크 | usecase 계획서 갱신, `screenshots/` 증적 |

## 상태 표기

| 표기 | 의미 |
|------|------|
| `[ ]` | 작업항목(대기) |
| `[~]` | 진행중 |
| `[V]` | 작업완료 |
| `[X]` | 실패 (usecase 실행 시에만 사용) |

- 전체진행률(%) = `[V]` 수 / 전체 항목 수
- 작업상태: 대기 / 진행 / 완료
- 애매한 사항은 모든 커맨드에서 AskUserQuestion으로 확답을 받는다.

## 흐름

```
workflow-plan ──▶ (복잡하면) workflow-plan-review ──▶ workflow-usecase-plan ──▶ workflow-usecase-do
```
