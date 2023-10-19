const core = require('@actions/core');
const github = require('@actions/github');

try {
    let repoName = core.getInput('repo-name');
    if(!repoName) {
        repoName = github.context.payload.repository.name;
    }
    repoName = repoName.split("/")[1];
    let organization = core.getInput('organization');
    let sonarToken = core.getInput('sonar-token');
    core.setSecret(sonarToken);
    const searchResponse = await fetch(`https://sonarcloud.io/api/projects/search?organization=${organization}&q=${repoName}`, {
        method: 'GET',
        headers: {
            "Accept": "application/json",
            "Authorization": `Bearer ${sonarToken}`
        }
    });
    if(searchResponse.status !== 200) {
        const searchResponseBodyText = await searchResponse.text();
        const searchResponseHeaders = searchResponse.headers;
        const logMessage = `Failed to search for existing SonarCloud project ${repoName} in ${organization}: ${searchResponse.status} ${searchResponseBodyText} ${searchResponseHeaders}`;
        core.error(logMessage);
        core.setFailed(logMessage);
        return;
    }
    const searchResponseJson = await searchResponse.json();
    if(searchResponseJson.paging.total > 0) {
        core.debug(`SonarCloud project ${repoName} already exists in ${organization}`);
        return;
    }
    const response = await fetch('https://sonarcloud.io/api/projects/create', {
        method: 'POST',
        body: JSON.stringify({name: repoName, project: `${organization}_${repoName}`, organization: organization}),
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${sonarToken}`
        }
    });
    if (response.status / 100 !== 2) {
        const responseBodyText = await response.text();
        const responseHeaders = response.headers;
        const logMessage = `Failed to create SonarCloud project ${repoName} in ${organization}: ${response.status} ${responseBodyText} ${responseHeaders}`;
        core.error(logMessage);
        core.setFailed(logMessage);
        return;
    }
    const responseJson = await response.json();
    core.setOutput("key", responseJson.project.key);
    core.info(`SonarCloud project ${repoName} created in ${organization}`);
    return;
} catch (error) {
    core.setFailed(error.message);
}
