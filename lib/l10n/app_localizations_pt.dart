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
  String get infoTab => 'Info';

  @override
  String get guestsTab => 'Guests';

  @override
  String get noGuestsYet =>
      'Nenhum convidado ainda. Toque em + para adicionar um.';

  @override
  String get addGuest => 'Adicionar convidado';

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
  String get splitAmong => 'Split among guests';

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
  String get eventTypeTrip => 'Viagem';

  @override
  String get eventTypeBirthday => 'Aniversário';

  @override
  String get eventTypeWedding => 'Casamento';

  @override
  String get eventTypeSocial => 'Social';

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
}
