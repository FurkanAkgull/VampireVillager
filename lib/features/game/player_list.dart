import 'package:flutter/material.dart';

import '../../core/constants/role_visuals.dart';
import '../../models/player.dart';
import '../../widgets/widgets.dart';

/// Scrollable player roster. Also used in "target" mode by [ActionPanel]:
/// pass a non-null [selectable] to make alive, non-self players tappable.
class PlayerList extends StatelessWidget {
  final List<PlayerInfo> players;
  final String? myPlayerId;
  final String? selectable; // if non-null: "target" mode, tapping calls onSelect
  final String? selectedId;
  final void Function(String playerId)? onSelect;

  const PlayerList({
    super.key,
    required this.players,
    required this.myPlayerId,
    this.selectable,
    this.selectedId,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: players.length,
      itemBuilder: (context, i) {
        final p = players[i];
        final isMe = p.playerId == myPlayerId;
        final canTarget = selectable != null && p.alive && !isMe;
        final selected = p.playerId == selectedId;

        // Role is only shown when the server actually revealed it (self or dead).
        final revealed = RoleVisuals.isRevealed(p.role);
        final visual = revealed ? RoleVisuals.of(p.role) : null;

        return GamePlayerCard(
          nickname: p.nickname,
          isMe: isMe,
          isHost: p.isHost,
          alive: p.alive,
          connected: p.connected,
          selectable: selectable != null,
          selected: selected,
          onTap: canTarget ? () => onSelect?.call(p.playerId) : null,
          roleLabel: visual?.displayNameTr,
          accentColor: visual?.color,
        );
      },
    );
  }
}
