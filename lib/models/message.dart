import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String uid;
  final String text;
  final String? email;
  final DateTime? timestamp;

  Message({
    required this.uid,
    required this.text,
    this.email,
    this.timestamp,
  });

  factory Message.fromMap(Map<String, dynamic> data) {
    return Message(
      uid: data['uid'],
      text: data['text'],
      email: data['email'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}
