# gerinogi-routine-runner

로컬 반복 입력 실험을 위한 Windows 도구입니다.

## 실행

1. `release` 폴더를 내려받습니다.
2. `상태루틴 실행.vbs`를 실행합니다.
3. 관리자 권한이 필요한 환경에서는 `상태루틴 관리자 실행.vbs`를 사용합니다.
4. 오류 확인이 필요하면 `상태루틴 디버그 실행.bat`를 실행합니다.

## 샘플 이미지

배포본에는 `release/state_samples` 폴더의 기준 이미지가 포함됩니다.
개별 사용자가 추가 촬영한 이미지와 로그는 각 PC에 로컬로 남습니다.

## 업데이트

프로그램 안의 `업데이트 확인` 버튼은 이 저장소의 `version.json`을 기준으로 새 버전을 확인합니다.

## 로그

실행 후 아래 로그가 로컬 PC의 `release` 폴더에 생성됩니다.

- `local_state_routine_log.csv`
- `routine_trace_log.csv`
- `click_trace_log.csv`

문제가 생기면 위 로그 파일을 전달하면 원인 분석에 사용할 수 있습니다.