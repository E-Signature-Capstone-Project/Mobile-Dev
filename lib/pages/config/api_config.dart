class ApiConfig {
  static const String baseUrl = "http://10.0.2.2:4000";

  static String get authUrl => "$baseUrl/auth";
  static String get documentsUrl => "$baseUrl/documents";
  static String get logsUrl => "$baseUrl/logs";
  static String get baselineUrl => "$baseUrl/signature_baseline";
  static String get requestsUrl => "$baseUrl/requests";
  static String get usersUrl => "$baseUrl/users";
  static String get pendingAdminUrl => "$authUrl/admin/pending";

  static String approveAdminUrl(int userId) => "$authUrl/admin/approve/$userId";
  static String rejectAdminUrl(int userId) => "$authUrl/admin/reject/$userId";

  static String requestSignatureUrl(int requestId) =>
      "$baseUrl/requests/$requestId/signature";

  static String signExternalUrl(int documentId) =>
      "$baseUrl/documents/$documentId/sign-external";
}
