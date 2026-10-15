import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi')
  ];

  /// The application title shown in the task switcher and browser tab.
  ///
  /// In en, this message translates to:
  /// **'Ell-ena'**
  String get appTitle;

  /// Primary authentication action on the login screen.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get login;

  /// Registration action on the authentication screens.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Logout action label.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Title for the logout confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutTitle;

  /// Body text for the logout confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'You will need to log in again to access your account.'**
  String get logoutMessage;

  /// Dashboard navigation label.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Calendar navigation label.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// Workspace navigation label.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// Chat navigation label.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// Profile navigation label.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Tasks section label.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// Tickets section label.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get tickets;

  /// Meetings section label.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get meetings;

  /// Settings section label.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Generic cancel action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Generic save action.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Generic loading indicator label.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Generic search placeholder label.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Language preference setting label.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Display name for a language identified by locale code.
  ///
  /// In en, this message translates to:
  /// **'{localeCode, select, en{English} hi{हिन्दी} other{{localeCode}}}'**
  String languageName(String localeCode);

  /// Title for the language selection sheet.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Tooltip for the button that reloads the open page.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Title of the team switcher dialog and tooltip of the team button.
  ///
  /// In en, this message translates to:
  /// **'Switch Team'**
  String get switchTeam;

  /// Team code shown under each team in the team switcher.
  ///
  /// In en, this message translates to:
  /// **'Team Code: {code}'**
  String teamCode(String code);

  /// Shown when a team has no name.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get teamFallbackName;

  /// Shown when the current team's name is unknown.
  ///
  /// In en, this message translates to:
  /// **'My Team'**
  String get myTeam;

  /// Snackbar when switching teams fails.
  ///
  /// In en, this message translates to:
  /// **'Error switching team: {error}'**
  String errorSwitchingTeam(String error);

  /// Greeting above the user's name on the phone dashboard.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get dashboardWelcomeBack;

  /// Title of the phone dashboard summary card.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Overview'**
  String get dashboardTodaysOverview;

  /// Dashboard stat label.
  ///
  /// In en, this message translates to:
  /// **'Total Tasks'**
  String get dashboardTotalTasks;

  /// Dashboard stat label for tasks in progress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get dashboardInProgress;

  /// Dashboard stat label for completed tasks.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get dashboardCompleted;

  /// Dashboard stat label.
  ///
  /// In en, this message translates to:
  /// **'Open Tickets'**
  String get dashboardOpenTickets;

  /// Dashboard stat label.
  ///
  /// In en, this message translates to:
  /// **'Tickets In Progress'**
  String get dashboardTicketsInProgress;

  /// Dashboard stat label for resolved tickets.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get dashboardResolved;

  /// Title of the dashboard completion chart.
  ///
  /// In en, this message translates to:
  /// **'Task Completion by Day'**
  String get dashboardTaskCompletionByDay;

  /// Chart range option.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get dashboardWeek;

  /// Chart range option.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get dashboardMonth;

  /// Empty state of the completion chart.
  ///
  /// In en, this message translates to:
  /// **'No completions yet'**
  String get dashboardNoCompletions;

  /// Title of the upcoming items section.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get dashboardUpcoming;

  /// Empty state of the upcoming section.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today or scheduled soon'**
  String get dashboardNothingUpcoming;

  /// Title of the recent activity section.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get dashboardRecentActivity;

  /// Empty state of the recent activity section.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get dashboardNoRecentActivity;

  /// Type label for a task in dashboard lists.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get dashboardTask;

  /// Type label for a ticket in dashboard lists.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get dashboardTicket;

  /// Fallback title for a meeting without a title.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get dashboardMeeting;

  /// Status line in the recent activity list.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String dashboardStatus(String status);

  /// Wide-screen top bar button that opens the create-task screen.
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get newTask;

  /// Wide-screen top bar button that opens the create-ticket screen.
  ///
  /// In en, this message translates to:
  /// **'New Ticket'**
  String get newTicket;

  /// Wide-screen top bar button that opens the create-meeting screen.
  ///
  /// In en, this message translates to:
  /// **'New Meeting'**
  String get newMeeting;

  /// Title of the login screen.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get authWelcomeBack;

  /// Subtitle of the login screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue with Ell-ena'**
  String get authSignInSubtitle;

  /// Label of email input fields on auth screens.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// Label of password input fields on auth screens.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Validation error when the email field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get authEnterEmail;

  /// Validation error when the email is not valid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get authEnterValidEmail;

  /// Validation error when the password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get authEnterPassword;

  /// Validation error when the password is shorter than 6 characters.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPasswordTooShort;

  /// Link on the login screen to reset the password.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get authForgotPassword;

  /// Divider text between email sign-in and Google sign-in.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get authOr;

  /// Button label for Google sign-in on the login screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get authSignInWithGoogle;

  /// Prompt before the Sign Up link on the login screen. Keep the trailing space.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authNoAccount;

  /// Snackbar when login does not return a user.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get authLoginFailed;

  /// Snackbar when login credentials are wrong.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get authInvalidCredentials;

  /// Snackbar when login fails due to a connection problem.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Please try again.'**
  String get authConnectionError;

  /// Fallback snackbar when Google sign-in fails without an error message.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed'**
  String get authGoogleSignInFailed;

  /// Generic error snackbar showing technical error details.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String authErrorWithDetails(String error);

  /// Snackbar after the signup verification email is sent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent. Please check your inbox.'**
  String get authVerificationEmailSent;

  /// Snackbar when the entered team ID does not exist.
  ///
  /// In en, this message translates to:
  /// **'Team ID not found. Please check and try again.'**
  String get authTeamIdNotFound;

  /// Label of the team ID field on the signup screen.
  ///
  /// In en, this message translates to:
  /// **'Team ID'**
  String get authTeamIdLabel;

  /// Validation error when the team ID field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter team ID'**
  String get authEnterTeamId;

  /// Validation error when the team ID is not 6 characters.
  ///
  /// In en, this message translates to:
  /// **'Team ID must be 6 characters'**
  String get authTeamIdLength;

  /// Label of the full name field on the signup screen.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get authFullNameLabel;

  /// Validation error when the name field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get authEnterName;

  /// Label of the confirm password field.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPasswordLabel;

  /// Validation error when the confirm password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get authConfirmPasswordPrompt;

  /// Validation error when the two passwords differ.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDoNotMatch;

  /// Label of the team name field.
  ///
  /// In en, this message translates to:
  /// **'Team Name'**
  String get authTeamNameLabel;

  /// Validation error when the team name field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter team name'**
  String get authEnterTeamName;

  /// Label of the admin name field when creating a team.
  ///
  /// In en, this message translates to:
  /// **'Admin Name'**
  String get authAdminNameLabel;

  /// Validation error when the admin name field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter admin name'**
  String get authEnterAdminName;

  /// Label of the admin email field when creating a team.
  ///
  /// In en, this message translates to:
  /// **'Admin Email'**
  String get authAdminEmailLabel;

  /// Validation error when the admin email field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter admin email'**
  String get authEnterAdminEmail;

  /// Title of the signup screen.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// Subtitle of the signup screen.
  ///
  /// In en, this message translates to:
  /// **'Join Ell-ena to get started'**
  String get authSignUpSubtitle;

  /// Signup tab for joining an existing team.
  ///
  /// In en, this message translates to:
  /// **'Join the Team'**
  String get authJoinTheTeamTab;

  /// Signup tab for creating a new team.
  ///
  /// In en, this message translates to:
  /// **'Create the Team'**
  String get authCreateTheTeamTab;

  /// Button/option to join an existing team.
  ///
  /// In en, this message translates to:
  /// **'Join Team'**
  String get authJoinTeam;

  /// Button/option to create a new team.
  ///
  /// In en, this message translates to:
  /// **'Create Team'**
  String get authCreateTeam;

  /// Button label for Google sign-up on the signup screen.
  ///
  /// In en, this message translates to:
  /// **'Sign up with Google'**
  String get authSignUpWithGoogle;

  /// Button on the signup screen that goes to the login screen.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get authAlreadyHaveAccount;

  /// Snackbar after the password reset code is sent.
  ///
  /// In en, this message translates to:
  /// **'Reset code sent to your email'**
  String get authResetCodeSent;

  /// Generic error message on auth screens.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get authGenericError;

  /// Error when the email address is invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get authInvalidEmailAddress;

  /// Error when the email address is not registered.
  ///
  /// In en, this message translates to:
  /// **'Email address not found'**
  String get authEmailNotFound;

  /// Error when the server rate-limits requests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get authTooManyAttempts;

  /// Title of the forgot password screen.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authResetPasswordTitle;

  /// Subtitle of the forgot password screen.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a reset code'**
  String get authResetPasswordSubtitle;

  /// Button that sends the password reset code.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Code'**
  String get authSendResetCode;

  /// Button that returns to the login screen.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get authBackToLogin;

  /// Snackbar after the password is changed.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully'**
  String get authPasswordUpdated;

  /// Error when the password update fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to update password'**
  String get authPasswordUpdateFailed;

  /// Title of the set new password screen.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get authSetNewPasswordTitle;

  /// Subtitle of the set new password screen.
  ///
  /// In en, this message translates to:
  /// **'Create a new password for your account'**
  String get authSetNewPasswordSubtitle;

  /// Label of the new password field.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get authNewPasswordLabel;

  /// Validation error when the new password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get authEnterNewPassword;

  /// Button that saves the new password.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get authUpdatePassword;

  /// Fallback error when OTP verification fails.
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get authVerificationFailed;

  /// Error when the OTP is expired or invalid.
  ///
  /// In en, this message translates to:
  /// **'Verification code has expired or invalid. Please request a new code.'**
  String get authCodeExpiredOrInvalid;

  /// Error when the OTP is invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid verification code. Please try again.'**
  String get authInvalidCode;

  /// Error when the OTP has expired.
  ///
  /// In en, this message translates to:
  /// **'Verification code has expired. Please request a new code.'**
  String get authCodeExpired;

  /// Snackbar after the OTP is resent.
  ///
  /// In en, this message translates to:
  /// **'Verification code resent successfully. Please check your inbox and spam folder.'**
  String get authCodeResent;

  /// Fallback error when resending the OTP fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend code'**
  String get authResendFailed;

  /// Error when resending the OTP to an unknown or invalid email.
  ///
  /// In en, this message translates to:
  /// **'Email address not found or invalid.'**
  String get authEmailNotFoundOrInvalid;

  /// Error when the OTP cannot be resent.
  ///
  /// In en, this message translates to:
  /// **'Unable to resend code. Please go back and try again.'**
  String get authUnableToResend;

  /// Title of the dialog shown after a team is created.
  ///
  /// In en, this message translates to:
  /// **'Team Created Successfully!'**
  String get authTeamCreatedTitle;

  /// Text above the new team ID in the team created dialog.
  ///
  /// In en, this message translates to:
  /// **'Your Team ID is:'**
  String get authYourTeamIdIs;

  /// Tooltip of the button that copies the team ID.
  ///
  /// In en, this message translates to:
  /// **'Copy Team ID'**
  String get authCopyTeamId;

  /// Snackbar after the team ID is copied.
  ///
  /// In en, this message translates to:
  /// **'Team ID copied to clipboard'**
  String get authTeamIdCopied;

  /// Hint in the team created dialog.
  ///
  /// In en, this message translates to:
  /// **'Share this ID with your team members so they can join your team.'**
  String get authShareTeamId;

  /// Button that closes the team created dialog and continues to the app.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get authContinue;

  /// Title of the OTP verification screen.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get authVerifyEmailTitle;

  /// Subtitle of the OTP verification screen.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {email}'**
  String authVerifyEmailSubtitle(String email);

  /// Countdown before the OTP can be resent; countdown is formatted like 00:59.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {countdown}'**
  String authResendCodeIn(String countdown);

  /// Hint on the OTP screen. Keep the line break.
  ///
  /// In en, this message translates to:
  /// **'Check your spam/junk folder if you don\'t\n see the email.'**
  String get authCheckSpamFolder;

  /// Button that verifies the OTP.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get authVerifyCode;

  /// Prompt before the Resend link. Keep the trailing space.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? '**
  String get authDidNotReceiveCode;

  /// Link that resends the OTP.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get authResend;

  /// Fallback error when joining a team with Google fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to join team'**
  String get authFailedToJoinTeam;

  /// Fallback error when creating a team with Google fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to create team'**
  String get authFailedToCreateTeam;

  /// Title of the team selection dialog after Google sign-in.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Setup'**
  String get authCompleteSetup;

  /// Instruction in the team selection dialog.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to proceed:'**
  String get authChooseHowToProceed;

  /// Label of the name field in the team selection dialog.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get authYourNameLabel;

  /// Label of the team code field in the team selection dialog.
  ///
  /// In en, this message translates to:
  /// **'Team Code'**
  String get authTeamCodeLabel;

  /// Validation error when the team code field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter team code'**
  String get authEnterTeamCode;

  /// Title of the first onboarding slide.
  ///
  /// In en, this message translates to:
  /// **'All-in-One Task Management'**
  String get onboardingTaskManagementTitle;

  /// Description of the first onboarding slide.
  ///
  /// In en, this message translates to:
  /// **'Create tickets, to-dos, and transcribe meetings—all in one place.'**
  String get onboardingTaskManagementDescription;

  /// Title of the second onboarding slide.
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Assistant'**
  String get onboardingAssistantTitle;

  /// Description of the second onboarding slide.
  ///
  /// In en, this message translates to:
  /// **'Just chat with Ell-ena and let AI do the heavy lifting.'**
  String get onboardingAssistantDescription;

  /// Title of the third onboarding slide.
  ///
  /// In en, this message translates to:
  /// **'Smart Context'**
  String get onboardingContextTitle;

  /// Description of the third onboarding slide.
  ///
  /// In en, this message translates to:
  /// **'Smarter you with AI-powered context awareness.'**
  String get onboardingContextDescription;

  /// Button on the last onboarding slide.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// Button that goes to the next onboarding slide.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Button that skips onboarding.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Snackbar shown when deleting a meeting fails.
  ///
  /// In en, this message translates to:
  /// **'Error deleting meeting: {error}'**
  String meetingErrorDeleting(String error);

  /// Snackbar shown when the meeting link cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Could not launch meeting URL'**
  String get meetingCouldNotLaunchUrl;

  /// Snackbar shown when opening the meeting link throws an error.
  ///
  /// In en, this message translates to:
  /// **'Error launching URL: {error}'**
  String meetingErrorLaunchingUrl(String error);

  /// Label for upcoming meetings stat and filter tab.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get meetingUpcoming;

  /// Label for past meetings stat and filter tab.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get meetingPast;

  /// Empty state title when there are no upcoming meetings.
  ///
  /// In en, this message translates to:
  /// **'No upcoming meetings'**
  String get meetingNoUpcoming;

  /// Empty state title when there are no past meetings.
  ///
  /// In en, this message translates to:
  /// **'No past meetings'**
  String get meetingNoPast;

  /// Empty state hint for the upcoming meetings list.
  ///
  /// In en, this message translates to:
  /// **'Create new meetings to get started'**
  String get meetingEmptyUpcomingHint;

  /// Empty state hint for the past meetings list.
  ///
  /// In en, this message translates to:
  /// **'Past meetings will appear here'**
  String get meetingEmptyPastHint;

  /// Relative date label for a meeting today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get meetingToday;

  /// Relative date label for a meeting tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get meetingTomorrow;

  /// Relative date label for a meeting yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get meetingYesterday;

  /// Relative date label for a past meeting a number of days ago.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String meetingDaysAgo(int count);

  /// Fallback title for a meeting without a title.
  ///
  /// In en, this message translates to:
  /// **'Untitled Meeting'**
  String get meetingUntitled;

  /// Fallback name when the meeting creator is unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get meetingUnknownUser;

  /// Tooltip for the delete icon on a meeting card.
  ///
  /// In en, this message translates to:
  /// **'Cancel Meeting'**
  String get meetingCancelMeetingTooltip;

  /// Short meeting duration shown on a meeting card.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String meetingDurationMin(String minutes);

  /// Shows who created the meeting.
  ///
  /// In en, this message translates to:
  /// **'Created by {name}'**
  String meetingCreatedBy(String name);

  /// Button to join a meeting from the meeting card.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get meetingJoin;

  /// Button / tab label for the meeting transcription.
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get meetingTranscription;

  /// Button / tab label for the AI-generated meeting summary.
  ///
  /// In en, this message translates to:
  /// **'AI Summary'**
  String get meetingAiSummary;

  /// Snackbar when creating a Meet link before choosing date and time.
  ///
  /// In en, this message translates to:
  /// **'Please select date and time first'**
  String get meetingSelectDateTimeFirst;

  /// Snackbar when the chosen meeting time is in the past.
  ///
  /// In en, this message translates to:
  /// **'Meeting time must be in the future'**
  String get meetingTimeMustBeFuture;

  /// Snackbar after a Google Meet link is created.
  ///
  /// In en, this message translates to:
  /// **'Google Meet link created successfully'**
  String get meetingMeetLinkCreated;

  /// Snackbar when creating a Google Meet link fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to create Google Meet link. Please sign in with Google.'**
  String get meetingMeetLinkFailed;

  /// Snackbar action to retry creating a Google Meet link.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get meetingRetry;

  /// Snackbar when no meeting date is selected.
  ///
  /// In en, this message translates to:
  /// **'Please select a date'**
  String get meetingSelectDatePrompt;

  /// Snackbar when no meeting time is selected.
  ///
  /// In en, this message translates to:
  /// **'Please select a time'**
  String get meetingSelectTimePrompt;

  /// Snackbar when a non-Google Meet URL is entered.
  ///
  /// In en, this message translates to:
  /// **'Only Google Meet URLs are supported for transcription'**
  String get meetingOnlyGoogleMeetSupported;

  /// Snackbar when the backend rejects meeting creation.
  ///
  /// In en, this message translates to:
  /// **'Failed to create meeting: {error}'**
  String meetingFailedToCreate(String error);

  /// Snackbar when creating a meeting throws an error.
  ///
  /// In en, this message translates to:
  /// **'Error creating meeting: {error}'**
  String meetingErrorCreating(String error);

  /// App bar title and submit button on the create-meeting screen.
  ///
  /// In en, this message translates to:
  /// **'Create Meeting'**
  String get meetingCreateTitle;

  /// Label for the required meeting title field.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get meetingTitleRequiredLabel;

  /// Validation message for an empty meeting title.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get meetingEnterTitle;

  /// Label for the meeting description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get meetingDescription;

  /// Placeholder for the required meeting date picker.
  ///
  /// In en, this message translates to:
  /// **'Select Date *'**
  String get meetingSelectDateRequired;

  /// Placeholder for the required meeting time picker.
  ///
  /// In en, this message translates to:
  /// **'Select Time *'**
  String get meetingSelectTimeRequired;

  /// Label for the meeting duration field.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get meetingDurationMinutesLabel;

  /// Validation message for a non-positive duration.
  ///
  /// In en, this message translates to:
  /// **'Duration must be greater than 0'**
  String get meetingDurationPositive;

  /// Validation message for a non-numeric duration.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get meetingEnterValidNumber;

  /// Label for the Google Meet URL field.
  ///
  /// In en, this message translates to:
  /// **'Google Meet URL'**
  String get meetingGoogleMeetUrl;

  /// Button label while a Google Meet link is being created.
  ///
  /// In en, this message translates to:
  /// **'Creating Meet Link...'**
  String get meetingCreatingMeetLink;

  /// Button to create a Google Meet link.
  ///
  /// In en, this message translates to:
  /// **'Create Google Meet Link'**
  String get meetingCreateMeetLink;

  /// Warning shown for non-Google Meet URLs.
  ///
  /// In en, this message translates to:
  /// **'Ellena AI transcription only works with Google Meet URLs'**
  String get meetingTranscriptionGoogleMeetOnly;

  /// Shown when the meeting cannot be found.
  ///
  /// In en, this message translates to:
  /// **'Meeting not found'**
  String get meetingNotFound;

  /// Snackbar when loading meeting details fails.
  ///
  /// In en, this message translates to:
  /// **'Error loading meeting details: {error}'**
  String meetingErrorLoadingDetails(String error);

  /// Snackbar when saving a meeting with an empty title.
  ///
  /// In en, this message translates to:
  /// **'Title cannot be empty'**
  String get meetingTitleEmpty;

  /// Snackbar when saving a meeting without date or time.
  ///
  /// In en, this message translates to:
  /// **'Please select date and time'**
  String get meetingSelectDateTime;

  /// Snackbar when updating a meeting fails.
  ///
  /// In en, this message translates to:
  /// **'Error updating meeting: {error}'**
  String meetingErrorUpdating(String error);

  /// Snackbar after creating a ticket from a meeting action item.
  ///
  /// In en, this message translates to:
  /// **'Ticket created'**
  String get meetingTicketCreated;

  /// Snackbar when creating a ticket from an action item fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to create ticket: {error}'**
  String meetingFailedToCreateTicket(String error);

  /// Generic error snackbar on the meeting detail screen.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String meetingErrorGeneric(String error);

  /// Snackbar after creating a task from a meeting follow-up.
  ///
  /// In en, this message translates to:
  /// **'Task created'**
  String get meetingTaskCreated;

  /// Snackbar when creating a task from a follow-up fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to create task: {error}'**
  String meetingFailedToCreateTask(String error);

  /// Snackbar after copying the meeting URL.
  ///
  /// In en, this message translates to:
  /// **'Meeting URL copied to clipboard'**
  String get meetingUrlCopied;

  /// App bar title in edit mode and tooltip of the edit button.
  ///
  /// In en, this message translates to:
  /// **'Edit Meeting'**
  String get meetingEditTitle;

  /// App bar title of the meeting detail screen.
  ///
  /// In en, this message translates to:
  /// **'Meeting Details'**
  String get meetingDetailsTitle;

  /// Button and tooltip to save meeting edits.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get meetingSaveChanges;

  /// Tooltip of the delete button and title of the delete confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete Meeting'**
  String get meetingDeleteTitle;

  /// Transcription status: not started.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get meetingStatusNotStarted;

  /// Transcription status: completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get meetingStatusCompleted;

  /// Transcription status: attempted.
  ///
  /// In en, this message translates to:
  /// **'Attempted'**
  String get meetingStatusAttempted;

  /// Transcription status: in progress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get meetingStatusInProgress;

  /// Transcription status: pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get meetingStatusPending;

  /// Transcription status: not available.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get meetingStatusNotAvailable;

  /// Uppercase badge for an upcoming meeting.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get meetingBadgeUpcoming;

  /// Uppercase badge for a past meeting.
  ///
  /// In en, this message translates to:
  /// **'PAST'**
  String get meetingBadgePast;

  /// Label for the meeting date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get meetingDate;

  /// Label for the meeting time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get meetingTime;

  /// Label for the meeting duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get meetingDuration;

  /// Meeting duration value on the detail screen.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String meetingDurationMinutes(String minutes);

  /// Label for the meeting URL.
  ///
  /// In en, this message translates to:
  /// **'Meeting URL'**
  String get meetingUrl;

  /// Tooltip for the copy-URL button.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get meetingCopyUrl;

  /// Tooltip for the open-URL button.
  ///
  /// In en, this message translates to:
  /// **'Open URL'**
  String get meetingOpenUrl;

  /// Shows the transcription status of a meeting.
  ///
  /// In en, this message translates to:
  /// **'Transcription: {status}'**
  String meetingTranscriptionStatus(String status);

  /// Button to join the meeting on the detail screen.
  ///
  /// In en, this message translates to:
  /// **'Join Meeting'**
  String get meetingJoinMeeting;

  /// Label for the meeting title field in edit mode.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get meetingTitleLabel;

  /// Placeholder for the meeting date picker in edit mode.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get meetingSelectDate;

  /// Placeholder for the meeting time picker in edit mode.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get meetingSelectTime;

  /// Shown when a past meeting has no AI summary.
  ///
  /// In en, this message translates to:
  /// **'AI summary not available yet.'**
  String get meetingAiSummaryNotAvailable;

  /// Fallback title for an action item without text.
  ///
  /// In en, this message translates to:
  /// **'Action Item'**
  String get meetingActionItemFallback;

  /// Owner and deadline of a meeting action item (values come from AI output).
  ///
  /// In en, this message translates to:
  /// **'Owner: {owner}   •   Deadline: {deadline}'**
  String meetingOwnerDeadline(String owner, String deadline);

  /// Fallback when an action item has no deadline.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get meetingNotApplicable;

  /// Section title for meeting action items.
  ///
  /// In en, this message translates to:
  /// **'Manage Important Discussion'**
  String get meetingManageDiscussion;

  /// Shown when the summary has no action items.
  ///
  /// In en, this message translates to:
  /// **'No action items detected'**
  String get meetingNoActionItems;

  /// Section title for meeting follow-up tasks.
  ///
  /// In en, this message translates to:
  /// **'Manage Tasks'**
  String get meetingManageTasks;

  /// Shown when the summary has no follow-up tasks.
  ///
  /// In en, this message translates to:
  /// **'No follow-up tasks detected'**
  String get meetingNoFollowUps;

  /// Fallback title for a follow-up task without text.
  ///
  /// In en, this message translates to:
  /// **'Follow-up Task'**
  String get meetingFollowUpTaskFallback;

  /// Deadline of a follow-up task (value comes from AI output).
  ///
  /// In en, this message translates to:
  /// **'Deadline: {deadline}'**
  String meetingDeadline(String deadline);

  /// Body of the delete-meeting confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this meeting? This action cannot be undone.'**
  String get meetingDeleteConfirm;

  /// Confirm button in the delete-meeting dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get meetingDelete;

  /// Snackbar when loading meeting insights fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load meeting: {error}'**
  String meetingFailedToLoad(String error);

  /// App bar title of the meeting insights screen.
  ///
  /// In en, this message translates to:
  /// **'Meeting Insights'**
  String get meetingInsightsTitle;

  /// Tooltip for the download-PDF button.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get meetingDownloadPdf;

  /// Snackbar after saving a PDF, with the file path.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String meetingSavedTo(String path);

  /// Snackbar when PDF generation fails.
  ///
  /// In en, this message translates to:
  /// **'PDF error: {error}'**
  String meetingPdfError(String error);

  /// Empty state of the transcription tab.
  ///
  /// In en, this message translates to:
  /// **'No transcription available'**
  String get meetingNoTranscription;

  /// Fallback name for an unknown transcript speaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get meetingSpeaker;

  /// Empty state of the AI summary tab.
  ///
  /// In en, this message translates to:
  /// **'No AI summary generated yet'**
  String get meetingNoAiSummary;

  /// AI summary section title.
  ///
  /// In en, this message translates to:
  /// **'Key Discussion Points'**
  String get meetingKeyDiscussionPoints;

  /// AI summary section title.
  ///
  /// In en, this message translates to:
  /// **'Important Decisions'**
  String get meetingImportantDecisions;

  /// AI summary section title.
  ///
  /// In en, this message translates to:
  /// **'Action Items'**
  String get meetingActionItems;

  /// AI summary section title.
  ///
  /// In en, this message translates to:
  /// **'Meeting Highlights'**
  String get meetingHighlights;

  /// AI summary section title.
  ///
  /// In en, this message translates to:
  /// **'Follow-up Tasks'**
  String get meetingFollowUpTasks;

  /// AI summary section title.
  ///
  /// In en, this message translates to:
  /// **'Overall Summary'**
  String get meetingOverallSummary;

  /// Title in the voice input listening dialog.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get chatListening;

  /// Hint in the voice input listening dialog.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to cancel'**
  String get chatTapToCancel;

  /// SnackBar when a context result has no entity id.
  ///
  /// In en, this message translates to:
  /// **'Could not open this item. Details missing.'**
  String get chatCouldNotOpenItemDetails;

  /// SnackBar when a context result has an unknown type.
  ///
  /// In en, this message translates to:
  /// **'Could not open this item.'**
  String get chatCouldNotOpenItem;

  /// SnackBar when a created item card cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Could not navigate to the item. Details missing.'**
  String get chatCouldNotNavigate;

  /// SnackBar when navigating to an item throws.
  ///
  /// In en, this message translates to:
  /// **'Navigation error: {error}'**
  String chatNavigationError(String error);

  /// SnackBar when speech-to-text is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition not available on this device'**
  String get chatSpeechNotAvailable;

  /// Chat screen header title.
  ///
  /// In en, this message translates to:
  /// **'Chat with Ell-ena'**
  String get chatTitle;

  /// Chat screen header subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI Assistant'**
  String get chatSubtitle;

  /// Title of the context insights panel and tooltip of the button that opens it.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get chatContext;

  /// Empty state of the chat message list.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation with Ell-ena'**
  String get chatEmptyState;

  /// Hint text of the chat input field.
  ///
  /// In en, this message translates to:
  /// **'Type your message...'**
  String get chatInputHint;

  /// Tooltip of the microphone button.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get chatVoiceInputTooltip;

  /// Tooltip of the microphone button while listening.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get chatStopListeningTooltip;

  /// Tooltip of the send button.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatSendTooltip;

  /// Title of a created-item card with unknown type.
  ///
  /// In en, this message translates to:
  /// **'Item Created'**
  String get chatItemCreated;

  /// Label on a created task/ticket card.
  ///
  /// In en, this message translates to:
  /// **'Created just now'**
  String get chatCreatedJustNow;

  /// Button on a created task card.
  ///
  /// In en, this message translates to:
  /// **'View Task'**
  String get chatViewTask;

  /// Button on a created ticket card.
  ///
  /// In en, this message translates to:
  /// **'View Ticket'**
  String get chatViewTicket;

  /// Button on a created meeting card.
  ///
  /// In en, this message translates to:
  /// **'View Meeting'**
  String get chatViewMeeting;

  /// Button on a created item card with no type.
  ///
  /// In en, this message translates to:
  /// **'View Item'**
  String get chatViewItem;

  /// Context insights panel error title.
  ///
  /// In en, this message translates to:
  /// **'Could not load context'**
  String get chatContextLoadError;

  /// Context insights panel fallback error message.
  ///
  /// In en, this message translates to:
  /// **'Try sending your message again.'**
  String get chatContextTryAgain;

  /// Context insights panel idle title.
  ///
  /// In en, this message translates to:
  /// **'No context yet'**
  String get chatContextEmptyTitle;

  /// Context insights panel idle message.
  ///
  /// In en, this message translates to:
  /// **'Send a message to find related tasks, tickets, and meetings.'**
  String get chatContextEmptyMessage;

  /// Context insights panel empty-results title.
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get chatContextNoMatchesTitle;

  /// Context insights panel empty-results message.
  ///
  /// In en, this message translates to:
  /// **'Nothing in your workspace matched this message closely enough.'**
  String get chatContextNoMatchesMessage;

  /// Due date label on a context result tile.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String chatResultDue(String date);

  /// Calendar event title fallback for a task without a title.
  ///
  /// In en, this message translates to:
  /// **'Untitled Task'**
  String get calendarUntitledTask;

  /// Calendar event title fallback for a ticket without a title.
  ///
  /// In en, this message translates to:
  /// **'Untitled Ticket'**
  String get calendarUntitledTicket;

  /// Calendar event title fallback for a meeting without a title.
  ///
  /// In en, this message translates to:
  /// **'Untitled Meeting'**
  String get calendarUntitledMeeting;

  /// Title of the calendar create dialog for a selected time slot.
  ///
  /// In en, this message translates to:
  /// **'Create at {time}'**
  String calendarCreateAt(String time);

  /// Calendar create dialog option.
  ///
  /// In en, this message translates to:
  /// **'Schedule a Meeting'**
  String get calendarScheduleMeeting;

  /// Calendar create dialog option.
  ///
  /// In en, this message translates to:
  /// **'Create a Task'**
  String get calendarCreateTask;

  /// Calendar create dialog option.
  ///
  /// In en, this message translates to:
  /// **'Create a Ticket'**
  String get calendarCreateTicket;

  /// Calendar create dialog option that opens chat.
  ///
  /// In en, this message translates to:
  /// **'Create with Ell-ena AI'**
  String get calendarCreateWithAi;

  /// SnackBar when loading the profile fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile: {error}'**
  String profileFailedToLoad(String error);

  /// Fallback display name when the profile has no full name.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileUserFallback;

  /// Role label under the user name for admins.
  ///
  /// In en, this message translates to:
  /// **'Team Admin'**
  String get profileTeamAdmin;

  /// Role label under the user name for members.
  ///
  /// In en, this message translates to:
  /// **'Team Member'**
  String get profileTeamMember;

  /// Fallback team name on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Your Team'**
  String get profileYourTeam;

  /// Role badge on the profile avatar for admins.
  ///
  /// In en, this message translates to:
  /// **'ADMIN'**
  String get profileAdminBadge;

  /// Role badge on the profile avatar for members.
  ///
  /// In en, this message translates to:
  /// **'MEMBER'**
  String get profileMemberBadge;

  /// SnackBar after switching teams.
  ///
  /// In en, this message translates to:
  /// **'Team switched successfully'**
  String get profileTeamSwitched;

  /// Profile team info section title.
  ///
  /// In en, this message translates to:
  /// **'Team Information'**
  String get profileTeamInformation;

  /// Label for the team name on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Team Name'**
  String get profileTeamName;

  /// Label for the team code on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Team ID'**
  String get profileTeamId;

  /// Profile stats section title.
  ///
  /// In en, this message translates to:
  /// **'Your Activity'**
  String get profileYourActivity;

  /// Profile stat label (two lines).
  ///
  /// In en, this message translates to:
  /// **'Tasks\nCompleted'**
  String get profileStatTasksCompleted;

  /// Profile stat label (two lines).
  ///
  /// In en, this message translates to:
  /// **'Hours\nLogged'**
  String get profileStatHoursLogged;

  /// Profile stat label (two lines).
  ///
  /// In en, this message translates to:
  /// **'Team\nProjects'**
  String get profileStatTeamProjects;

  /// Settings item and edit profile screen title.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditProfile;

  /// Settings item subtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your personal information'**
  String get profileEditProfileSubtitle;

  /// Settings item title.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotifications;

  /// Settings item subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your notification preferences'**
  String get profileNotificationsSubtitle;

  /// Settings item title.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get profileSecurity;

  /// Settings item subtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure security settings'**
  String get profileSecuritySubtitle;

  /// Switch team settings item subtitle.
  ///
  /// In en, this message translates to:
  /// **'Change to another team'**
  String get profileSwitchTeamSubtitle;

  /// Settings item title and team members screen title.
  ///
  /// In en, this message translates to:
  /// **'Team Members'**
  String get profileTeamMembers;

  /// Settings item subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your team members'**
  String get profileTeamMembersSubtitle;

  /// Theme mode option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get profileThemeLight;

  /// Theme mode option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get profileThemeDark;

  /// Theme mode option.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get profileThemeSystem;

  /// Profile preferences section title.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profilePreferences;

  /// Preferences item title.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get profilePushNotifications;

  /// Preferences item title for theme mode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get profileTheme;

  /// SnackBar after saving the profile.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdated;

  /// SnackBar when saving the profile fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get profileUpdateFailed;

  /// SnackBar when saving the profile throws.
  ///
  /// In en, this message translates to:
  /// **'Error updating profile: {error}'**
  String profileUpdateError(String error);

  /// Edit profile section title.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get profilePersonalInformation;

  /// Edit profile first name field label.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get profileFirstName;

  /// Validator message for the first name field.
  ///
  /// In en, this message translates to:
  /// **'Please enter your first name'**
  String get profileFirstNameRequired;

  /// Edit profile last name field label.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get profileLastName;

  /// Edit profile email field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// Helper text under the read-only email field.
  ///
  /// In en, this message translates to:
  /// **'Email cannot be changed'**
  String get profileEmailCannotChange;

  /// Edit profile role section title.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get profileRole;

  /// Role description for admins.
  ///
  /// In en, this message translates to:
  /// **'You have admin privileges'**
  String get profileAdminPrivileges;

  /// Role description for members.
  ///
  /// In en, this message translates to:
  /// **'Standard team member access'**
  String get profileStandardAccess;

  /// SnackBar when loading team members fails.
  ///
  /// In en, this message translates to:
  /// **'Error loading team members: {error}'**
  String profileErrorLoadingMembers(String error);

  /// Team members screen app bar title.
  ///
  /// In en, this message translates to:
  /// **'{teamName} Members'**
  String profileTeamMembersTitle(String teamName);

  /// Team members empty state title.
  ///
  /// In en, this message translates to:
  /// **'No team members found'**
  String get profileNoMembersFound;

  /// Team members empty state message.
  ///
  /// In en, this message translates to:
  /// **'Your team doesn\'t have any members yet'**
  String get profileNoMembersYet;

  /// Fallback name for a team member without a name.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get profileUnknownMember;

  /// Role chip for admin team members.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get profileRoleAdmin;

  /// Role chip for regular team members.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get profileRoleMember;

  /// SnackBar after creating a task from the workspace.
  ///
  /// In en, this message translates to:
  /// **'Task created successfully'**
  String get workspaceTaskCreated;

  /// SnackBar after creating a ticket from the workspace.
  ///
  /// In en, this message translates to:
  /// **'Ticket created successfully'**
  String get workspaceTicketCreated;

  /// SnackBar after creating a meeting from the workspace.
  ///
  /// In en, this message translates to:
  /// **'Meeting created successfully'**
  String get workspaceMeetingCreated;

  /// SnackBar when signing out fails.
  ///
  /// In en, this message translates to:
  /// **'Error logging out: {error}'**
  String commonErrorLoggingOut(String error);

  /// Snackbar when updating a task's status fails.
  ///
  /// In en, this message translates to:
  /// **'Error updating task status: {error}'**
  String taskErrorUpdatingStatus(String error);

  /// Snackbar when updating a task's approval fails.
  ///
  /// In en, this message translates to:
  /// **'Error updating task approval: {error}'**
  String taskErrorUpdatingApproval(String error);

  /// Snackbar after a task is created.
  ///
  /// In en, this message translates to:
  /// **'Task created successfully'**
  String get taskCreatedSuccess;

  /// Empty state title on the task list.
  ///
  /// In en, this message translates to:
  /// **'No tasks found'**
  String get taskNoTasksFound;

  /// Empty state hint for the To Do tab.
  ///
  /// In en, this message translates to:
  /// **'Add new tasks to get started'**
  String get taskEmptyTodo;

  /// Empty state hint for the In Progress tab.
  ///
  /// In en, this message translates to:
  /// **'Move tasks here when you start working on them'**
  String get taskEmptyInProgress;

  /// Empty state hint for the Completed tab.
  ///
  /// In en, this message translates to:
  /// **'Completed tasks will appear here'**
  String get taskEmptyCompleted;

  /// Task status label: to do.
  ///
  /// In en, this message translates to:
  /// **'To Do'**
  String get taskStatusTodo;

  /// Task status label: in progress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get taskStatusInProgress;

  /// Task status label: completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskStatusCompleted;

  /// Button in the empty state that switches to another status tab. {status} is a translated status label.
  ///
  /// In en, this message translates to:
  /// **'View {status} Tasks'**
  String taskViewStatusTasks(String status);

  /// Title of the delete-task confirmation dialog; also the delete tooltip on the task detail screen.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get taskDeleteTitle;

  /// Body of the delete-task confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this task? This action cannot be undone.'**
  String get taskDeleteConfirmMessage;

  /// Delete button / tooltip for a task.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get taskDelete;

  /// Snackbar after a task is deleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted successfully'**
  String get taskDeletedSuccess;

  /// Snackbar fallback when deleting a task fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete task'**
  String get taskDeleteFailed;

  /// Generic error snackbar on the task list.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String taskErrorGeneric(String error);

  /// Fallback title for a task without a title.
  ///
  /// In en, this message translates to:
  /// **'Untitled Task'**
  String get taskUntitled;

  /// Fallback for a task without a description.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get taskNoDescription;

  /// Shown instead of the current user's name as creator/assignee.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get taskYou;

  /// Fallback when a person or status is unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get taskUnknown;

  /// Shown when a task has no assignee; also the 'no assignee' dropdown option.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get taskUnassigned;

  /// Shown when a task has no due date.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get taskNoDueDate;

  /// Approve a task (button / tooltip).
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get taskApprove;

  /// Reject a task (button / tooltip).
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get taskReject;

  /// Task creator line.
  ///
  /// In en, this message translates to:
  /// **'Created by {name}'**
  String taskCreatedBy(String name);

  /// Task assignee line.
  ///
  /// In en, this message translates to:
  /// **'Assigned to {name}'**
  String taskAssignedTo(String name);

  /// Hint on task cards / tooltip on the drag handle.
  ///
  /// In en, this message translates to:
  /// **'Drag to change status'**
  String get taskDragToChangeStatus;

  /// Column header in the wide-screen task table.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskTableTask;

  /// Column header in the wide-screen task table.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get taskTableApproval;

  /// Column header in the wide-screen task table.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get taskTableCreatedBy;

  /// Column header in the wide-screen task table.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get taskTableAssignedTo;

  /// Column header in the wide-screen task table.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get taskTableDueDate;

  /// Snackbar when changing a task's linked ticket fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to update linked ticket'**
  String get taskLinkedTicketUpdateFailed;

  /// Snackbar after a task's status changes. {status} is a translated status label.
  ///
  /// In en, this message translates to:
  /// **'Task status updated to {status}'**
  String taskStatusUpdatedTo(String status);

  /// Snackbar when a status update fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to update task status'**
  String get taskStatusUpdateFailed;

  /// Snackbar after approving a task.
  ///
  /// In en, this message translates to:
  /// **'Task approved'**
  String get taskApprovedMessage;

  /// Snackbar after rejecting a task.
  ///
  /// In en, this message translates to:
  /// **'Task rejected'**
  String get taskRejectedMessage;

  /// Snackbar when deleting a task fails.
  ///
  /// In en, this message translates to:
  /// **'Error deleting task: {error}'**
  String taskErrorDeleting(String error);

  /// Snackbar when adding a comment fails.
  ///
  /// In en, this message translates to:
  /// **'Error adding comment: {error}'**
  String taskErrorAddingComment(String error);

  /// App bar title of the task detail screen.
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get taskDetailsTitle;

  /// Title when a task can't be loaded.
  ///
  /// In en, this message translates to:
  /// **'Task not found'**
  String get taskNotFound;

  /// Subtitle when a task can't be loaded.
  ///
  /// In en, this message translates to:
  /// **'The task may have been deleted'**
  String get taskMayHaveBeenDeleted;

  /// Due date line on the task detail screen.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String taskDueLabel(String date);

  /// Label for the linked-ticket picker.
  ///
  /// In en, this message translates to:
  /// **'Linked ticket'**
  String get taskLinkedTicket;

  /// Option/hint when no ticket is linked to a task.
  ///
  /// In en, this message translates to:
  /// **'No linked ticket'**
  String get taskNoLinkedTicket;

  /// Section heading for task action buttons.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get taskActions;

  /// Button that moves a task to In Progress.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get taskStart;

  /// Button that marks a task as completed.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get taskComplete;

  /// Comments section heading with the number of comments.
  ///
  /// In en, this message translates to:
  /// **'Comments ({count})'**
  String taskCommentsCount(int count);

  /// Comment sort label.
  ///
  /// In en, this message translates to:
  /// **'Latest first'**
  String get taskLatestFirst;

  /// Empty state for task comments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get taskNoCommentsYet;

  /// Empty state hint for task comments.
  ///
  /// In en, this message translates to:
  /// **'Be the first to comment'**
  String get taskBeFirstToComment;

  /// Relative comment time in days.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String taskDaysAgo(int count);

  /// Relative comment time in hours.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String taskHoursAgo(int count);

  /// Relative comment time in minutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String taskMinutesAgo(int count);

  /// Relative comment time for under a minute.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get taskJustNow;

  /// Hint in the task comment input.
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get taskAddCommentHint;

  /// Tooltip for the send-comment icon button.
  ///
  /// In en, this message translates to:
  /// **'Send comment'**
  String get taskSendComment;

  /// Snackbar when creating a task fails.
  ///
  /// In en, this message translates to:
  /// **'Error creating task: {error}'**
  String taskErrorCreating(String error);

  /// App bar title of the create-task screen.
  ///
  /// In en, this message translates to:
  /// **'Create New Task'**
  String get taskCreateNewTitle;

  /// Label for the task title field.
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get taskTitleLabel;

  /// Hint for the task title field.
  ///
  /// In en, this message translates to:
  /// **'Enter task title'**
  String get taskTitleHint;

  /// Validation error when the task title is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a task title'**
  String get taskTitleRequired;

  /// Label for the task description field.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get taskDescriptionLabel;

  /// Hint for the task description field.
  ///
  /// In en, this message translates to:
  /// **'Enter task description'**
  String get taskDescriptionHint;

  /// Label for the due date picker on the create-task screen.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get taskDueDateLabel;

  /// Placeholder when no due date is selected.
  ///
  /// In en, this message translates to:
  /// **'Select due date'**
  String get taskSelectDueDate;

  /// Label for the assignee picker.
  ///
  /// In en, this message translates to:
  /// **'Assign To'**
  String get taskAssignToLabel;

  /// Hint for the assignee picker.
  ///
  /// In en, this message translates to:
  /// **'Select team member'**
  String get taskSelectTeamMember;

  /// Badge next to admin team members in the assignee picker.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get taskAdminBadge;

  /// Submit button on the create-task screen.
  ///
  /// In en, this message translates to:
  /// **'Create Task'**
  String get taskCreateButton;

  /// Snackbar when updating a ticket's status throws.
  ///
  /// In en, this message translates to:
  /// **'Error updating ticket status: {error}'**
  String ticketErrorUpdatingStatus(String error);

  /// Snackbar when updating a ticket's approval throws.
  ///
  /// In en, this message translates to:
  /// **'Error updating ticket approval: {error}'**
  String ticketErrorUpdatingApproval(String error);

  /// Snackbar after a ticket is created.
  ///
  /// In en, this message translates to:
  /// **'Ticket created successfully'**
  String get ticketCreatedSuccess;

  /// Ticket status label for 'open'.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get ticketStatusOpen;

  /// Ticket status label for 'in_progress'.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get ticketStatusInProgress;

  /// Ticket status label for 'resolved'.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get ticketStatusResolved;

  /// Empty-state title on the tickets list.
  ///
  /// In en, this message translates to:
  /// **'No tickets found'**
  String get ticketNoTicketsFound;

  /// Empty-state hint for the Open tab.
  ///
  /// In en, this message translates to:
  /// **'Create new tickets to get started'**
  String get ticketEmptyOpen;

  /// Empty-state hint for the In Progress tab.
  ///
  /// In en, this message translates to:
  /// **'Move tickets here when you start working on them'**
  String get ticketEmptyInProgress;

  /// Empty-state hint for the Resolved tab.
  ///
  /// In en, this message translates to:
  /// **'Resolved tickets will appear here'**
  String get ticketEmptyResolved;

  /// Button to switch to another status tab; status is the translated status label.
  ///
  /// In en, this message translates to:
  /// **'View {status} Tickets'**
  String ticketViewStatusTickets(String status);

  /// Title of the delete-ticket confirmation dialog and the delete menu item.
  ///
  /// In en, this message translates to:
  /// **'Delete Ticket'**
  String get ticketDeleteTitle;

  /// Body of the delete-ticket confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this ticket? This action cannot be undone.'**
  String get ticketDeleteConfirm;

  /// Delete button and tooltip for a ticket.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get ticketDelete;

  /// Snackbar after a ticket is deleted.
  ///
  /// In en, this message translates to:
  /// **'Ticket deleted successfully'**
  String get ticketDeletedSuccess;

  /// Fallback snackbar when deleting a ticket fails without an error message.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete ticket'**
  String get ticketDeleteFailed;

  /// Generic error snackbar on the tickets list.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String ticketErrorGeneric(String error);

  /// Fallback title for a ticket with no title.
  ///
  /// In en, this message translates to:
  /// **'Untitled Ticket'**
  String get ticketUntitled;

  /// Fallback description on ticket cards.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get ticketNoDescription;

  /// Shown instead of the creator's name when the current user created the ticket.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get ticketYou;

  /// Fallback for an unknown person's name.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get ticketUnknown;

  /// Tooltip of the approve-ticket button.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get ticketApprove;

  /// Tooltip of the reject-ticket button.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get ticketReject;

  /// Creator line on a ticket card.
  ///
  /// In en, this message translates to:
  /// **'Created by {name}'**
  String ticketCreatedByName(String name);

  /// Hint/tooltip on the drag handle of a ticket.
  ///
  /// In en, this message translates to:
  /// **'Drag to change status'**
  String get ticketDragToChangeStatus;

  /// Priority column heading and form label.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get ticketPriority;

  /// Ticket-number column heading in the tickets table.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get ticketTicket;

  /// Title column heading and title field label.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get ticketTitle;

  /// Category column heading and form label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get ticketCategory;

  /// Approval column heading in the tickets table.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get ticketApproval;

  /// Label above/heading for the ticket creator.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get ticketCreatedByLabel;

  /// Created-date column heading in the tickets table.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get ticketCreated;

  /// Snackbar when ticket details cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Failed to load ticket details'**
  String get ticketLoadDetailsFailed;

  /// Snackbar when loading ticket details throws.
  ///
  /// In en, this message translates to:
  /// **'Error loading ticket details: {error}'**
  String ticketErrorLoadingDetails(String error);

  /// Snackbar when deleting a ticket fails.
  ///
  /// In en, this message translates to:
  /// **'Error deleting ticket: {error}'**
  String ticketErrorDeleting(String error);

  /// Snackbar when adding a comment fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to add comment: {error}'**
  String ticketAddCommentFailed(String error);

  /// Snackbar when adding a comment throws.
  ///
  /// In en, this message translates to:
  /// **'Error adding comment: {error}'**
  String ticketErrorAddingComment(String error);

  /// Snackbar after a ticket status change.
  ///
  /// In en, this message translates to:
  /// **'Ticket status updated successfully'**
  String get ticketStatusUpdated;

  /// Snackbar when a ticket status change fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to update ticket status: {error}'**
  String ticketUpdateStatusFailed(String error);

  /// Snackbar after a ticket priority change.
  ///
  /// In en, this message translates to:
  /// **'Ticket priority updated successfully'**
  String get ticketPriorityUpdated;

  /// Snackbar when a ticket priority change fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to update ticket priority: {error}'**
  String ticketUpdatePriorityFailed(String error);

  /// Snackbar when a ticket priority change throws.
  ///
  /// In en, this message translates to:
  /// **'Error updating ticket priority: {error}'**
  String ticketErrorUpdatingPriority(String error);

  /// Snackbar when the GitHub issue link cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Could not open GitHub issue'**
  String get ticketCouldNotOpenGithubIssue;

  /// Snackbar after retrying GitHub sync succeeds.
  ///
  /// In en, this message translates to:
  /// **'GitHub sync updated'**
  String get ticketGithubSyncUpdated;

  /// Fallback snackbar when GitHub sync fails.
  ///
  /// In en, this message translates to:
  /// **'GitHub synchronization failed'**
  String get ticketGithubSyncFailed;

  /// Snackbar when GitHub sync throws.
  ///
  /// In en, this message translates to:
  /// **'Error syncing to GitHub: {error}'**
  String ticketErrorSyncingGithub(String error);

  /// Button opening the linked GitHub issue, with its number.
  ///
  /// In en, this message translates to:
  /// **'View on GitHub (#{id})'**
  String ticketViewOnGithubWithId(String id);

  /// Button opening the linked GitHub issue.
  ///
  /// In en, this message translates to:
  /// **'View on GitHub'**
  String get ticketViewOnGithub;

  /// Button to retry a failed GitHub sync.
  ///
  /// In en, this message translates to:
  /// **'Retry GitHub sync'**
  String get ticketRetryGithubSync;

  /// Snackbar after a ticket is assigned.
  ///
  /// In en, this message translates to:
  /// **'Ticket assigned successfully'**
  String get ticketAssignedSuccess;

  /// Snackbar when assigning a ticket fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to assign ticket: {error}'**
  String ticketAssignFailed(String error);

  /// Snackbar when assigning a ticket throws.
  ///
  /// In en, this message translates to:
  /// **'Error assigning ticket: {error}'**
  String ticketErrorAssigning(String error);

  /// Title of the assign-ticket dialog.
  ///
  /// In en, this message translates to:
  /// **'Assign Ticket'**
  String get ticketAssignTitle;

  /// Shown in the assign dialog when team members fail to load.
  ///
  /// In en, this message translates to:
  /// **'Error loading team members'**
  String get ticketErrorLoadingTeamMembers;

  /// Shown in the assign dialog when the team has no members.
  ///
  /// In en, this message translates to:
  /// **'No team members found'**
  String get ticketNoTeamMembers;

  /// Role label for an admin team member.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get ticketRoleAdmin;

  /// Role label for a regular team member.
  ///
  /// In en, this message translates to:
  /// **'Team Member'**
  String get ticketRoleTeamMember;

  /// App bar title of the ticket detail screen.
  ///
  /// In en, this message translates to:
  /// **'Ticket Details'**
  String get ticketDetailsTitle;

  /// Title shown when a ticket cannot be found.
  ///
  /// In en, this message translates to:
  /// **'Ticket not found'**
  String get ticketNotFound;

  /// Explanation shown when a ticket cannot be found.
  ///
  /// In en, this message translates to:
  /// **'The ticket may have been deleted or you do not have access to it.'**
  String get ticketNotFoundMessage;

  /// Menu section header for changing ticket status.
  ///
  /// In en, this message translates to:
  /// **'Change Status'**
  String get ticketChangeStatus;

  /// Menu section header for changing ticket priority.
  ///
  /// In en, this message translates to:
  /// **'Change Priority'**
  String get ticketChangePriority;

  /// Label for 'high' priority.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get ticketPriorityHigh;

  /// Label for 'medium' priority.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get ticketPriorityMedium;

  /// Label for 'low' priority.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get ticketPriorityLow;

  /// Display label for the 'Bug' ticket category.
  ///
  /// In en, this message translates to:
  /// **'Bug'**
  String get ticketCategoryBug;

  /// Display label for the 'Feature Request' ticket category.
  ///
  /// In en, this message translates to:
  /// **'Feature Request'**
  String get ticketCategoryFeatureRequest;

  /// Display label for the 'UI/UX' ticket category.
  ///
  /// In en, this message translates to:
  /// **'UI/UX'**
  String get ticketCategoryUiUx;

  /// Display label for the 'Performance' ticket category.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get ticketCategoryPerformance;

  /// Display label for the 'Documentation' ticket category.
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get ticketCategoryDocumentation;

  /// Display label for the 'Security' ticket category.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get ticketCategorySecurity;

  /// Display label for the 'Other' ticket category.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get ticketCategoryOther;

  /// Fallback description on the ticket detail screen.
  ///
  /// In en, this message translates to:
  /// **'No description provided.'**
  String get ticketNoDescriptionProvided;

  /// Label above the ticket assignee's name.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get ticketAssignedTo;

  /// Button to assign an unassigned ticket.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get ticketAssign;

  /// Comments section heading with the number of comments.
  ///
  /// In en, this message translates to:
  /// **'Comments ({count})'**
  String ticketCommentsCount(int count);

  /// Empty state of the comments section.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get ticketNoComments;

  /// Empty-state hint of the comments section.
  ///
  /// In en, this message translates to:
  /// **'Be the first to add a comment'**
  String get ticketBeFirstComment;

  /// Hint of the comment input field.
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get ticketAddCommentHint;

  /// Tooltip of the send-comment button.
  ///
  /// In en, this message translates to:
  /// **'Send comment'**
  String get ticketSendComment;

  /// Snackbar when creating a ticket fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to create ticket: {error}'**
  String ticketCreateFailed(String error);

  /// Snackbar when creating a ticket throws.
  ///
  /// In en, this message translates to:
  /// **'Error creating ticket: {error}'**
  String ticketErrorCreating(String error);

  /// Create-ticket screen title, tooltip and submit button.
  ///
  /// In en, this message translates to:
  /// **'Create Ticket'**
  String get ticketCreateTitle;

  /// Hint of the ticket title field.
  ///
  /// In en, this message translates to:
  /// **'Enter ticket title'**
  String get ticketTitleHint;

  /// Validation error when the ticket title is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get ticketTitleRequired;

  /// Label of the ticket description field.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get ticketDescription;

  /// Hint of the ticket description field.
  ///
  /// In en, this message translates to:
  /// **'Enter ticket description (max 75 words recommended)'**
  String get ticketDescriptionHint;

  /// Validation error when the ticket description is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get ticketDescriptionRequired;

  /// Label of the assignee picker on the create-ticket form.
  ///
  /// In en, this message translates to:
  /// **'Assign To (Optional)'**
  String get ticketAssignToOptional;

  /// Hint of the assignee dropdown.
  ///
  /// In en, this message translates to:
  /// **'Select team member'**
  String get ticketSelectTeamMember;

  /// Dropdown option for no assignee.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get ticketUnassigned;

  /// Switch title to also create a GitHub issue.
  ///
  /// In en, this message translates to:
  /// **'Create GitHub issue'**
  String get ticketCreateGithubIssue;

  /// Subtitle of the create-GitHub-issue switch.
  ///
  /// In en, this message translates to:
  /// **'Sync this ticket to the configured GitHub repository'**
  String get ticketCreateGithubIssueSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
