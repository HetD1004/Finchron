import 'package:equatable/equatable.dart';
import '../../models/user.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String name;
  final String password;

  const AuthRegisterRequested({
    required this.email,
    required this.name,
    required this.password,
  });

  @override
  List<Object?> get props => [email, name, password];
}

class AuthGoogleSignInRequested extends AuthEvent {}

class AuthSignOutRequested extends AuthEvent {}

class AuthUserChanged extends AuthEvent {
  final String? userId;

  const AuthUserChanged({this.userId});

  @override
  List<Object?> get props => [userId];
}

class AuthUserProfileUpdated extends AuthEvent {
  final User user;

  const AuthUserProfileUpdated({required this.user});

  @override
  List<Object?> get props => [user];
}
