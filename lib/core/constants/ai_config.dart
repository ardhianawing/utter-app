class AiConfig {
  static const String geminiApiKey = 'AIzaSyDiR01Gcxue8qle62_f95Nk_MBddr1QtuE';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String geminiModel = 'gemini-1.5-flash'; // Supports function calling
  // gemini-pro does NOT support tools/function calling
  // gemini-1.5-flash and gemini-1.5-pro DO support function calling
}
