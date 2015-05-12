import "dart:io";
import "dart:async";
import "dart:convert";
import "package:args/args.dart";
import "package:git/git.dart";
import "package:github/server.dart";

class Configuration {
  String authToken;
  String originAccountName;
  String repoName;
  String localRepoPath;
}

RepositorySlug makeRepoSlug(Configuration config) =>
new RepositorySlug(config.originAccountName, config.repoName);

/// Given a github repository, finds all open PRs, and attempts to merge
/// each PR.  If there are any merge conflicts, returns the previous
/// successful branch that was merged, and the branch that caused the
/// merge conflict.
main(List<String> args) async {
  Configuration config = await getConfiguration(args);
  var auth = new Authentication.withToken(config.authToken);
  var githubClient = createGitHubClient(auth: auth);

  // make a list of pull requests
  var pullRequestStream = githubClient.pullRequests.list(makeRepoSlug(config));
  var pullRequestList = await pullRequestStream.toList();

  await detectConflicts(pullRequestList, config.localRepoPath);
  exit(0);
}

/// exits if incorrect arguments were given
Future<Configuration> getConfiguration(List<String> args) async {
  var parser = new ArgParser();
  var results = parser.parse(args);
  if (results.rest.length != 3) {
    print('Usage: detector [github account] [repository] [local repo path]');
    exit(1);
  }
  return new Configuration()
    ..originAccountName = results.rest[0]
    ..repoName = results.rest[1]
    ..authToken = await getAuthToken()
    ..localRepoPath = results.rest[2];
}

/// Attempts to read .merge_conflict_detector_config in the user's home
/// directory.  If none exists, prompts the user for a github API key
/// and creates a config file.
Future<String> getAuthToken() async {
  var homeDir = Platform.environment['HOME'];
  var configFile = new File('$homeDir/.merge_conflict_detector_config');
  if (await configFile.exists()) return configFile.readAsString();

  print('no config file found.  Enter your github auth token:');
  var authToken = stdin.readLineSync();
  configFile.writeAsString(authToken);
  return authToken;
}

detectConflicts(List<PullRequest> pullRequests, String localRepoPath) async {
//  pullRequests.forEach((PullRequest pr) {
//    print("""
//      PR title: ${pr.title}
//      Github Repo User: ${pr.base.user.login}
//      Github Repo: ${pr.base.repo.name}
//      branch name: ${pr.base.ref}
//    """);
//  });
  await attemptMerge(pullRequests[0], pullRequests[1], localRepoPath);
}

attemptMerge(PullRequest pr1, PullRequest pr2, String repoPath) async {
  await addRemote(pr1, repoPath);
  await addRemote(pr2, repoPath);
  await fetchRemote(pr1, repoPath);
  await fetchRemote(pr2, repoPath);
  await checkoutBranch(pr1, repoPath);
  await mergeBranch(pr2, repoPath);
//  print('${pr1.base.user.login}/${pr1.base.ref} <= ${pr2.base.user.login}/${pr2.base.ref}');
}

Future addRemote(PullRequest pr, String repoPath) async {
  var args = ['remote', 'add', remoteName(pr), remoteUrl(pr)];
  await Process.run('git', args, workingDirectory: repoPath);
}
String remoteName(PullRequest pr) => 'merge_conflict_detector/${pr.base.user.login}';
String remoteUrl(PullRequest pr) => pr.base.repo.cloneUrls.ssh;
String remoteBranchName(PullRequest pr) => 'remotes/${remoteName(pr)}/${pr.base.ref}';
String tempBranchName(PullRequest pr) => 'merge_conflict_detector/${pr.base.user.login}/${pr.base.ref}';

Future fetchRemote(PullRequest pr, String repoPath) async {
  var args = ['fetch', remoteName(pr)];
  await Process.run('git', args, workingDirectory: repoPath);
}

Future checkoutBranch(PullRequest pr, String repoPath) async {
  var args = ['checkout', remoteBranchName(pr)];
  await Process.run('git', args, workingDirectory: repoPath);
  var args2 = ['checkout', '-b', tempBranchName(pr)];
  await Process.run('git', args2, workingDirectory: repoPath);
}

Future<ProcessResult> mergeBranch(PullRequest pr, String repoPath) async {
  var args = ['merge', '--no-commit', '--no-ff', remoteBranchName(pr)];
  ProcessResult result = await Process.run('git', args, workingDirectory: repoPath);
  print('merged? ${result.stdout}');
  print('merge error? ${result.stderr}');
  print('exit code: ${result.exitCode}');
  await Process.run('git', ['reset', '--hard'], workingDirectory: repoPath);
  await Process.run('git', ['checkout', 'master'], workingDirectory: repoPath);
  return result;
}