import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

test('test runs', () => {
    const ip = path.join(__dirname, 'dist', 'index.js');
    const env = {
        ...process.env,
        "INPUT_REPO-NAME": "ymeadows/step-test-name"
    }
    const result = execSync(`node ${ip}`, {env: env}).toString();
    expect(result).toContain("test-name");
});
