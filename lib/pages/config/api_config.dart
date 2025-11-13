class ApiConfig {
  static const String baseUrl = "http://10.0.2.2:4000"; //http://10.0.2.2:4000

  static String get authUrl => "$baseUrl/auth";
  static String get documentsUrl => "$baseUrl/documents";
  static String get logsUrl => "$baseUrl/logs";
  static String get baselineUrl => "$baseUrl/signature_baseline";
  static String get requestsUrl => "$baseUrl/requests";
}
