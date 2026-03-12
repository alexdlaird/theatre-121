import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:theatre_121/data/models/models.dart';
import 'package:theatre_121/domain/services/google_sheets_service.dart';

class GoogleSheetsServiceImpl implements GoogleSheetsService {
  final GoogleSignIn _googleSignIn;

  GoogleSheetsServiceImpl({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [
                'email',
                'https://www.googleapis.com/auth/drive.file',
              ],
            );

  Future<AuthClient> _getAuthClient() async {
    final account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) {
      throw StateError('Not signed in to Google');
    }

    final auth = await account.authentication;
    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        auth.accessToken!,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      ['https://www.googleapis.com/auth/drive.file'],
    );

    return authenticatedClient(http.Client(), credentials);
  }

  @override
  Future<String> createResultsSpreadsheet({
    required EventModel event,
    required List<BallotModel> ballots,
  }) async {
    final client = await _getAuthClient();

    try {
      final sheetsApi = sheets.SheetsApi(client);

      // Create the spreadsheet
      final spreadsheet = await sheetsApi.spreadsheets.create(
        sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(
            title: '${event.name} - Voting Results',
          ),
          sheets: [
            sheets.Sheet(
              properties: sheets.SheetProperties(title: 'Audience Votes'),
            ),
            sheets.Sheet(
              properties: sheets.SheetProperties(title: 'Judge Votes'),
            ),
            sheets.Sheet(
              properties: sheets.SheetProperties(title: 'Summary'),
            ),
          ],
        ),
      );

      final spreadsheetId = spreadsheet.spreadsheetId!;

      // Prepare audience votes data
      final audienceBallots = ballots.where((b) => b.isAudience && b.submitted).toList();
      final judgeBallots = ballots.where((b) => b.isJudge && b.submitted).toList();
      final participants = List<ParticipantModel>.from(event.participants)
        ..sort((a, b) => a.order.compareTo(b.order));

      // Build audience votes sheet
      final audienceRows = <List<Object?>>[];
      audienceRows.add(['Ballot Code', ...participants.map((p) => p.displayName)]);
      for (final ballot in audienceBallots) {
        final row = <Object?>[ballot.code];
        for (final participant in participants) {
          row.add(ballot.audienceVotes[participant.id] ?? '');
        }
        audienceRows.add(row);
      }

      // Build judge votes sheet
      final judgeRows = <List<Object?>>[];
      judgeRows.add([
        'Judge',
        'Ballot Code',
        'Participant',
        'Singing',
        'Performance',
        'Audience Participation',
        'Total',
        'Comments',
      ]);
      for (final ballot in judgeBallots) {
        for (final participant in participants) {
          final vote = ballot.judgeVotes[participant.id];
          if (vote != null) {
            final total = vote.singing + vote.performance + vote.audienceParticipation;
            judgeRows.add([
              ballot.judgeName ?? ballot.code,
              ballot.code,
              participant.displayName,
              vote.singing,
              vote.performance,
              vote.audienceParticipation,
              total,
              vote.comments,
            ]);
          }
        }
      }

      // Build summary sheet
      final summaryRows = <List<Object?>>[];
      summaryRows.add(['Participant', 'Audience Points', 'Judge Total', 'Combined']);
      for (final participant in participants) {
        summaryRows.add([
          participant.displayName,
          '=SUMIF(\'Audience Votes\'!A:A,"<>",\'Audience Votes\'!${_columnLetter(participants.indexOf(participant) + 2)}:\${_columnLetter(participants.indexOf(participant) + 2)})',
          '=SUMIF(\'Judge Votes\'!C:C,"${participant.displayName}",\'Judge Votes\'!G:G)',
          '=B${participants.indexOf(participant) + 2}+C${participants.indexOf(participant) + 2}',
        ]);
      }

      // Write data to sheets
      await sheetsApi.spreadsheets.values.batchUpdate(
        sheets.BatchUpdateValuesRequest(
          valueInputOption: 'USER_ENTERED',
          data: [
            sheets.ValueRange(
              range: 'Audience Votes!A1',
              values: audienceRows,
            ),
            sheets.ValueRange(
              range: 'Judge Votes!A1',
              values: judgeRows,
            ),
            sheets.ValueRange(
              range: 'Summary!A1',
              values: summaryRows,
            ),
          ],
        ),
        spreadsheetId,
      );

      return 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit';
    } finally {
      client.close();
    }
  }

  String _columnLetter(int column) {
    String result = '';
    var col = column;
    while (col > 0) {
      col--;
      result = String.fromCharCode(65 + (col % 26)) + result;
      col ~/= 26;
    }
    return result;
  }
}
