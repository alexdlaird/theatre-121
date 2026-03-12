import 'package:theatre_121/data/models/models.dart';

abstract class EventRepository {
  Future<EventModel?> getCurrentEvent();
  Future<EventModel> createEvent(EventModel event);
  Future<void> updateEvent(EventModel event);
  Future<void> closeVoting(String eventId);
  Future<void> deleteEvent(String eventId);
  Stream<EventModel?> watchCurrentEvent();
}
