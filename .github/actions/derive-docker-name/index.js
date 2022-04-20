const core = require('@actions/core');
const github = require('@actions/github');

try {
    let repoName = core.getInput('repo-name');
    if(!repoName) {
        repoName = github.context.payload.repository.name;
    }
    repoName = repoName.split("/")[1];
    const dockerImageName = repoName.replace("step-", "");
    core.info(`Docker Image Name is ${dockerImageName}`);
    core.setOutput("docker-name", dockerImageName);
} catch (error) {
    core.setFailed(error.message);
}
