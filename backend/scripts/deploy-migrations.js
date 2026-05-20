import { spawn } from 'node:child_process';

const maxAttempts = Number(process.env.DB_DEPLOY_MAX_ATTEMPTS || 12);
const initialDelayMs = Number(process.env.DB_DEPLOY_INITIAL_DELAY_MS || 2000);
const maxDelayMs = Number(process.env.DB_DEPLOY_MAX_DELAY_MS || 15000);
const retryablePatterns = [
  'P1001',
  "Can't reach database server",
  'ECONNREFUSED',
  'ETIMEDOUT',
  'ENOTFOUND',
  'Connection terminated',
];

function wait(milliseconds) {
  return new Promise((resolve) => {
    setTimeout(resolve, milliseconds);
  });
}

function runPrismaDeploy() {
  return new Promise((resolve) => {
    const child = spawn('prisma', ['migrate', 'deploy'], {
      shell: process.platform === 'win32',
      stdio: ['inherit', 'pipe', 'pipe'],
      env: process.env,
    });

    let output = '';
    const capture = (chunk, stream) => {
      const text = chunk.toString();
      output += text;
      stream.write(chunk);
    };

    child.stdout.on('data', (chunk) => capture(chunk, process.stdout));
    child.stderr.on('data', (chunk) => capture(chunk, process.stderr));
    child.on('close', (code) => {
      resolve({ code, output });
    });
  });
}

function isRetryable(output) {
  return retryablePatterns.some((pattern) => output.includes(pattern));
}

for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
  console.log(`Running Prisma migrate deploy (attempt ${attempt}/${maxAttempts})`);
  const result = await runPrismaDeploy();

  if (result.code === 0) {
    process.exit(0);
  }

  if (!isRetryable(result.output) || attempt === maxAttempts) {
    process.exit(result.code || 1);
  }

  const delayMs = Math.min(initialDelayMs * 2 ** (attempt - 1), maxDelayMs);
  console.warn(`Database is not reachable yet. Retrying migration deploy in ${Math.round(delayMs / 1000)}s...`);
  await wait(delayMs);
}
