const core = require('@actions/core');
const github = require('@actions/github');

try {
    const repoName = core.getInput('repo-name');
    const dockerImageName = repoName.replace("step-", "");
    core.info(`Docker Image Name is ${dockerImageName}`);
    core.setOutput("docker-name", dockerImageName);
} catch (error) {
    core.setFailed(error.message);
}
