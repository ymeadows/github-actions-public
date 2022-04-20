const core = require('@actions/core');
const github = require('@actions/github');

try {
    console.log(github.repository);
    console.log(github.repository.split("/")[1]);
    const repoName = github.context.payload.repository.name;
    console.log(`repoName: ${repoName}`);
    const dockerImageName = repoName.replace("step-", "");
    console.log(`docker-name: ${dockerImageName}`);
    core.setOutput("docker-name", dockerImageName);
} catch (error) {
    core.setFailed(error.message);
}
