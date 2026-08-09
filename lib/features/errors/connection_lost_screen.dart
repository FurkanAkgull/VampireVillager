import 'package:flutter/material.dart';

import '../../core/constants/app_theme.dart';
import '../../widgets/widgets.dart';

/// Shown when the websocket drops unexpectedly (design doc §23).
///
/// Reconnecting re-fetches the authoritative snapshot from the server; the
/// client never keeps playing on a stale local state.
class ConnectionLostScreen extends StatelessWidget {
  final VoidCallback onRetry;

  /// True while a reconnect attempt is in flight.
  final bool retrying;

  const ConnectionLostScreen({
    super.key,
    required this.onRetry,
    this.retrying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: retrying
          ? const GameLoading(label: 'Sunucuya yeniden bağlanılıyor...')
          : GameError(
              icon: Icons.wifi_off_rounded,
              title: 'BAĞLANTI KOPTU',
              message: 'Sunucuya yeniden bağlanılıyor...',
              retryLabelTr: 'Tekrar Dene',
              onRetry: onRetry,
            ),
    );
  }
}
