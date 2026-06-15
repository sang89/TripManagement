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
  String get continueWithGoogle => 'Google로 계속하기';

  @override
  String get continueWithApple => 'Apple로 계속하기';

  @override
  String get orSignInWith => '또는';

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
    return '$tripTitle을(를) 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.';
  }

  @override
  String get leave => '나가기';

  @override
  String get leaveTripTooltip => '여행 나가기';

  @override
  String get thisTripFallback => '이 여행';

  @override
  String get leaveTripTitle => '여행에서 나가시겠습니까?';

  @override
  String leaveTripMessage(String tripTitle) {
    return '$tripTitle에서 제거되고 접근 권한을 잃게 됩니다.';
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
  String get selectFriendOptional => '친구 선택 (선택사항)';

  @override
  String get searchFriends => '친구 검색…';

  @override
  String get invitePending => '대기 중';

  @override
  String get inviteAccepted => '수락됨';

  @override
  String get inviteDeclined => '거절됨';

  @override
  String get memberLeft => '탈퇴함';

  @override
  String invitedBy(String name) {
    return '$name님이 초대함';
  }

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

  @override
  String get blockReinviteLabel => '이 여행에 대한 향후 초대 허용 안 함';

  @override
  String get reinviteBlockedError => '이 사용자는 이 여행에 대한 향후 초대를 거부했습니다';

  @override
  String get resendInvite => '초대 재전송';

  @override
  String inviteResentTo(String name) {
    return '$name에게 초대를 다시 보냈습니다';
  }

  @override
  String get declineInviteConfirmTitle => '초대 거절?';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return '«$tripTitle» 초대를 거절하시겠습니까? 접근 권한을 잃게 됩니다.';
  }

  @override
  String get securitySectionTitle => '보안';

  @override
  String get biometricToggleTitle => 'Face ID / Touch ID';

  @override
  String get biometricToggleSubtitle => '생체 인식으로 앱 잠금 해제';

  @override
  String get biometricLockTitle => '본인 확인';

  @override
  String get biometricLockSubtitle => '계정에 접근하려면 인증하세요';

  @override
  String get biometricSignInWithFace => 'Face ID로 로그인';

  @override
  String get biometricSignInWithFingerprint => '지문으로 로그인';

  @override
  String get biometricSignInWithBiometrics => '생체 인식으로 로그인';

  @override
  String get biometricReason => '계정에 접근하려면 인증하세요';

  @override
  String get biometricFailed => '인증에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get usePasswordInstead => '비밀번호 사용';

  @override
  String get navFriends => '친구';

  @override
  String get friendsTabFriends => '친구';

  @override
  String get friendsTabRequests => '요청';

  @override
  String get friendsAddFriend => '친구 추가';

  @override
  String get friendsSearchHint => '이름, 이메일 또는 전화번호로 검색';

  @override
  String get friendsNoResults => '사용자를 찾을 수 없습니다';

  @override
  String get friendsRequestSent => '친구 요청을 보냈습니다';

  @override
  String get friendsAccept => '수낙';

  @override
  String get friendsDecline => '거절';

  @override
  String get friendsRemove => '친구 삭제';

  @override
  String friendsRemoveConfirm(String name) {
    return '$name을(를) 친구 목록에서 삭제하시겠습니까?';
  }

  @override
  String get friendsNoFriends => '아직 친구가 없습니다';

  @override
  String get friendsNoFriendsHint => '친구로 추가할 사람을 검색하세요.';

  @override
  String get friendsNoRequests => '대기 중인 요청이 없습니다';

  @override
  String get friendsIncomingSection => '받은 요청';

  @override
  String get friendsOutgoingSection => '보낸 요청';

  @override
  String get friendsCancelRequest => '요청 취소';

  @override
  String get chatTabLabel => '체팅';

  @override
  String get chatSendHint => '메시지…';

  @override
  String get chatNoMessages => '아직 메시지가 없습니다. 인사해 보세요!';

  @override
  String get chatSend => '전송';

  @override
  String get notificationsSectionTitle => '알림';

  @override
  String get mentionNotifToggleTitle => '멘션 알림';

  @override
  String get mentionNotifToggleSubtitle => '여행 채팅에서 @멘션될 때 알림 받기';

  @override
  String get privacySectionTitle => '개인 정보';

  @override
  String get blockedUsersTitle => '차단된 사용자';

  @override
  String get blockedUsersEmpty => '차단한 사용자가 없습니다';

  @override
  String get blockUser => '차단';

  @override
  String get unblockUser => '차단 해제';

  @override
  String blockConfirmTitle(String name) {
    return '$name을(를) 차단할까요?';
  }

  @override
  String get blockConfirmBody => '이 사람은 더 이상 당신을 여행에 추가하거나 친구 요청을 보낼 수 없습니다.';

  @override
  String blockSuccess(String name) {
    return '$name이(가) 차단되었습니다';
  }

  @override
  String unblockSuccess(String name) {
    return '$name의 차단이 해제되었습니다';
  }

  @override
  String get contactsButton => '연락처에서';

  @override
  String get contactsScreenTitle => '연락처에서 찾기';

  @override
  String get contactsPermissionDenied =>
      'TripManagement에서 친구를 찾으려면 연락처 접근이 필요합니다.';

  @override
  String get contactsOpenSettings => '설정 열기';

  @override
  String get contactsOnApp => 'TripManagement 사용 중';

  @override
  String get contactsInviteSection => 'TripManagement에 초대';

  @override
  String get contactsEmpty => '전화번호나 이메일이 있는 연락처를 찾을 수 없습니다.';

  @override
  String get contactsAddFriend => '추가';

  @override
  String get contactsPending => '대기 중';

  @override
  String get contactsInvite => '초대';

  @override
  String contactsInviteMessage(String name) {
    return '안녕 $name! TripManagement로 함께 여행을 계획해요. 여기서 참여하세요: [APP_STORE_LINK]';
  }

  @override
  String get navEvents => 'Events';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get editEventSubtitle => '세부 정보, 날짜 또는 위치 업데이트';

  @override
  String get saveEvent => 'Save event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventDescription => 'Description (optional)';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventCapacity => '최대 멤버 수 (선택)';

  @override
  String get eventStartDateTime => 'Start date & time';

  @override
  String get eventEndDateTime => 'End date & time (optional)';

  @override
  String get noEventsYet => 'No events yet. Tap + to create one.';

  @override
  String get noUpcomingEvents => '예정된 이벤트가 없습니다';

  @override
  String get noUpcomingEventsHint => '+ 를 눌러 다음 이벤트를 계획하세요.';

  @override
  String get noPastEvents => '아직 지난 이벤트가 없습니다';

  @override
  String get noPastEventsHint => '참여한 이벤트가 여기에 표시됩니다.';

  @override
  String get filterAll => '전체';

  @override
  String get calendarViewToggle => '캘린더';

  @override
  String get listViewToggle => '목록';

  @override
  String get noEventsOnDay => '이 날에 이벤트가 없습니다';

  @override
  String get myEvents => 'My events';

  @override
  String get invitedEvents => 'Invited';

  @override
  String get infoTab => '정보';

  @override
  String get guestsTab => '멤버';

  @override
  String get noGuestsYet => '아직 멤버가 없습니다. +를 눌러 추가하세요.';

  @override
  String get addGuest => '멤버 추가';

  @override
  String get photosTab => 'Photos';

  @override
  String get expensesTab => 'Expenses';

  @override
  String get rsvpGoing => 'Going';

  @override
  String get rsvpMaybe => 'Maybe';

  @override
  String get rsvpDeclined => 'Can\'t go';

  @override
  String get changeRsvp => 'Change RSVP';

  @override
  String goingCount(int count) {
    return '$count going';
  }

  @override
  String maybeCount(int count) {
    return '$count maybe';
  }

  @override
  String declinedCount(int count) {
    return '$count can\'t go';
  }

  @override
  String get shareEvent => 'Share event';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get noPhotosYet => 'No photos yet.';

  @override
  String get deletePhoto => 'Delete photo';

  @override
  String get deletePhotoConfirm => 'Delete this photo?';

  @override
  String get addExpense => 'Add expense';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get deleteExpenseTitle => 'Delete expense';

  @override
  String deleteExpenseMessage(String description) {
    return 'Delete \"$description\"? This cannot be undone.';
  }

  @override
  String get noExpensesYet => '아직 지출이 없습니다';

  @override
  String get expenseDescription => 'What was paid for?';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get splitAmong => '멤버 간 분할';

  @override
  String get paidBy => '지불자';

  @override
  String get selectAll => '모두 선택';

  @override
  String get deselectAll => '모두 해제';

  @override
  String totalOwed(String amount) {
    return 'You owe: $amount';
  }

  @override
  String youAreOwed(String amount) {
    return '받을 금액: $amount';
  }

  @override
  String get settleUp => '정산하기';

  @override
  String get totalSpent => '총 지출';

  @override
  String get theScore => '스코어';

  @override
  String get settlementPlan => '정산 계획';

  @override
  String get allSquare => '모두 정산됐어요! 🎉';

  @override
  String get eventFull => 'This event is at capacity.';

  @override
  String get publicRsvpTitle => 'You\'re invited!';

  @override
  String get publicRsvpName => 'Your name';

  @override
  String get publicRsvpEmail => 'Email (optional)';

  @override
  String get publicRsvpPhone => 'Phone (optional)';

  @override
  String get rsvpSuccess => 'Your RSVP was saved!';

  @override
  String get rsvpNoteHint => '메모 추가 (선택사항)';

  @override
  String get organizeTab => '정리';

  @override
  String get detailsTab => '세부 정보';

  @override
  String get todoTab => '할 일';

  @override
  String get cravingsTab => '먹고싶은것';

  @override
  String get pollsTab => '투표';

  @override
  String get pollsEmpty => '아직 투표가 없습니다.';

  @override
  String get pollsAddPoll => '투표 추가';

  @override
  String get pollsQuestion => '질문';

  @override
  String pollsOptionHint(int n) {
    return '옵션 $n';
  }

  @override
  String get pollsAddOption => '+ 옵션 추가';

  @override
  String pollsVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count표',
      one: '1표',
    );
    return '$_temp0';
  }

  @override
  String get pollsDeletePoll => '투표 삭제';

  @override
  String get bringListTitle => '할 일';

  @override
  String get bringListEmpty => '할 일 없음. 추가하세요.';

  @override
  String get bringListAddItem => '할 일 추가';

  @override
  String get bringListEditItem => '작업 편집';

  @override
  String get bringListItemLabel => '무엇을 할지';

  @override
  String get bringListNote => '메모 (선택)';

  @override
  String get bringListAssignTo => '멤버에게 할당';

  @override
  String get bringListNoAssignment => '미할당';

  @override
  String get bringListTake => '맡기';

  @override
  String get bringListUnassign => '할당 취소';

  @override
  String get rsvpNoteLabel => '메모';

  @override
  String get confirmRsvp => '확인';

  @override
  String get foodMoodTitle => '얼마나 배가 고프세요?';

  @override
  String get foodMoodStarving => '배고파 죽겠어';

  @override
  String get foodMoodCouldEat => '먹을 수 있어';

  @override
  String get foodMoodDrinksOnly => '음료만';

  @override
  String get foodMoodNibble => '조금만 먹을게';

  @override
  String get foodMoodDDMode => '지정 운전자';

  @override
  String get cravingsPrompt => '뭐가 먹고 싶어요?';

  @override
  String get cravingsHint => '매운 라멘, 아늑한 분위기, 20,000원 이하...';

  @override
  String get cravingsPrivacyNote => '나만 볼 수 있어요';

  @override
  String get cravingsFindButton => '장소 찾기';

  @override
  String get cravingsEmpty => '결과가 없어요. 다른 키워드를 시도해보세요.';

  @override
  String get cravingsPitchButton => '그룹에 제안';

  @override
  String get cravingsPitched => '그룹 투표에 추가됐어요!';

  @override
  String get restaurantPollTitle => '장소 선택';

  @override
  String get addRestaurantOption => '식당 추가';

  @override
  String get restaurantSearchHint => '식당 검색...';

  @override
  String get setAsVenueButton => '장소로 설정';

  @override
  String organizedBy(String name) {
    return 'Organised by $name';
  }

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String get deleteEventSubtitle => '이 이벤트를 영구적으로 삭제';

  @override
  String deleteEventMessage(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get eventTypeTrip => '여행';

  @override
  String get eventTypeBirthday => '생일';

  @override
  String get eventTypeWedding => '결혼식';

  @override
  String get eventTypeSocial => '소셜';

  @override
  String get eventTypeQuickBites => '퀵 바이츠';

  @override
  String get eventTypeSignup => '신청';

  @override
  String signupSpotsFilled(int filled, int total) {
    return '$filled / $total 자리 사용 중';
  }

  @override
  String signupWaitlistCount(int count) {
    return '$count명 대기 중';
  }

  @override
  String get signupEventFull => '자리가 꽉 찼습니다';

  @override
  String get signupJoinWaitlist => '대기 명단에 등록';

  @override
  String get signupClaimSpot => '자리 확보';

  @override
  String signupConfirmedPosition(int pos) {
    return '목록의 #$pos번째입니다!';
  }

  @override
  String signupWaitlistPosition(int pos) {
    return '대기 명단 #$pos번째입니다';
  }

  @override
  String get signupWaitlistEnabled => '대기 명단 활성화';

  @override
  String get signupWaitlistDescription => '정원 초과 게스트는 순서가 있는 대기 명단에 추가됩니다';

  @override
  String get signupRosterTab => '명단';

  @override
  String get signupInviteTab => '초대';

  @override
  String get signupPromoteGuest => '확정으로 승격';

  @override
  String get signupRemoveGuest => '이벤트에서 제거';

  @override
  String get signupCopyLink => '초대 링크 복사';

  @override
  String get signupShowQr => 'QR 코드 보기';

  @override
  String get signupLocked => '신청이 마감되었습니다';

  @override
  String get signupLockedMessage => '신청이 마감되었습니다. 주최자에게 문의하세요.';

  @override
  String get signupPendingReview => '요청이 승인 대기 중입니다';

  @override
  String get signupCancelSpot => '자리 취소';

  @override
  String get signupMarkAttended => '출석';

  @override
  String get signupMarkNoShow => '결석';

  @override
  String get signupAttendanceHeader => '출석';

  @override
  String get signupRepeat => '반복';

  @override
  String get signupRepeatNone => '없음';

  @override
  String get signupRepeatWeekly => '매주';

  @override
  String get signupRepeatBiweekly => '격주';

  @override
  String get signupRepeatMonthly => '매월';

  @override
  String get signupNextSession => '다음 세션 만들기';

  @override
  String get signupCarryOverGuests => '확정 게스트 자동 등록';

  @override
  String get signupCarryOverGuestsHint => '게스트에게 알림이 전송되며 취소할 수 있습니다';

  @override
  String signupPartOfSeries(String interval) {
    return '$interval 시리즈의 일부';
  }

  @override
  String get eventTypePicker => '이벤트 유형';

  @override
  String get routeTab => '경로';

  @override
  String get leaveEventTitle => '이벤트를 떠나시겠습니까?';

  @override
  String leaveEventMessage(String eventTitle) {
    return '$eventTitle에서 제거되고 접근 권한을 잃게 됩니다.';
  }

  @override
  String get generateWithAi => 'AI Assistant';

  @override
  String get aiTripPlannerSubtitle => '목적지에 대해 질문하거나 스타일을 설명해 일정에 장소를 추가하세요.';

  @override
  String get aiChatHint => '여행에 대해 무엇이든 물어보세요...';

  @override
  String get tierFree => 'Basic';

  @override
  String get tierPro => '프로';

  @override
  String tierProTrial(String date) {
    return 'Pro 체험 · $date 종료';
  }

  @override
  String get cancelTrial => '체험 취소';

  @override
  String get cancelTrialConfirmTitle => '무료 체험을 취소하시겠어요?';

  @override
  String get cancelTrialConfirmMessage =>
      'Pro 기능에 대한 접근이 즉시 중단됩니다. 나중에 Pro로 업그레이드할 수 있습니다.';

  @override
  String get cancelTrialSuccess => '체험이 취소되었습니다. 현재 Basic 플랜입니다.';

  @override
  String get cancelTrialError => '체험 취소에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get upgradeToPro => '프로로 업그레이드';

  @override
  String get upgradeNow => '지금 업그레이드';

  @override
  String get proAnnualPrice => '\$39.99 / 년';

  @override
  String get proMonthlyPrice => '\$4.99 / 월';

  @override
  String get proAnnualSavings => '33% 절약';

  @override
  String get comparePlans => '플랜 비교';

  @override
  String get restorePurchases => '구매 복원';

  @override
  String get proFeatureAIPlanner => 'AI Event Assistant';

  @override
  String get proFeatureUnlimitedEvents => '무제한 이벤트 & 게스트';

  @override
  String get proFeatureExpenseExport => 'Expense export';

  @override
  String get proFeatureOfflineAccess => '오프라인 액세스';

  @override
  String get proFeatureTemplates => '이벤트 템플릿';

  @override
  String get freeEventsLimit => '이벤트 (최대 3개)';

  @override
  String get freeGuestsLimit => '게스트 (최대 10명)';

  @override
  String get freeBasicPlanning => 'RSVP & 기본 계획';

  @override
  String get budgetPerHeadLabel => '1인당 예산 (선택)';

  @override
  String get cuisineTagsLabel => '요리 종류';

  @override
  String get rsvpDeadlineLabel => 'RSVP 마감일';

  @override
  String get rsvpDeadlineClosed => 'RSVP 마감';

  @override
  String get vibePickerLabel => '분위기 (선택)';

  @override
  String get honoreeNameLabel => '누구의 생일인가요?';

  @override
  String get honoreeNameHint => '이름을 입력하세요';

  @override
  String get birthYearLabel => '출생 연도 (선택)';

  @override
  String get birthYearHint => '예: 1996';

  @override
  String get celebrateTab => '파티';

  @override
  String get giftsTab => '선물';

  @override
  String get memoriesTab => '추억';

  @override
  String birthdayHeroTitle(String name) {
    return '$name의 생일';
  }

  @override
  String turningAge(int age) {
    return '$age살이 됩니다';
  }

  @override
  String birthdayCountdownDays(int count) {
    return '$count일 남았어요';
  }

  @override
  String birthdayCountdownHours(int count) {
    return '$count시간 남았어요';
  }

  @override
  String get birthdayToday => '오늘이 그날이에요!';

  @override
  String activityVoteTitle(String name) {
    return '$name의 파티에서 뭘 할까요?';
  }

  @override
  String get activityVoteEmpty => '아직 활동이 없습니다.';

  @override
  String get addActivityOption => '활동 추가';

  @override
  String cakeVoteTitle(String name) {
    return '$name는 어떤 케이크를 원할까요?';
  }

  @override
  String get cakeVoteEmpty => '아직 케이크 옵션이 없습니다.';

  @override
  String get addCakeOption => '맛 추가';

  @override
  String wishlistTitle(String name) {
    return '$name의 위시리스트';
  }

  @override
  String wishlistEmpty(String name) {
    return '아직 항목이 없습니다. $name이 좋아할 것을 추가해보세요!';
  }

  @override
  String get addWishlistItem => '선물 아이디어 추가';

  @override
  String get wishlistItemLabel => '선물 아이디어';

  @override
  String get wishlistPriceRange => '가격대 (선택)';

  @override
  String get wishlistLink => '링크 (선택)';

  @override
  String get claimItem => '내가 할게요!';

  @override
  String get unclaimItem => '취소';

  @override
  String get itemClaimed => '누군가 담당 중';

  @override
  String itemClaimedBy(String name) {
    return '$name이 담당 중';
  }

  @override
  String get markReceived => '수령 완료 표시';

  @override
  String get giftPoolTitle => '공동 선물';

  @override
  String get giftPoolEmpty => '아직 공동 선물이 없습니다.';

  @override
  String get createGiftPool => '공동 선물 시작';

  @override
  String get giftPoolName => '선물 이름';

  @override
  String get giftPoolTarget => '목표 금액';

  @override
  String giftPoolProgress(String pledged, String target) {
    return '$target 중 $pledged 약속됨';
  }

  @override
  String giftPoolContributors(int count) {
    return '$count명 참여';
  }

  @override
  String get pledgeAmount => '약속 금액';

  @override
  String get addPledge => '참여하기';

  @override
  String get myPledge => '내 약속';

  @override
  String get removePledge => '약속 취소';

  @override
  String predictionsTitle(String name) {
    return '$name에 대한 예언';
  }

  @override
  String predictionsSealed(int count) {
    return '$count개 예언 봉인 중';
  }

  @override
  String get revealPredictions => '예언 공개';

  @override
  String get predictionsHowItWorks =>
      '예측은 이벤트 날짜까지 잠겨 있습니다 — 그 후 누가 맞혔는지 알게 됩니다!';

  @override
  String predictionsEmpty(String name) {
    return '$name에 대한 예언이 아직 없습니다.';
  }

  @override
  String get addPrediction => '예언 추가';

  @override
  String predictionHint(String name) {
    return '$name의 내년에 대해 예언해보세요...';
  }

  @override
  String wishesTitle(String name) {
    return '$name에게 보내는 소원';
  }

  @override
  String wishesSealed(String name) {
    return '$name은 아직 볼 수 없어요';
  }

  @override
  String get wishesHowItWorks => '소원은 주최자가 특별한 날에 공개할 때까지 비밀로 유지됩니다!';

  @override
  String get wishesEmpty => '아직 소원이 없습니다. 첫 번째가 되세요!';

  @override
  String get addWish => '소원 보내기';

  @override
  String wishHint(String name) {
    return '$name에게 소원을 써보세요...';
  }

  @override
  String get blowOutCandles => '초를 끄세요!';

  @override
  String get wishesRevealed => '소원이 공개되었습니다!';

  @override
  String memoryWallTitle(String name) {
    return '$name의 추억 벽';
  }

  @override
  String memoryWallEmpty(String name) {
    return '$name과의 추억을 공유해보세요!';
  }

  @override
  String get addMemory => '추억 추가';

  @override
  String memoryCaptionHint(String name) {
    return '$name과의 가장 좋은 추억을 적어주세요...';
  }

  @override
  String get toastsTitle => '축사 & 스피치';

  @override
  String toastsEmpty(String name) {
    return '$name을 위한 축사가 아직 없습니다.';
  }

  @override
  String get addToast => '축사 작성';

  @override
  String get toastTypeSweet => '감동적';

  @override
  String get toastTypeFunny => '재미있는';

  @override
  String get toastTypePoem => '시';

  @override
  String get toastTextHint => '여기에 스피치를 작성해주세요...';

  @override
  String get exportToasts => '스피치 내보내기';

  @override
  String get wishesTab => '소원';

  @override
  String get predictionsTab => '예언';

  @override
  String get wallTab => '추억 벽';

  @override
  String get pleaseSelectEventType => '이벤트 유형을 선택해 주세요';

  @override
  String get notifications => '알림';

  @override
  String get notificationsEmpty => '모두 확인했습니다!';

  @override
  String get notificationsMarkAllRead => '모두 읽음으로 표시';
}
