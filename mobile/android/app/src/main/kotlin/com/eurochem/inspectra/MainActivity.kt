package com.eurochem.inspectra

// ВАЖНО: Импортируем именно FlutterFragmentActivity, а не FlutterActivity
import io.flutter.embedding.android.FlutterFragmentActivity

// Наследуемся от FlutterFragmentActivity для корректной работы local_auth
class MainActivity: FlutterFragmentActivity()