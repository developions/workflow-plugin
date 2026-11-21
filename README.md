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
- 다섯 커맨드는 모두 `/`로 직접 입력했을 때만 실행된다. (`disable-model-invocation: true` — Claude가 대화 맥락만 보고 스스로 실행하지 않는다) skill 두 개(`db-design`, `api-design`)는 예외다. 커맨드가 Skill 도구로 불러야 하므로 Claude가 부를 수 있게 열어 두었다. (아래 `skill` 참고)

## 커맨드

| 커맨드 | 설명 | 산출물 |
|--------|------|--------|
| `/workflow:workflow-plan <요구사항>` | 요구사항 → 작업계획서 생성, git branch 추천/생성 | `ai-work/plans/YYMMDD/HHMISS_[summary].md` |
| `/workflow:workflow-plan-review @<계획서>` | 범위가 크거나 복잡한 계획서 리뷰·보완 | 계획서에 리뷰 결과 반영 |
| `/workflow:workflow-do @<계획서> [항목 ID 또는 Phase]` | 계획서 기준으로 구현(코딩), 항목마다 진행 상황 갱신 | 소스 변경, 계획서 진행률 갱신 |
| `/workflow:workflow-usecase-plan @<계획서>` | Playwright MCP용 usecase 계획서 생성 | `ai-work/usecases/YYMMDD/HHMISS_[summary].md` |
| `/workflow:workflow-usecase-do @<usecase> [UC-01,...]` | usecase를 Playwright MCP로 실행하고 결과 체크 | usecase 계획서 갱신, `<usecase 파일명>_evidence/<실행 YYMMDD_HHMISS>/` 증적 |

## skill

| skill | 설명 | 부르는 곳 |
|-------|------|-----------|
| `workflow:db-design` | DB 변경(테이블·컬럼·제약·인덱스·마이그레이션)을 설계·점검하는 기준과 `### DB 변경` 형식 | `workflow-plan`(설계), `workflow-plan-review`·`workflow-do`(점검) |
| `workflow:api-design` | API 변경(엔드포인트·요청·응답·오류 코드·권한·하위 호환)을 설계·점검하는 기준과 `### API 변경` 형식 | 위와 같음 |

- skill은 기준과 형식만 준다. 파일을 쓰거나 커밋하지 않고, 커맨드가 불렀을 때는 사용자에게 직접 묻지 않는다. 미정 사항을 돌려주면 커맨드가 묻고 결정 사항에 기록한다.
- DB와 API가 함께 바뀌면 `db-design`을 먼저 하고 그 정의를 가지고 `api-design`을 한다.
- 설계 모드에서 찾은 관례는 정의의 `따른 관례` 줄에 근거와 함께 남는다. 점검 모드(`workflow-plan-review`, `workflow-do`)는 관례를 처음부터 다시 찾지 않고 이 줄을 재사용한다.
- 결과는 변경 규모에 맞게 쓴다. 컬럼 몇 개 추가처럼 작은 변경은 바뀐 표만 쓴다.
- 관례가 없으면 기본값을 제안해 쓰고, 되돌리기 어렵거나 업무 규칙이거나 다른 팀에 영향을 주는 것만 미정 사항으로 묻는다.
- 커맨드 없이도 쓸 수 있다. (`/workflow:db-design 설계`, `/workflow:api-design 점검 @<계획서>`, 또는 대화에서 DB·API 설계를 요청) 이때는 결과를 대화에만 보여 준다.
- skill을 쓸 수 없는 세션에서는 커맨드가 `${CLAUDE_PLUGIN_ROOT}/skills/<이름>/SKILL.md`를 직접 읽어 같은 기준으로 진행한다.

## 흐름

```
workflow-plan ─▶ (복잡하면) workflow-plan-review ─▶ workflow-do ─▶ workflow-usecase-plan ─▶ workflow-usecase-do
                                                     ▲                                          │
                                                     └──────────── 실패 시 수정 후 재실행 ─────────┘
```

- `workflow-do`는 구현 전에 계획서의 미결 사항(`(미결)` 표시, 비어 있거나 `미정`·`보류`인 결정, 조치가 `미결`인 리뷰 지적 등)을 찾아 AskUserQuestion으로 확정하고 계획서를 고친 뒤 진행한다. 보류한 사항에 걸린 항목은 그 실행에서 건너뛴다.
- `workflow-do`는 계획서의 `진행 관리 규칙`에 따라 항목마다 `[~]` → `[V]`로 갱신하며 구현한다. 중단된 경우 같은 커맨드로 이어서 진행한다. 커밋은 Phase 단위로 계획서의 `커밋 방식`(기본 `자동`)에 따라 하고(아래 `git 처리`), push는 하지 않는다.
- 작업항목이 모두 끝나면 `workflow-do`가 완료 기준을 확인한다. 명령 기준이 실패하거나 사람이 판단한 기준이 미충족이면 수정 작업항목을 추가할지 묻고, 사람이 판단하는 기준은 사용자 확인을 받아 `[V]`로 바꾼다. 작업항목이 모두 `[V]`여도 남은 완료 기준이 있으면 다시 실행해 확인할 수 있다.
- 소스 코드를 바꾸는 계획에는 마지막 Phase로 `코드 정리 및 리뷰`가 들어간다. `workflow-do`가 Claude Code의 `/simplify`로 코드를 정리하고, `/code-review medium`으로 리뷰한 뒤 지적 사항 중 반영할 것을 사용자가 고르게 한다.
- usecase 실패를 고칠 때도 `workflow-do`에 수정 내용을 추가 지시로 넣어 진행할 수 있다.
- `workflow-usecase-plan`은 구현 전에 먼저 써 둘 수도 있다. 이때 확인되지 않은 화면 요소에는 `(가정)`이 붙는다.
- `workflow-usecase-do`는 검증만 한다. 실패해도 소스를 고치지 않고 결과를 보고한다.

## 작업 브랜치

- `workflow-plan`은 코드를 탐색하기 전에 기준 브랜치를 확인한다. 기본 브랜치가 아닌 곳에서 실행하면 어느 브랜치 코드를 기준으로 계획할지 먼저 묻고, 그 위치에서 작업 브랜치를 만든다.
- `workflow-plan`이 만든(또는 고른) 브랜치가 계획서 상단 표의 `작업 브랜치`에 기록되고, 이후 모든 커맨드는 이 브랜치에서 실행된다.
- `workflow-plan-review`, `workflow-do`, `workflow-usecase-plan`은 시작할 때 현재 브랜치를 확인한다. 다르면 전환 / 중단을 묻는다. `workflow-plan-review`·`workflow-do`는 `현재 브랜치에서 진행`(계획서의 작업 브랜치를 바꾸고 이력 기록)도 고를 수 있다.
- `workflow-usecase-do`는 서버가 다른 코드로 떠 있을 수 있어 브랜치를 직접 바꾸지 않는다. 중단하거나, 계속하면 결과에 `브랜치 불일치`를 표시하고 원본 계획서에 반영하지 않는다.
- 전환이 실패하면(미커밋 변경 충돌 등) stash나 강제 전환 없이 중단한다.

## usecase 실행 환경 (URL · 계정)

URL·서버 기동·로그인 절차·계정은 usecase 문서에 쓰지 않고 `ai-work/usecase-env/`에 한 번만 둔다. usecase 문서에는 환경 이름(`local`), web 기준 경로(`/login`), 계정 역할(`admin`)만 쓴다.

| 파일 | git | 내용 |
|------|-----|------|
| `environment.yaml` | 커밋 | 환경별 web·api URL, 서비스 기동 명령·health URL, 공통 로그인 절차, 계정 역할(이름·설명만) |
| `environment.local.yaml` | 제외 | 개인 PC에서만 다른 값(포트 등). 같은 키만 덮어쓴다 |
| `accounts.yaml` | 제외 | 환경·역할별 실제 아이디·비밀번호 |

- `workflow-usecase-plan`이 `environment.yaml`이 없을 때 처음 한 번 코드와 질문으로 만들고, 두 개인 파일을 `.gitignore`에 넣는다. 이후에는 URL·계정을 다시 묻지 않는다. `accounts.yaml`은 읽지 않는다.
- `workflow-usecase-do`는 두 파일을 합쳐 환경을 정하고, `health` URL로 서버를 확인한다. 떠 있지 않으면 `start` 명령으로 띄울지 묻는다.
- `accounts.yaml`이 없으면 `workflow-usecase-do`가 역할 키만 있는 뼈대를 만든다. 값은 사용자가 파일에 직접 채운다. (비밀번호를 대화창으로 받지 않는다)
- usecase의 `login` 단계는 `environment.yaml`의 공통 로그인 절차를 그 역할의 계정으로 실행한다. UC마다 로그인 단계를 풀어 쓰지 않는다.
- **테스트 전용 계정만 쓴다.** Playwright MCP로 입력하는 값은 대화 내용을 거쳐 모델에 전달된다. 증적 스크린샷에도 아이디가 찍힐 수 있으니 외부로 공유할 때 주의한다.
- `Base URL`·`${환경변수}`로 쓴 예전 usecase 문서도 `workflow-usecase-do`가 그대로 실행한다.

## 계획 작성 순서 (workflow-plan)

컨텍스트 파악(기준 브랜치 확인 포함) → 애매한 사항 확인 → 설계안 비교 → 상세 설계와 남은 사항 확인 → 브랜치 생성 → 파일 경로 결정 → 계획서 작성

- 설계안을 고른 뒤 그 안만 구체화하고, 그 과정에서 나온 질문을 계획서를 쓰기 전에 모두 확인한다.
- 기존 기능의 동작을 바꾸면 `1. 요구사항` 아래 `현재 동작 → 변경 후 동작` 표를 코드 근거와 함께 쓰고, 바뀌는 코드의 호출부와 옛 동작을 검증하는 기존 테스트를 찾아 영향 범위·작업항목·완료 기준에 넣는다. `workflow-plan-review`도 이것을 점검한다.
- API나 DB가 바뀌면 `workflow:db-design`·`workflow:api-design` skill로 정의를 만들어 `4. 영향 범위` 아래 `### DB 변경`·`### API 변경`에 쓴다. `workflow-plan-review`는 같은 skill의 점검 기준으로 이 정의를 점검하고, `workflow-do`는 구현 기준으로 삼아 구현 결과를 대조하며, `workflow-usecase-plan`은 `network` 검증 기준으로 쓴다.
- engineering plugin이 설치되어 있으면 필요한 단계에서 `system-design`·`architecture`·`testing-strategy`·`deploy-checklist` skill의 점검 관점을 가져와 쓴다. 설치되어 있지 않으면 그대로 진행한다. DB·API 정의는 `db-design`·`api-design`이 맡고, engineering skill은 설계안 비교(`system-design`·`architecture`), 테스트 설계(`testing-strategy`), 배포·운영 관점의 롤백 기준(`deploy-checklist`)에만 쓴다. engineering skill은 두 skill 안에서 부르지 않는다.

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
- 커밋은 계획서 상단 표의 `커밋 방식`을 따른다. `workflow-plan`이 브랜치 질문과 함께 한 번 묻고, 이후 모든 커맨드가 이 값을 쓴다.
  - `자동`(추천): 아래 시점마다 묻지 않고 커밋하고 `커밋 <해시> <제목>` 한 줄로 알린다.
  - `확인`: 시점마다 묻는다. `커밋 방식` 행이 없는 예전 계획서도 `확인`으로 동작한다.
  - `끝에 한꺼번에`: 각 커맨드가 끝날 때만 묻는다.
  - `자동`이어도 작업 브랜치가 기본 브랜치일 때, 시작 전부터 미커밋 변경이 있던 파일이 섞일 때, 검증이 끝나지 않은(`[~]`) 변경이 섞일 때, 비밀값 파일로 보이는 파일이 있을 때, 커밋 훅이 실패했을 때, usecase를 작업 브랜치가 아닌 곳에서 실행했을 때는 묻는다.
  - 바꾸려면 `workflow-do`에 추가 지시로 준다. (예: `/workflow:workflow-do @<계획서> 커밋 방식을 확인으로 바꿔줘`)
- 그 커맨드가 만들거나 고친 파일만 스테이징하고(`git add -A` 쓰지 않음), push는 하지 않는다. 프로젝트 규칙(CLAUDE.md 등)에 커밋 형식이 있으면 그것을 따르고, 없으면 본문 끝에 `Plan: <계획서 경로>`를 붙인다.

| 시점 | 커맨드 | 커밋 내용 |
|------|--------|-----------|
| 계획서 작성 후 | `workflow-plan` | 계획서 |
| 리뷰 반영 후 | `workflow-plan-review` | 계획서 |
| Phase 완료 | `workflow-do` | 그 Phase의 소스 + 계획서 |
| `(단독 커밋)` 항목 완료 | `workflow-do` | 그 항목의 소스 + 계획서 (DB 마이그레이션, 파일 삭제 등) |
| `/simplify`, `/code-review` 반영 각각 | `workflow-do` | 정리·리뷰 반영 소스 + 계획서 |
| 종료 처리 | `workflow-do` | 아직 커밋하지 않은 이번 실행의 변경 (완료 기준 확인 등) |
| usecase 작성 후 | `workflow-usecase-plan` | usecase 문서 + 원본 계획서 (+ 처음 만든 `environment.yaml`, `.gitignore`) |
| usecase 실행 후 | `workflow-usecase-do` | usecase 문서 + 원본 계획서 + `.gitignore` (브랜치 불일치면 커밋하지 않는 것을 추천) |

- Phase는 커밋 단위이므로 `workflow-plan`은 Phase가 끝났을 때 빌드·테스트가 통과하도록 나누고, 되돌리기 어려운 항목에 `(단독 커밋)`을 붙인다.
- `확인` 방식의 커밋 질문에서 `이번 실행은 끝에 한꺼번에`를 고르면 그 실행에서는 종료 처리에서만 묻는다. `workflow-do` 시작 전부터 있던 미커밋 변경은 커밋에 넣지 않는다.
- 자동 커밋은 push 전이면 `git reset --soft <기준 커밋>`으로 되돌릴 수 있다. (`workflow-do` 완료 보고에 기준 커밋이 나온다)
- **권한 프롬프트**: 질문을 없애도 Claude Code 권한 설정에 따라 `git add`·`git commit` 실행 승인을 따로 물을 수 있다. 자동 커밋을 쓸 프로젝트의 `.claude/settings.json`에 허용 규칙을 넣는다.

  ```json
  {
    "permissions": {
      "allow": ["Bash(git add:*)", "Bash(git commit:*)"]
    }
  }
  ```

  그래도 승인을 자주 물으면 `/fewer-permission-prompts`로 실제로 자주 쓰인 명령을 허용 목록에 넣는다.
- `/simplify`·`/code-review`는 Phase마다 커밋해도 이번 작업 전체를 보도록 첫 `do 시작` 행의 기준 커밋 이후 변경을 대상으로 한다.
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
