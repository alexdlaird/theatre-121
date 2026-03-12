import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:theatre_121/data/models/models.dart';
import 'package:theatre_121/domain/repositories/event_repository.dart';
import 'package:theatre_121/domain/repositories/ballot_repository.dart';
import 'package:theatre_121/domain/services/google_sheets_service.dart';

abstract class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

class StartWatching extends AdminEvent {
  const StartWatching();
}

class _EventUpdated extends AdminEvent {
  final EventModel? event;

  const _EventUpdated(this.event);

  @override
  List<Object?> get props => [event];
}

class _BallotsUpdated extends AdminEvent {
  final List<BallotModel> ballots;

  const _BallotsUpdated(this.ballots);

  @override
  List<Object?> get props => [ballots];
}

class _StreamError extends AdminEvent {
  final String message;

  const _StreamError(this.message);

  @override
  List<Object?> get props => [message];
}

class CreateEvent extends AdminEvent {
  final String name;
  final List<String> participantNames;
  final int audienceBallotCount;
  final List<String> judgeNames;

  const CreateEvent({
    required this.name,
    required this.participantNames,
    required this.audienceBallotCount,
    required this.judgeNames,
  });

  @override
  List<Object?> get props =>
      [name, participantNames, audienceBallotCount, judgeNames];
}

class CloseVoting extends AdminEvent {
  const CloseVoting();
}

class RerunExport extends AdminEvent {
  const RerunExport();
}

class UpdateDonationWinner extends AdminEvent {
  final String? largestDonationWinnerId;
  final String? mostDonationsWinnerId;

  const UpdateDonationWinner({
    this.largestDonationWinnerId,
    this.mostDonationsWinnerId,
  });

  @override
  List<Object?> get props => [largestDonationWinnerId, mostDonationsWinnerId];
}

enum ClosingProgress {
  none,
  closingVoting,
  exportingBallots,
  calculatingResults,
  complete,
}

abstract class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {
  const AdminInitial();
}

class AdminLoading extends AdminState {
  const AdminLoading();
}

class AdminLoaded extends AdminState {
  final EventModel? currentEvent;
  final List<BallotModel> ballots;
  final bool isCreatingEvent;
  final ClosingProgress closingProgress;
  final VotingResults? votingResults;

  const AdminLoaded({
    this.currentEvent,
    this.ballots = const [],
    this.isCreatingEvent = false,
    this.closingProgress = ClosingProgress.none,
    this.votingResults,
  });

  bool get isClosingVoting => closingProgress != ClosingProgress.none &&
      closingProgress != ClosingProgress.complete;

  int get audienceBallotCount => ballots.where((b) => b.isAudience).length;
  int get judgeBallotCount => ballots.where((b) => b.isJudge).length;
  int get submittedAudienceCount =>
      ballots.where((b) => b.isAudience && b.submitted).length;
  int get submittedJudgeCount =>
      ballots.where((b) => b.isJudge && b.submitted).length;

  String get closingProgressText {
    switch (closingProgress) {
      case ClosingProgress.closingVoting:
        return 'Closing voting ...';
      case ClosingProgress.exportingBallots:
        return 'Exporting ballots ...';
      case ClosingProgress.calculatingResults:
        return 'Calculating results ...';
      case ClosingProgress.none:
      case ClosingProgress.complete:
        return '';
    }
  }

  @override
  List<Object?> get props =>
      [currentEvent, ballots, isCreatingEvent, closingProgress, votingResults];

  AdminLoaded copyWith({
    EventModel? currentEvent,
    List<BallotModel>? ballots,
    bool? isCreatingEvent,
    ClosingProgress? closingProgress,
    VotingResults? votingResults,
    bool clearEvent = false,
    bool clearResults = false,
  }) {
    return AdminLoaded(
      currentEvent: clearEvent ? null : (currentEvent ?? this.currentEvent),
      ballots: ballots ?? this.ballots,
      isCreatingEvent: isCreatingEvent ?? this.isCreatingEvent,
      closingProgress: closingProgress ?? this.closingProgress,
      votingResults: clearResults ? null : (votingResults ?? this.votingResults),
    );
  }
}

class AdminError extends AdminState {
  final String message;

  const AdminError(this.message);

  @override
  List<Object?> get props => [message];
}

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final EventRepository _eventRepository;
  final BallotRepository _ballotRepository;
  final GoogleSheetsService _sheetsService;

  StreamSubscription<EventModel?>? _eventSubscription;
  StreamSubscription<List<BallotModel>>? _ballotsSubscription;
  String? _currentEventId;

  AdminBloc({
    required EventRepository eventRepository,
    required BallotRepository ballotRepository,
    required GoogleSheetsService sheetsService,
  })  : _eventRepository = eventRepository,
        _ballotRepository = ballotRepository,
        _sheetsService = sheetsService,
        super(const AdminInitial()) {
    on<StartWatching>(_onStartWatching);
    on<_EventUpdated>(_onEventUpdated);
    on<_BallotsUpdated>(_onBallotsUpdated);
    on<_StreamError>(_onStreamError);
    on<CreateEvent>(_onCreateEvent);
    on<CloseVoting>(_onCloseVoting);
    on<RerunExport>(_onRerunExport);
    on<UpdateDonationWinner>(_onUpdateDonationWinner);
  }

  void _onStartWatching(
    StartWatching event,
    Emitter<AdminState> emit,
  ) {
    emit(const AdminLoading());

    _eventSubscription?.cancel();
    _eventSubscription = _eventRepository.watchCurrentEvent().listen(
      (event) => add(_EventUpdated(event)),
      onError: (e) => add(_StreamError(e.toString())),
    );
  }

  void _onStreamError(
    _StreamError event,
    Emitter<AdminState> emit,
  ) {
    emit(AdminError(event.message));
  }

  void _onEventUpdated(
    _EventUpdated event,
    Emitter<AdminState> emit,
  ) {
    final currentState = state;
    final newEvent = event.event;

    // Update ballots subscription if event changed
    if (newEvent?.id != _currentEventId) {
      _currentEventId = newEvent?.id;
      _ballotsSubscription?.cancel();

      if (newEvent != null) {
        _ballotsSubscription =
            _ballotRepository.watchEventBallots(newEvent.id).listen(
                  (ballots) => add(_BallotsUpdated(ballots)),
                  onError: (e) => add(_StreamError(e.toString())),
                );
      }
    }

    if (currentState is AdminLoaded) {
      emit(currentState.copyWith(
        currentEvent: newEvent,
        clearEvent: newEvent == null,
      ));
    } else {
      emit(AdminLoaded(currentEvent: newEvent));
    }
  }

  void _onBallotsUpdated(
    _BallotsUpdated event,
    Emitter<AdminState> emit,
  ) {
    final currentState = state;
    if (currentState is AdminLoaded) {
      // Only emit if ballots actually changed
      if (!const DeepCollectionEquality()
          .equals(currentState.ballots, event.ballots)) {
        final eventData = currentState.currentEvent;
        // Recalculate results if event is closed and has spreadsheet URL
        if (eventData != null &&
            !eventData.isVotingOpen &&
            eventData.spreadsheetUrl != null &&
            currentState.votingResults == null) {
          final results = _calculateResults(
            event: eventData,
            ballots: event.ballots,
            spreadsheetUrl: eventData.spreadsheetUrl!,
          );
          emit(currentState.copyWith(
            ballots: event.ballots,
            votingResults: results,
            closingProgress: ClosingProgress.complete,
          ));
        } else {
          emit(currentState.copyWith(ballots: event.ballots));
        }
      }
    }
  }

  Future<void> _onCreateEvent(
    CreateEvent event,
    Emitter<AdminState> emit,
  ) async {
    final currentState = state;
    if (currentState is AdminLoaded) {
      emit(currentState.copyWith(isCreatingEvent: true));
    }

    try {
      final participants = event.participantNames.asMap().entries.map((entry) {
        return ParticipantModel(
          id: 'p${entry.key + 1}',
          name: entry.value,
          order: entry.key + 1,
        );
      }).toList();

      final newEvent = await _eventRepository.createEvent(
        EventModel(
          id: '',
          name: event.name,
          participants: participants,
          judges: event.judgeNames,
          status: EventStatus.open,
          createdAt: DateTime.now(),
        ),
      );

      final ballots = await _ballotRepository.createBallotsAndReturn(
        eventId: newEvent.id,
        audienceCount: event.audienceBallotCount,
        judgeNames: event.judgeNames,
      );

      // Emit AdminLoaded directly - streams will update with any changes
      emit(AdminLoaded(currentEvent: newEvent, ballots: ballots));
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  Future<void> _onCloseVoting(
    CloseVoting event,
    Emitter<AdminState> emit,
  ) async {
    var currentState = state;
    if (currentState is! AdminLoaded || currentState.currentEvent == null) {
      return;
    }

    final eventData = currentState.currentEvent!;
    final ballotData = currentState.ballots;

    try {
      // Step 1: Closing voting
      currentState = currentState.copyWith(closingProgress: ClosingProgress.closingVoting);
      emit(currentState);
      await _eventRepository.closeVoting(eventData.id);

      // Update event status to closed immediately
      final closedEvent = eventData.copyWith(status: EventStatus.closed);
      currentState = currentState.copyWith(currentEvent: closedEvent);

      // Step 2: Exporting ballots
      currentState = currentState.copyWith(closingProgress: ClosingProgress.exportingBallots);
      emit(currentState);
      final spreadsheetUrl = await _sheetsService.createResultsSpreadsheet(
        event: eventData,
        ballots: ballotData,
      );
      await _eventRepository.updateSpreadsheetUrl(eventData.id, spreadsheetUrl);

      // Step 3: Calculating results
      currentState = currentState.copyWith(closingProgress: ClosingProgress.calculatingResults);
      emit(currentState);
      final results = _calculateResults(
        event: eventData,
        ballots: ballotData,
        spreadsheetUrl: spreadsheetUrl,
      );

      // Step 4: Complete
      emit(currentState.copyWith(
        closingProgress: ClosingProgress.complete,
        votingResults: results,
        currentEvent: eventData.copyWith(status: EventStatus.closed),
      ));
    } catch (e) {
      // Reset progress and show error via snackbar (listener handles AdminError)
      if (state is AdminLoaded) {
        emit((state as AdminLoaded).copyWith(closingProgress: ClosingProgress.none));
      }
      emit(AdminError(e.toString()));
    }
  }

  void _onRerunExport(
    RerunExport event,
    Emitter<AdminState> emit,
  ) {
    final currentState = state;
    if (currentState is! AdminLoaded || currentState.currentEvent == null) {
      return;
    }

    final eventData = currentState.currentEvent!;
    final ballotData = currentState.ballots;
    final spreadsheetUrl = eventData.spreadsheetUrl;

    if (spreadsheetUrl == null) {
      emit(const AdminError('No spreadsheet URL found. Close voting first.'));
      return;
    }

    final results = _calculateResults(
      event: eventData,
      ballots: ballotData,
      spreadsheetUrl: spreadsheetUrl,
    );

    emit(currentState.copyWith(
      votingResults: results,
      closingProgress: ClosingProgress.complete,
    ));
  }

  VotingResults _calculateResults({
    required EventModel event,
    required List<BallotModel> ballots,
    required String spreadsheetUrl,
  }) {
    final participants = event.participants;
    final audienceBallots = ballots.where((b) => b.isAudience && b.submitted).toList();
    final judgeBallots = ballots.where((b) => b.isJudge && b.submitted).toList();

    final rankings = <ParticipantResult>[];

    for (final participant in participants) {
      // Calculate audience points (sum of rankings where lower is better)
      int audiencePoints = 0;
      for (final ballot in audienceBallots) {
        final vote = ballot.audienceVotes[participant.id];
        if (vote != null) {
          audiencePoints += vote;
        }
      }

      // Calculate judge total
      int judgeTotal = 0;
      for (final ballot in judgeBallots) {
        final vote = ballot.judgeVotes[participant.id];
        if (vote != null) {
          judgeTotal += vote.singing + vote.performance + vote.audienceParticipation;
        }
      }

      rankings.add(ParticipantResult(
        id: participant.id,
        name: participant.displayName,
        audiencePoints: audiencePoints,
        judgeTotal: judgeTotal,
        combinedScore: audiencePoints + judgeTotal,
      ));
    }

    // Sort by combined score (lower is better for audience rankings)
    rankings.sort((a, b) => a.combinedScore.compareTo(b.combinedScore));

    // Find participants with the lowest score (highest combined = worst)
    String? eliminatedId;
    List<String> tiedIds = [];

    if (rankings.isNotEmpty) {
      final lowestScore = rankings.last.combinedScore;
      final lowestScorers = rankings
          .where((r) => r.combinedScore == lowestScore)
          .map((r) => r.id)
          .toList();

      if (lowestScorers.length > 1) {
        // There's a tie - don't auto-eliminate, require judge decision
        tiedIds = lowestScorers;
      } else {
        // Clear winner for elimination
        eliminatedId = lowestScorers.first;
      }
    }

    return VotingResults(
      rankings: rankings,
      eliminatedParticipantId: eliminatedId,
      tiedParticipantIds: tiedIds,
      spreadsheetUrl: spreadsheetUrl,
    );
  }

  Future<void> _onUpdateDonationWinner(
    UpdateDonationWinner event,
    Emitter<AdminState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AdminLoaded || currentState.currentEvent == null) {
      return;
    }

    try {
      await _eventRepository.updateDonationWinners(
        currentState.currentEvent!.id,
        largestDonationWinnerId: event.largestDonationWinnerId,
        mostDonationsWinnerId: event.mostDonationsWinnerId,
      );
      // Stream will automatically update the state
    } catch (e) {
      emit(AdminError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    _ballotsSubscription?.cancel();
    return super.close();
  }
}
