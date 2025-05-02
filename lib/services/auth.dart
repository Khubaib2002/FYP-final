import 'package:firebase_auth/firebase_auth.dart';
import 'package:agaahi/models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

//create user object based on firebase user
  User_? _userFromFireBaseUser(User? user) {
    // ignore: unnecessary_null_comparison
    return user != null ? User_(uid: user.uid) : null;
  }

//auth change user stream
  Stream<User_?> get user {
    return _auth
        .authStateChanges()
        // .map((User? user) => _userFromFireBaseUser(user));
        .map(_userFromFireBaseUser);
  }

//sign in anon
  Future signInAnon() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      User? user = result.user;
      return _userFromFireBaseUser(user);
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

//method to sign in with email & password
  Future signin_wenp(String email, String pass) async {
    try {
      UserCredential result =
          await _auth.signInWithEmailAndPassword(email: email, password: pass);
      User? user = result.user;
      return _userFromFireBaseUser(user);
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

// register with email and password
  Future register_wenp(String email, String pass) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: pass);
      User? user = result.user;
      return _userFromFireBaseUser(user);
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

//sign out
  Future SignOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print(e.toString());
      return null;
    }
  }
}
