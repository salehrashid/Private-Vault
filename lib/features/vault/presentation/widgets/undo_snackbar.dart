import 'package:circular_countdown_timer/circular_countdown_timer.dart';
import 'package:flutter/material.dart';

SnackBar buildUndoSnackBar({
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 4),
}) {
  return SnackBar(
    content: _AnimatedUndoContent(message: message, duration: duration),
    duration: duration,
    behavior: SnackBarBehavior.floating,
    action: SnackBarAction(
      label: 'Undo',
      onPressed: onUndo,
    ),
  );
}

class _AnimatedUndoContent extends StatelessWidget {
  const _AnimatedUndoContent({
    required this.message,
    required this.duration,
  });

  final String message;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularCountDownTimer(
          duration: duration.inSeconds,
          initialDuration: 0,
          controller: CountDownController(),
          width: 24,
          height: 24,
          ringColor: Theme.of(context).colorScheme.inversePrimary.withValues(alpha: 0.2),
          ringGradient: null,
          fillColor: Theme.of(context).colorScheme.inversePrimary,
          fillGradient: null,
          backgroundColor: Colors.transparent,
          backgroundGradient: null,
          strokeWidth: 3.0,
          strokeCap: StrokeCap.round,
          textStyle: TextStyle(
            fontSize: 10.0,
            color: Theme.of(context).colorScheme.inversePrimary,
            fontWeight: FontWeight.bold,
          ),
          textFormat: CountdownTextFormat.S,
          isReverse: true,
          isReverseAnimation: true,
          isTimerTextShown: true,
          autoStart: true,
          onStart: () {},
          onComplete: () {},
          onChange: (String timeStamp) {},
          timeFormatterFunction: (defaultFormatterFunction, duration) {
            return Function.apply(defaultFormatterFunction, [duration]);
          },
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    );
  }
}
