import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';

/// Thin ticking wrapper around [GamePhaseHeader].
///
/// The server owns the phase deadline ([endsAt], epoch seconds, spec §11); this
/// widget only re-renders the remaining time once per second and never changes
/// phase on its own.
class PhaseTimer extends StatefulWidget {
  final String phase;
  final int round;
  final double? endsAt; // epoch seconds, server-authoritative (spec §11)

  /// Phase start, epoch seconds, also server-authoritative. Only used to derive
  /// the total phase length for the progress ring; null keeps the text-only
  /// timer.
  final double? startedAt;

  /// Already-localized "what do I do now?" line (design rule 29).
  final String? instructionTr;

  const PhaseTimer({
    super.key,
    required this.phase,
    required this.round,
    required this.endsAt,
    this.startedAt,
    this.instructionTr,
  });

  @override
  State<PhaseTimer> createState() => _PhaseTimerState();
}

class _PhaseTimerState extends State<PhaseTimer> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant PhaseTimer old) {
    super.didUpdateWidget(old);
    _tick();
  }

  void _tick() {
    if (widget.endsAt == null) return;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch / 1000;
    final remainingSeconds = widget.endsAt! - nowSeconds;
    final next = Duration(seconds: remainingSeconds.clamp(0, 1 << 30).round());
    if (next == _remaining) return;
    setState(() => _remaining = next);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Full phase length as the server defined it. Null (or non-positive) means
  /// no ring is drawn.
  Duration? get _total {
    final start = widget.startedAt;
    final end = widget.endsAt;
    if (start == null || end == null) return null;
    final seconds = end - start;
    if (seconds <= 0) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  @override
  Widget build(BuildContext context) {
    return GamePhaseHeader(
      phase: widget.phase,
      round: widget.round,
      remaining: _remaining,
      total: _total,
      instructionTr: widget.instructionTr,
    );
  }
}
