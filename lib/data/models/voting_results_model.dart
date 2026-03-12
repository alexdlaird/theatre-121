import 'package:equatable/equatable.dart';

class ParticipantResult extends Equatable {
  final String id;
  final String name;
  final int audiencePoints;
  final int judgeTotal;
  final int combinedScore;

  const ParticipantResult({
    required this.id,
    required this.name,
    required this.audiencePoints,
    required this.judgeTotal,
    required this.combinedScore,
  });

  @override
  List<Object?> get props => [id, name, audiencePoints, judgeTotal, combinedScore];
}

class VotingResults extends Equatable {
  final List<ParticipantResult> rankings;
  final String? eliminatedParticipantId;
  final String spreadsheetUrl;

  const VotingResults({
    required this.rankings,
    this.eliminatedParticipantId,
    required this.spreadsheetUrl,
  });

  ParticipantResult? get eliminatedParticipant {
    if (eliminatedParticipantId == null) return null;
    return rankings.where((r) => r.id == eliminatedParticipantId).firstOrNull;
  }

  @override
  List<Object?> get props => [rankings, eliminatedParticipantId, spreadsheetUrl];
}
