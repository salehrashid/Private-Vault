import 'dart:async';
import 'dart:io';

class InternetConnectionService {
  InternetConnectionService({
    Duration checkInterval = const Duration(seconds: 15),
    Duration timeout = const Duration(seconds: 3),
    List<String> hosts = const [
      'firebase.googleapis.com',
      'identitytoolkit.googleapis.com',
    ],
  }) : _checkInterval = checkInterval,
       _timeout = timeout,
       _hosts = hosts;

  final Duration _checkInterval;
  final Duration _timeout;
  final List<String> _hosts;
  final _controller = StreamController<bool>.broadcast();

  Timer? _timer;
  bool? _lastStatus;
  Future<bool>? _activeCheck;

  Stream<bool> get status async* {
    yield await checkNow();
    _timer ??= Timer.periodic(_checkInterval, (_) => checkNow());
    yield* _controller.stream.distinct();
  }

  bool get isOnline => _lastStatus ?? true;

  Future<bool> checkNow() {
    final running = _activeCheck;
    if (running != null) {
      return running;
    }

    final check = _probe()
        .then((online) {
          if (_lastStatus != online) {
            _lastStatus = online;
            _controller.add(online);
          } else {
            _lastStatus = online;
          }
          return online;
        })
        .whenComplete(() {
          _activeCheck = null;
        });

    _activeCheck = check;
    return check;
  }

  Future<bool> _probe() async {
    for (final host in _hosts) {
      try {
        final result = await InternetAddress.lookup(host).timeout(_timeout);
        if (result.any((address) => address.rawAddress.isNotEmpty)) {
          return true;
        }
      } on Object {
        // Try the next Firebase host before reporting offline.
      }
    }
    return false;
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
