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
    return 'Xóa \"$tripTitle\"? Không thể hoàn tác.';
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
}
