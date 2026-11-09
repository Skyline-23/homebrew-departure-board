# AeroDataBox API 키 설정

**[English](api-key.md) · [한국어](api-key.ko.md) · [README로 돌아가기](../README.ko.md)**

Departure Board는 **RapidAPI를 통한 AeroDataBox**를 사용합니다. AeroDataBox에서 직접 구독해 받은 키는 접속 주소와 인증 방식이 달라 이 앱에서 사용할 수 없습니다.

## 1. RapidAPI 계정 만들기

[RapidAPI](https://rapidapi.com/)에 가입하거나 로그인합니다. 가입하면 보통 기본 앱이 하나 만들어집니다. 이 앱을 그대로 쓰거나 [Developer Dashboard](https://rapidapi.com/developer/dashboard)에서 **Departure Board**라는 앱을 따로 만들어도 됩니다.

## 2. AeroDataBox 구독하기

공식 [AeroDataBox 요금제 페이지](https://rapidapi.com/aedbx-aedbx/api/aerodatabox/pricing)에서 요금제를 고르고 구독을 완료합니다.

- 계정 가입과 API 구독은 별도 절차입니다.
- 무료 Basic 요금제에도 월 사용 한도가 있습니다.
- 무료 요금제에서 결제 정보를 요구할 수 있습니다. 확정하기 전에 표시된 요금, 제공량, 추가 비용과 이용 조건을 확인해 주세요.
- 요금제에 맞게 앱의 **Refresh interval**을 설정해 주세요. 이 값은 네트워크 조회 주기입니다. 언어와 페이지, 공동운항 편명 순환에는 API가 추가로 호출되지 않습니다.

요금제는 바뀔 수 있으니 [현재 요금제 페이지](https://rapidapi.com/aedbx-aedbx/api/aerodatabox/pricing)에서 최신 한도를 확인해 주세요. 항공편 데이터가 담긴 화면을 공개할 때는 제공자의 [출처 표기 조건](https://aerodatabox.com/2026-09-terms-update/)도 확인해야 합니다.

## 3. 키 찾기 또는 발급하기

1. [Developer Dashboard](https://rapidapi.com/developer/dashboard)를 엽니다.
2. **Apps**에서 기본 앱이나 **Departure Board**를 선택합니다.
3. **Authorization**에서 기존 앱 키를 복사합니다. 새 키가 필요하다면 **Add authorization**을 누르고 이름을 입력합니다.
4. 복사할 값은 **X-RapidAPI-Key**입니다. AeroDataBox의 **Endpoints** 탭에 있는 코드 예제에서도 확인할 수 있습니다.

키 값만 복사해 주세요. **X-RapidAPI-Host**와 앱 ID, 계정 비밀번호는 API 키가 아닙니다. 접속할 호스트는 앱에서 설정하므로 따로 입력하지 않아도 됩니다.

## 4. Departure Board에 저장하기

1. `/Applications`나 메뉴 막대에서 **Departure Board**를 열고 **Settings**로 들어갑니다.
2. **Timetable source**에서 **Live flight data**를 선택합니다.
3. **API key**에 키 값을 붙여 넣고 **Apply**를 누릅니다.
4. 공항을 고른 뒤 첫 조회가 끝날 때까지 기다립니다.

키는 macOS 키체인에 저장됩니다. 저장 후에는 키 값이 가려져 표시됩니다. 앱과 배경화면, 화면 보호기는 같은 설정을 사용하므로 공항이나 모니터마다 키를 따로 입력할 필요가 없습니다.

## 항공편이 표시되지 않을 때

| 증상 | 확인할 내용 |
| --- | --- |
| 인증 오류 / 401 | RapidAPI 앱 키가 빠짐없이 복사됐는지, 아직 유효한 키인지 확인합니다. |
| 구독 또는 접근 오류 / 403 | 같은 계정에서 AeroDataBox를 구독했는지 확인합니다. 공항별 지원 범위와 요금제의 접근 권한도 확인해 주세요. |
| API 한도 도달 / 429 | RapidAPI에서 사용량을 확인합니다. 조회 주기를 늘리거나 제공자의 재시도 대기 시간이 끝날 때까지 기다립니다. |
| 샘플 항공편이 표시됨 | **Timetable source**를 **Sample schedule**에서 **Live flight data**로 바꿉니다. |
| 특정 공항에 출발편이 없음 | 공항별 데이터 지원 범위와 조회 가능한 출발 시간대는 다릅니다. 키가 잘못됐다는 뜻은 아닐 수 있습니다. |

이슈나 스크린샷, 공유하는 설정 파일에 API 키를 넣지 마세요. 키가 노출됐다면 **Authorization**에서 새 키를 만들어 앱에 저장하고 기존 키는 폐기해 주세요.

참고: [RapidAPI 키 관리](https://docs.rapidapi.com/v2/docs/keys-and-key-rotation), [RapidAPI 구독 안내](https://docs.rapidapi.com/v2/docs/api-pricing), [AeroDataBox API 문서](https://doc.aerodatabox.com/rapidapi.html).
