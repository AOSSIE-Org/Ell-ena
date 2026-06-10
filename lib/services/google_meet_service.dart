import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class GoogleMeetService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      cal.CalendarApi.calendarScope,
      cal.CalendarApi.calendarEventsScope,
    ],
  );

  Future<String?> createMeetLink({
    required DateTime start,
    required int durationMinutes,
    required String title,
    String? description,
  }) async {
    try {
      // Sign in with Google
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      // Get authentication
      final authentication = await account.authentication;
      final accessToken = authentication.accessToken;
      
      if (accessToken == null) {
        print('No access token available');
        return null;
      }

      // Create authenticated client using authenticatedClient function (FIXED)
      final credentials = AccessCredentials(
        AccessToken('Bearer', accessToken, DateTime.now().add(const Duration(hours: 1)).toUtc()),
        null, // No refresh token needed for one-time use
        _googleSignIn.scopes,
      );

      final authClient = authenticatedClient(http.Client(), credentials);

      try {
        final calendarApi = cal.CalendarApi(authClient);

        final event = cal.Event(
          summary: title,
          description: description,
          start: cal.EventDateTime(dateTime: start.toUtc()),
          end: cal.EventDateTime(
            dateTime: start.add(Duration(minutes: durationMinutes)).toUtc(),
          ),
          conferenceData: cal.ConferenceData(
            createRequest: cal.CreateConferenceRequest(
              requestId: DateTime.now().millisecondsSinceEpoch.toString(),
              conferenceSolutionKey: cal.ConferenceSolutionKey(
                type: 'hangoutsMeet',
              ),
            ),
          ),
        );

        final createdEvent = await calendarApi.events.insert(
          event,
          'primary',
          conferenceDataVersion: 1,
        );

        // Return the meet link
        return createdEvent.hangoutLink ??
            createdEvent.conferenceData?.entryPoints
                ?.firstWhere(
                  (e) => e.entryPointType == 'video',
                  orElse: () => cal.EntryPoint(uri: ''),
                )
                .uri;
      } finally {
        authClient.close();
      }
    } catch (e) {
      print('Error creating Google Meet link: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}