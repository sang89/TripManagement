// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get cancel => 'Hủy';

  @override
  String get delete => 'Xóa';

  @override
  String get close => 'Đóng';

  @override
  String get retry => 'Thử lại';

  @override
  String get save => 'Lưu';

  @override
  String get required => 'Bắt buộc';

  @override
  String get notes => 'Ghi chú';

  @override
  String get email => 'Email';

  @override
  String get phone => 'Số điện thoại';

  @override
  String get remove => 'Xóa';

  @override
  String get notSet => 'Chưa đặt';

  @override
  String failed(String error) {
    return 'Thất bại: $error';
  }

  @override
  String comingSoon(String feature) {
    return '$feature — Sắp ra mắt';
  }

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get languageSectionTitle => 'Ngôn ngữ';

  @override
  String get selectLanguageTitle => 'Chọn ngôn ngữ';

  @override
  String get systemDefault => 'Mặc định hệ thống';

  @override
  String get themeSectionTitle => 'Giao diện';

  @override
  String get themeSystem => 'Mặc định hệ thống';

  @override
  String get themeLight => 'Sáng';

  @override
  String get themeDark => 'Tối';

  @override
  String get accountSectionTitle => 'Tài khoản';

  @override
  String get changePasswordTitle => 'Đổi mật khẩu';

  @override
  String get currentPassword => 'Mật khẩu hiện tại';

  @override
  String get newPassword => 'Mật khẩu mới';

  @override
  String get confirmNewPassword => 'Xác nhận mật khẩu mới';

  @override
  String get updatePassword => 'Cập nhật mật khẩu';

  @override
  String get passwordUpdated => 'Mật khẩu đã được cập nhật';

  @override
  String get currentPasswordIncorrect => 'Mật khẩu hiện tại không đúng';

  @override
  String get passwordMinLength => 'Ít nhất 8 ký tự';

  @override
  String get passwordsDoNotMatch => 'Mật khẩu không khớp';

  @override
  String get deleteAccountTitle => 'Xóa tài khoản';

  @override
  String get deleteAccountWarning =>
      'Thao tác này sẽ xóa vĩnh viễn tài khoản và toàn bộ dữ liệu của bạn. Không thể hoàn tác.';

  @override
  String get deleteAccountInstructions =>
      'Để xóa tài khoản, vui lòng liên hệ bộ phận hỗ trợ. Chúng tôi sẽ xử lý yêu cầu trong vòng 48 giờ.';

  @override
  String get supportEmail => 'support@tripplanner.app';

  @override
  String get emailCopied => 'Đã sao chép email vào bộ nhớ tạm';

  @override
  String get copyEmail => 'Sao chép email';

  @override
  String get aboutSectionTitle => 'Giới thiệu';

  @override
  String get appVersion => 'Phiên bản ứng dụng';

  @override
  String get privacyPolicy => 'Chính sách bảo mật';

  @override
  String get termsOfService => 'Điều khoản dịch vụ';

  @override
  String get myProfile => 'Hồ sơ của tôi';

  @override
  String get failedToLoadProfile => 'Không thể tải hồ sơ';

  @override
  String get settingsTooltip => 'Cài đặt';

  @override
  String get editProfileTooltip => 'Chỉnh sửa hồ sơ';

  @override
  String get personalInfoSection => 'Thông tin cá nhân';

  @override
  String get fullName => 'Họ và tên';

  @override
  String get fullNameHint => 'Họ và tên của bạn';

  @override
  String get jobTitle => 'Chức danh';

  @override
  String get jobTitleHint => 'vd: Người yêu du lịch';

  @override
  String get contactInfoSection => 'Thông tin liên hệ';

  @override
  String get managedByAccount => 'Được quản lý bởi tài khoản của bạn';

  @override
  String get memberSince => 'Thành viên từ';

  @override
  String get saveChanges => 'Lưu thay đổi';

  @override
  String get signOut => 'Đăng xuất';

  @override
  String get chooseFromLibrary => 'Chọn từ thư viện';

  @override
  String get takePhoto => 'Chụp ảnh';

  @override
  String get removePhoto => 'Xóa ảnh';

  @override
  String uploadFailed(String error) {
    return 'Tải lên thất bại: $error';
  }

  @override
  String get uploadRequiresConnection => 'Cần kết nối để tải lên';

  @override
  String get photoUpdated => 'Ảnh đã được cập nhật';

  @override
  String get removeRequiresConnection => 'Cần kết nối để xóa ảnh';

  @override
  String removeFailed(String error) {
    return 'Xóa thất bại: $error';
  }

  @override
  String get profileSaved => 'Đã lưu hồ sơ';

  @override
  String profileSaveFailed(String error) {
    return 'Lưu thất bại: $error';
  }

  @override
  String get signOutConfirmTitle => 'Đăng xuất?';

  @override
  String get signOutConfirmMessage =>
      'Bạn sẽ được chuyển về màn hình đăng nhập.';

  @override
  String get nameTooLong => 'Tên quá dài';

  @override
  String get appTitle => 'Lập kế hoạch chuyến đi';

  @override
  String get signInToAccount => 'Đăng nhập vào tài khoản';

  @override
  String get planNextAdventure => 'Lên kế hoạch cho chuyến phiêu lưu tiếp theo';

  @override
  String get signIn => 'Đăng nhập';

  @override
  String get signUp => 'Đăng ký';

  @override
  String get createAccount => 'Tạo tài khoản';

  @override
  String get dontHaveAccount => 'Chưa có tài khoản?';

  @override
  String get alreadyHaveAccount => 'Đã có tài khoản?';

  @override
  String get password => 'Mật khẩu';

  @override
  String get enterValidEmail => 'Nhập email hợp lệ';

  @override
  String get passwordTooShort => 'Mật khẩu quá ngắn';

  @override
  String get enterYourName => 'Nhập tên của bạn';

  @override
  String get passwordMinimum6 => 'Tối thiểu 6 ký tự';

  @override
  String get confirmPassword => 'Xác nhận mật khẩu';

  @override
  String get rememberMe => 'Ghi nhớ đăng nhập';

  @override
  String get continueWithGoogle => 'Tiếp tục với Google';

  @override
  String get continueWithApple => 'Tiếp tục với Apple';

  @override
  String get orSignInWith => 'hoặc';

  @override
  String get myTrips => 'Chuyến đi của tôi';

  @override
  String get all => 'Tất cả';

  @override
  String get upcoming => 'Sắp tới';

  @override
  String get past => 'Đã qua';

  @override
  String get deleteTripTitle => 'Xóa chuyến đi?';

  @override
  String deleteTripMessage(String tripTitle) {
    return 'Xóa $tripTitle? Không thể hoàn tác.';
  }

  @override
  String get leave => 'Rời';

  @override
  String get leaveTripTooltip => 'Rời khỏi chuyến đi';

  @override
  String get thisTripFallback => 'chuyến đi này';

  @override
  String get leaveTripTitle => 'Rời khỏi chuyến đi?';

  @override
  String leaveTripMessage(String tripTitle) {
    return 'Bạn sẽ bị xóa khỏi $tripTitle và mất quyền truy cập.';
  }

  @override
  String get couldNotLoadTrips => 'Không thể tải chuyến đi';

  @override
  String get noTripsYet => 'Chưa có chuyến đi';

  @override
  String get noTripsHint => 'Nhấn + để bắt đầu.';

  @override
  String get noUpcomingTrips => 'Không có chuyến đi sắp tới';

  @override
  String get noUpcomingTripsHint =>
      'Nhấn + để lên kế hoạch cho chuyến phiêu lưu tiếp theo.';

  @override
  String get noPastTrips => 'Không có chuyến đi đã qua';

  @override
  String get noPastTripsHint =>
      'Các chuyến đi đã hoàn thành sẽ xuất hiện ở đây.';

  @override
  String get editTrip => 'Chỉnh sửa chuyến đi';

  @override
  String get newTrip => 'Chuyến đi mới';

  @override
  String get tripTitle => 'Tiêu đề chuyến đi';

  @override
  String get startingFromLabel => 'Khởi hành từ (tùy chọn)';

  @override
  String get destinationLabel => 'Điểm đến';

  @override
  String get notesOptional => 'Ghi chú (tùy chọn)';

  @override
  String get startLabel => 'Bắt đầu';

  @override
  String get endLabel => 'Kết thúc';

  @override
  String get setStartDateTime => 'Đặt ngày giờ bắt đầu';

  @override
  String get setEndDateTime => 'Đặt ngày giờ kết thúc';

  @override
  String get endDateAfterStart => 'Ngày kết thúc phải sau ngày bắt đầu.';

  @override
  String get stopsSection => 'Điểm dừng';

  @override
  String get addStop => 'Thêm điểm dừng';

  @override
  String get noStopsYet => 'Chưa có điểm dừng.';

  @override
  String get mapSection => 'Bản đồ';

  @override
  String get membersSection => 'Thành viên';

  @override
  String get addMember => 'Thêm thành viên';

  @override
  String get fullNameLabel => 'Tên';

  @override
  String get emailOptional => 'Email (tùy chọn)';

  @override
  String get phoneOptional => 'Số điện thoại (tùy chọn)';

  @override
  String get saveTrip => 'Lưu chuyến đi';

  @override
  String get you => 'Bạn';

  @override
  String get organizer => 'Người tổ chức';

  @override
  String get member => 'Thành viên';

  @override
  String get tripNotFound => 'Không tìm thấy chuyến đi';

  @override
  String get editTripTooltip => 'Chỉnh sửa chuyến đi';

  @override
  String get overview => 'Tổng quan';

  @override
  String get itinerary => 'Lịch trình';

  @override
  String get mapTab => 'Bản đồ';

  @override
  String get startingFrom => 'Khởi hành từ';

  @override
  String get destination => 'Điểm đến';

  @override
  String get noStopsInItinerary => 'Chưa có điểm dừng';

  @override
  String get addFirstStop => 'Nhấn + để thêm điểm dừng đầu tiên.';

  @override
  String get removeStopTitle => 'Xóa điểm dừng?';

  @override
  String removeStopMessage(String stopTitle) {
    return 'Xóa \"$stopTitle\" khỏi lịch trình?';
  }

  @override
  String get arrive => 'Đến';

  @override
  String get depart => 'Rời';

  @override
  String get stopTitleLabel => 'Tiêu đề';

  @override
  String get addressOptional => 'Địa chỉ (tùy chọn)';

  @override
  String get arriveLabel => 'Đến';

  @override
  String get departLabel => 'Rời';

  @override
  String get addStopButton => 'Thêm điểm dừng';

  @override
  String get editStop => 'Chỉnh sửa điểm dừng';

  @override
  String get navTrips => 'Chuyến đi';

  @override
  String get navJournal => 'Nhật ký';

  @override
  String get navProfile => 'Hồ sơ';

  @override
  String get journalComingSoon => 'Nhật ký sắp ra mắt';

  @override
  String get memberSearching => 'Đang tìm kiếm…';

  @override
  String get memberAccountFound => 'Đã tìm thấy tài khoản';

  @override
  String get memberNoAccountFound => 'Không tìm thấy tài khoản';

  @override
  String get memberLinkedAccount => 'Tài khoản đã liên kết';

  @override
  String get selectFriendOptional => 'Chọn bạn bè (tùy chọn)';

  @override
  String get searchFriends => 'Tìm kiếm bạn bè…';

  @override
  String get invitePending => 'Đang chờ';

  @override
  String get inviteAccepted => 'Đã chấp nhận';

  @override
  String get inviteDeclined => 'Đã từ chối';

  @override
  String get memberLeft => 'Đã rời';

  @override
  String invitedBy(String name) {
    return 'Được mời bởi $name';
  }

  @override
  String tripInvitationsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lời mời chuyến đi',
      one: '1 lời mời chuyến đi',
    );
    return '$_temp0';
  }

  @override
  String get acceptInvite => 'Chấp nhận';

  @override
  String get declineInvite => 'Từ chối';

  @override
  String get inviteNotifTitle => 'Lời mời chuyến đi';

  @override
  String inviteNotifBody(String tripTitle) {
    return 'Bạn đã được mời tham gia $tripTitle';
  }

  @override
  String get blockReinviteLabel =>
      'Không cho phép lời mời trong tương lai cho chuyến đi này';

  @override
  String get reinviteBlockedError =>
      'Người dùng này đã từ chối lời mời trong tương lai cho chuyến đi này';

  @override
  String get resendInvite => 'Gửi lại lời mời';

  @override
  String inviteResentTo(String name) {
    return 'Đã gửi lại lời mời tới $name';
  }

  @override
  String get declineInviteConfirmTitle => 'Từ chối lời mời?';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return 'Từ chối lời mời tới «$tripTitle»? Bạn sẽ mất quyền truy cập.';
  }

  @override
  String get securitySectionTitle => 'Bảo mật';

  @override
  String get biometricToggleTitle => 'Face ID / Touch ID';

  @override
  String get biometricToggleSubtitle =>
      'Dùng sinh trắc học để mở khóa ứng dụng';

  @override
  String get biometricLockTitle => 'Xác minh danh tính';

  @override
  String get biometricLockSubtitle => 'Xác thực để truy cập tài khoản của bạn';

  @override
  String get biometricSignInWithFace => 'Đăng nhập bằng Face ID';

  @override
  String get biometricSignInWithFingerprint => 'Đăng nhập bằng vân tay';

  @override
  String get biometricSignInWithBiometrics => 'Đăng nhập bằng sinh trắc học';

  @override
  String get biometricReason => 'Xác thực để truy cập tài khoản của bạn';

  @override
  String get biometricFailed => 'Xác thực thất bại. Vui lòng thử lại.';

  @override
  String get usePasswordInstead => 'Dùng mật khẩu thay thế';

  @override
  String get navFriends => 'Bạn bè';

  @override
  String get friendsTabFriends => 'Bạn bè';

  @override
  String get friendsTabRequests => 'Lời mời';

  @override
  String get friendsAddFriend => 'Thêm bạn';

  @override
  String get friendsSearchHint => 'Tìm theo tên, email hoặc số điện thoại';

  @override
  String get friendsNoResults => 'Không tìm thấy người dùng';

  @override
  String get friendsRequestSent => 'Đã gửi lời mời kết bạn';

  @override
  String get friendsAccept => 'Chấp nhận';

  @override
  String get friendsDecline => 'Từ chối';

  @override
  String get friendsRemove => 'Xóa bạn';

  @override
  String friendsRemoveConfirm(String name) {
    return 'Xóa $name khỏi danh sách bạn bè?';
  }

  @override
  String get friendsNoFriends => 'Chưa có bạn bè';

  @override
  String get friendsNoFriendsHint => 'Tìm kiếm ai đó để kết bạn.';

  @override
  String get friendsNoRequests => 'Không có yêu cầu đang chờ';

  @override
  String get friendsIncomingSection => 'Nhận được';

  @override
  String get friendsOutgoingSection => 'Đã gửi';

  @override
  String get friendsCancelRequest => 'Hủy yêu cầu';

  @override
  String get chatTabLabel => 'Trò chuyện';

  @override
  String get chatSendHint => 'Tin nhắn…';

  @override
  String get chatNoMessages => 'Chưa có tin nhắn. Hãy chào nhau!';

  @override
  String get chatSend => 'Gửi';

  @override
  String get notificationsSectionTitle => 'Thông báo';

  @override
  String get mentionNotifToggleTitle => 'Cảnh báo đề cập';

  @override
  String get mentionNotifToggleSubtitle =>
      'Nhận thông báo khi bạn được @đề cập trong cuộc trò chuyện chuyến đi';

  @override
  String get privacySectionTitle => 'Quyền riêng tư';

  @override
  String get blockedUsersTitle => 'Người dùng bị chặn';

  @override
  String get blockedUsersEmpty => 'Bạn chưa chặn ai';

  @override
  String get blockUser => 'Chặn';

  @override
  String get unblockUser => 'Bỏ chặn';

  @override
  String blockConfirmTitle(String name) {
    return 'Chặn $name?';
  }

  @override
  String get blockConfirmBody =>
      'Họ sẽ không thể thêm bạn vào chuyến đi hoặc gửi lời mời kết bạn.';

  @override
  String blockSuccess(String name) {
    return '$name đã bị chặn';
  }

  @override
  String unblockSuccess(String name) {
    return '$name đã được bỏ chặn';
  }

  @override
  String get contactsButton => 'Từ danh bạ';

  @override
  String get contactsScreenTitle => 'Tìm từ danh bạ';

  @override
  String get contactsPermissionDenied =>
      'Cần quyền truy cập danh bạ để tìm bạn bè của bạn trên TripManagement.';

  @override
  String get contactsOpenSettings => 'Mở cài đặt';

  @override
  String get contactsOnApp => 'Đang dùng TripManagement';

  @override
  String get contactsInviteSection => 'Mời vào TripManagement';

  @override
  String get contactsEmpty =>
      'Không tìm thấy liên hệ nào có số điện thoại hoặc email.';

  @override
  String get contactsAddFriend => 'Thêm';

  @override
  String get contactsPending => 'Đang chờ';

  @override
  String get contactsInvite => 'Mời';

  @override
  String contactsInviteMessage(String name) {
    return 'Xin chào $name! Tôi dùng TripManagement để lên kế hoạch du lịch cùng nhau. Tham gia tại đây: [APP_STORE_LINK]';
  }

  @override
  String get navEvents => 'Events';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get editEventSubtitle => 'Cập nhật chi tiết, ngày hoặc địa điểm';

  @override
  String get saveEvent => 'Save event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventDescription => 'Description (optional)';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventCapacity => 'Tối đa thành viên (tuỳ chọn)';

  @override
  String get eventStartDateTime => 'Start date & time';

  @override
  String get eventEndDateTime => 'End date & time (optional)';

  @override
  String get noEventsYet => 'No events yet. Tap + to create one.';

  @override
  String get noUpcomingEvents => 'Không có sự kiện sắp tới';

  @override
  String get noUpcomingEventsHint =>
      'Nhấn + để lên kế hoạch sự kiện tiếp theo.';

  @override
  String get noPastEvents => 'Chưa có sự kiện nào trong quá khứ';

  @override
  String get noPastEventsHint =>
      'Các sự kiện bạn đã tham gia sẽ hiển thị ở đây.';

  @override
  String get filterAll => 'Tất cả';

  @override
  String get calendarViewToggle => 'Lịch';

  @override
  String get listViewToggle => 'Danh sách';

  @override
  String get noEventsOnDay => 'Không có sự kiện vào ngày này';

  @override
  String get myEvents => 'My events';

  @override
  String get invitedEvents => 'Invited';

  @override
  String get infoTab => 'Thông tin';

  @override
  String get guestsTab => 'Thành viên';

  @override
  String get noGuestsYet => 'Chưa có thành viên. Nhấn + để thêm.';

  @override
  String get addGuest => 'Thêm thành viên';

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
  String get noMemoriesYet => 'Chưa có kỷ niệm nào';

  @override
  String get addFirstPhoto => 'Nhấn + để thêm ảnh đầu tiên của bạn!';

  @override
  String get slideshow => 'Trình chiếu';

  @override
  String get captionHint => 'Thêm chú thích…';

  @override
  String get photoUploadLimit =>
      'Đã đạt giới hạn tải lên. Thử lại sau một giờ.';

  @override
  String get photoCapReached => 'Sự kiện này đã đạt giới hạn ảnh.';

  @override
  String get loadMore => 'Tải thêm';

  @override
  String get storiesEditCaption => 'Chỉnh sửa chú thích';

  @override
  String get captionSaved => 'Đã lưu chú thích';

  @override
  String get saveToGallery => 'Lưu';

  @override
  String get savedToGallery => 'Đã lưu vào thư viện ảnh';

  @override
  String get sharePhoto => 'Chia sẻ';

  @override
  String uploadingProgress(int current, int total) {
    return 'Đang tải lên $current / $total…';
  }

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
  String get noExpensesYet => 'Chưa có chi phí';

  @override
  String get expenseDescription => 'What was paid for?';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get splitAmong => 'Chia đều cho thành viên';

  @override
  String get paidBy => 'Người trả';

  @override
  String get selectAll => 'Chọn tất cả';

  @override
  String get deselectAll => 'Bỏ chọn tất cả';

  @override
  String totalOwed(String amount) {
    return 'You owe: $amount';
  }

  @override
  String youAreOwed(String amount) {
    return 'Bạn được nợ: $amount';
  }

  @override
  String get settleUp => 'Thanh toán';

  @override
  String get totalSpent => 'Tổng chi tiêu';

  @override
  String get theScore => 'Bảng điểm';

  @override
  String get settlementPlan => 'Kế hoạch thanh toán';

  @override
  String get allSquare => 'Tất cả đã cân bằng! 🎉';

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
  String get rsvpNoteHint => 'Thêm ghi chú (tùy chọn)';

  @override
  String get organizeTab => 'Tổ chức';

  @override
  String get detailsTab => 'Chi tiết';

  @override
  String get todoTab => 'Việc cần làm';

  @override
  String get cravingsTab => 'Thèm ăn';

  @override
  String get pollsTab => 'Bình chọn';

  @override
  String get pollsEmpty => 'Chưa có bình chọn.';

  @override
  String get pollsAddPoll => 'Thêm bình chọn';

  @override
  String get pollsQuestion => 'Câu hỏi';

  @override
  String pollsOptionHint(int n) {
    return 'Lựa chọn $n';
  }

  @override
  String get pollsAddOption => '+ Thêm lựa chọn';

  @override
  String pollsVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phiếu',
      one: '1 phiếu',
    );
    return '$_temp0';
  }

  @override
  String get pollsDeletePoll => 'Xóa bình chọn';

  @override
  String get bringListTitle => 'Cong viec';

  @override
  String get bringListEmpty => 'Chua co cong viec. Nhan + de them.';

  @override
  String get bringListAddItem => 'Them cong viec';

  @override
  String get bringListEditItem => 'Chỉnh sửa nhiệm vụ';

  @override
  String get bringListItemLabel => 'Phai lam gi';

  @override
  String get bringListNote => 'Ghi chu (tuy chon)';

  @override
  String get bringListAssignTo => 'Giao cho thanh vien';

  @override
  String get bringListNoAssignment => 'Chua phan cong';

  @override
  String get bringListTake => 'Nhan';

  @override
  String get bringListUnassign => 'Bo phan cong';

  @override
  String get rsvpNoteLabel => 'Ghi chú của bạn';

  @override
  String get confirmRsvp => 'Xác nhận';

  @override
  String get foodMoodTitle => 'Bạn đói bao nhiêu?';

  @override
  String get foodMoodStarving => 'Đói lắm rồi';

  @override
  String get foodMoodCouldEat => 'Có thể ăn';

  @override
  String get foodMoodDrinksOnly => 'Chỉ uống thôi';

  @override
  String get foodMoodNibble => 'Nhấm nháp thôi';

  @override
  String get foodMoodDDMode => 'Tài xế hôm nay';

  @override
  String get cravingsPrompt => 'Bạn đang thèm gì?';

  @override
  String get cravingsHint => 'ramen cay, không khí ấm cúng, dưới 200k...';

  @override
  String get cravingsPrivacyNote => 'Chỉ bạn mới thấy điều này';

  @override
  String get cravingsFindButton => 'Tìm chỗ cho tôi';

  @override
  String get cravingsEmpty => 'Không tìm thấy kết quả. Thử từ khóa khác.';

  @override
  String get cravingsPitchButton => 'Đề xuất với nhóm';

  @override
  String get cravingsPitched => 'Đã thêm vào bình chọn nhóm!';

  @override
  String get exploreTab => 'Khám phá';

  @override
  String exploreTitle(String destination) {
    return 'Hoạt động tại $destination';
  }

  @override
  String get exploreSubtitle => 'Powered by Viator • GetYourGuide • Klook';

  @override
  String get exploreSortCheapest => 'Rẻ nhất';

  @override
  String get exploreSortTopRated => 'Đánh giá cao nhất';

  @override
  String get exploreMorePlatforms => 'NỀN TẢNG KHÁC';

  @override
  String get bookOnViator => 'Đặt trên Viator';

  @override
  String get bookNow => 'Đặt ngay';

  @override
  String get browseGetYourGuide => 'Xem trên GetYourGuide';

  @override
  String get browseKlook => 'Xem trên Klook';

  @override
  String exploreFromPrice(String price) {
    return 'Từ $price';
  }

  @override
  String get exploreNoResults =>
      'Không tìm thấy hoạt động nào cho điểm đến này.';

  @override
  String get exploreLoadError => 'Không thể tải gợi ý. Nhấn để thử lại.';

  @override
  String get restaurantPollTitle => 'Chọn địa điểm';

  @override
  String get addRestaurantOption => 'Thêm nhà hàng';

  @override
  String get restaurantSearchHint => 'Tìm nhà hàng...';

  @override
  String get setAsVenueButton => 'Đặt làm địa điểm';

  @override
  String organizedBy(String name) {
    return 'Organised by $name';
  }

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String get deleteEventSubtitle => 'Xóa vĩnh viễn sự kiện này';

  @override
  String deleteEventMessage(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get eventTypeTrip => 'Chuyến đi';

  @override
  String get eventTypeBirthday => 'Sinh nhật';

  @override
  String get eventTypeWedding => 'Đám cưới';

  @override
  String get eventTypeSocial => 'Xã hội';

  @override
  String get eventTypeQuickBites => 'Bữa Ăn Nhanh';

  @override
  String get eventTypeSignup => 'Đăng ký';

  @override
  String signupSpotsFilled(int filled, int total) {
    return '$filled / $total chỗ đã được đặt';
  }

  @override
  String signupWaitlistCount(int count) {
    return '$count người trong danh sách chờ';
  }

  @override
  String get signupEventFull => 'Sự kiện đã đầy';

  @override
  String get signupSessionFull => 'Buổi đã đầy';

  @override
  String get signupJoinWaitlist => 'Tham gia danh sách chờ';

  @override
  String get signupClaimSpot => 'Đặt chỗ';

  @override
  String signupConfirmedPosition(int pos) {
    return 'Bạn đứng thứ #$pos trong danh sách!';
  }

  @override
  String signupWaitlistPosition(int pos) {
    return 'Bạn đứng thứ #$pos trong danh sách chờ';
  }

  @override
  String get signupWaitlistEnabled => 'Bật danh sách chờ';

  @override
  String get signupWaitlistDescription =>
      'Khách vượt quá số lượng sẽ vào danh sách chờ theo thứ tự';

  @override
  String get signupRosterTab => 'Danh sách';

  @override
  String get signupInviteTab => 'Mời';

  @override
  String get signupPromoteGuest => 'Chuyển sang đã xác nhận';

  @override
  String get signupRemoveGuest => 'Xóa khỏi sự kiện';

  @override
  String get signupCopyLink => 'Sao chép liên kết mời';

  @override
  String get signupShowQr => 'Hiển thị mã QR';

  @override
  String get signupLocked => 'Đăng ký đã bị khóa';

  @override
  String get signupLockedMessage =>
      'Đăng ký đã bị khóa. Liên hệ người tổ chức.';

  @override
  String get signupPendingReview => 'Yêu cầu của bạn đang chờ phê duyệt';

  @override
  String get signupCancelSpot => 'Hủy chỗ của tôi';

  @override
  String get signupMarkAttended => 'Đã tham dự';

  @override
  String get signupMarkNoShow => 'Vắng mặt';

  @override
  String get signupAttendanceHeader => 'Điểm danh';

  @override
  String get signupRepeat => 'Lặp lại';

  @override
  String get signupRepeatNone => 'Không';

  @override
  String get signupRepeatWeekly => 'Hàng tuần';

  @override
  String get signupRepeatBiweekly => 'Hai tuần một lần';

  @override
  String get signupRepeatMonthly => 'Hàng tháng';

  @override
  String get signupNextSession => 'Tạo buổi tiếp theo';

  @override
  String get signupCarryOverGuests => 'Tự động đăng ký khách đã xác nhận';

  @override
  String get signupCarryOverGuestsHint =>
      'Khách sẽ nhận được thông báo và có thể hủy';

  @override
  String signupPartOfSeries(String interval) {
    return 'Một phần của chuỗi $interval';
  }

  @override
  String get chooseEventType => 'Bạn đang lên kế hoạch gì?';

  @override
  String get eventTypePicker => 'Loại sự kiện';

  @override
  String get routeTab => 'Lộ trình';

  @override
  String get leaveEventTitle => 'Rời sự kiện?';

  @override
  String leaveEventMessage(String eventTitle) {
    return 'Bạn sẽ bị xóa khỏi $eventTitle và mất quyền truy cập.';
  }

  @override
  String get generateWithAi => 'AI Assistant';

  @override
  String get aiTripPlannerSubtitle =>
      'Hỏi về điểm đến hoặc mô tả phong cách của bạn để thêm điểm dừng vào lịch trình.';

  @override
  String get aiChatHint => 'Hỏi bất cứ điều gì về chuyến đi của bạn...';

  @override
  String get tierFree => 'Basic';

  @override
  String get tierPro => 'Pro';

  @override
  String tierProTrial(String date) {
    return 'Dùng thử Pro · Kết thúc $date';
  }

  @override
  String get cancelTrial => 'Hủy dùng thử';

  @override
  String get cancelTrialConfirmTitle => 'Hủy bản dùng thử miễn phí?';

  @override
  String get cancelTrialConfirmMessage =>
      'Bạn sẽ mất quyền truy cập các tính năng Pro ngay lập tức. Bạn có thể nâng cấp Pro sau.';

  @override
  String get cancelTrialSuccess =>
      'Bản dùng thử đã bị hủy. Bạn đang dùng gói Basic.';

  @override
  String get cancelTrialError => 'Không thể hủy dùng thử. Vui lòng thử lại.';

  @override
  String get upgradeToPro => 'Nâng cấp lên Pro';

  @override
  String get upgradeNow => 'Nâng cấp ngay';

  @override
  String get proAnnualPrice => '\$39.99 / năm';

  @override
  String get proMonthlyPrice => '\$4.99 / tháng';

  @override
  String get proAnnualSavings => 'Tiết kiệm 33%';

  @override
  String get comparePlans => 'So sánh gói';

  @override
  String get restorePurchases => 'Khôi phục giao dịch';

  @override
  String get proFeatureAIPlanner => 'AI Event Assistant';

  @override
  String get proFeatureUnlimitedEvents => 'Sự kiện & khách không giới hạn';

  @override
  String get proFeatureExpenseExport => 'Expense export';

  @override
  String get proFeatureOfflineAccess => 'Truy cập ngoại tuyến';

  @override
  String get proFeatureTemplates => 'Mẫu sự kiện';

  @override
  String get freeEventsLimit => 'Sự kiện (tối đa 3)';

  @override
  String get freeGuestsLimit => 'Khách (tối đa 10)';

  @override
  String get freeBasicPlanning => 'RSVP & lập kế hoạch cơ bản';

  @override
  String get budgetPerHeadLabel => 'Ngân sách mỗi người (tuỳ chọn)';

  @override
  String get cuisineTagsLabel => 'Ẩm thực';

  @override
  String get rsvpDeadlineLabel => 'Hạn phản hồi';

  @override
  String get rsvpDeadlineClosed => 'Đã đóng phản hồi';

  @override
  String get vibePickerLabel => 'Không khí (tuỳ chọn)';

  @override
  String get honoreeNameLabel => 'Sinh nhật của ai?';

  @override
  String get honoreeNameHint => 'Nhập tên của họ';

  @override
  String get birthYearLabel => 'Năm sinh (tùy chọn)';

  @override
  String get birthYearHint => 'ví dụ: 1996';

  @override
  String get celebrateTab => 'Tiệc';

  @override
  String get giftsTab => 'Quà tặng';

  @override
  String get memoriesTab => 'Kỷ niệm';

  @override
  String birthdayHeroTitle(String name) {
    return 'Sinh nhật của $name';
  }

  @override
  String turningAge(int age) {
    return 'Tròn $age tuổi';
  }

  @override
  String birthdayCountdownDays(int count) {
    return 'Còn $count ngày';
  }

  @override
  String birthdayCountdownHours(int count) {
    return 'Còn $count giờ';
  }

  @override
  String get birthdayToday => 'Hôm nay là ngày trọng đại!';

  @override
  String activityVoteTitle(String name) {
    return 'Làm gì tại tiệc của $name?';
  }

  @override
  String get activityVoteEmpty => 'Chưa có hoạt động nào.';

  @override
  String get addActivityOption => 'Thêm hoạt động';

  @override
  String cakeVoteTitle(String name) {
    return '$name muốn bánh gì?';
  }

  @override
  String get cakeVoteEmpty => 'Chưa có tùy chọn bánh nào.';

  @override
  String get addCakeOption => 'Thêm hương vị';

  @override
  String wishlistTitle(String name) {
    return 'Danh sách của $name';
  }

  @override
  String wishlistEmpty(String name) {
    return 'Chưa có mục nào. Thêm thứ gì đó $name sẽ thích!';
  }

  @override
  String get addWishlistItem => 'Thêm ý tưởng quà';

  @override
  String get wishlistItemLabel => 'Ý tưởng quà';

  @override
  String get wishlistPriceRange => 'Mức giá (tùy chọn)';

  @override
  String get wishlistLink => 'Liên kết (tùy chọn)';

  @override
  String get claimItem => 'Tôi sẽ mua!';

  @override
  String get unclaimItem => 'Hủy';

  @override
  String get itemClaimed => 'Ai đó đang lo';

  @override
  String itemClaimedBy(String name) {
    return 'Được nhận bởi $name';
  }

  @override
  String get markReceived => 'Đánh dấu đã nhận';

  @override
  String get giftPoolTitle => 'Quà tập thể';

  @override
  String get giftPoolEmpty => 'Chưa có quà tập thể nào.';

  @override
  String get createGiftPool => 'Bắt đầu quà tập thể';

  @override
  String get giftPoolName => 'Tên quà';

  @override
  String get giftPoolTarget => 'Số tiền mục tiêu';

  @override
  String giftPoolProgress(String pledged, String target) {
    return '$pledged trong $target đã cam kết';
  }

  @override
  String giftPoolContributors(int count) {
    return '$count người tham gia';
  }

  @override
  String get pledgeAmount => 'Số tiền cam kết';

  @override
  String get addPledge => 'Cam kết';

  @override
  String get myPledge => 'Cam kết của tôi';

  @override
  String get removePledge => 'Xóa cam kết';

  @override
  String predictionsTitle(String name) {
    return 'Dự đoán cho $name';
  }

  @override
  String predictionsSealed(int count) {
    return '$count dự đoán đang được niêm phong';
  }

  @override
  String get revealPredictions => 'Tiết lộ dự đoán';

  @override
  String get predictionsHowItWorks =>
      'Dự đoán bị khóa đến ngày sự kiện — sau đó mọi người sẽ biết ai đoán đúng!';

  @override
  String predictionsEmpty(String name) {
    return 'Chưa có dự đoán nào cho $name.';
  }

  @override
  String get addPrediction => 'Thêm dự đoán';

  @override
  String predictionHint(String name) {
    return 'Dự đoán điều gì cho năm tới của $name...';
  }

  @override
  String wishesTitle(String name) {
    return 'Lời chúc cho $name';
  }

  @override
  String wishesSealed(String name) {
    return '$name chưa thể thấy những lời này';
  }

  @override
  String get wishesHowItWorks =>
      'Những lời chúc được giữ bí mật cho đến khi người tổ chức tiết lộ vào ngày trọng đại!';

  @override
  String get wishesEmpty => 'Chưa có lời chúc nào. Hãy là người đầu tiên!';

  @override
  String get addWish => 'Gửi lời chúc';

  @override
  String wishHint(String name) {
    return 'Viết lời chúc của bạn cho $name...';
  }

  @override
  String get blowOutCandles => 'Thổi nến!';

  @override
  String get wishesRevealed => 'Lời chúc đã được tiết lộ!';

  @override
  String memoryWallTitle(String name) {
    return 'Tường kỷ niệm của $name';
  }

  @override
  String memoryWallEmpty(String name) {
    return 'Chia sẻ kỷ niệm với $name!';
  }

  @override
  String get addMemory => 'Thêm kỷ niệm';

  @override
  String memoryCaptionHint(String name) {
    return 'Chia sẻ kỷ niệm yêu thích với $name...';
  }

  @override
  String get toastsTitle => 'Lời chúc mừng & Bài phát biểu';

  @override
  String toastsEmpty(String name) {
    return 'Chưa có lời chúc nào cho $name.';
  }

  @override
  String get addToast => 'Viết lời chúc';

  @override
  String get toastTypeSweet => 'Cảm động';

  @override
  String get toastTypeFunny => 'Vui';

  @override
  String get toastTypePoem => 'Thơ';

  @override
  String get toastTextHint => 'Viết bài phát biểu ở đây...';

  @override
  String get exportToasts => 'Xuất bài phát biểu';

  @override
  String get wishesTab => 'Lời chúc';

  @override
  String get predictionsTab => 'Dự đoán';

  @override
  String get wallTab => 'Tường';

  @override
  String get pleaseSelectEventType => 'Vui lòng chọn loại sự kiện';

  @override
  String get notifications => 'Thông báo';

  @override
  String get notificationsEmpty => 'Bạn đã xem tất cả!';

  @override
  String get notificationsMarkAllRead => 'Đánh dấu tất cả là đã đọc';

  @override
  String get sessionActivityTab => 'Hoạt động';

  @override
  String get queueUp => 'Hàng đợi';

  @override
  String get createQueue => 'Tạo hàng đợi';

  @override
  String get playersPerRound => 'Người chơi mỗi vòng';

  @override
  String get maxRounds => 'Số vòng tối đa';

  @override
  String get noLimit => 'Không giới hạn';

  @override
  String get checkIn => 'Điểm danh';

  @override
  String get checkOut => 'Ra về';

  @override
  String get joinQueue => 'Tham gia hàng đợi';

  @override
  String get leaveQueue => 'Rời hàng đợi';

  @override
  String get startQueue => 'Bắt đầu';

  @override
  String get nextRound => 'Vòng tiếp theo';

  @override
  String roundN(int n) {
    return 'Vòng $n';
  }

  @override
  String get allRejoinQueue => 'Tất cả quay lại hàng đợi';

  @override
  String get releaseToFreePool => 'Trả về nhóm tự do';

  @override
  String get freePool => 'Nhóm tự do';

  @override
  String get nowPlaying => 'Đang chơi';

  @override
  String get waitingQueue => 'Đang đợi';

  @override
  String get queueEnded => 'Hàng đợi kết thúc';

  @override
  String get noQueuesYet => 'Chưa có hoạt động';

  @override
  String get createFirstQueue => 'Tạo hàng đợi đầu tiên để bắt đầu';

  @override
  String queueRoundComplete(int n) {
    return 'Vòng $n hoàn thành!';
  }

  @override
  String get setupQueues => 'Thiết lập hàng chờ';

  @override
  String get numberOfQueues => 'Số hàng chờ';

  @override
  String get spotsPerQueue => 'Chỗ mỗi hàng chờ';

  @override
  String get clearQueue => 'Xóa';

  @override
  String get queueFull => 'Hàng chờ đã đầy';

  @override
  String get alreadyInQueue => 'Bạn đã ở trong một hàng chờ';

  @override
  String get addToSlot => 'Chiếm chỗ thôi!';

  @override
  String get addMyselfToQueue => 'Tôi tham gia!';

  @override
  String get addSomeoneElse => 'Thêm đồng đội';

  @override
  String get selectAMember => 'Chọn thành viên';

  @override
  String get searchMembersHint => 'Tìm kiếm thành viên…';

  @override
  String get leaveSlotTitle => 'Rời ô này?';

  @override
  String leaveSlotMessage(int number) {
    return 'Rút khỏi ô trong hàng đợi #$number?';
  }

  @override
  String get leaveSlotConfirm => 'Rút';

  @override
  String get kickFromSlotTitle => 'Đuổi không?';

  @override
  String kickFromSlotMessage(String name, int number) {
    return 'Xóa $name khỏi hàng đợi #$number?';
  }

  @override
  String get kickFromSlotConfirm => 'Đuổi!';

  @override
  String get allowDuplicates => 'Cho phép tham gia nhiều hàng đợi';

  @override
  String get allowDuplicatesSubtitle =>
      'Thành viên có thể ở nhiều hàng đợi cùng lúc';

  @override
  String get customizeQueues => 'Tùy chỉnh hàng đợi';

  @override
  String get pollSpinButton => 'Quay';

  @override
  String get pollWheelTitle => 'Quay bánh xe';

  @override
  String get pollWheelResult => 'Bánh xe đã chọn!';

  @override
  String get pollWheelSpin => 'Quay';

  @override
  String get pollWheelSpinAgain => 'Quay lại';

  @override
  String get pollsDeleteConfirmTitle => 'Xóa cuộc bình chọn?';

  @override
  String get pollsDeleteConfirmBody =>
      'Thao tác này sẽ xóa cuộc bình chọn và mọi lượt bình chọn. Không thể hoàn tác.';

  @override
  String get pollWheelHeadline => 'Để bánh xe quyết định!';

  @override
  String get pollWheelHeadlineFood => 'Đến giờ ăn rồi!';

  @override
  String get pollWheelSpinning => 'Đang quay…';
}
