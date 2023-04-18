const process = require('process');
const cp = require('child_process');
const path = require('path');

test('test runs', () => {
    process.env['INPUT_REPO-NAME'] = "ymeadowsstep-test-name";
    const ip = path.join(__dirname, 'index.js');
    const env = {
        "INPUT_REPO-NAME": "ymeadows/step-test-name"
    }
    const result = cp.execSync(`node ${ip}`, {env: env}).toString();
    expect(result).toContain("::set-output name=docker-name::test-name");
});