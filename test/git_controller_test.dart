import 'package:merge_conflict_detector/git_controller.dart';
import 'package:unittest/unittest.dart';

class MockGitController implements GitController {
  noSuchMethod(Invocation inv) {
    print('called ${inv.memberName}');
  }
}

main() {
  group('GitController', (){
    test('does stuff', () {
      var mockController = new MockGitController();
      print(mockController.getPrs());
    });
    test('more stuff', ()) {
    	// no-op
    }
  });
}