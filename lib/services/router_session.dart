import '../models/router_models.dart';
import 'router_api.dart';

class RouterCredentials {
  const RouterCredentials(this.username, this.password);
  final String username;
  final String password;
}

/// Performs at most one re-login after an expired ubus session. The second
/// denial is an ACL problem, not a reason to retry forever.
class RouterSession {
  const RouterSession(this.api, this.readCredentials);

  final RouterApi api;
  final Future<RouterCredentials?> Function() readCredentials;

  Future<RouterSnapshot> fetch(RouterSection section,
      {RouterSnapshot? previous}) async {
    try {
      return await api.fetch(section: section, previous: previous);
    } on RouterSessionExpiredException {
      final credentials = await readCredentials();
      if (credentials == null) {
        throw const RouterApiException('会话已失效，请重新输入账号密码');
      }
      await api.login(credentials.username, credentials.password);
      try {
        return await api.fetch(section: section, previous: previous);
      } on RouterSessionExpiredException {
        throw const RouterAccessDeniedException();
      }
    }
  }
}
