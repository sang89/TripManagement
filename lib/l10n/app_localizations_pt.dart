// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String get close => 'Fechar';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get save => 'Salvar';

  @override
  String get required => 'Obrigatório';

  @override
  String get notes => 'Notas';

  @override
  String get email => 'E-mail';

  @override
  String get phone => 'Telefone';

  @override
  String get remove => 'Remover';

  @override
  String get notSet => 'Não definido';

  @override
  String failed(String error) {
    return 'Falhou: $error';
  }

  @override
  String comingSoon(String feature) {
    return '$feature — Em breve';
  }

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get languageSectionTitle => 'Idioma';

  @override
  String get selectLanguageTitle => 'Selecionar idioma';

  @override
  String get systemDefault => 'Padrão do sistema';

  @override
  String get themeSectionTitle => 'Aparência';

  @override
  String get themeSystem => 'Padrão do sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get accountSectionTitle => 'Conta';

  @override
  String get changePasswordTitle => 'Alterar senha';

  @override
  String get currentPassword => 'Senha atual';

  @override
  String get newPassword => 'Nova senha';

  @override
  String get confirmNewPassword => 'Confirmar nova senha';

  @override
  String get updatePassword => 'Atualizar senha';

  @override
  String get passwordUpdated => 'Senha atualizada';

  @override
  String get currentPasswordIncorrect => 'A senha atual está incorreta';

  @override
  String get passwordMinLength => 'Pelo menos 8 caracteres';

  @override
  String get passwordsDoNotMatch => 'As senhas não coincidem';

  @override
  String get deleteAccountTitle => 'Excluir conta';

  @override
  String get deleteAccountWarning =>
      'Isso excluirá permanentemente sua conta e todos os dados. Esta ação não pode ser desfeita.';

  @override
  String get deleteAccountInstructions =>
      'Para excluir sua conta, entre em contato com o suporte. Processaremos sua solicitação em 48 horas.';

  @override
  String get supportEmail => 'support@tripplanner.app';

  @override
  String get emailCopied => 'E-mail copiado para a área de transferência';

  @override
  String get copyEmail => 'Copiar e-mail';

  @override
  String get aboutSectionTitle => 'Sobre';

  @override
  String get appVersion => 'Versão do app';

  @override
  String get privacyPolicy => 'Política de privacidade';

  @override
  String get termsOfService => 'Termos de serviço';

  @override
  String get myProfile => 'Meu perfil';

  @override
  String get failedToLoadProfile => 'Falha ao carregar o perfil';

  @override
  String get settingsTooltip => 'Configurações';

  @override
  String get editProfileTooltip => 'Editar perfil';

  @override
  String get personalInfoSection => 'Informações pessoais';

  @override
  String get fullName => 'Nome completo';

  @override
  String get fullNameHint => 'Seu nome completo';

  @override
  String get jobTitle => 'Cargo';

  @override
  String get jobTitleHint => 'ex.: Viajante entusiasta';

  @override
  String get contactInfoSection => 'Informações de contato';

  @override
  String get managedByAccount => 'Gerenciado pela sua conta';

  @override
  String get memberSince => 'Membro desde';

  @override
  String get saveChanges => 'Salvar alterações';

  @override
  String get signOut => 'Sair';

  @override
  String get chooseFromLibrary => 'Escolher da galeria';

  @override
  String get takePhoto => 'Tirar foto';

  @override
  String get removePhoto => 'Remover foto';

  @override
  String uploadFailed(String error) {
    return 'Falha no upload: $error';
  }

  @override
  String get uploadRequiresConnection => 'Upload requer conexão';

  @override
  String get photoUpdated => 'Foto atualizada';

  @override
  String get removeRequiresConnection => 'Requer conexão para remover a foto';

  @override
  String removeFailed(String error) {
    return 'Falha ao remover: $error';
  }

  @override
  String get profileSaved => 'Perfil salvo';

  @override
  String profileSaveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get signOutConfirmTitle => 'Sair?';

  @override
  String get signOutConfirmMessage =>
      'Você será redirecionado para a tela de login.';

  @override
  String get nameTooLong => 'Nome muito longo';

  @override
  String get appTitle => 'Planejador de Viagens';

  @override
  String get signInToAccount => 'Entre na sua conta';

  @override
  String get planNextAdventure => 'Planeje sua próxima aventura';

  @override
  String get signIn => 'Entrar';

  @override
  String get signUp => 'Cadastrar';

  @override
  String get createAccount => 'Criar conta';

  @override
  String get dontHaveAccount => 'Não tem conta?';

  @override
  String get alreadyHaveAccount => 'Já tem uma conta?';

  @override
  String get password => 'Senha';

  @override
  String get enterValidEmail => 'Digite um e-mail válido';

  @override
  String get passwordTooShort => 'Senha muito curta';

  @override
  String get enterYourName => 'Digite seu nome';

  @override
  String get passwordMinimum6 => 'Mínimo 6 caracteres';

  @override
  String get confirmPassword => 'Confirmar senha';

  @override
  String get rememberMe => 'Lembrar-me';

  @override
  String get continueWithGoogle => 'Continuar com o Google';

  @override
  String get continueWithApple => 'Continuar com a Apple';

  @override
  String get orSignInWith => 'ou';

  @override
  String get myTrips => 'Minhas viagens';

  @override
  String get all => 'Todas';

  @override
  String get upcoming => 'Próximas';

  @override
  String get past => 'Passadas';

  @override
  String get deleteTripTitle => 'Excluir viagem?';

  @override
  String deleteTripMessage(String tripTitle) {
    return 'Excluir $tripTitle? Isso não pode ser desfeito.';
  }

  @override
  String get leave => 'Sair';

  @override
  String get leaveTripTooltip => 'Sair da viagem';

  @override
  String get thisTripFallback => 'esta viagem';

  @override
  String get leaveTripTitle => 'Sair da viagem?';

  @override
  String leaveTripMessage(String tripTitle) {
    return 'Você será removido de $tripTitle e perderá o acesso.';
  }

  @override
  String get couldNotLoadTrips => 'Não foi possível carregar as viagens';

  @override
  String get noTripsYet => 'Sem viagens ainda';

  @override
  String get noTripsHint => 'Toque + para começar.';

  @override
  String get noUpcomingTrips => 'Sem próximas viagens';

  @override
  String get noUpcomingTripsHint =>
      'Toque + para planejar sua próxima aventura.';

  @override
  String get noPastTrips => 'Sem viagens passadas';

  @override
  String get noPastTripsHint => 'Suas viagens concluídas aparecerão aqui.';

  @override
  String get editTrip => 'Editar viagem';

  @override
  String get newTrip => 'Nova viagem';

  @override
  String get tripTitle => 'Título da viagem';

  @override
  String get startingFromLabel => 'Partindo de (opcional)';

  @override
  String get destinationLabel => 'Destino';

  @override
  String get notesOptional => 'Notas (opcional)';

  @override
  String get startLabel => 'Início';

  @override
  String get endLabel => 'Fim';

  @override
  String get setStartDateTime => 'Definir data e hora de início';

  @override
  String get setEndDateTime => 'Definir data e hora de fim';

  @override
  String get endDateAfterStart =>
      'A data de fim deve ser após a data de início.';

  @override
  String get stopsSection => 'Paradas';

  @override
  String get addStop => 'Adicionar parada';

  @override
  String get noStopsYet => 'Nenhuma parada adicionada.';

  @override
  String get mapSection => 'Mapa';

  @override
  String get membersSection => 'Membros';

  @override
  String get addMember => 'Adicionar membro';

  @override
  String get fullNameLabel => 'Nome';

  @override
  String get emailOptional => 'E-mail (opcional)';

  @override
  String get phoneOptional => 'Telefone (opcional)';

  @override
  String get saveTrip => 'Salvar viagem';

  @override
  String get you => 'Você';

  @override
  String get organizer => 'Organizador';

  @override
  String get member => 'Membro';

  @override
  String get tripNotFound => 'Viagem não encontrada';

  @override
  String get editTripTooltip => 'Editar viagem';

  @override
  String get overview => 'Visão geral';

  @override
  String get itinerary => 'Itinerário';

  @override
  String get mapTab => 'Mapa';

  @override
  String get startingFrom => 'Partindo de';

  @override
  String get destination => 'Destino';

  @override
  String get noStopsInItinerary => 'Sem paradas ainda';

  @override
  String get addFirstStop => 'Toque + para adicionar sua primeira parada.';

  @override
  String get removeStopTitle => 'Remover parada?';

  @override
  String removeStopMessage(String stopTitle) {
    return 'Remover \"$stopTitle\" do itinerário?';
  }

  @override
  String get arrive => 'Chegada';

  @override
  String get depart => 'Partida';

  @override
  String get stopTitleLabel => 'Título';

  @override
  String get addressOptional => 'Endereço (opcional)';

  @override
  String get arriveLabel => 'Chegada';

  @override
  String get departLabel => 'Partida';

  @override
  String get addStopButton => 'Adicionar parada';

  @override
  String get editStop => 'Editar parada';

  @override
  String get navTrips => 'Viagens';

  @override
  String get navJournal => 'Diário';

  @override
  String get navProfile => 'Perfil';

  @override
  String get journalComingSoon => 'Diário em breve';

  @override
  String get memberSearching => 'Buscando…';

  @override
  String get memberAccountFound => 'Conta encontrada';

  @override
  String get memberNoAccountFound => 'Nenhuma conta encontrada';

  @override
  String get memberLinkedAccount => 'Conta vinculada';

  @override
  String get selectFriendOptional => 'Selecionar um amigo (opcional)';

  @override
  String get searchFriends => 'Pesquisar amigos…';

  @override
  String get invitePending => 'Pendente';

  @override
  String get inviteAccepted => 'Aceito';

  @override
  String get inviteDeclined => 'Recusado';

  @override
  String get memberLeft => 'Saiu';

  @override
  String invitedBy(String name) {
    return 'Convidado por $name';
  }

  @override
  String tripInvitationsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convites de viagem',
      one: '1 convite de viagem',
    );
    return '$_temp0';
  }

  @override
  String get acceptInvite => 'Aceitar';

  @override
  String get declineInvite => 'Recusar';

  @override
  String get inviteNotifTitle => 'Convite de viagem';

  @override
  String inviteNotifBody(String tripTitle) {
    return 'Você foi convidado para $tripTitle';
  }

  @override
  String get blockReinviteLabel =>
      'Não permitir convites futuros para esta viagem';

  @override
  String get reinviteBlockedError =>
      'Este utilizador optou por não receber convites futuros para esta viagem';

  @override
  String get resendInvite => 'Reenviar convite';

  @override
  String inviteResentTo(String name) {
    return 'Convite reenviado para $name';
  }

  @override
  String get declineInviteConfirmTitle => 'Recusar convite?';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return 'Recusar o convite para «$tripTitle»? Perderá o acesso.';
  }

  @override
  String get securitySectionTitle => 'Segurança';

  @override
  String get biometricToggleTitle => 'Face ID / Touch ID';

  @override
  String get biometricToggleSubtitle => 'Usar biometria para desbloquear o app';

  @override
  String get biometricLockTitle => 'Confirme sua identidade';

  @override
  String get biometricLockSubtitle => 'Autentique-se para acessar sua conta';

  @override
  String get biometricSignInWithFace => 'Entrar com Face ID';

  @override
  String get biometricSignInWithFingerprint => 'Entrar com impressão digital';

  @override
  String get biometricSignInWithBiometrics => 'Entrar com biometria';

  @override
  String get biometricReason => 'Autentique-se para acessar sua conta';

  @override
  String get biometricFailed => 'Autenticação falhou. Tente novamente.';

  @override
  String get usePasswordInstead => 'Usar senha';

  @override
  String get navFriends => 'Amigos';

  @override
  String get friendsTabFriends => 'Amigos';

  @override
  String get friendsTabRequests => 'Solicitações';

  @override
  String get friendsAddFriend => 'Adicionar amigo';

  @override
  String get friendsSearchHint => 'Buscar por nome, e-mail ou telefone';

  @override
  String get friendsNoResults => 'Nenhum usuário encontrado';

  @override
  String get friendsRequestSent => 'Solicitação de amizade enviada';

  @override
  String get friendsAccept => 'Aceitar';

  @override
  String get friendsDecline => 'Recusar';

  @override
  String get friendsRemove => 'Remover amigo';

  @override
  String friendsRemoveConfirm(String name) {
    return 'Remover $name dos seus amigos?';
  }

  @override
  String get friendsNoFriends => 'Sem amigos ainda';

  @override
  String get friendsNoFriendsHint =>
      'Pesquise alguém para adicionar como amigo.';

  @override
  String get friendsNoRequests => 'Sem solicitações pendentes';

  @override
  String get friendsIncomingSection => 'Recebidas';

  @override
  String get friendsOutgoingSection => 'Enviadas';

  @override
  String get friendsCancelRequest => 'Cancelar solicitação';

  @override
  String get chatTabLabel => 'Chat';

  @override
  String get chatSendHint => 'Mensagem…';

  @override
  String get chatNoMessages => 'Sem mensagens ainda. Diga olá!';

  @override
  String get chatSend => 'Enviar';

  @override
  String get notificationsSectionTitle => 'Notificações';

  @override
  String get mentionNotifToggleTitle => 'Alertas de menção';

  @override
  String get mentionNotifToggleSubtitle =>
      'Receba notificações quando for @mencionado em um chat de viagem';

  @override
  String get privacySectionTitle => 'Privacidade';

  @override
  String get blockedUsersTitle => 'Usuários bloqueados';

  @override
  String get blockedUsersEmpty => 'Você não bloqueou ninguém';

  @override
  String get blockUser => 'Bloquear';

  @override
  String get unblockUser => 'Desbloquear';

  @override
  String blockConfirmTitle(String name) {
    return 'Bloquear $name?';
  }

  @override
  String get blockConfirmBody =>
      'Eles não poderão adicionar você a viagens ou enviar solicitações de amizade.';

  @override
  String blockSuccess(String name) {
    return '$name foi bloqueado';
  }

  @override
  String unblockSuccess(String name) {
    return '$name foi desbloqueado';
  }

  @override
  String get contactsButton => 'De contatos';

  @override
  String get contactsScreenTitle => 'Encontrar nos contatos';

  @override
  String get contactsPermissionDenied =>
      'O acesso aos contatos é necessário para encontrar seus amigos no TripManagement.';

  @override
  String get contactsOpenSettings => 'Abrir configurações';

  @override
  String get contactsOnApp => 'No TripManagement';

  @override
  String get contactsInviteSection => 'Convidar para o TripManagement';

  @override
  String get contactsEmpty =>
      'Nenhum contato com telefone ou e-mail foi encontrado.';

  @override
  String get contactsAddFriend => 'Adicionar';

  @override
  String get contactsPending => 'Pendente';

  @override
  String get contactsInvite => 'Convidar';

  @override
  String contactsInviteMessage(String name) {
    return 'Olá $name! Estou usando o TripManagement para planejar viagens. Junte-se a mim aqui: [APP_STORE_LINK]';
  }

  @override
  String get navEvents => 'Events';

  @override
  String get newEvent => 'New event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get editEventSubtitle => 'Atualizar detalhes, data ou localização';

  @override
  String get saveEvent => 'Save event';

  @override
  String get eventTitle => 'Event title';

  @override
  String get eventDescription => 'Description (optional)';

  @override
  String get eventLocation => 'Location';

  @override
  String get eventCapacity => 'Máx. de membros (opcional)';

  @override
  String get eventStartDateTime => 'Start date & time';

  @override
  String get eventEndDateTime => 'End date & time (optional)';

  @override
  String get noEventsYet => 'No events yet. Tap + to create one.';

  @override
  String get noUpcomingEvents => 'Nenhum evento próximo';

  @override
  String get noUpcomingEventsHint =>
      'Toque em + para planejar seu próximo evento.';

  @override
  String get noPastEvents => 'Ainda não há eventos passados';

  @override
  String get noPastEventsHint =>
      'Os eventos dos quais você participou aparecerão aqui.';

  @override
  String get filterAll => 'Todos';

  @override
  String get calendarViewToggle => 'Calendário';

  @override
  String get listViewToggle => 'Lista';

  @override
  String get noEventsOnDay => 'Nenhum evento neste dia';

  @override
  String get myEvents => 'My events';

  @override
  String get invitedEvents => 'Invited';

  @override
  String get infoTab => 'Info';

  @override
  String get guestsTab => 'Membros';

  @override
  String get noGuestsYet => 'Sem membros ainda. Toque em + para adicionar um.';

  @override
  String get addGuest => 'Adicionar membro';

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
  String get noMemoriesYet => 'Ainda não há memórias';

  @override
  String get addFirstPhoto => 'Toque em + para adicionar sua primeira foto!';

  @override
  String get slideshow => 'Apresentação de slides';

  @override
  String get captionHint => 'Adicionar legenda…';

  @override
  String get photoUploadLimit =>
      'Limite de envio atingido. Tente novamente em uma hora.';

  @override
  String get photoCapReached => 'Este evento atingiu o limite de fotos.';

  @override
  String get loadMore => 'Carregar mais';

  @override
  String get storiesEditCaption => 'Editar legenda';

  @override
  String get captionSaved => 'Legenda salva';

  @override
  String get saveToGallery => 'Salvar';

  @override
  String get savedToGallery => 'Salvo na galeria';

  @override
  String get sharePhoto => 'Compartilhar';

  @override
  String uploadingProgress(int current, int total) {
    return 'Enviando $current / $total…';
  }

  @override
  String get addExpense => 'Add expense';

  @override
  String get editExpense => 'Editar despesa';

  @override
  String get deleteExpenseTitle => 'Excluir despesa';

  @override
  String deleteExpenseMessage(String description) {
    return 'Excluir \"$description\"? Esta acao nao pode ser desfeita.';
  }

  @override
  String get noExpensesYet => 'Sem despesas ainda';

  @override
  String get expenseDescription => 'What was paid for?';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get splitAmong => 'Dividir entre membros';

  @override
  String get paidBy => 'Pago por';

  @override
  String get selectAll => 'Selecionar tudo';

  @override
  String get deselectAll => 'Desmarcar tudo';

  @override
  String totalOwed(String amount) {
    return 'You owe: $amount';
  }

  @override
  String youAreOwed(String amount) {
    return 'Você tem a receber: $amount';
  }

  @override
  String get settleUp => 'Acertar contas';

  @override
  String get totalSpent => 'Total gasto';

  @override
  String get theScore => 'O placar';

  @override
  String get settlementPlan => 'Plano de quitação';

  @override
  String get allSquare => 'Tudo acertado! 🎉';

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
  String get rsvpNoteHint => 'Adicionar nota (opcional)';

  @override
  String get organizeTab => 'Organizar';

  @override
  String get detailsTab => 'Detalhes';

  @override
  String get todoTab => 'Tarefas';

  @override
  String get cravingsTab => 'Desejos';

  @override
  String get pollsTab => 'Enquetes';

  @override
  String get pollsEmpty => 'Nenhuma enquete ainda.';

  @override
  String get pollsAddPoll => 'Adicionar enquete';

  @override
  String get pollsQuestion => 'Pergunta';

  @override
  String pollsOptionHint(int n) {
    return 'Opção $n';
  }

  @override
  String get pollsAddOption => '+ Adicionar opção';

  @override
  String pollsVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
    );
    return '$_temp0';
  }

  @override
  String get pollsDeletePoll => 'Excluir enquete';

  @override
  String get bringListTitle => 'Tarefas';

  @override
  String get bringListEmpty => 'Sem tarefas ainda. Toque em +.';

  @override
  String get bringListAddItem => 'Adicionar tarefa';

  @override
  String get bringListEditItem => 'Editar tarefa';

  @override
  String get bringListItemLabel => 'O que fazer';

  @override
  String get bringListNote => 'Nota (opcional)';

  @override
  String get bringListAssignTo => 'Atribuir a membro';

  @override
  String get bringListNoAssignment => 'Nao atribuido';

  @override
  String get bringListTake => 'Pegar';

  @override
  String get bringListUnassign => 'Desatribuir';

  @override
  String get rsvpNoteLabel => 'Sua nota';

  @override
  String get confirmRsvp => 'Confirmar';

  @override
  String get foodMoodTitle => 'Com quanta fome você está?';

  @override
  String get foodMoodStarving => 'Morrendo de fome';

  @override
  String get foodMoodCouldEat => 'Poderia comer';

  @override
  String get foodMoodDrinksOnly => 'Só para beber';

  @override
  String get foodMoodNibble => 'Vou beliscar';

  @override
  String get foodMoodDDMode => 'Motorista designado';

  @override
  String get cravingsPrompt => 'O que você está com vontade?';

  @override
  String get cravingsHint =>
      'ramen picante, ambiente aconchegante, menos de R\$20...';

  @override
  String get cravingsPrivacyNote => 'Só você pode ver isso';

  @override
  String get cravingsFindButton => 'Encontre um lugar para mim';

  @override
  String get cravingsEmpty =>
      'Sem resultados. Tente palavras-chave diferentes.';

  @override
  String get cravingsPitchButton => 'Propor ao grupo';

  @override
  String get cravingsPitched => 'Adicionado à votação do grupo!';

  @override
  String get exploreTab => 'Explorar';

  @override
  String exploreTitle(String destination) {
    return 'Atividades em $destination';
  }

  @override
  String get exploreSubtitle => 'Powered by Viator • GetYourGuide • Klook';

  @override
  String get exploreSortCheapest => 'Mais baratos';

  @override
  String get exploreSortTopRated => 'Mais bem avaliados';

  @override
  String get exploreMorePlatforms => 'MAIS PLATAFORMAS';

  @override
  String get bookOnViator => 'Reservar no Viator';

  @override
  String get bookNow => 'Reservar agora';

  @override
  String get browseGetYourGuide => 'Explorar no GetYourGuide';

  @override
  String get browseKlook => 'Explorar no Klook';

  @override
  String exploreFromPrice(String price) {
    return 'A partir de $price';
  }

  @override
  String get exploreNoResults =>
      'Nenhuma atividade encontrada para este destino.';

  @override
  String get exploreLoadError =>
      'Não foi possível carregar sugestões. Toque para tentar novamente.';

  @override
  String get restaurantPollTitle => 'Escolher um lugar';

  @override
  String get addRestaurantOption => 'Adicionar restaurante';

  @override
  String get restaurantSearchHint => 'Pesquisar restaurantes...';

  @override
  String get setAsVenueButton => 'Definir como local';

  @override
  String organizedBy(String name) {
    return 'Organised by $name';
  }

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String get deleteEventSubtitle => 'Remover permanentemente este evento';

  @override
  String deleteEventMessage(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get eventTypeTrip => 'Viagem';

  @override
  String get eventTypeBirthday => 'Aniversário';

  @override
  String get eventTypeWedding => 'Casamento';

  @override
  String get eventTypeSocial => 'Social';

  @override
  String get eventTypeQuickBites => 'Petiscos Rápidos';

  @override
  String get eventTypeSignup => 'Inscrição';

  @override
  String signupSpotsFilled(int filled, int total) {
    return '$filled / $total vagas preenchidas';
  }

  @override
  String signupWaitlistCount(int count) {
    return '$count na lista de espera';
  }

  @override
  String get signupEventFull => 'Evento lotado';

  @override
  String get signupJoinWaitlist => 'Entrar na lista de espera';

  @override
  String get signupClaimSpot => 'Reservar uma vaga';

  @override
  String signupConfirmedPosition(int pos) {
    return 'Você é o #$pos na lista!';
  }

  @override
  String signupWaitlistPosition(int pos) {
    return 'Você é o #$pos na lista de espera';
  }

  @override
  String get signupWaitlistEnabled => 'Ativar lista de espera';

  @override
  String get signupWaitlistDescription =>
      'Convidados além da capacidade entram em uma lista de espera ordenada';

  @override
  String get signupRosterTab => 'Lista';

  @override
  String get signupInviteTab => 'Convidar';

  @override
  String get signupPromoteGuest => 'Promover para confirmado';

  @override
  String get signupRemoveGuest => 'Remover do evento';

  @override
  String get signupCopyLink => 'Copiar link de convite';

  @override
  String get signupShowQr => 'Mostrar QR Code';

  @override
  String get signupLocked => 'Inscrições encerradas';

  @override
  String get signupLockedMessage =>
      'Inscrições encerradas. Entre em contato com o organizador.';

  @override
  String get signupPendingReview => 'Seu pedido está pendente de aprovação';

  @override
  String get signupCancelSpot => 'Cancelar minha vaga';

  @override
  String get signupMarkAttended => 'Compareceu';

  @override
  String get signupMarkNoShow => 'Não compareceu';

  @override
  String get signupAttendanceHeader => 'Presença';

  @override
  String get signupRepeat => 'Repetir';

  @override
  String get signupRepeatNone => 'Nenhuma';

  @override
  String get signupRepeatWeekly => 'Semanal';

  @override
  String get signupRepeatBiweekly => 'A cada 2 semanas';

  @override
  String get signupRepeatMonthly => 'Mensal';

  @override
  String get signupNextSession => 'Criar próxima sessão';

  @override
  String get signupCarryOverGuests =>
      'Inscrever automaticamente os confirmados';

  @override
  String get signupCarryOverGuestsHint =>
      'Os convidados receberão uma notificação e poderão cancelar';

  @override
  String signupPartOfSeries(String interval) {
    return 'Parte de uma série $interval';
  }

  @override
  String get chooseEventType => 'O que você está planejando?';

  @override
  String get eventTypePicker => 'Tipo de evento';

  @override
  String get routeTab => 'Rota';

  @override
  String get leaveEventTitle => 'Sair do evento?';

  @override
  String leaveEventMessage(String eventTitle) {
    return 'Você será removido de $eventTitle e perderá o acesso.';
  }

  @override
  String get generateWithAi => 'AI Assistant';

  @override
  String get aiTripPlannerSubtitle =>
      'Faça perguntas sobre seu destino ou descreva seu estilo para adicionar paradas ao roteiro.';

  @override
  String get aiChatHint => 'Pergunte qualquer coisa sobre sua viagem...';

  @override
  String get tierFree => 'Basic';

  @override
  String get tierPro => 'Pro';

  @override
  String tierProTrial(String date) {
    return 'Teste Pro · Termina em $date';
  }

  @override
  String get cancelTrial => 'Cancelar teste';

  @override
  String get cancelTrialConfirmTitle => 'Cancelar seu teste gratuito?';

  @override
  String get cancelTrialConfirmMessage =>
      'Você perderá acesso imediato aos recursos Pro. Você pode fazer upgrade para Pro mais tarde.';

  @override
  String get cancelTrialSuccess =>
      'Seu teste foi cancelado. Agora você está no plano Basic.';

  @override
  String get cancelTrialError =>
      'Falha ao cancelar o teste. Por favor, tente novamente.';

  @override
  String get upgradeToPro => 'Atualizar para Pro';

  @override
  String get upgradeNow => 'Atualizar agora';

  @override
  String get proAnnualPrice => '\$39,99 / ano';

  @override
  String get proMonthlyPrice => '\$4,99 / mês';

  @override
  String get proAnnualSavings => 'Economize 33%';

  @override
  String get comparePlans => 'Comparar planos';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get proFeatureAIPlanner => 'AI Event Assistant';

  @override
  String get proFeatureUnlimitedEvents => 'Eventos e convidados ilimitados';

  @override
  String get proFeatureExpenseExport => 'Expense export';

  @override
  String get proFeatureOfflineAccess => 'Acesso offline';

  @override
  String get proFeatureTemplates => 'Modelos de eventos';

  @override
  String get freeEventsLimit => 'Eventos (máx. 3)';

  @override
  String get freeGuestsLimit => 'Convidados (máx. 10)';

  @override
  String get freeBasicPlanning => 'RSVP e planejamento básico';

  @override
  String get budgetPerHeadLabel => 'Orçamento por pessoa (opcional)';

  @override
  String get cuisineTagsLabel => 'Cozinha';

  @override
  String get rsvpDeadlineLabel => 'Prazo de confirmação';

  @override
  String get rsvpDeadlineClosed => 'Confirmação encerrada';

  @override
  String get vibePickerLabel => 'Clima (opcional)';

  @override
  String get honoreeNameLabel => 'De quem é o aniversário?';

  @override
  String get honoreeNameHint => 'Digite o nome';

  @override
  String get birthYearLabel => 'Ano de nascimento (opcional)';

  @override
  String get birthYearHint => 'ex: 1996';

  @override
  String get celebrateTab => 'Festa';

  @override
  String get giftsTab => 'Presentes';

  @override
  String get memoriesTab => 'Memórias';

  @override
  String birthdayHeroTitle(String name) {
    return 'Aniversário de $name';
  }

  @override
  String turningAge(int age) {
    return 'Fazendo $age anos';
  }

  @override
  String birthdayCountdownDays(int count) {
    return 'Faltam $count dias';
  }

  @override
  String birthdayCountdownHours(int count) {
    return 'Faltam $count horas';
  }

  @override
  String get birthdayToday => 'Hoje é o grande dia!';

  @override
  String activityVoteTitle(String name) {
    return 'O que fazer na festa de $name?';
  }

  @override
  String get activityVoteEmpty => 'Nenhuma atividade ainda.';

  @override
  String get addActivityOption => 'Adicionar atividade';

  @override
  String cakeVoteTitle(String name) {
    return 'Qual bolo $name quer?';
  }

  @override
  String get cakeVoteEmpty => 'Nenhuma opção de bolo ainda.';

  @override
  String get addCakeOption => 'Adicionar sabor';

  @override
  String wishlistTitle(String name) {
    return 'Lista de $name';
  }

  @override
  String wishlistEmpty(String name) {
    return 'Nenhum item ainda. Adicione algo que $name adoraria!';
  }

  @override
  String get addWishlistItem => 'Adicionar ideia de presente';

  @override
  String get wishlistItemLabel => 'Ideia de presente';

  @override
  String get wishlistPriceRange => 'Faixa de preço (opcional)';

  @override
  String get wishlistLink => 'Link (opcional)';

  @override
  String get claimItem => 'Eu vou pegar este!';

  @override
  String get unclaimItem => 'Cancelar';

  @override
  String get itemClaimed => 'Alguém está cuidando disso';

  @override
  String itemClaimedBy(String name) {
    return 'Reservado por $name';
  }

  @override
  String get markReceived => 'Marcar como recebido';

  @override
  String get giftPoolTitle => 'Presente coletivo';

  @override
  String get giftPoolEmpty => 'Nenhum presente coletivo ainda.';

  @override
  String get createGiftPool => 'Iniciar presente coletivo';

  @override
  String get giftPoolName => 'Nome do presente';

  @override
  String get giftPoolTarget => 'Valor alvo';

  @override
  String giftPoolProgress(String pledged, String target) {
    return '$pledged de $target prometido';
  }

  @override
  String giftPoolContributors(int count) {
    return '$count contribuidores';
  }

  @override
  String get pledgeAmount => 'Valor do compromisso';

  @override
  String get addPledge => 'Comprometer';

  @override
  String get myPledge => 'Meu compromisso';

  @override
  String get removePledge => 'Remover compromisso';

  @override
  String predictionsTitle(String name) {
    return 'Previsões para $name';
  }

  @override
  String predictionsSealed(int count) {
    return '$count previsões seladas';
  }

  @override
  String get revealPredictions => 'Revelar previsões';

  @override
  String get predictionsHowItWorks =>
      'As previsões ficam bloqueadas até a data do evento — depois, veja quem acertou!';

  @override
  String predictionsEmpty(String name) {
    return 'Nenhuma previsão ainda para $name.';
  }

  @override
  String get addPrediction => 'Adicionar previsão';

  @override
  String predictionHint(String name) {
    return 'Preveja algo para o próximo ano de $name...';
  }

  @override
  String wishesTitle(String name) {
    return 'Desejos para $name';
  }

  @override
  String wishesSealed(String name) {
    return '$name ainda não pode ver estes';
  }

  @override
  String get wishesHowItWorks =>
      'Os desejos ficam em segredo até o organizador revelá-los no grande dia!';

  @override
  String get wishesEmpty => 'Nenhum desejo ainda. Seja o primeiro!';

  @override
  String get addWish => 'Fazer um desejo';

  @override
  String wishHint(String name) {
    return 'Escreva seu desejo para $name...';
  }

  @override
  String get blowOutCandles => 'Apagar as velas!';

  @override
  String get wishesRevealed => 'Desejos revelados!';

  @override
  String memoryWallTitle(String name) {
    return 'Mural de memórias de $name';
  }

  @override
  String memoryWallEmpty(String name) {
    return 'Compartilhe memórias com $name!';
  }

  @override
  String get addMemory => 'Adicionar memória';

  @override
  String memoryCaptionHint(String name) {
    return 'Compartilhe sua memória favorita com $name...';
  }

  @override
  String get toastsTitle => 'Brindes e discursos';

  @override
  String toastsEmpty(String name) {
    return 'Nenhum brinde ainda para $name.';
  }

  @override
  String get addToast => 'Escrever um brinde';

  @override
  String get toastTypeSweet => 'Emocionante';

  @override
  String get toastTypeFunny => 'Engraçado';

  @override
  String get toastTypePoem => 'Poema';

  @override
  String get toastTextHint => 'Escreva seu discurso aqui...';

  @override
  String get exportToasts => 'Exportar discursos';

  @override
  String get wishesTab => 'Desejos';

  @override
  String get predictionsTab => 'Previsões';

  @override
  String get wallTab => 'Mural';

  @override
  String get pleaseSelectEventType => 'Por favor selecione um tipo de evento';

  @override
  String get notifications => 'Notificações';

  @override
  String get notificationsEmpty => 'Você está em dia!';

  @override
  String get notificationsMarkAllRead => 'Marcar tudo como lido';

  @override
  String get sessionActivityTab => 'Atividade';

  @override
  String get queueUp => 'Fila';

  @override
  String get createQueue => 'Criar fila';

  @override
  String get playersPerRound => 'Jogadores por rodada';

  @override
  String get maxRounds => 'Máximo de rodadas';

  @override
  String get noLimit => 'Sem limite';

  @override
  String get checkIn => 'Fazer check-in';

  @override
  String get checkOut => 'Fazer check-out';

  @override
  String get joinQueue => 'Entrar na fila';

  @override
  String get leaveQueue => 'Sair da fila';

  @override
  String get startQueue => 'Iniciar';

  @override
  String get nextRound => 'Próxima rodada';

  @override
  String roundN(int n) {
    return 'Rodada $n';
  }

  @override
  String get allRejoinQueue => 'Todos voltam para a fila';

  @override
  String get releaseToFreePool => 'Liberar para o pool';

  @override
  String get freePool => 'Pool livre';

  @override
  String get nowPlaying => 'Jogando agora';

  @override
  String get waitingQueue => 'Aguardando';

  @override
  String get queueEnded => 'Fila encerrada';

  @override
  String get noQueuesYet => 'Nenhuma atividade ainda';

  @override
  String get createFirstQueue => 'Crie a primeira fila para começar';

  @override
  String queueRoundComplete(int n) {
    return 'Rodada $n concluída!';
  }

  @override
  String get setupQueues => 'Configurar filas';

  @override
  String get numberOfQueues => 'Número de filas';

  @override
  String get spotsPerQueue => 'Lugares por fila';

  @override
  String get clearQueue => 'Limpar';

  @override
  String get queueFull => 'Fila cheia';

  @override
  String get alreadyInQueue => 'Você já está em uma fila';

  @override
  String get addToSlot => 'Garanta um lugar!';

  @override
  String get addMyselfToQueue => 'Estou dentro!';

  @override
  String get addSomeoneElse => 'Adicionar parceiro';

  @override
  String get selectAMember => 'Selecionar um membro';

  @override
  String get searchMembersHint => 'Pesquisar membros…';

  @override
  String get leaveSlotTitle => 'Sair do lugar?';

  @override
  String leaveSlotMessage(int number) {
    return 'Retirar-se do lugar na fila #$number?';
  }

  @override
  String get leaveSlotConfirm => 'Retirar';

  @override
  String get kickFromSlotTitle => 'Expulsar?';

  @override
  String kickFromSlotMessage(String name, int number) {
    return 'Remover $name da fila #$number?';
  }

  @override
  String get kickFromSlotConfirm => 'Expulsar!';

  @override
  String get allowDuplicates => 'Permitir múltiplas filas';

  @override
  String get allowDuplicatesSubtitle =>
      'Membros podem estar em mais de uma fila ao mesmo tempo';

  @override
  String get customizeQueues => 'Personalizar filas';
}
