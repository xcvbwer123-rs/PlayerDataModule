local Settings = {
    Autosave = true; -- 오토세이브를 사용할지 말지 여부
    AutosaveDelay = 120; -- 오토세이브 할 시간 간격, 안에 들어간 숫자 초 만큼 기다림 (단, 서버에서 걸리는 랙에 따라서 시간오차가 생길수도 있음)

    RetryOnFail = true; -- 데이터 로드 실패했을때 알아서 다시 반복할지 여부
    RetryCount = 3; -- 데이터 리로드 횟수
    RetryDelay = 5; -- 리로드 할때마다 기다릴 시간(초)

    Debug = false; -- 디버그 메세지 출력여부

    AutoRetryOnConnectFail = true; -- 로블록스의 Data Store Api와의 연결에 실패했을때
    ReconnectCount = 5; -- 연결 재시도 횟수
    ReconnectDelay = 1; -- 연결을 재시도 할때마다 기다릴 시간(초)

    ConnectFailKickMessage = [[
        로블록스의 Data Store Api와의 연결에 실패했습니다. 로블록스 서버의 상태를 확인해주세요.
        Connect to Roblox's Data Store Api failed. Please check roblox's servers' status.
    ]]; -- 로블록스 데이터 스토어 서비스와 연결이 실패해서 유저를 킥하게 될때 띄울 메세지

    KickPlayerOnFail = true; -- 데이터 로드 실패했을때 킥 할지 여부 (꺼져있으면 디폴트 데이터로 바뀜)
    KickMessage = [[
        데이터 로드에 실패했습니다. 데이터 보호를 위해 강제퇴장 되었습니다.
        Data load failed. Due to data protection reasons, you were kicked.
        ]]; -- 킥할때 띄울 메세지

    StoreName = "PlayerData"; -- 저장할 스토어 이름
    StoreVersion = "1"; -- 꼭 숫자 아니고 "Demo" 이런식으로도 됨. 아니면 스토어값 초기화 하거나 바꿀때 쓰는값

    SaveInStudio = false; -- 스튜디오 안에서도 스토어의 변경을 저장할지 여부 ("게임설정 => Security => Enable Studio Access to API Services" 이거가 켜져있어야 작동됨)
    LoadDefaultDataInStudio = false; -- SaveInStudio가 꺼져있을때만 작동됨, 스튜디오에서 게임 시작시 기본 데이터를 불러옴
}

return table.freeze(Settings)