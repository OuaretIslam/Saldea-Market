import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String address;
  final List<String> type;    // e.g. ["client","seller"]
  final String picture;       // ← new field
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.address,
    required this.type,
    required this.picture,     // ← include it in your ctor
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'address': address,
      'type': type,
      'picture': picture,       // ← save the URL
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      uid: data['uid'] as String,
      email: data['email'] as String,
      username: data['username'] as String,
      address: data['address'] as String,
      type: List<String>.from(data['type'] as List<dynamic>),
      picture: data['picture'] as String? ?? '', // ← read it
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
