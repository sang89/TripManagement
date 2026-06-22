// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get close => '閉じる';

  @override
  String get retry => '再試行';

  @override
  String get save => '保存';

  @override
  String get required => '必須';

  @override
  String get notes => 'メモ';

  @override
  String get email => 'メール';

  @override
  String get phone => '電話';

  @override
  String get remove => '削除';

  @override
  String get notSet => '未設定';

  @override
  String failed(String error) {
    return '失敗：$error';
  }

  @override
  String comingSoon(String feature) {
    return '$feature — 近日公開';
  }

  @override
  String get settingsTitle => '設定';

  @override
  String get languageSectionTitle => '言語';

  @override
  String get selectLanguageTitle => '言語を選択';

  @override
  String get systemDefault => 'システムデフォルト';

  @override
  String get themeSectionTitle => '外観';

  @override
  String get themeSystem => 'システムデフォルト';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get accountSectionTitle => 'アカウント';

  @override
  String get changePasswordTitle => 'パスワードを変更';

  @override
  String get currentPassword => '現在のパスワード';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get confirmNewPassword => '新しいパスワードを確認';

  @override
  String get updatePassword => 'パスワードを更新';

  @override
  String get passwordUpdated => 'パスワードを更新しました';

  @override
  String get currentPasswordIncorrect => '現在のパスワードが正しくありません';

  @override
  String get passwordMinLength => '8文字以上';

  @override
  String get passwordsDoNotMatch => 'パスワードが一致しません';

  @override
  String get deleteAccountTitle => 'アカウントを削除';

  @override
  String get deleteAccountWarning => 'アカウントとすべてのデータが完全に削除されます。この操作は元に戻せません。';

  @override
  String get deleteAccountInstructions =>
      'アカウントを削除するには、サポートにご連絡ください。48時間以内に対応いたします。';

  @override
  String get supportEmail => 'support@tripplanner.app';

  @override
  String get emailCopied => 'メールをクリップボードにコピーしました';

  @override
  String get copyEmail => 'メールをコピー';

  @override
  String get aboutSectionTitle => 'このアプリについて';

  @override
  String get appVersion => 'アプリバージョン';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get termsOfService => '利用規約';

  @override
  String get myProfile => 'マイプロフィール';

  @override
  String get failedToLoadProfile => 'プロフィールの読み込みに失敗しました';

  @override
  String get settingsTooltip => '設定';

  @override
  String get editProfileTooltip => 'プロフィールを編集';

  @override
  String get personalInfoSection => '個人情報';

  @override
  String get fullName => '氏名';

  @override
  String get fullNameHint => '氏名を入力してください';

  @override
  String get jobTitle => '役職';

  @override
  String get jobTitleHint => '例：旅行好き';

  @override
  String get contactInfoSection => '連絡先情報';

  @override
  String get managedByAccount => 'アカウントで管理';

  @override
  String get memberSince => '登録日';

  @override
  String get saveChanges => '変更を保存';

  @override
  String get signOut => 'サインアウト';

  @override
  String get chooseFromLibrary => 'ライブラリから選択';

  @override
  String get takePhoto => '写真を撮る';

  @override
  String get removePhoto => '写真を削除';

  @override
  String uploadFailed(String error) {
    return 'アップロード失敗：$error';
  }

  @override
  String get uploadRequiresConnection => 'アップロードには接続が必要です';

  @override
  String get photoUpdated => '写真を更新しました';

  @override
  String get removeRequiresConnection => '写真の削除には接続が必要です';

  @override
  String removeFailed(String error) {
    return '削除失敗：$error';
  }

  @override
  String get profileSaved => 'プロフィールを保存しました';

  @override
  String profileSaveFailed(String error) {
    return '保存失敗：$error';
  }

  @override
  String get signOutConfirmTitle => 'サインアウトしますか？';

  @override
  String get signOutConfirmMessage => 'ログイン画面に戻ります。';

  @override
  String get nameTooLong => '名前が長すぎます';

  @override
  String get appTitle => '旅行プランナー';

  @override
  String get signInToAccount => 'アカウントにサインイン';

  @override
  String get planNextAdventure => '次の冒険を計画しよう';

  @override
  String get signIn => 'サインイン';

  @override
  String get signUp => '登録';

  @override
  String get createAccount => 'アカウントを作成';

  @override
  String get dontHaveAccount => 'アカウントをお持ちでないですか？';

  @override
  String get alreadyHaveAccount => 'すでにアカウントをお持ちですか？';

  @override
  String get password => 'パスワード';

  @override
  String get enterValidEmail => '有効なメールを入力してください';

  @override
  String get passwordTooShort => 'パスワードが短すぎます';

  @override
  String get enterYourName => '名前を入力してください';

  @override
  String get passwordMinimum6 => '最低6文字';

  @override
  String get confirmPassword => 'パスワードを確認';

  @override
  String get rememberMe => 'ログイン状態を保持';

  @override
  String get continueWithGoogle => 'Googleで続ける';

  @override
  String get continueWithApple => 'Appleで続ける';

  @override
  String get orSignInWith => 'または';

  @override
  String get myTrips => 'マイトリップ';

  @override
  String get all => 'すべて';

  @override
  String get upcoming => '予定';

  @override
  String get past => '過去';

  @override
  String get deleteTripTitle => '旅行を削除しますか？';

  @override
  String deleteTripMessage(String tripTitle) {
    return '$tripTitleを削除しますか？この操作は元に戻せません。';
  }

  @override
  String get leave => '退出';

  @override
  String get leaveTripTooltip => '旅行から退出';

  @override
  String get thisTripFallback => 'この旅行';

  @override
  String get leaveTripTitle => '旅行から退出しますか？';

  @override
  String leaveTripMessage(String tripTitle) {
    return '$tripTitle から削除され、アクセスできなくなります。';
  }

  @override
  String get couldNotLoadTrips => '旅行を読み込めませんでした';

  @override
  String get noTripsYet => 'まだ旅行はありません';

  @override
  String get noTripsHint => '+ をタップして始めましょう。';

  @override
  String get noUpcomingTrips => '予定の旅行はありません';

  @override
  String get noUpcomingTripsHint => '+ をタップして次の冒険を計画しましょう。';

  @override
  String get noPastTrips => '過去の旅行はありません';

  @override
  String get noPastTripsHint => '完了した旅行がここに表示されます。';

  @override
  String get editTrip => '旅行を編集';

  @override
  String get newTrip => '新しい旅行';

  @override
  String get tripTitle => '旅行タイトル';

  @override
  String get startingFromLabel => '出発地（任意）';

  @override
  String get destinationLabel => '目的地';

  @override
  String get notesOptional => 'メモ（任意）';

  @override
  String get startLabel => '開始';

  @override
  String get endLabel => '終了';

  @override
  String get setStartDateTime => '開始日時を設定';

  @override
  String get setEndDateTime => '終了日時を設定';

  @override
  String get endDateAfterStart => '終了日は開始日より後にしてください。';

  @override
  String get stopsSection => '途中停車地';

  @override
  String get addStop => '停車地を追加';

  @override
  String get noStopsYet => '停車地はまだありません。';

  @override
  String get mapSection => '地図';

  @override
  String get membersSection => 'メンバー';

  @override
  String get addMember => 'メンバーを追加';

  @override
  String get fullNameLabel => '名前';

  @override
  String get emailOptional => 'メール（任意）';

  @override
  String get phoneOptional => '電話（任意）';

  @override
  String get saveTrip => '旅行を保存';

  @override
  String get you => 'あなた';

  @override
  String get organizer => '主催者';

  @override
  String get member => 'メンバー';

  @override
  String get tripNotFound => '旅行が見つかりません';

  @override
  String get editTripTooltip => '旅行を編集';

  @override
  String get overview => '概要';

  @override
  String get itinerary => '旅程';

  @override
  String get mapTab => '地図';

  @override
  String get startingFrom => '出発地';

  @override
  String get destination => '目的地';

  @override
  String get noStopsInItinerary => '停車地はまだありません';

  @override
  String get addFirstStop => '+ をタップして最初の停車地を追加しましょう。';

  @override
  String get removeStopTitle => '停車地を削除しますか？';

  @override
  String removeStopMessage(String stopTitle) {
    return '旅程から\"$stopTitle\"を削除しますか？';
  }

  @override
  String get arrive => '到着';

  @override
  String get depart => '出発';

  @override
  String get stopTitleLabel => 'タイトル';

  @override
  String get addressOptional => '住所（任意）';

  @override
  String get arriveLabel => '到着';

  @override
  String get departLabel => '出発';

  @override
  String get addStopButton => '停車地を追加';

  @override
  String get editStop => '停車地を編集';

  @override
  String get navTrips => '旅行';

  @override
  String get navJournal => '日記';

  @override
  String get navProfile => 'プロフィール';

  @override
  String get journalComingSoon => '日記機能は近日公開';

  @override
  String get memberSearching => '検索中…';

  @override
  String get memberAccountFound => 'アカウントが見つかりました';

  @override
  String get memberNoAccountFound => 'アカウントが見つかりません';

  @override
  String get memberLinkedAccount => 'リンク済みアカウント';

  @override
  String get selectFriendOptional => '友達を選ぶ（任意）';

  @override
  String get searchFriends => '友達を検索…';

  @override
  String get invitePending => '保留中';

  @override
  String get inviteAccepted => '承諾済み';

  @override
  String get inviteDeclined => '辞退済み';

  @override
  String get memberLeft => '退出済み';

  @override
  String invitedBy(String name) {
    return '$nameから招待';
  }

  @override
  String tripInvitationsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の旅行招待',
    );
    return '$_temp0';
  }

  @override
  String get acceptInvite => '承諾';

  @override
  String get declineInvite => '辞退';

  @override
  String get inviteNotifTitle => '旅行招待';

  @override
  String inviteNotifBody(String tripTitle) {
    return '$tripTitleに招待されました';
  }

  @override
  String get blockReinviteLabel => 'このトリップへの今後の招待を許可しない';

  @override
  String get reinviteBlockedError => 'このユーザーはこのトリップへの今後の招待を拒否しています';

  @override
  String get resendInvite => '招待を再送信';

  @override
  String inviteResentTo(String name) {
    return '$nameに招待を再送信しました';
  }

  @override
  String get declineInviteConfirmTitle => '招待を断りますか？';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return '「$tripTitle」への招待を断りますか？アクセスできなくなります。';
  }

  @override
  String get securitySectionTitle => 'セキュリティ';

  @override
  String get biometricToggleTitle => 'Face ID / Touch ID';

  @override
  String get biometricToggleSubtitle => '生体認証でアプリのロックを解除する';

  @override
  String get biometricLockTitle => '本人確認';

  @override
  String get biometricLockSubtitle => 'アカウントにアクセスするために認証してください';

  @override
  String get biometricSignInWithFace => 'Face IDでサインイン';

  @override
  String get biometricSignInWithFingerprint => '指紋でサインイン';

  @override
  String get biometricSignInWithBiometrics => '生体認証でサインイン';

  @override
  String get biometricReason => 'アカウントにアクセスするために認証してください';

  @override
  String get biometricFailed => '認証に失敗しました。もう一度お試しください。';

  @override
  String get usePasswordInstead => 'パスワードを使用する';

  @override
  String get navFriends => '友達';

  @override
  String get friendsTabFriends => '友達';

  @override
  String get friendsTabRequests => 'リクエスト';

  @override
  String get friendsAddFriend => '友達を追加';

  @override
  String get friendsSearchHint => '名前、メール、電話番号で検索';

  @override
  String get friendsNoResults => 'ユーザーが見つかりません';

  @override
  String get friendsRequestSent => '友達リクエストを送信しました';

  @override
  String get friendsAccept => '承認';

  @override
  String get friendsDecline => '断る';

  @override
  String get friendsRemove => '友達を削除';

  @override
  String friendsRemoveConfirm(String name) {
    return '$name を友達から削除しますか？';
  }

  @override
  String get friendsNoFriends => 'まだ友達がいません';

  @override
  String get friendsNoFriendsHint => '友達として追加する人を検索してください。';

  @override
  String get friendsNoRequests => '保留中のリクエストはありません';

  @override
  String get friendsIncomingSection => '受信';

  @override
  String get friendsOutgoingSection => '送信済み';

  @override
  String get friendsCancelRequest => 'リクエストをキャンセル';

  @override
  String get chatTabLabel => 'チャット';

  @override
  String get chatSendHint => 'メッセージ…';

  @override
  String get chatNoMessages => 'メッセージはまだありません。挨拶してみよう！';

  @override
  String get chatSend => '送信';

  @override
  String get notificationsSectionTitle => '通知';

  @override
  String get mentionNotifToggleTitle => 'メンション通知';

  @override
  String get mentionNotifToggleSubtitle => '旅行チャットで@メンションされたときに通知を受け取る';

  @override
  String get privacySectionTitle => 'プライバシー';

  @override
  String get blockedUsersTitle => 'ブロック中のユーザー';

  @override
  String get blockedUsersEmpty => 'ブロックしているユーザーはいません';

  @override
  String get blockUser => 'ブロック';

  @override
  String get unblockUser => 'ブロック解除';

  @override
  String blockConfirmTitle(String name) {
    return '$nameをブロックしますか？';
  }

  @override
  String get blockConfirmBody => 'この人はあなたを旅行に追加したり、フレンド申請を送ることができなくなります。';

  @override
  String blockSuccess(String name) {
    return '$nameをブロックしました';
  }

  @override
  String unblockSuccess(String name) {
    return '$nameのブロックを解除しました';
  }

  @override
  String get contactsButton => '連絡先から';

  @override
  String get contactsScreenTitle => '連絡先から探す';

  @override
  String get contactsPermissionDenied =>
      'TripManagementで友達を見つけるには連絡先へのアクセスが必要です。';

  @override
  String get contactsOpenSettings => '設定を開く';

  @override
  String get contactsOnApp => 'TripManagement登録済み';

  @override
  String get contactsInviteSection => 'TripManagementに招待';

  @override
  String get contactsEmpty => '電話番号またはメールアドレスのある連絡先が見つかりませんでした。';

  @override
  String get contactsAddFriend => '追加';

  @override
  String get contactsPending => '保留中';

  @override
  String get contactsInvite => '招待';

  @override
  String contactsInviteMessage(String name) {
    return '$nameさん、TripManagementで一緒に旅行を計画しましょう！こちらから参加：[APP_STORE_LINK]';
  }

  @override
  String get navEvents => 'Events';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get editEventSubtitle => '詳細、日付、または場所を更新';

  @override
  String get saveEvent => 'Save event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventDescription => 'Description (optional)';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventCapacity => '最大メンバー数（任意）';

  @override
  String get eventStartDateTime => 'Start date & time';

  @override
  String get eventEndDateTime => 'End date & time (optional)';

  @override
  String get noEventsYet => 'No events yet. Tap + to create one.';

  @override
  String get noUpcomingEvents => '予定されているイベントはありません';

  @override
  String get noUpcomingEventsHint => '+ をタップして次のイベントを計画しましょう。';

  @override
  String get noPastEvents => 'まだ過去のイベントはありません';

  @override
  String get noPastEventsHint => '参加したイベントがここに表示されます。';

  @override
  String get filterAll => 'すべて';

  @override
  String get calendarViewToggle => 'カレンダー';

  @override
  String get listViewToggle => 'リスト';

  @override
  String get noEventsOnDay => 'この日にイベントはありません';

  @override
  String get myEvents => 'My events';

  @override
  String get invitedEvents => 'Invited';

  @override
  String get infoTab => '詳細';

  @override
  String get guestsTab => 'メンバー';

  @override
  String get noGuestsYet => 'まだメンバーがいません。+をタップして追加してください。';

  @override
  String get addGuest => 'メンバーを追加';

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
  String get noMemoriesYet => 'まだ思い出がありません';

  @override
  String get addFirstPhoto => '+ をタップして最初の写真を追加しましょう！';

  @override
  String get slideshow => 'スライドショー';

  @override
  String get captionHint => 'キャプションを追加…';

  @override
  String get photoUploadLimit => 'アップロード制限に達しました。1時間後に再試行してください。';

  @override
  String get photoCapReached => 'このイベントは写真の上限に達しました。';

  @override
  String get loadMore => 'もっと読み込む';

  @override
  String get storiesEditCaption => 'キャプションを編集';

  @override
  String get captionSaved => 'キャプションを保存しました';

  @override
  String get saveToGallery => '保存';

  @override
  String get savedToGallery => 'ギャラリーに保存しました';

  @override
  String get sharePhoto => '共有';

  @override
  String uploadingProgress(int current, int total) {
    return 'アップロード中 $current / $total…';
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
  String get noExpensesYet => 'まだ費用がありません';

  @override
  String get expenseDescription => 'What was paid for?';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get splitAmong => 'メンバー間で分割';

  @override
  String get paidBy => '支払い者';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get deselectAll => 'すべて解除';

  @override
  String totalOwed(String amount) {
    return 'You owe: $amount';
  }

  @override
  String youAreOwed(String amount) {
    return 'あなたへの支払い: $amount';
  }

  @override
  String get settleUp => '精算する';

  @override
  String get totalSpent => '総支出';

  @override
  String get theScore => 'スコア';

  @override
  String get settlementPlan => '精算プラン';

  @override
  String get allSquare => '全員イーブン！ 🎉';

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
  String get rsvpNoteHint => 'メモを追加（任意）';

  @override
  String get organizeTab => '整理';

  @override
  String get detailsTab => '詳細';

  @override
  String get todoTab => 'タスク';

  @override
  String get cravingsTab => '気分';

  @override
  String get pollsTab => '投票';

  @override
  String get pollsEmpty => 'まだ投票がありません。';

  @override
  String get pollsAddPoll => '投票を追加';

  @override
  String get pollsQuestion => '質問';

  @override
  String pollsOptionHint(int n) {
    return '選択肢$n';
  }

  @override
  String get pollsAddOption => '+ 選択肢を追加';

  @override
  String pollsVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count票',
      one: '1票',
    );
    return '$_temp0';
  }

  @override
  String get pollsDeletePoll => '投票を削除';

  @override
  String get bringListTitle => 'タスク';

  @override
  String get bringListEmpty => 'タスクがありません。プラスをタップ。';

  @override
  String get bringListAddItem => 'タスクを追加';

  @override
  String get bringListEditItem => 'タスクを編集';

  @override
  String get bringListItemLabel => '何をするか';

  @override
  String get bringListNote => 'メモ（任意）';

  @override
  String get bringListAssignTo => 'メンバーに割り当て';

  @override
  String get bringListNoAssignment => '未割り当て';

  @override
  String get bringListTake => '引き受ける';

  @override
  String get bringListUnassign => '割り当て解除';

  @override
  String get rsvpNoteLabel => 'あなたのメモ';

  @override
  String get confirmRsvp => '確認';

  @override
  String get foodMoodTitle => 'どのくらいお腹が空いていますか？';

  @override
  String get foodMoodStarving => '激腹';

  @override
  String get foodMoodCouldEat => '食べられる';

  @override
  String get foodMoodDrinksOnly => '飲み物だけ';

  @override
  String get foodMoodNibble => '少し食べる';

  @override
  String get foodMoodDDMode => 'ドライバー当番';

  @override
  String get cravingsPrompt => '何が食べたい？';

  @override
  String get cravingsHint => '辛いラーメン、落ち着いた雰囲気、2000円以下...';

  @override
  String get cravingsPrivacyNote => 'あなただけが見ることができます';

  @override
  String get cravingsFindButton => 'スポットを見つける';

  @override
  String get cravingsEmpty => '結果が見つかりませんでした。別のキーワードをお試しください。';

  @override
  String get cravingsPitchButton => 'グループに提案';

  @override
  String get cravingsPitched => 'グループ投票に追加しました！';

  @override
  String get exploreTab => '探索';

  @override
  String exploreTitle(String destination) {
    return '$destinationのアクティビティ';
  }

  @override
  String get exploreSubtitle => 'Powered by Viator • GetYourGuide • Klook';

  @override
  String get exploreSortCheapest => '安い順';

  @override
  String get exploreSortTopRated => '評価が高い順';

  @override
  String get exploreMorePlatforms => 'その他のプラットフォーム';

  @override
  String get bookOnViator => 'Viatorで予約';

  @override
  String get bookNow => '今すぐ予約';

  @override
  String get browseGetYourGuide => 'GetYourGuideで探す';

  @override
  String get browseKlook => 'Klookで探す';

  @override
  String exploreFromPrice(String price) {
    return '$priceから';
  }

  @override
  String get exploreNoResults => 'このデスティネーションのアクティビティは見つかりませんでした。';

  @override
  String get exploreLoadError => '候補を読み込めませんでした。タップして再試行してください。';

  @override
  String get restaurantPollTitle => '場所を選ぶ';

  @override
  String get addRestaurantOption => 'レストランを追加';

  @override
  String get restaurantSearchHint => 'レストランを検索...';

  @override
  String get setAsVenueButton => '会場に設定';

  @override
  String organizedBy(String name) {
    return 'Organised by $name';
  }

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String get deleteEventSubtitle => 'このイベントを完全に削除';

  @override
  String deleteEventMessage(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get eventTypeTrip => '旅行';

  @override
  String get eventTypeBirthday => '誕生日';

  @override
  String get eventTypeWedding => '結婚式';

  @override
  String get eventTypeSocial => 'ソーシャル';

  @override
  String get eventTypeQuickBites => 'クイックバイツ';

  @override
  String get eventTypeSignup => 'サインアップ';

  @override
  String signupSpotsFilled(int filled, int total) {
    return '$filled / $total 席が埋まっています';
  }

  @override
  String signupWaitlistCount(int count) {
    return '$count 人がウェイトリストに登録中';
  }

  @override
  String get signupEventFull => '満席';

  @override
  String get signupSessionFull => 'セッションは満員です';

  @override
  String get signupJoinWaitlist => 'ウェイトリストに追加';

  @override
  String get signupClaimSpot => '席を確保する';

  @override
  String signupConfirmedPosition(int pos) {
    return 'リストの#$pos番目です！';
  }

  @override
  String signupWaitlistPosition(int pos) {
    return 'ウェイトリストの#$pos番目です';
  }

  @override
  String get signupWaitlistEnabled => 'ウェイトリストを有効化';

  @override
  String get signupWaitlistDescription => '定員を超えたゲストは順番待ちリストに入ります';

  @override
  String get signupRosterTab => '名簿';

  @override
  String get signupInviteTab => '招待';

  @override
  String get signupPromoteGuest => '確定枠に昇格';

  @override
  String get signupRemoveGuest => 'イベントから削除';

  @override
  String get signupCopyLink => '招待リンクをコピー';

  @override
  String get signupShowQr => 'QRコードを表示';

  @override
  String get signupLocked => '登録が締め切られました';

  @override
  String get signupLockedMessage => '登録が締め切られました。主催者にお問い合わせください。';

  @override
  String get signupPendingReview => 'リクエストは承認待ちです';

  @override
  String get signupCancelSpot => '席をキャンセル';

  @override
  String get signupMarkAttended => '出席';

  @override
  String get signupMarkNoShow => '欠席';

  @override
  String get signupAttendanceHeader => '出欠';

  @override
  String get signupRepeat => '繰り返し';

  @override
  String get signupRepeatNone => 'なし';

  @override
  String get signupRepeatWeekly => '毎週';

  @override
  String get signupRepeatBiweekly => '隔週';

  @override
  String get signupRepeatMonthly => '毎月';

  @override
  String get signupNextSession => '次のセッションを作成';

  @override
  String get signupCarryOverGuests => '確定ゲストを自動登録';

  @override
  String get signupCarryOverGuestsHint => 'ゲストに通知が届き、キャンセルできます';

  @override
  String signupPartOfSeries(String interval) {
    return '$intervalシリーズの一部';
  }

  @override
  String get chooseEventType => '何を計画していますか？';

  @override
  String get eventTypePicker => 'イベントの種類';

  @override
  String get routeTab => 'ルート';

  @override
  String get leaveEventTitle => 'イベントを退出しますか？';

  @override
  String leaveEventMessage(String eventTitle) {
    return '$eventTitleから削除され、アクセスできなくなります。';
  }

  @override
  String get generateWithAi => 'AI Assistant';

  @override
  String get aiTripPlannerSubtitle => '目的地について質問したり、スタイルを説明してスポットを追加できます。';

  @override
  String get aiChatHint => '旅行について何でも聞いてください...';

  @override
  String get tierFree => 'Basic';

  @override
  String get tierPro => 'プロ';

  @override
  String tierProTrial(String date) {
    return 'Proトライアル · 終了日: $date';
  }

  @override
  String get cancelTrial => 'トライアルをキャンセル';

  @override
  String get cancelTrialConfirmTitle => '無料トライアルをキャンセルしますか？';

  @override
  String get cancelTrialConfirmMessage =>
      'Proの機能へのアクセスが即座に失われます。後でProにアップグレードできます。';

  @override
  String get cancelTrialSuccess => 'トライアルがキャンセルされました。現在Basicプランです。';

  @override
  String get cancelTrialError => 'トライアルのキャンセルに失敗しました。もう一度お試しください。';

  @override
  String get upgradeToPro => 'プロにアップグレード';

  @override
  String get upgradeNow => '今すぐアップグレード';

  @override
  String get proAnnualPrice => '\$39.99 / 年';

  @override
  String get proMonthlyPrice => '\$4.99 / 月';

  @override
  String get proAnnualSavings => '33%お得';

  @override
  String get comparePlans => 'プランを比較';

  @override
  String get restorePurchases => '購入を復元';

  @override
  String get proFeatureAIPlanner => 'AI Event Assistant';

  @override
  String get proFeatureUnlimitedEvents => '無制限のイベントとゲスト';

  @override
  String get proFeatureExpenseExport => 'Expense export';

  @override
  String get proFeatureOfflineAccess => 'オフラインアクセス';

  @override
  String get proFeatureTemplates => 'イベントテンプレート';

  @override
  String get freeEventsLimit => 'イベント（最大3件）';

  @override
  String get freeGuestsLimit => 'ゲスト（最大10人）';

  @override
  String get freeBasicPlanning => 'RSVP・基本プランニング';

  @override
  String get budgetPerHeadLabel => '一人あたりの予算（任意）';

  @override
  String get cuisineTagsLabel => '料理ジャンル';

  @override
  String get rsvpDeadlineLabel => '返信期限';

  @override
  String get rsvpDeadlineClosed => '返信締め切り';

  @override
  String get vibePickerLabel => '雰囲気（任意）';

  @override
  String get honoreeNameLabel => '誰の誕生日ですか？';

  @override
  String get honoreeNameHint => '名前を入力';

  @override
  String get birthYearLabel => '生年（任意）';

  @override
  String get birthYearHint => '例：1996';

  @override
  String get celebrateTab => 'パーティー';

  @override
  String get giftsTab => 'ギフト';

  @override
  String get memoriesTab => '思い出';

  @override
  String birthdayHeroTitle(String name) {
    return '$nameの誕生日';
  }

  @override
  String turningAge(int age) {
    return '$age歳になります';
  }

  @override
  String birthdayCountdownDays(int count) {
    return 'あと$count日';
  }

  @override
  String birthdayCountdownHours(int count) {
    return 'あと$count時間';
  }

  @override
  String get birthdayToday => '今日が当日！';

  @override
  String activityVoteTitle(String name) {
    return '$nameのパーティーで何をする？';
  }

  @override
  String get activityVoteEmpty => 'アクティビティがまだありません。';

  @override
  String get addActivityOption => 'アクティビティを追加';

  @override
  String cakeVoteTitle(String name) {
    return '$nameはどんなケーキが欲しい？';
  }

  @override
  String get cakeVoteEmpty => 'ケーキの選択肢がまだありません。';

  @override
  String get addCakeOption => 'フレーバーを追加';

  @override
  String wishlistTitle(String name) {
    return '$nameのウィッシュリスト';
  }

  @override
  String wishlistEmpty(String name) {
    return 'まだアイテムがありません。$nameが喜ぶものを追加して！';
  }

  @override
  String get addWishlistItem => 'ギフトアイデアを追加';

  @override
  String get wishlistItemLabel => 'ギフトアイデア';

  @override
  String get wishlistPriceRange => '価格帯（任意）';

  @override
  String get wishlistLink => 'リンク（任意）';

  @override
  String get claimItem => '私が担当します！';

  @override
  String get unclaimItem => '取り消す';

  @override
  String get itemClaimed => '誰かが担当中';

  @override
  String itemClaimedBy(String name) {
    return '$nameが担当中';
  }

  @override
  String get markReceived => '受け取り済みにする';

  @override
  String get giftPoolTitle => 'グループギフト';

  @override
  String get giftPoolEmpty => 'グループギフトはまだありません。';

  @override
  String get createGiftPool => 'グループギフトを始める';

  @override
  String get giftPoolName => 'ギフト名';

  @override
  String get giftPoolTarget => '目標金額';

  @override
  String giftPoolProgress(String pledged, String target) {
    return '$target中$pledgedが約束済み';
  }

  @override
  String giftPoolContributors(int count) {
    return '$count人が参加';
  }

  @override
  String get pledgeAmount => '約束金額';

  @override
  String get addPledge => '参加する';

  @override
  String get myPledge => '私の約束';

  @override
  String get removePledge => '約束を取り消す';

  @override
  String predictionsTitle(String name) {
    return '$nameへの予言';
  }

  @override
  String predictionsSealed(int count) {
    return '$count件の予言がシール中';
  }

  @override
  String get revealPredictions => '予言を公開';

  @override
  String get predictionsHowItWorks => '予測はイベント日まで封印されます — 誰が当てたかはその後のお楽しみ！';

  @override
  String predictionsEmpty(String name) {
    return '$nameへの予言はまだありません。';
  }

  @override
  String get addPrediction => '予言を追加';

  @override
  String predictionHint(String name) {
    return '$nameの来年について予言してみて...';
  }

  @override
  String wishesTitle(String name) {
    return '$nameへのお祝いの言葉';
  }

  @override
  String wishesSealed(String name) {
    return '$nameにはまだ見えません';
  }

  @override
  String get wishesHowItWorks => '願い事はオーガナイザーが当日に公開するまで秘密に保たれます！';

  @override
  String get wishesEmpty => 'まだお祝いの言葉がありません。';

  @override
  String get addWish => 'お祝いの言葉を送る';

  @override
  String wishHint(String name) {
    return '$nameへのお祝いの言葉を書いて...';
  }

  @override
  String get blowOutCandles => 'ろうそくを吹き消して！';

  @override
  String get wishesRevealed => 'お祝いの言葉が公開されました！';

  @override
  String memoryWallTitle(String name) {
    return '$nameの思い出の壁';
  }

  @override
  String memoryWallEmpty(String name) {
    return '$nameとの思い出をシェアして！';
  }

  @override
  String get addMemory => '思い出を追加';

  @override
  String memoryCaptionHint(String name) {
    return '$nameとの一番好きな思い出を書いて...';
  }

  @override
  String get toastsTitle => 'スピーチ & トースト';

  @override
  String toastsEmpty(String name) {
    return '$nameへのスピーチはまだありません。';
  }

  @override
  String get addToast => 'スピーチを書く';

  @override
  String get toastTypeSweet => 'ハート';

  @override
  String get toastTypeFunny => '面白い';

  @override
  String get toastTypePoem => '詩';

  @override
  String get toastTextHint => 'スピーチをここに書いて...';

  @override
  String get exportToasts => 'スピーチをエクスポート';

  @override
  String get wishesTab => 'ウィッシュ';

  @override
  String get predictionsTab => '予言';

  @override
  String get wallTab => 'ウォール';

  @override
  String get pleaseSelectEventType => 'イベントの種類を選択してください';

  @override
  String get notifications => '通知';

  @override
  String get notificationsEmpty => 'すべて確認済みです！';

  @override
  String get notificationsMarkAllRead => 'すべて既読にする';

  @override
  String get sessionActivityTab => 'アクティビティ';

  @override
  String get queueUp => 'キュー';

  @override
  String get createQueue => 'キューを作成';

  @override
  String get playersPerRound => 'ラウンドあたりの人数';

  @override
  String get maxRounds => '最大ラウンド数';

  @override
  String get noLimit => '制限なし';

  @override
  String get checkIn => 'チェックイン';

  @override
  String get checkOut => 'チェックアウト';

  @override
  String get joinQueue => 'キューに参加';

  @override
  String get leaveQueue => 'キューを離れる';

  @override
  String get startQueue => '開始';

  @override
  String get nextRound => '次のラウンド';

  @override
  String roundN(int n) {
    return 'ラウンド $n';
  }

  @override
  String get allRejoinQueue => '全員がキューに戻る';

  @override
  String get releaseToFreePool => 'フリープールに戻す';

  @override
  String get freePool => 'フリープール';

  @override
  String get nowPlaying => 'プレイ中';

  @override
  String get waitingQueue => '待機中';

  @override
  String get queueEnded => 'キュー終了';

  @override
  String get noQueuesYet => 'まだアクティビティはありません';

  @override
  String get createFirstQueue => '最初のキューを作成して始めましょう';

  @override
  String queueRoundComplete(int n) {
    return 'ラウンド $n 完了！';
  }

  @override
  String get setupQueues => 'キューを設定';

  @override
  String get numberOfQueues => 'キュー数';

  @override
  String get spotsPerQueue => 'キューあたりのスポット数';

  @override
  String get clearQueue => 'クリア';

  @override
  String get queueFull => 'キューが満員です';

  @override
  String get alreadyInQueue => 'すでにキューに入っています';

  @override
  String get addToSlot => 'スポットをゲット！';

  @override
  String get addMyselfToQueue => '';

  @override
  String get addSomeoneElse => '';

  @override
  String get selectAMember => 'メンバーを選択';

  @override
  String get searchMembersHint => 'メンバーを検索…';

  @override
  String get leaveSlotTitle => 'スロットを退出？';

  @override
  String leaveSlotMessage(int number) {
    return 'キュー#$numberのスポットから撤退しますか？';
  }

  @override
  String get leaveSlotConfirm => '撤退';

  @override
  String get kickFromSlotTitle => '追い出す？';

  @override
  String kickFromSlotMessage(String name, int number) {
    return 'キュー#$numberから$nameを外しますか？';
  }

  @override
  String get kickFromSlotConfirm => '追い出す！';

  @override
  String get allowDuplicates => '複数のキューへの参加を許可';

  @override
  String get allowDuplicatesSubtitle => 'メンバーは同時に複数のキューに参加できます';

  @override
  String get customizeQueues => 'キューをカスタマイズ';

  @override
  String get pollSpinButton => '回す';

  @override
  String get pollWheelTitle => 'ルーレットを回す';

  @override
  String get pollWheelResult => 'ルーレットが選びました！';

  @override
  String get pollWheelSpin => '回す';

  @override
  String get pollWheelSpinAgain => 'もう一度回す';

  @override
  String get pollsDeleteConfirmTitle => '投票を削除しますか？';

  @override
  String get pollsDeleteConfirmBody => '投票とすべての票が削除されます。元に戻せません。';

  @override
  String get pollWheelHeadline => 'ルーレットにおまかせ！';

  @override
  String get pollWheelHeadlineFood => 'いただきます！';

  @override
  String get pollWheelSpinning => '回転中…';
}
