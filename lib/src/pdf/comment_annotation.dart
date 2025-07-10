import 'dart:ui';

class CommentAnnotation {
  final String comment;
  final Offset position;

  CommentAnnotation({required this.comment, required this.position});

  CommentAnnotation copyWith({String? comment, Offset? position}) {
    return CommentAnnotation(
      comment: comment ?? this.comment,
      position: position ?? this.position,
    );
  }
}
