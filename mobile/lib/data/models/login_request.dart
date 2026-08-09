class LoginRequest {
  final String username;
  final String password;

  LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() {
    // FastAPI OAuth2PasswordRequestForm ожидает поля username и password
    return {
      'username': username,
      'password': password,
    };
  }
}