const core = require('@actions/core');
const github = require('@actions/github');

try {
    const payload = JSON.stringify(github.context.payload, undefined, 2)
    console.log(`The event payload: ${payload}`);
    const repoName = github.context.payload.repository.name;
    console.log(`repoName: ${repoName}`);
    const dockerImageName = repoName.replace("step-", "");
    console.log(`dockerImageName: ${dockerImageName}`);
    core.setOutput("docker-name", dockerImageName);
} catch (error) {
    core.setFailed(error.message);
}
