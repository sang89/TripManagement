// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get save => '保存';

  @override
  String get required => '必填';

  @override
  String get notes => '备注';

  @override
  String get email => '邮箱';

  @override
  String get phone => '电话';

  @override
  String get remove => '删除';

  @override
  String get notSet => '未设置';

  @override
  String failed(String error) {
    return '失败：$error';
  }

  @override
  String comingSoon(String feature) {
    return '$feature — 即将推出';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get languageSectionTitle => '语言';

  @override
  String get selectLanguageTitle => '选择语言';

  @override
  String get systemDefault => '系统默认';

  @override
  String get themeSectionTitle => '外观';

  @override
  String get themeSystem => '系统默认';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get accountSectionTitle => '账户';

  @override
  String get changePasswordTitle => '修改密码';

  @override
  String get currentPassword => '当前密码';

  @override
  String get newPassword => '新密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get updatePassword => '更新密码';

  @override
  String get passwordUpdated => '密码已更新';

  @override
  String get currentPasswordIncorrect => '当前密码不正确';

  @override
  String get passwordMinLength => '至少8个字符';

  @override
  String get passwordsDoNotMatch => '密码不匹配';

  @override
  String get deleteAccountTitle => '删除账户';

  @override
  String get deleteAccountWarning => '这将永久删除您的账户和所有数据，此操作无法撤销。';

  @override
  String get deleteAccountInstructions => '要删除您的账户，请联系客服。我们将在48小时内处理您的请求。';

  @override
  String get supportEmail => 'support@tripplanner.app';

  @override
  String get emailCopied => '邮箱已复制到剪贴板';

  @override
  String get copyEmail => '复制邮箱';

  @override
  String get aboutSectionTitle => '关于';

  @override
  String get appVersion => '应用版本';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsOfService => '服务条款';

  @override
  String get myProfile => '我的资料';

  @override
  String get failedToLoadProfile => '加载资料失败';

  @override
  String get settingsTooltip => '设置';

  @override
  String get editProfileTooltip => '编辑资料';

  @override
  String get personalInfoSection => '个人信息';

  @override
  String get fullName => '全名';

  @override
  String get fullNameHint => '您的全名';

  @override
  String get jobTitle => '职位';

  @override
  String get jobTitleHint => '例如：旅行爱好者';

  @override
  String get contactInfoSection => '联系方式';

  @override
  String get managedByAccount => '由您的账户管理';

  @override
  String get memberSince => '注册时间';

  @override
  String get saveChanges => '保存更改';

  @override
  String get signOut => '退出登录';

  @override
  String get chooseFromLibrary => '从相册选择';

  @override
  String get takePhoto => '拍照';

  @override
  String get removePhoto => '删除照片';

  @override
  String uploadFailed(String error) {
    return '上传失败：$error';
  }

  @override
  String get uploadRequiresConnection => '上传需要网络连接';

  @override
  String get photoUpdated => '照片已更新';

  @override
  String get removeRequiresConnection => '删除照片需要网络连接';

  @override
  String removeFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get profileSaved => '资料已保存';

  @override
  String profileSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get signOutConfirmTitle => '退出登录？';

  @override
  String get signOutConfirmMessage => '您将被返回到登录界面。';

  @override
  String get nameTooLong => '名称过长';

  @override
  String get appTitle => '旅行规划';

  @override
  String get signInToAccount => '登录您的账户';

  @override
  String get planNextAdventure => '规划您的下一次冒险';

  @override
  String get signIn => '登录';

  @override
  String get signUp => '注册';

  @override
  String get createAccount => '创建账户';

  @override
  String get dontHaveAccount => '还没有账户？';

  @override
  String get alreadyHaveAccount => '已有账户？';

  @override
  String get password => '密码';

  @override
  String get enterValidEmail => '请输入有效的邮箱';

  @override
  String get passwordTooShort => '密码太短';

  @override
  String get enterYourName => '请输入您的姓名';

  @override
  String get passwordMinimum6 => '最少6个字符';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get rememberMe => '记住我';

  @override
  String get continueWithGoogle => '使用 Google 继续';

  @override
  String get continueWithApple => '使用 Apple 继续';

  @override
  String get orSignInWith => '或';

  @override
  String get myTrips => '我的行程';

  @override
  String get all => '全部';

  @override
  String get upcoming => '即将出行';

  @override
  String get past => '已完成';

  @override
  String get deleteTripTitle => '删除行程？';

  @override
  String deleteTripMessage(String tripTitle) {
    return '删除$tripTitle？此操作无法撤销。';
  }

  @override
  String get leave => '离开';

  @override
  String get leaveTripTooltip => '离开行程';

  @override
  String get thisTripFallback => '此行程';

  @override
  String get leaveTripTitle => '离开行程？';

  @override
  String leaveTripMessage(String tripTitle) {
    return '您将被从 $tripTitle 中移除，并失去访问权限。';
  }

  @override
  String get couldNotLoadTrips => '无法加载行程';

  @override
  String get noTripsYet => '暂无行程';

  @override
  String get noTripsHint => '点击 + 开始规划。';

  @override
  String get noUpcomingTrips => '暂无即将出行的行程';

  @override
  String get noUpcomingTripsHint => '点击 + 规划您的下一次冒险。';

  @override
  String get noPastTrips => '暂无已完成的行程';

  @override
  String get noPastTripsHint => '您完成的行程将在此显示。';

  @override
  String get editTrip => '编辑行程';

  @override
  String get newTrip => '新行程';

  @override
  String get tripTitle => '行程标题';

  @override
  String get startingFromLabel => '出发地（可选）';

  @override
  String get destinationLabel => '目的地';

  @override
  String get notesOptional => '备注（可选）';

  @override
  String get startLabel => '开始';

  @override
  String get endLabel => '结束';

  @override
  String get setStartDateTime => '设置开始日期和时间';

  @override
  String get setEndDateTime => '设置结束日期和时间';

  @override
  String get endDateAfterStart => '结束日期必须在开始日期之后。';

  @override
  String get stopsSection => '途经地';

  @override
  String get addStop => '添加途经地';

  @override
  String get noStopsYet => '暂无途经地。';

  @override
  String get mapSection => '地图';

  @override
  String get membersSection => '成员';

  @override
  String get addMember => '添加成员';

  @override
  String get fullNameLabel => '姓名';

  @override
  String get emailOptional => '邮箱（可选）';

  @override
  String get phoneOptional => '电话（可选）';

  @override
  String get saveTrip => '保存行程';

  @override
  String get you => '您';

  @override
  String get organizer => '组织者';

  @override
  String get member => '成员';

  @override
  String get tripNotFound => '未找到行程';

  @override
  String get editTripTooltip => '编辑行程';

  @override
  String get overview => '概览';

  @override
  String get itinerary => '行程安排';

  @override
  String get mapTab => '地图';

  @override
  String get startingFrom => '出发地';

  @override
  String get destination => '目的地';

  @override
  String get noStopsInItinerary => '暂无途经地';

  @override
  String get addFirstStop => '点击 + 添加第一个途经地。';

  @override
  String get removeStopTitle => '删除途经地？';

  @override
  String removeStopMessage(String stopTitle) {
    return '从行程中删除\"$stopTitle\"？';
  }

  @override
  String get arrive => '到达';

  @override
  String get depart => '出发';

  @override
  String get stopTitleLabel => '标题';

  @override
  String get addressOptional => '地址（可选）';

  @override
  String get arriveLabel => '到达';

  @override
  String get departLabel => '出发';

  @override
  String get addStopButton => '添加途经地';

  @override
  String get editStop => '编辑途经地';

  @override
  String get navTrips => '行程';

  @override
  String get navJournal => '日记';

  @override
  String get navProfile => '资料';

  @override
  String get journalComingSoon => '日记即将推出';

  @override
  String get memberSearching => '搜索中…';

  @override
  String get memberAccountFound => '找到账户';

  @override
  String get memberNoAccountFound => '未找到账户';

  @override
  String get memberLinkedAccount => '已关联账户';

  @override
  String get invitePending => '待定';

  @override
  String get inviteAccepted => '已接受';

  @override
  String get inviteDeclined => '已拒绝';

  @override
  String get memberLeft => '已离开';

  @override
  String invitedBy(String name) {
    return '由$name邀请';
  }

  @override
  String tripInvitationsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个行程邀请',
    );
    return '$_temp0';
  }

  @override
  String get acceptInvite => '接受';

  @override
  String get declineInvite => '拒绝';

  @override
  String get inviteNotifTitle => '行程邀请';

  @override
  String inviteNotifBody(String tripTitle) {
    return '您被邀请加入$tripTitle';
  }

  @override
  String get blockReinviteLabel => '不允许此行程的未来邀请';

  @override
  String get reinviteBlockedError => '该用户已选择拒绝此行程的未来邀请';

  @override
  String get resendInvite => '重新发送邀请';

  @override
  String inviteResentTo(String name) {
    return '已向$name重新发送邀请';
  }

  @override
  String get declineInviteConfirmTitle => '拒绝邀请？';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return '拒绝«$tripTitle»的邀请？您将失去访问权限。';
  }

  @override
  String get securitySectionTitle => '安全';

  @override
  String get biometricToggleTitle => 'Face ID / Touch ID';

  @override
  String get biometricToggleSubtitle => '使用生物识别解锁应用';

  @override
  String get biometricLockTitle => '验证您的身份';

  @override
  String get biometricLockSubtitle => '请验证身份以访问您的账户';

  @override
  String get biometricSignInWithFace => '使用 Face ID 登录';

  @override
  String get biometricSignInWithFingerprint => '使用指纹登录';

  @override
  String get biometricSignInWithBiometrics => '使用生物识别登录';

  @override
  String get biometricReason => '请验证身份以访问您的账户';

  @override
  String get biometricFailed => '身份验证失败，请重试。';

  @override
  String get usePasswordInstead => '使用密码登录';

  @override
  String get navFriends => '好友';

  @override
  String get friendsTabFriends => '好友';

  @override
  String get friendsTabRequests => '请求';

  @override
  String get friendsAddFriend => '添加好友';

  @override
  String get friendsSearchHint => '按姓名、邮箱或手机号搜索';

  @override
  String get friendsNoResults => '未找到用户';

  @override
  String get friendsRequestSent => '已发送好友请求';

  @override
  String get friendsAccept => '接受';

  @override
  String get friendsDecline => '拒绍';

  @override
  String get friendsRemove => '删除好友';

  @override
  String friendsRemoveConfirm(String name) {
    return '将 $name 从好友列表中删除？';
  }

  @override
  String get friendsNoFriends => '还没有好友';

  @override
  String get friendsNoFriendsHint => '搜索要添加为好友的人。';

  @override
  String get friendsNoRequests => '没有待处理的请求';

  @override
  String get friendsIncomingSection => '收到的';

  @override
  String get friendsOutgoingSection => '已发送';

  @override
  String get friendsCancelRequest => '取消请求';

  @override
  String get chatTabLabel => '聊天';

  @override
  String get chatSendHint => '消息…';

  @override
  String get chatNoMessages => '还没有消息。打个招呼吧！';

  @override
  String get chatSend => '发送';

  @override
  String get notificationsSectionTitle => '通知';

  @override
  String get mentionNotifToggleTitle => '提及通知';

  @override
  String get mentionNotifToggleSubtitle => '当您在旅行聊天中被@提及时收到通知';

  @override
  String get privacySectionTitle => '隐私';

  @override
  String get blockedUsersTitle => '已屏蔽用户';

  @override
  String get blockedUsersEmpty => '您尚未屏蔽任何人';

  @override
  String get blockUser => '屏蔽';

  @override
  String get unblockUser => '取消屏蔽';

  @override
  String blockConfirmTitle(String name) {
    return '屏蔽 $name？';
  }

  @override
  String get blockConfirmBody => '他们将无法将您添加到行程或向您发送好友请求。';

  @override
  String blockSuccess(String name) {
    return '已屏蔽 $name';
  }

  @override
  String unblockSuccess(String name) {
    return '已取消屏蔽 $name';
  }

  @override
  String get contactsButton => '从通讯录';

  @override
  String get contactsScreenTitle => '从通讯录查找';

  @override
  String get contactsPermissionDenied => '需要访问通讯录才能在TripManagement中找到您的朋友。';

  @override
  String get contactsOpenSettings => '打开设置';

  @override
  String get contactsOnApp => '已在TripManagement';

  @override
  String get contactsInviteSection => '邀请加入TripManagement';

  @override
  String get contactsEmpty => '未找到有电话或电子邮件的联系人。';

  @override
  String get contactsAddFriend => '添加';

  @override
  String get contactsPending => '待处理';

  @override
  String get contactsInvite => '邀请';

  @override
  String contactsInviteMessage(String name) {
    return '嗨 $name！我在使用TripManagement一起规划旅行。在这里加入我：[APP_STORE_LINK]';
  }

  @override
  String get navEvents => 'Events';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get saveEvent => 'Save event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventDescription => 'Description (optional)';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventCapacity => 'Max guests (optional)';

  @override
  String get eventStartDateTime => 'Start date & time';

  @override
  String get eventEndDateTime => 'End date & time (optional)';

  @override
  String get noEventsYet => 'No events yet. Tap + to create one.';

  @override
  String get myEvents => 'My events';

  @override
  String get invitedEvents => 'Invited';

  @override
  String get infoTab => '信息';

  @override
  String get guestsTab => 'Guests';

  @override
  String get noGuestsYet => '暂无嘉宾。点击 + 添加。';

  @override
  String get addGuest => '添加嘉宾';

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
  String get noExpensesYet => '暂无支出';

  @override
  String get expenseDescription => 'What was paid for?';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get splitAmong => 'Split among guests';

  @override
  String get paidBy => '由...支付';

  @override
  String get selectAll => '全选';

  @override
  String get deselectAll => '取消全选';

  @override
  String totalOwed(String amount) {
    return 'You owe: $amount';
  }

  @override
  String youAreOwed(String amount) {
    return '应收金额：$amount';
  }

  @override
  String get settleUp => '结算';

  @override
  String get totalSpent => '总支出';

  @override
  String get theScore => '得分';

  @override
  String get settlementPlan => '结算方案';

  @override
  String get allSquare => '大家都平了！🎉';

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
  String organizedBy(String name) {
    return 'Organised by $name';
  }

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String deleteEventMessage(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get eventTypeTrip => '旅行';

  @override
  String get eventTypeBirthday => '生日';

  @override
  String get eventTypeWedding => '婚礼';

  @override
  String get eventTypeSocial => '社交';

  @override
  String get eventTypePicker => '活动类型';

  @override
  String get routeTab => '路线';

  @override
  String get leaveEventTitle => '离开活动？';

  @override
  String leaveEventMessage(String eventTitle) {
    return '您将从 $eventTitle 中被移除并失去访问权限。';
  }
}
