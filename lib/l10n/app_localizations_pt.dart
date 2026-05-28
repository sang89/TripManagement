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
  String get leave => 'Leave';

  @override
  String get leaveTripTooltip => 'Leave trip';

  @override
  String get thisTripFallback => 'this trip';

  @override
  String get leaveTripTitle => 'Leave trip?';

  @override
  String leaveTripMessage(String tripTitle) {
    return 'You will be removed from $tripTitle and lose access.';
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
  String get declineInviteConfirmTitle => 'Recusar convite?';

  @override
  String declineInviteConfirmMessage(String tripTitle) {
    return 'Recusar o convite para «$tripTitle»? Perderá o acesso.';
  }
}
