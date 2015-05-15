import "dart:io";
import "dart:async";
import "dart:convert";
import "dart:math" show min;
import "package:args/args.dart";
import "package:github/server.dart";
import 'package:collection/equality.dart';

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

class Pair<T> {
  Set<T> _set = new Set<T>();
  Pair(T a, T b) {
    _set
      ..add(a)
      ..add(b);
  }
  bool operator ==(T o) => new SetEquality().equals(_set, o._set);
  int get hashCode => new SetEquality().hash(_set);
  T get first => _set.elementAt(0);
  T get second => _set.elementAt(1);
}


detectConflicts(List<PullRequest> pullRequests, String localRepoPath) async {
  var alreadyTested = new Set<Pair<PullRequest>>();
  var conflicts = new Set<Pair<PullRequest>>();
  var maxPrs = 100;
  for (var i = 0; i < min(pullRequests.length, maxPrs); i++) {
    for (var j = 0; j < min(pullRequests.length, maxPrs); j++) {
      var pr1 = pullRequests[i];
      var pr2 = pullRequests[j];
      var pair = new Pair(pr1,pr2);
      if(pr1 != pr2 && !alreadyTested.contains(pair)) {
        var canMerge = await attemptMerge(pr1, pr2, localRepoPath);
        alreadyTested.add(pair);
        if (!canMerge) {
          conflicts.add(pair);
        }
      }
    }
  }
  // generate a adjency list
  Map<List<String>> aList = {};
  conflicts.forEach((Pair<PullRequest> pair) {
    var al = aList as Map<List<String>>;
    if(!al.containsKey(pair.first.base.ref)) {
      al[pair.first.base.ref] = [];
    }
    (al[pair.first.base.ref] as List).add(pair.second.base.ref);

    if(!al.containsKey(pair.second.base.ref)) {
      al[pair.second.base.ref] = [];
    }
    (al[pair.second.base.ref] as List).add(pair.first.base.ref);
  });

  // add any prs we didn't include
  alreadyTested.forEach((Pair<PullRequest> pair) {
    var al = aList as Map<List<String>>;
    if(!al.containsKey(pair.first.base.ref)) {
      al[pair.first.base.ref] = [];
    }
    if(!al.containsKey(pair.second.base.ref)) {
      al[pair.second.base.ref] = [];
    }
  });
  print(JSON.encode(aList));
}

Future<bool> attemptMerge(PullRequest pr1, PullRequest pr2, String repoPath) async {
  await addRemote(pr1, repoPath);
  await addRemote(pr2, repoPath);
  await fetchRemote(pr1, repoPath);
  await fetchRemote(pr2, repoPath);
  await checkoutBranch(pr1, repoPath);
  ProcessResult mergeResult = await mergeBranch(pr2, repoPath);
  ProcessResult deleted = await Process.run('git', ['branch', '-D', tempBranchName(pr1)], workingDirectory: repoPath);
  if (mergeResult.exitCode != 0) {
    print('FAILURE ${simpleName(pr2)} => ${simpleName(pr1)}');
    return false;
  } else {
    print('SUCCESS ${simpleName(pr2)} => ${simpleName(pr1)}');
    return true;
  }
}

Future addRemote(PullRequest pr, String repoPath) async {
  var args = ['remote', 'add', remoteName(pr), remoteUrl(pr)];
  await Process.run('git', args, workingDirectory: repoPath);
}
String simpleName(PullRequest pr) => '${pr.base.user.login}/${pr.base.ref}';
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
  await Process.run('git', ['reset', '--hard'], workingDirectory: repoPath);
  await Process.run('git', ['checkout', 'master'], workingDirectory: repoPath);
  return result;
}