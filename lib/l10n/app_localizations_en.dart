// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Ell-ena';

  @override
  String get login => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get logout => 'Logout';

  @override
  String get logoutTitle => 'Log out?';

  @override
  String get logoutMessage =>
      'You will need to log in again to access your account.';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get calendar => 'Calendar';

  @override
  String get workspace => 'Workspace';

  @override
  String get chat => 'Chat';

  @override
  String get profile => 'Profile';

  @override
  String get tasks => 'Tasks';

  @override
  String get tickets => 'Tickets';

  @override
  String get meetings => 'Meetings';

  @override
  String get settings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get loading => 'Loading...';

  @override
  String get search => 'Search';

  @override
  String get language => 'Language';

  @override
  String languageName(String localeCode) {
    String _temp0 = intl.Intl.selectLogic(
      localeCode,
      {
        'en': 'English',
        'hi': 'हिन्दी',
        'other': '$localeCode',
      },
    );
    return '$_temp0';
  }

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get refresh => 'Refresh';

  @override
  String get switchTeam => 'Switch Team';

  @override
  String teamCode(String code) {
    return 'Team Code: $code';
  }

  @override
  String get teamFallbackName => 'Team';

  @override
  String get myTeam => 'My Team';

  @override
  String errorSwitchingTeam(String error) {
    return 'Error switching team: $error';
  }

  @override
  String get dashboardWelcomeBack => 'Welcome back,';

  @override
  String get dashboardTodaysOverview => 'Today\'s Overview';

  @override
  String get dashboardTotalTasks => 'Total Tasks';

  @override
  String get dashboardInProgress => 'In Progress';

  @override
  String get dashboardCompleted => 'Completed';

  @override
  String get dashboardOpenTickets => 'Open Tickets';

  @override
  String get dashboardTicketsInProgress => 'Tickets In Progress';

  @override
  String get dashboardResolved => 'Resolved';

  @override
  String get dashboardTaskCompletionByDay => 'Task Completion by Day';

  @override
  String get dashboardWeek => 'Week';

  @override
  String get dashboardMonth => 'Month';

  @override
  String get dashboardNoCompletions => 'No completions yet';

  @override
  String get dashboardUpcoming => 'Upcoming';

  @override
  String get dashboardNothingUpcoming => 'Nothing due today or scheduled soon';

  @override
  String get dashboardRecentActivity => 'Recent Activity';

  @override
  String get dashboardNoRecentActivity => 'No recent activity';

  @override
  String get dashboardTask => 'Task';

  @override
  String get dashboardTicket => 'Ticket';

  @override
  String get dashboardMeeting => 'Meeting';

  @override
  String dashboardStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get newTask => 'New Task';

  @override
  String get newTicket => 'New Ticket';

  @override
  String get newMeeting => 'New Meeting';

  @override
  String get authWelcomeBack => 'Welcome Back';

  @override
  String get authSignInSubtitle => 'Sign in to continue with Ell-ena';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authEnterEmail => 'Please enter your email';

  @override
  String get authEnterValidEmail => 'Please enter a valid email';

  @override
  String get authEnterPassword => 'Please enter your password';

  @override
  String get authPasswordTooShort => 'Password must be at least 6 characters';

  @override
  String get authForgotPassword => 'Forgot Password?';

  @override
  String get authOr => 'OR';

  @override
  String get authSignInWithGoogle => 'Sign in with Google';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authLoginFailed => 'Login failed. Please try again.';

  @override
  String get authInvalidCredentials => 'Invalid email or password';

  @override
  String get authConnectionError => 'Connection error. Please try again.';

  @override
  String get authGoogleSignInFailed => 'Google sign-in failed';

  @override
  String authErrorWithDetails(String error) {
    return 'Error: $error';
  }

  @override
  String get authVerificationEmailSent =>
      'Verification email sent. Please check your inbox.';

  @override
  String get authTeamIdNotFound =>
      'Team ID not found. Please check and try again.';

  @override
  String get authTeamIdLabel => 'Team ID';

  @override
  String get authEnterTeamId => 'Please enter team ID';

  @override
  String get authTeamIdLength => 'Team ID must be 6 characters';

  @override
  String get authFullNameLabel => 'Full Name';

  @override
  String get authEnterName => 'Please enter your name';

  @override
  String get authConfirmPasswordLabel => 'Confirm Password';

  @override
  String get authConfirmPasswordPrompt => 'Please confirm your password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get authTeamNameLabel => 'Team Name';

  @override
  String get authEnterTeamName => 'Please enter team name';

  @override
  String get authAdminNameLabel => 'Admin Name';

  @override
  String get authEnterAdminName => 'Please enter admin name';

  @override
  String get authAdminEmailLabel => 'Admin Email';

  @override
  String get authEnterAdminEmail => 'Please enter admin email';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authSignUpSubtitle => 'Join Ell-ena to get started';

  @override
  String get authJoinTheTeamTab => 'Join the Team';

  @override
  String get authCreateTheTeamTab => 'Create the Team';

  @override
  String get authJoinTeam => 'Join Team';

  @override
  String get authCreateTeam => 'Create Team';

  @override
  String get authSignUpWithGoogle => 'Sign up with Google';

  @override
  String get authAlreadyHaveAccount => 'Already have an account? Sign In';

  @override
  String get authResetCodeSent => 'Reset code sent to your email';

  @override
  String get authGenericError => 'An error occurred. Please try again.';

  @override
  String get authInvalidEmailAddress => 'Invalid email address';

  @override
  String get authEmailNotFound => 'Email address not found';

  @override
  String get authTooManyAttempts =>
      'Too many attempts. Please try again later.';

  @override
  String get authResetPasswordTitle => 'Reset Password';

  @override
  String get authResetPasswordSubtitle =>
      'Enter your email to receive a reset code';

  @override
  String get authSendResetCode => 'Send Reset Code';

  @override
  String get authBackToLogin => 'Back to Login';

  @override
  String get authPasswordUpdated => 'Password updated successfully';

  @override
  String get authPasswordUpdateFailed => 'Failed to update password';

  @override
  String get authSetNewPasswordTitle => 'Set New Password';

  @override
  String get authSetNewPasswordSubtitle =>
      'Create a new password for your account';

  @override
  String get authNewPasswordLabel => 'New Password';

  @override
  String get authEnterNewPassword => 'Please enter a password';

  @override
  String get authUpdatePassword => 'Update Password';

  @override
  String get authVerificationFailed => 'Verification failed';

  @override
  String get authCodeExpiredOrInvalid =>
      'Verification code has expired or invalid. Please request a new code.';

  @override
  String get authInvalidCode => 'Invalid verification code. Please try again.';

  @override
  String get authCodeExpired =>
      'Verification code has expired. Please request a new code.';

  @override
  String get authCodeResent =>
      'Verification code resent successfully. Please check your inbox and spam folder.';

  @override
  String get authResendFailed => 'Failed to resend code';

  @override
  String get authEmailNotFoundOrInvalid =>
      'Email address not found or invalid.';

  @override
  String get authUnableToResend =>
      'Unable to resend code. Please go back and try again.';

  @override
  String get authTeamCreatedTitle => 'Team Created Successfully!';

  @override
  String get authYourTeamIdIs => 'Your Team ID is:';

  @override
  String get authCopyTeamId => 'Copy Team ID';

  @override
  String get authTeamIdCopied => 'Team ID copied to clipboard';

  @override
  String get authShareTeamId =>
      'Share this ID with your team members so they can join your team.';

  @override
  String get authContinue => 'Continue';

  @override
  String get authVerifyEmailTitle => 'Verify Email';

  @override
  String authVerifyEmailSubtitle(String email) {
    return 'Enter the 6-digit code sent to $email';
  }

  @override
  String authResendCodeIn(String countdown) {
    return 'Resend code in $countdown';
  }

  @override
  String get authCheckSpamFolder =>
      'Check your spam/junk folder if you don\'t\n see the email.';

  @override
  String get authVerifyCode => 'Verify Code';

  @override
  String get authDidNotReceiveCode => 'Didn\'t receive the code? ';

  @override
  String get authResend => 'Resend';

  @override
  String get authFailedToJoinTeam => 'Failed to join team';

  @override
  String get authFailedToCreateTeam => 'Failed to create team';

  @override
  String get authCompleteSetup => 'Complete Your Setup';

  @override
  String get authChooseHowToProceed => 'Choose how you want to proceed:';

  @override
  String get authYourNameLabel => 'Your Name';

  @override
  String get authTeamCodeLabel => 'Team Code';

  @override
  String get authEnterTeamCode => 'Please enter team code';

  @override
  String get onboardingTaskManagementTitle => 'All-in-One Task Management';

  @override
  String get onboardingTaskManagementDescription =>
      'Create tickets, to-dos, and transcribe meetings—all in one place.';

  @override
  String get onboardingAssistantTitle => 'AI-Powered Assistant';

  @override
  String get onboardingAssistantDescription =>
      'Just chat with Ell-ena and let AI do the heavy lifting.';

  @override
  String get onboardingContextTitle => 'Smart Context';

  @override
  String get onboardingContextDescription =>
      'Smarter you with AI-powered context awareness.';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String meetingErrorDeleting(String error) {
    return 'Error deleting meeting: $error';
  }

  @override
  String get meetingCouldNotLaunchUrl => 'Could not launch meeting URL';

  @override
  String meetingErrorLaunchingUrl(String error) {
    return 'Error launching URL: $error';
  }

  @override
  String get meetingUpcoming => 'Upcoming';

  @override
  String get meetingPast => 'Past';

  @override
  String get meetingNoUpcoming => 'No upcoming meetings';

  @override
  String get meetingNoPast => 'No past meetings';

  @override
  String get meetingEmptyUpcomingHint => 'Create new meetings to get started';

  @override
  String get meetingEmptyPastHint => 'Past meetings will appear here';

  @override
  String get meetingToday => 'Today';

  @override
  String get meetingTomorrow => 'Tomorrow';

  @override
  String get meetingYesterday => 'Yesterday';

  @override
  String meetingDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get meetingUntitled => 'Untitled Meeting';

  @override
  String get meetingUnknownUser => 'Unknown';

  @override
  String get meetingCancelMeetingTooltip => 'Cancel Meeting';

  @override
  String meetingDurationMin(String minutes) {
    return '$minutes min';
  }

  @override
  String meetingCreatedBy(String name) {
    return 'Created by $name';
  }

  @override
  String get meetingJoin => 'Join';

  @override
  String get meetingTranscription => 'Transcription';

  @override
  String get meetingAiSummary => 'AI Summary';

  @override
  String get meetingSelectDateTimeFirst => 'Please select date and time first';

  @override
  String get meetingTimeMustBeFuture => 'Meeting time must be in the future';

  @override
  String get meetingMeetLinkCreated => 'Google Meet link created successfully';

  @override
  String get meetingMeetLinkFailed =>
      'Failed to create Google Meet link. Please sign in with Google.';

  @override
  String get meetingRetry => 'Retry';

  @override
  String get meetingSelectDatePrompt => 'Please select a date';

  @override
  String get meetingSelectTimePrompt => 'Please select a time';

  @override
  String get meetingOnlyGoogleMeetSupported =>
      'Only Google Meet URLs are supported for transcription';

  @override
  String meetingFailedToCreate(String error) {
    return 'Failed to create meeting: $error';
  }

  @override
  String meetingErrorCreating(String error) {
    return 'Error creating meeting: $error';
  }

  @override
  String get meetingCreateTitle => 'Create Meeting';

  @override
  String get meetingTitleRequiredLabel => 'Title *';

  @override
  String get meetingEnterTitle => 'Please enter a title';

  @override
  String get meetingDescription => 'Description';

  @override
  String get meetingSelectDateRequired => 'Select Date *';

  @override
  String get meetingSelectTimeRequired => 'Select Time *';

  @override
  String get meetingDurationMinutesLabel => 'Duration (minutes)';

  @override
  String get meetingDurationPositive => 'Duration must be greater than 0';

  @override
  String get meetingEnterValidNumber => 'Please enter a valid number';

  @override
  String get meetingGoogleMeetUrl => 'Google Meet URL';

  @override
  String get meetingCreatingMeetLink => 'Creating Meet Link...';

  @override
  String get meetingCreateMeetLink => 'Create Google Meet Link';

  @override
  String get meetingTranscriptionGoogleMeetOnly =>
      'Ellena AI transcription only works with Google Meet URLs';

  @override
  String get meetingNotFound => 'Meeting not found';

  @override
  String meetingErrorLoadingDetails(String error) {
    return 'Error loading meeting details: $error';
  }

  @override
  String get meetingTitleEmpty => 'Title cannot be empty';

  @override
  String get meetingSelectDateTime => 'Please select date and time';

  @override
  String meetingErrorUpdating(String error) {
    return 'Error updating meeting: $error';
  }

  @override
  String get meetingTicketCreated => 'Ticket created';

  @override
  String meetingFailedToCreateTicket(String error) {
    return 'Failed to create ticket: $error';
  }

  @override
  String meetingErrorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String get meetingTaskCreated => 'Task created';

  @override
  String meetingFailedToCreateTask(String error) {
    return 'Failed to create task: $error';
  }

  @override
  String get meetingUrlCopied => 'Meeting URL copied to clipboard';

  @override
  String get meetingEditTitle => 'Edit Meeting';

  @override
  String get meetingDetailsTitle => 'Meeting Details';

  @override
  String get meetingSaveChanges => 'Save Changes';

  @override
  String get meetingDeleteTitle => 'Delete Meeting';

  @override
  String get meetingStatusNotStarted => 'Not started';

  @override
  String get meetingStatusCompleted => 'Completed';

  @override
  String get meetingStatusAttempted => 'Attempted';

  @override
  String get meetingStatusInProgress => 'In progress';

  @override
  String get meetingStatusPending => 'Pending';

  @override
  String get meetingStatusNotAvailable => 'Not available';

  @override
  String get meetingBadgeUpcoming => 'UPCOMING';

  @override
  String get meetingBadgePast => 'PAST';

  @override
  String get meetingDate => 'Date';

  @override
  String get meetingTime => 'Time';

  @override
  String get meetingDuration => 'Duration';

  @override
  String meetingDurationMinutes(String minutes) {
    return '$minutes minutes';
  }

  @override
  String get meetingUrl => 'Meeting URL';

  @override
  String get meetingCopyUrl => 'Copy URL';

  @override
  String get meetingOpenUrl => 'Open URL';

  @override
  String meetingTranscriptionStatus(String status) {
    return 'Transcription: $status';
  }

  @override
  String get meetingJoinMeeting => 'Join Meeting';

  @override
  String get meetingTitleLabel => 'Title';

  @override
  String get meetingSelectDate => 'Select Date';

  @override
  String get meetingSelectTime => 'Select Time';

  @override
  String get meetingAiSummaryNotAvailable => 'AI summary not available yet.';

  @override
  String get meetingActionItemFallback => 'Action Item';

  @override
  String meetingOwnerDeadline(String owner, String deadline) {
    return 'Owner: $owner   •   Deadline: $deadline';
  }

  @override
  String get meetingNotApplicable => 'N/A';

  @override
  String get meetingManageDiscussion => 'Manage Important Discussion';

  @override
  String get meetingNoActionItems => 'No action items detected';

  @override
  String get meetingManageTasks => 'Manage Tasks';

  @override
  String get meetingNoFollowUps => 'No follow-up tasks detected';

  @override
  String get meetingFollowUpTaskFallback => 'Follow-up Task';

  @override
  String meetingDeadline(String deadline) {
    return 'Deadline: $deadline';
  }

  @override
  String get meetingDeleteConfirm =>
      'Are you sure you want to delete this meeting? This action cannot be undone.';

  @override
  String get meetingDelete => 'Delete';

  @override
  String meetingFailedToLoad(String error) {
    return 'Failed to load meeting: $error';
  }

  @override
  String get meetingInsightsTitle => 'Meeting Insights';

  @override
  String get meetingDownloadPdf => 'Download PDF';

  @override
  String meetingSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String meetingPdfError(String error) {
    return 'PDF error: $error';
  }

  @override
  String get meetingNoTranscription => 'No transcription available';

  @override
  String get meetingSpeaker => 'Speaker';

  @override
  String get meetingNoAiSummary => 'No AI summary generated yet';

  @override
  String get meetingKeyDiscussionPoints => 'Key Discussion Points';

  @override
  String get meetingImportantDecisions => 'Important Decisions';

  @override
  String get meetingActionItems => 'Action Items';

  @override
  String get meetingHighlights => 'Meeting Highlights';

  @override
  String get meetingFollowUpTasks => 'Follow-up Tasks';

  @override
  String get meetingOverallSummary => 'Overall Summary';

  @override
  String get chatListening => 'Listening...';

  @override
  String get chatTapToCancel => 'Tap anywhere to cancel';

  @override
  String get chatCouldNotOpenItemDetails =>
      'Could not open this item. Details missing.';

  @override
  String get chatCouldNotOpenItem => 'Could not open this item.';

  @override
  String get chatCouldNotNavigate =>
      'Could not navigate to the item. Details missing.';

  @override
  String get chatSpeechNotAvailable =>
      'Speech recognition not available on this device';

  @override
  String get chatTitle => 'Chat with Ell-ena';

  @override
  String get chatSubtitle => 'Your AI Assistant';

  @override
  String get chatContext => 'Context';

  @override
  String get chatEmptyState => 'Start a conversation with Ell-ena';

  @override
  String get chatInputHint => 'Type your message...';

  @override
  String get chatVoiceInputTooltip => 'Voice input';

  @override
  String get chatStopListeningTooltip => 'Stop listening';

  @override
  String get chatSendTooltip => 'Send message';

  @override
  String get chatItemCreated => 'Item Created';

  @override
  String get chatCreatedJustNow => 'Created just now';

  @override
  String get chatViewTask => 'View Task';

  @override
  String get chatViewTicket => 'View Ticket';

  @override
  String get chatViewMeeting => 'View Meeting';

  @override
  String get chatViewItem => 'View Item';

  @override
  String get chatContextLoadError => 'Could not load context';

  @override
  String get chatContextTryAgain => 'Try sending your message again.';

  @override
  String get chatContextEmptyTitle => 'No context yet';

  @override
  String get chatContextEmptyMessage =>
      'Send a message to find related tasks, tickets, and meetings.';

  @override
  String get chatContextNoMatchesTitle => 'No matches found';

  @override
  String get chatContextNoMatchesMessage =>
      'Nothing in your workspace matched this message closely enough.';

  @override
  String chatResultDue(String date) {
    return 'Due $date';
  }

  @override
  String get calendarUntitledTask => 'Untitled Task';

  @override
  String get calendarUntitledTicket => 'Untitled Ticket';

  @override
  String get calendarUntitledMeeting => 'Untitled Meeting';

  @override
  String calendarCreateAt(String time) {
    return 'Create at $time';
  }

  @override
  String get calendarScheduleMeeting => 'Schedule a Meeting';

  @override
  String get calendarCreateTask => 'Create a Task';

  @override
  String get calendarCreateTicket => 'Create a Ticket';

  @override
  String get calendarCreateWithAi => 'Create with Ell-ena AI';

  @override
  String profileFailedToLoad(String error) {
    return 'Failed to load profile: $error';
  }

  @override
  String get profileUserFallback => 'User';

  @override
  String get profileTeamAdmin => 'Team Admin';

  @override
  String get profileTeamMember => 'Team Member';

  @override
  String get profileYourTeam => 'Your Team';

  @override
  String get profileAdminBadge => 'ADMIN';

  @override
  String get profileMemberBadge => 'MEMBER';

  @override
  String get profileTeamSwitched => 'Team switched successfully';

  @override
  String get profileTeamInformation => 'Team Information';

  @override
  String get profileTeamName => 'Team Name';

  @override
  String get profileTeamId => 'Team ID';

  @override
  String get profileYourActivity => 'Your Activity';

  @override
  String get profileStatTasksCompleted => 'Tasks\nCompleted';

  @override
  String get profileStatHoursLogged => 'Hours\nLogged';

  @override
  String get profileStatTeamProjects => 'Team\nProjects';

  @override
  String get profileEditProfile => 'Edit Profile';

  @override
  String get profileEditProfileSubtitle => 'Update your personal information';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileNotificationsSubtitle =>
      'Manage your notification preferences';

  @override
  String get profileSecurity => 'Security';

  @override
  String get profileSecuritySubtitle => 'Configure security settings';

  @override
  String get profileSwitchTeamSubtitle => 'Change to another team';

  @override
  String get profileTeamMembers => 'Team Members';

  @override
  String get profileTeamMembersSubtitle => 'Manage your team members';

  @override
  String get profileThemeLight => 'Light';

  @override
  String get profileThemeDark => 'Dark';

  @override
  String get profileThemeSystem => 'System';

  @override
  String get profilePreferences => 'Preferences';

  @override
  String get profilePushNotifications => 'Push Notifications';

  @override
  String get profileTheme => 'Theme';

  @override
  String get profileUpdated => 'Profile updated successfully';

  @override
  String get profileUpdateFailed => 'Failed to update profile';

  @override
  String profileUpdateError(String error) {
    return 'Error updating profile: $error';
  }

  @override
  String get profilePersonalInformation => 'Personal Information';

  @override
  String get profileFirstName => 'First Name';

  @override
  String get profileFirstNameRequired => 'Please enter your first name';

  @override
  String get profileLastName => 'Last Name';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileEmailCannotChange => 'Email cannot be changed';

  @override
  String get profileRole => 'Role';

  @override
  String get profileAdminPrivileges => 'You have admin privileges';

  @override
  String get profileStandardAccess => 'Standard team member access';

  @override
  String profileTeamMembersTitle(String teamName) {
    return '$teamName Members';
  }

  @override
  String get profileNoMembersFound => 'No team members found';

  @override
  String get profileNoMembersYet => 'Your team doesn\'t have any members yet';

  @override
  String get profileUnknownMember => 'Unknown';

  @override
  String get profileRoleAdmin => 'Admin';

  @override
  String get profileRoleMember => 'Member';

  @override
  String get workspaceTaskCreated => 'Task created successfully';

  @override
  String get workspaceTicketCreated => 'Ticket created successfully';

  @override
  String get workspaceMeetingCreated => 'Meeting created successfully';

  @override
  String commonErrorLoggingOut(String error) {
    return 'Error logging out: $error';
  }

  @override
  String taskErrorUpdatingStatus(String error) {
    return 'Error updating task status: $error';
  }

  @override
  String taskErrorUpdatingApproval(String error) {
    return 'Error updating task approval: $error';
  }

  @override
  String get taskCreatedSuccess => 'Task created successfully';

  @override
  String get taskNoTasksFound => 'No tasks found';

  @override
  String get taskEmptyTodo => 'Add new tasks to get started';

  @override
  String get taskEmptyInProgress =>
      'Move tasks here when you start working on them';

  @override
  String get taskEmptyCompleted => 'Completed tasks will appear here';

  @override
  String get taskStatusTodo => 'To Do';

  @override
  String get taskStatusInProgress => 'In Progress';

  @override
  String get taskStatusCompleted => 'Completed';

  @override
  String taskViewStatusTasks(String status) {
    return 'View $status Tasks';
  }

  @override
  String get taskDeleteTitle => 'Delete Task';

  @override
  String get taskDeleteConfirmMessage =>
      'Are you sure you want to delete this task? This action cannot be undone.';

  @override
  String get taskDelete => 'Delete';

  @override
  String get taskDeletedSuccess => 'Task deleted successfully';

  @override
  String get taskDeleteFailed => 'Failed to delete task';

  @override
  String taskErrorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String get taskUntitled => 'Untitled Task';

  @override
  String get taskNoDescription => 'No description';

  @override
  String get taskYou => 'You';

  @override
  String get taskUnknown => 'Unknown';

  @override
  String get taskUnassigned => 'Unassigned';

  @override
  String get taskNoDueDate => 'No due date';

  @override
  String get taskApprove => 'Approve';

  @override
  String get taskReject => 'Reject';

  @override
  String taskCreatedBy(String name) {
    return 'Created by $name';
  }

  @override
  String taskAssignedTo(String name) {
    return 'Assigned to $name';
  }

  @override
  String get taskDragToChangeStatus => 'Drag to change status';

  @override
  String get taskTableTask => 'Task';

  @override
  String get taskTableApproval => 'Approval';

  @override
  String get taskTableCreatedBy => 'Created by';

  @override
  String get taskTableAssignedTo => 'Assigned to';

  @override
  String get taskTableDueDate => 'Due date';

  @override
  String get taskLinkedTicketUpdateFailed => 'Failed to update linked ticket';

  @override
  String taskStatusUpdatedTo(String status) {
    return 'Task status updated to $status';
  }

  @override
  String get taskStatusUpdateFailed => 'Failed to update task status';

  @override
  String get taskApprovedMessage => 'Task approved';

  @override
  String get taskRejectedMessage => 'Task rejected';

  @override
  String taskErrorDeleting(String error) {
    return 'Error deleting task: $error';
  }

  @override
  String taskErrorAddingComment(String error) {
    return 'Error adding comment: $error';
  }

  @override
  String get taskDetailsTitle => 'Task Details';

  @override
  String get taskNotFound => 'Task not found';

  @override
  String get taskMayHaveBeenDeleted => 'The task may have been deleted';

  @override
  String taskDueLabel(String date) {
    return 'Due: $date';
  }

  @override
  String get taskLinkedTicket => 'Linked ticket';

  @override
  String get taskNoLinkedTicket => 'No linked ticket';

  @override
  String get taskActions => 'Actions';

  @override
  String get taskStart => 'Start';

  @override
  String get taskComplete => 'Complete';

  @override
  String taskCommentsCount(int count) {
    return 'Comments ($count)';
  }

  @override
  String get taskLatestFirst => 'Latest first';

  @override
  String get taskNoCommentsYet => 'No comments yet';

  @override
  String get taskBeFirstToComment => 'Be the first to comment';

  @override
  String taskDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String taskHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String taskMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String get taskJustNow => 'Just now';

  @override
  String get taskAddCommentHint => 'Add a comment...';

  @override
  String get taskSendComment => 'Send comment';

  @override
  String taskErrorCreating(String error) {
    return 'Error creating task: $error';
  }

  @override
  String get taskCreateNewTitle => 'Create New Task';

  @override
  String get taskTitleLabel => 'Task Title';

  @override
  String get taskTitleHint => 'Enter task title';

  @override
  String get taskTitleRequired => 'Please enter a task title';

  @override
  String get taskDescriptionLabel => 'Description';

  @override
  String get taskDescriptionHint => 'Enter task description';

  @override
  String get taskDueDateLabel => 'Due Date';

  @override
  String get taskSelectDueDate => 'Select due date';

  @override
  String get taskAssignToLabel => 'Assign To';

  @override
  String get taskSelectTeamMember => 'Select team member';

  @override
  String get taskAdminBadge => 'Admin';

  @override
  String get taskCreateButton => 'Create Task';

  @override
  String ticketErrorUpdatingStatus(String error) {
    return 'Error updating ticket status: $error';
  }

  @override
  String ticketErrorUpdatingApproval(String error) {
    return 'Error updating ticket approval: $error';
  }

  @override
  String get ticketCreatedSuccess => 'Ticket created successfully';

  @override
  String get ticketStatusOpen => 'Open';

  @override
  String get ticketStatusInProgress => 'In Progress';

  @override
  String get ticketStatusResolved => 'Resolved';

  @override
  String get ticketNoTicketsFound => 'No tickets found';

  @override
  String get ticketEmptyOpen => 'Create new tickets to get started';

  @override
  String get ticketEmptyInProgress =>
      'Move tickets here when you start working on them';

  @override
  String get ticketEmptyResolved => 'Resolved tickets will appear here';

  @override
  String ticketViewStatusTickets(String status) {
    return 'View $status Tickets';
  }

  @override
  String get ticketDeleteTitle => 'Delete Ticket';

  @override
  String get ticketDeleteConfirm =>
      'Are you sure you want to delete this ticket? This action cannot be undone.';

  @override
  String get ticketDelete => 'Delete';

  @override
  String get ticketDeletedSuccess => 'Ticket deleted successfully';

  @override
  String get ticketDeleteFailed => 'Failed to delete ticket';

  @override
  String ticketErrorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String get ticketUntitled => 'Untitled Ticket';

  @override
  String get ticketNoDescription => 'No description';

  @override
  String get ticketYou => 'You';

  @override
  String get ticketUnknown => 'Unknown';

  @override
  String get ticketApprove => 'Approve';

  @override
  String get ticketReject => 'Reject';

  @override
  String ticketCreatedByName(String name) {
    return 'Created by $name';
  }

  @override
  String get ticketDragToChangeStatus => 'Drag to change status';

  @override
  String get ticketPriority => 'Priority';

  @override
  String get ticketTicket => 'Ticket';

  @override
  String get ticketTitle => 'Title';

  @override
  String get ticketCategory => 'Category';

  @override
  String get ticketApproval => 'Approval';

  @override
  String get ticketCreatedByLabel => 'Created by';

  @override
  String get ticketCreated => 'Created';

  @override
  String get ticketLoadDetailsFailed => 'Failed to load ticket details';

  @override
  String ticketErrorLoadingDetails(String error) {
    return 'Error loading ticket details: $error';
  }

  @override
  String ticketErrorDeleting(String error) {
    return 'Error deleting ticket: $error';
  }

  @override
  String ticketAddCommentFailed(String error) {
    return 'Failed to add comment: $error';
  }

  @override
  String ticketErrorAddingComment(String error) {
    return 'Error adding comment: $error';
  }

  @override
  String get ticketStatusUpdated => 'Ticket status updated successfully';

  @override
  String ticketUpdateStatusFailed(String error) {
    return 'Failed to update ticket status: $error';
  }

  @override
  String get ticketPriorityUpdated => 'Ticket priority updated successfully';

  @override
  String ticketUpdatePriorityFailed(String error) {
    return 'Failed to update ticket priority: $error';
  }

  @override
  String ticketErrorUpdatingPriority(String error) {
    return 'Error updating ticket priority: $error';
  }

  @override
  String get ticketCouldNotOpenGithubIssue => 'Could not open GitHub issue';

  @override
  String get ticketGithubSyncUpdated => 'GitHub sync updated';

  @override
  String get ticketGithubSyncFailed => 'GitHub synchronization failed';

  @override
  String ticketErrorSyncingGithub(String error) {
    return 'Error syncing to GitHub: $error';
  }

  @override
  String ticketViewOnGithubWithId(String id) {
    return 'View on GitHub (#$id)';
  }

  @override
  String get ticketViewOnGithub => 'View on GitHub';

  @override
  String get ticketRetryGithubSync => 'Retry GitHub sync';

  @override
  String get ticketAssignedSuccess => 'Ticket assigned successfully';

  @override
  String ticketAssignFailed(String error) {
    return 'Failed to assign ticket: $error';
  }

  @override
  String ticketErrorAssigning(String error) {
    return 'Error assigning ticket: $error';
  }

  @override
  String get ticketAssignTitle => 'Assign Ticket';

  @override
  String get ticketErrorLoadingTeamMembers => 'Error loading team members';

  @override
  String get ticketNoTeamMembers => 'No team members found';

  @override
  String get ticketRoleAdmin => 'Admin';

  @override
  String get ticketRoleTeamMember => 'Team Member';

  @override
  String get ticketDetailsTitle => 'Ticket Details';

  @override
  String get ticketNotFound => 'Ticket not found';

  @override
  String get ticketNotFoundMessage =>
      'The ticket may have been deleted or you do not have access to it.';

  @override
  String get ticketChangeStatus => 'Change Status';

  @override
  String get ticketChangePriority => 'Change Priority';

  @override
  String get ticketPriorityHigh => 'High';

  @override
  String get ticketPriorityMedium => 'Medium';

  @override
  String get ticketPriorityLow => 'Low';

  @override
  String get ticketCategoryBug => 'Bug';

  @override
  String get ticketCategoryFeatureRequest => 'Feature Request';

  @override
  String get ticketCategoryUiUx => 'UI/UX';

  @override
  String get ticketCategoryPerformance => 'Performance';

  @override
  String get ticketCategoryDocumentation => 'Documentation';

  @override
  String get ticketCategorySecurity => 'Security';

  @override
  String get ticketCategoryOther => 'Other';

  @override
  String get ticketNoDescriptionProvided => 'No description provided.';

  @override
  String get ticketAssignedTo => 'Assigned to';

  @override
  String get ticketAssign => 'Assign';

  @override
  String ticketCommentsCount(int count) {
    return 'Comments ($count)';
  }

  @override
  String get ticketNoComments => 'No comments yet';

  @override
  String get ticketBeFirstComment => 'Be the first to add a comment';

  @override
  String get ticketAddCommentHint => 'Add a comment...';

  @override
  String get ticketSendComment => 'Send comment';

  @override
  String ticketCreateFailed(String error) {
    return 'Failed to create ticket: $error';
  }

  @override
  String ticketErrorCreating(String error) {
    return 'Error creating ticket: $error';
  }

  @override
  String get ticketCreateTitle => 'Create Ticket';

  @override
  String get ticketTitleHint => 'Enter ticket title';

  @override
  String get ticketTitleRequired => 'Please enter a title';

  @override
  String get ticketDescription => 'Description';

  @override
  String get ticketDescriptionHint =>
      'Enter ticket description (max 75 words recommended)';

  @override
  String get ticketDescriptionRequired => 'Please enter a description';

  @override
  String get ticketAssignToOptional => 'Assign To (Optional)';

  @override
  String get ticketSelectTeamMember => 'Select team member';

  @override
  String get ticketUnassigned => 'Unassigned';

  @override
  String get ticketCreateGithubIssue => 'Create GitHub issue';

  @override
  String get ticketCreateGithubIssueSubtitle =>
      'Sync this ticket to the configured GitHub repository';

  @override
  String get shellSupportUs => 'Support Us';

  @override
  String get profileMembersLoadFailed => 'Couldn\'t load team members';

  @override
  String get profileMembersLoadFailedHint =>
      'Check your connection and try again.';

  @override
  String get profileRetry => 'Retry';

  @override
  String get meetingBotCalled => 'Bot called';

  @override
  String get meetingCallBotFailed =>
      'Couldn\'t call the bot. Please try again.';

  @override
  String get meetingCallBot => 'Call Bot';

  @override
  String get meetingCallingBot => 'Calling bot…';

  @override
  String get meetingSummaryReady => 'Summary ready';

  @override
  String get chatReplyError =>
      'Sorry, I encountered an error. Please try again later.';

  @override
  String get chatRequestError =>
      'Sorry, I encountered an error while processing your request.';

  @override
  String get chatRequestDone => 'Done! Your request has been completed.';

  @override
  String get meetingFetchSummaryFailed =>
      'Couldn\'t fetch the summary. The transcript may not be ready yet, so try again later.';

  @override
  String get meetingFetchSummary => 'Fetch Summary';

  @override
  String get meetingFetchingSummary => 'Fetching summary…';

  @override
  String get ticketGithubSyncPending => 'GitHub sync in progress';

  @override
  String get ticketGithubSynced => 'Synced to GitHub';

  @override
  String get ticketGithubNotSynced => 'Not synced to GitHub';

  @override
  String get ticketGithubSyncStatusFailed => 'GitHub sync failed';
}
