// lib/env.dart
import 'package:dotenv/dotenv.dart' as dotenv;

// single shared DotEnv instance used across the app (v4 usage)
final dotenv.DotEnv env = dotenv.DotEnv();
