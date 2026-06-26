const soukloraApiUrl = String.fromEnvironment('SOUKLORA_API_URL');
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const appleServiceId = String.fromEnvironment('APPLE_SERVICE_ID');
const appleRedirectUri = String.fromEnvironment('APPLE_REDIRECT_URI');

bool get isSoukloraApiConfigured =>
    soukloraApiUrl.isNotEmpty && soukloraApiUrl.startsWith('https://');
