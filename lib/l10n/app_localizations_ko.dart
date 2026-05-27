// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get close => '닫기';

  @override
  String get retry => '재시도';

  @override
  String get save => '저장';

  @override
  String get required => '필수';

  @override
  String get notes => '메모';

  @override
  String get email => '이메일';

  @override
  String get phone => '전화';

  @override
  String get remove => '제거';

  @override
  String get notSet => '미설정';

  @override
  String failed(String error) {
    return '실패: $error';
  }

  @override
  String comingSoon(String feature) {
    return '$feature — 곧 출시';
  }

  @override
  String get settingsTitle => '설정';

  @override
  String get languageSectionTitle => '언어';

  @override
  String get selectLanguageTitle => '언어 선택';

  @override
  String get systemDefault => '시스템 기본값';

  @override
  String get themeSectionTitle => '외관';

  @override
  String get themeSystem => '시스템 기본값';

  @override
  String get themeLight => '밝게';

  @override
  String get themeDark => '어둡게';

  @override
  String get accountSectionTitle => '계정';

  @override
  String get changePasswordTitle => '비밀번호 변경';

  @override
  String get currentPassword => '현재 비밀번호';

  @override
  String get newPassword => '새 비밀번호';

  @override
  String get confirmNewPassword => '새 비밀번호 확인';

  @override
  String get updatePassword => '비밀번호 업데이트';

  @override
  String get passwordUpdated => '비밀번호가 업데이트되었습니다';

  @override
  String get currentPasswordIncorrect => '현재 비밀번호가 올바르지 않습니다';

  @override
  String get passwordMinLength => '8자 이상';

  @override
  String get passwordsDoNotMatch => '비밀번호가 일치하지 않습니다';

  @override
  String get deleteAccountTitle => '계정 삭제';

  @override
  String get deleteAccountWarning =>
      '계정과 모든 데이터가 영구적으로 삭제됩니다. 이 작업은 취소할 수 없습니다.';

  @override
  String get deleteAccountInstructions =>
      '계정을 삭제하려면 고객 지원에 문의하세요. 48시간 이내에 처리해 드립니다.';

  @override
  String get supportEmail => 'support@tripplanner.app';

  @override
  String get emailCopied => '이메일이 클립보드에 복사되었습니다';

  @override
  String get copyEmail => '이메일 복사';

  @override
  String get aboutSectionTitle => '정보';

  @override
  String get appVersion => '앱 버전';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get termsOfService => '서비스 약관';

  @override
  String get myProfile => '내 프로필';

  @override
  String get failedToLoadProfile => '프로필을 불러오지 못했습니다';

  @override
  String get settingsTooltip => '설정';

  @override
  String get editProfileTooltip => '프로필 편집';

  @override
  String get personalInfoSection => '개인 정보';

  @override
  String get fullName => '성명';

  @override
  String get fullNameHint => '성명을 입력하세요';

  @override
  String get jobTitle => '직함';

  @override
  String get jobTitleHint => '예: 여행 애호가';

  @override
  String get contactInfoSection => '연락처 정보';

  @override
  String get managedByAccount => '계정으로 관리됨';

  @override
  String get memberSince => '가입일';

  @override
  String get saveChanges => '변경사항 저장';

  @override
  String get signOut => '로그아웃';

  @override
  String get chooseFromLibrary => '사진 보관함에서 선택';

  @override
  String get takePhoto => '사진 촬영';

  @override
  String get removePhoto => '사진 삭제';

  @override
  String uploadFailed(String error) {
    return '업로드 실패: $error';
  }

  @override
  String get uploadRequiresConnection => '업로드에는 인터넷 연결이 필요합니다';

  @override
  String get photoUpdated => '사진이 업데이트되었습니다';

  @override
  String get removeRequiresConnection => '사진 삭제에는 인터넷 연결이 필요합니다';

  @override
  String removeFailed(String error) {
    return '삭제 실패: $error';
  }

  @override
  String get profileSaved => '프로필이 저장되었습니다';

  @override
  String profileSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get signOutConfirmTitle => '로그아웃하시겠습니까?';

  @override
  String get signOutConfirmMessage => '로그인 화면으로 돌아갑니다.';

  @override
  String get nameTooLong => '이름이 너무 깁니다';

  @override
  String get appTitle => '여행 플래너';

  @override
  String get signInToAccount => '계정에 로그인';

  @override
  String get planNextAdventure => '다음 여행을 계획하세요';

  @override
  String get signIn => '로그인';

  @override
  String get signUp => '회원가입';

  @override
  String get createAccount => '계정 만들기';

  @override
  String get dontHaveAccount => '계정이 없으신가요?';

  @override
  String get alreadyHaveAccount => '이미 계정이 있으신가요?';

  @override
  String get password => '비밀번호';

  @override
  String get enterValidEmail => '유효한 이메일을 입력하세요';

  @override
  String get passwordTooShort => '비밀번호가 너무 짧습니다';

  @override
  String get enterYourName => '이름을 입력하세요';

  @override
  String get passwordMinimum6 => '최소 6자';

  @override
  String get confirmPassword => '비밀번호 확인';

  @override
  String get rememberMe => '로그인 유지';

  @override
  String get myTrips => '내 여행';

  @override
  String get all => '전체';

  @override
  String get upcoming => '예정';

  @override
  String get past => '지난';

  @override
  String get deleteTripTitle => '여행을 삭제하시겠습니까?';

  @override
  String deleteTripMessage(String tripTitle) {
    return '\"$tripTitle\"을(를) 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.';
  }

  @override
  String get couldNotLoadTrips => '여행을 불러올 수 없습니다';

  @override
  String get noTripsYet => '아직 여행이 없습니다';

  @override
  String get noTripsHint => '+ 를 탭하여 시작하세요.';

  @override
  String get noUpcomingTrips => '예정된 여행이 없습니다';

  @override
  String get noUpcomingTripsHint => '+ 를 탭하여 다음 여행을 계획하세요.';

  @override
  String get noPastTrips => '지난 여행이 없습니다';

  @override
  String get noPastTripsHint => '완료된 여행이 여기에 표시됩니다.';

  @override
  String get editTrip => '여행 편집';

  @override
  String get newTrip => '새 여행';

  @override
  String get tripTitle => '여행 제목';

  @override
  String get startingFromLabel => '출발지 (선택)';

  @override
  String get destinationLabel => '목적지';

  @override
  String get notesOptional => '메모 (선택)';

  @override
  String get startLabel => '시작';

  @override
  String get endLabel => '종료';

  @override
  String get setStartDateTime => '시작 날짜 및 시간 설정';

  @override
  String get setEndDateTime => '종료 날짜 및 시간 설정';

  @override
  String get endDateAfterStart => '종료 날짜는 시작 날짜 이후여야 합니다.';

  @override
  String get stopsSection => '경유지';

  @override
  String get addStop => '경유지 추가';

  @override
  String get noStopsYet => '아직 경유지가 없습니다.';

  @override
  String get mapSection => '지도';

  @override
  String get membersSection => '멤버';

  @override
  String get addMember => '멤버 추가';

  @override
  String get fullNameLabel => '이름';

  @override
  String get emailOptional => '이메일 (선택)';

  @override
  String get phoneOptional => '전화 (선택)';

  @override
  String get saveTrip => '여행 저장';

  @override
  String get you => '나';

  @override
  String get organizer => '주최자';

  @override
  String get member => '멤버';

  @override
  String get tripNotFound => '여행을 찾을 수 없습니다';

  @override
  String get editTripTooltip => '여행 편집';

  @override
  String get overview => '개요';

  @override
  String get itinerary => '일정';

  @override
  String get mapTab => '지도';

  @override
  String get startingFrom => '출발지';

  @override
  String get destination => '목적지';

  @override
  String get noStopsInItinerary => '아직 경유지가 없습니다';

  @override
  String get addFirstStop => '+ 를 탭하여 첫 번째 경유지를 추가하세요.';

  @override
  String get removeStopTitle => '경유지를 삭제하시겠습니까?';

  @override
  String removeStopMessage(String stopTitle) {
    return '일정에서 \"$stopTitle\"을(를) 삭제하시겠습니까?';
  }

  @override
  String get arrive => '도착';

  @override
  String get depart => '출발';

  @override
  String get stopTitleLabel => '제목';

  @override
  String get addressOptional => '주소 (선택)';

  @override
  String get arriveLabel => '도착';

  @override
  String get departLabel => '출발';

  @override
  String get addStopButton => '경유지 추가';

  @override
  String get editStop => '경유지 편집';

  @override
  String get navTrips => '여행';

  @override
  String get navJournal => '일지';

  @override
  String get navProfile => '프로필';

  @override
  String get journalComingSoon => '일지 기능 출시 예정';

  @override
  String get memberSearching => '검색 중…';

  @override
  String get memberAccountFound => '계정을 찾았습니다';

  @override
  String get memberNoAccountFound => '계정을 찾을 수 없습니다';

  @override
  String get memberLinkedAccount => '연결된 계정';

  @override
  String get invitePending => '대기 중';

  @override
  String get inviteAccepted => '수락됨';

  @override
  String get inviteDeclined => '거절됨';

  @override
  String tripInvitationsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '여행 초대 $count건',
    );
    return '$_temp0';
  }

  @override
  String get acceptInvite => '수락';

  @override
  String get declineInvite => '거절';

  @override
  String get inviteNotifTitle => '여행 초대';

  @override
  String inviteNotifBody(String tripTitle) {
    return '$tripTitle에 초대받으셨습니다';
  }
}
