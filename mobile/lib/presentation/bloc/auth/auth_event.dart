import 'package:equatable/equatable.dart';
import '../../../data/models/login_request.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final LoginRequest request;
  LoginRequested(this.request);

  @override
  List<Object?> get props => [request.username, request.password];
}

class LogoutRequested extends AuthEvent {}