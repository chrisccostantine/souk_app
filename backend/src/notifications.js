import admin from 'firebase-admin';

let firebaseApp;

function firebaseCredential() {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson) {
    return admin.credential.cert(JSON.parse(serviceAccountJson));
  }
  return admin.credential.applicationDefault();
}

export function firebaseMessaging() {
  if (!firebaseApp) {
    firebaseApp = admin.initializeApp({
      credential: firebaseCredential(),
    });
  }
  return admin.messaging(firebaseApp);
}

export function firebaseConfigured() {
  return Boolean(
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON ||
      process.env.GOOGLE_APPLICATION_CREDENTIALS,
  );
}

export async function sendPushToTokens({ tokens, title, body, data = {} }) {
  if (tokens.length === 0) {
    return { delivered: 0, failed: 0, invalidTokens: [] };
  }
  if (!firebaseConfigured()) {
    return { delivered: 0, failed: tokens.length, invalidTokens: [] };
  }
  let delivered = 0;
  let failed = 0;
  const invalidTokens = [];
  for (let index = 0; index < tokens.length; index += 500) {
    const batch = tokens.slice(index, index + 500);
    const response = await firebaseMessaging().sendEachForMulticast({
      tokens: batch,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, String(value ?? '')]),
      ),
    });
    delivered += response.successCount;
    failed += response.failureCount;
    invalidTokens.push(
      ...response.responses
        .map((item, batchIndex) => ({ item, batchIndex }))
        .filter(({ item }) =>
          item.error?.code === 'messaging/registration-token-not-registered' ||
          item.error?.code === 'messaging/invalid-registration-token',
        )
        .map(({ batchIndex }) => batch[batchIndex]),
    );
  }
  return {
    delivered,
    failed,
    invalidTokens,
  };
}
