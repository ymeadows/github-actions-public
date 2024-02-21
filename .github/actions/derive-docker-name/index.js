const core = require('@actions/core');
const github = require('@actions/github');

const repositoryNameSeparator = "/";
const stepRepoNamePrefix = "step-";
const emptyString = "";


try {
    let repoName = core.getInput('repo-name');
    if(!repoName) {
        repoName = github.context.payload.repository.name;
    }
    if(repoName.includes(repositoryNameSeparator)) {
        repoName = repoName.split(repositoryNameSeparator)[1];
    }
    core.info(`Repo Name is ${repoName}`);
    const dockerImageName = repoName.replace(stepRepoNamePrefix, emptyString);
    core.info(`Docker Image Name is ${dockerImageName}`);
    core.setOutput("docker-name", dockerImageName);
} catch (error) {
    core.setFailed(error.message);
}
