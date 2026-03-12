import 'package:equatable/equatable.dart';

class ParticipantModel extends Equatable {
  final String id;
  final String name;
  final int order;

  const ParticipantModel({
    required this.id,
    required this.name,
    required this.order,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id: json['id'] as String,
      name: json['name'] as String,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
    };
  }

  String get displayName => name;

  ParticipantModel copyWith({
    String? id,
    String? name,
    int? order,
  }) {
    return ParticipantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
    );
  }

  @override
  List<Object?> get props => [id, name, order];
}
