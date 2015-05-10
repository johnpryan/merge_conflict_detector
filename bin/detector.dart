import "dart:io";
import "dart:async";
import "dart:convert";
import "package:args/args.dart";
import "package:git/git.dart";
import "package:github/server.dart";

class Configuration {
  String authToken;
  String accountName;
  String repoName;
}

/// Given a github repository, finds all open PRs, and attempts to merge
/// each PR.  If there are any merge conflicts, returns the previous
/// successful branch that was merged, and the branch that caused the
/// merge conflict.
main(List<String> args) async {
  var config = await getConfiguration(args);
  var githubClient = createGitHubClient(auth: new Authentication.withToken(config.authToken));
  githubClient.pullRequests.list(new RepositorySlug(config.accountName, config.repoName)).listen((pr) {
    print(pr);
  });
}

/// exits if incorrect arguments were given
Future<Configuration> getConfiguration(List<String> args) async {
  var parser = new ArgParser();
  var results = parser.parse(args);
  if (results.rest.length != 2) {
    print('Usage: detector [github account] [repository]');
    exit(1);
  }
  return new Configuration()
    ..accountName = results.rest[0]
    ..repoName = results.rest[1]
    ..authToken = await getAuthToken();
}

/// Attempts to read .merge_conflict_detector_config in the user's home
/// directory.  If none exists, prompts the user for a github API key
/// and creates a config file.
Future<String> getAuthToken() async {
  var homeDir = Platform.environment['HOME'];
  var configFile = new File('$homeDir/.merge_conflict_detector_config');
  if (await configFile.exists())
    return configFile.readAsString();
  print('no config file found.  Enter your github auth token:');
  var authToken = stdin.readLineSync();
  configFile.writeAsString(authToken);
}
