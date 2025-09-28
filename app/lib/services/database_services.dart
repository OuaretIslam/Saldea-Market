import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app/modeles/users.dart';

class DatabaseService {
  final _db = FirebaseFirestore.instance;
  final _path = 'users';

  CollectionReference<UserModel> get _usersRef =>
    _db
      .collection(_path)
      .withConverter<UserModel>(
        fromFirestore: (snap, _) => UserModel.fromFirestore(snap),
        toFirestore:   (user, _) => user.toMap(),
      );

  Future<void> createUser(UserModel user) {
    return _usersRef.doc(user.uid).set(user);
  }

  Future<UserModel?> getUser(String uid) async {
    final snap = await _usersRef.doc(uid).get();
    return snap.data();
  }

  Future<void> updateUser(UserModel user) {
    return _usersRef.doc(user.uid).update(user.toMap());
  }

  Future<void> deleteUser(String uid) {
    return _usersRef.doc(uid).delete();
  }
}
