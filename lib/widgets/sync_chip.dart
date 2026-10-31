import 'dart:async';
import 'emoji_icons.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/run_saver.dart';
import 'block_ui.dart';

/// "1 RUN WAITING TO SYNC". Appears only while runs sit in the offline
/// outbox. Tap to try sending them now. Disappears by itself when empty.
class SyncChip extends StatefulWidget {
  const SyncChip({super.key});

  @override
  State<SyncChip> createState() => _SyncChipState();
}

class _SyncChipState extends State<SyncChip> {
  bool _busy = false;
  Timer? _retryT;

  @override
  void initState() {
    super.initState();
    RunOutbox.refresh();
    // quiet automatic retry while something is waiting
    _retryT = Timer.periodic(const Duration(seconds: 45), (_) {
      if (RunOutbox.pending.value > 0 && !_busy) _sync(silent: true);
    });
  }

  @override
  void dispose() {
    _retryT?.cancel();
    super.dispose();
  }

  Future<void> _sync({bool silent = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _busy) return;
    if (!silent) setState(() => _busy = true);
    try {
      await RunOutbox.flush(uid);
    } finally {
      if (mounted && !silent) setState(() => _busy = false);
    }
  }

  /// Tap on the chip: a window that explains what is waiting and why.
  void _open() {
    showDialog<void>(
      context: context,
      builder: (_) => const _SyncDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RunOutbox.pending,
      builder: (_, n, __) {
        if (n <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PressBlock(
            color: const Color(0xFF6B7078),
            edge: const Color(0xFF1B1D20),
            depth: 4,
            radius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onTap: _busy ? null : _open,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: BlockText(
                          _busy
                              ? '\u{1F4E1} SYNCING...'
                              : '\u{1F4E1} $n RUN${n == 1 ? '' : 'S'} WAITING TO SYNC • TAP FOR DETAILS',
                          size: 11,
                          stroke: 3,
                          align: TextAlign.center,
                        ),
                      ),
                      ValueListenableBuilder<String?>(
                        valueListenable: RunOutbox.lastError,
                        builder: (_, err, __) => err == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  err,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFFFFD7CF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SyncDialog extends StatefulWidget {
  const _SyncDialog();

  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  bool _busy = false;
  String? _result;

  Future<void> _syncNow() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _busy) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    RunOutbox.notes.value = const [];
    var sent = 0;
    try {
      sent = await RunOutbox.flush(uid);
    } catch (_) {}
    if (!mounted) return;
    final left = RunOutbox.pending.value;
    setState(() {
      _busy = false;
      _result = left == 0
          ? 'All done! ${sent > 0 ? '$sent run${sent == 1 ? '' : 's'} saved.' : ''}'
          : '${sent > 0 ? '$sent saved, ' : ''}$left still waiting.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Block(
        color: Rb.slate,
        edge: Colors.black,
        depth: 8,
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<int>(
          valueListenable: RunOutbox.pending,
          builder: (_, n, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmojiText('\u{1F4E1}', style: TextStyle(fontSize: 38)),
              const SizedBox(height: 4),
              BlockText(
                  n == 0
                      ? 'EVERYTHING IS SYNCED'
                      : '$n RUN${n == 1 ? '' : 'S'} WAITING TO SYNC',
                  size: 18,
                  stroke: 4.5,
                  align: TextAlign.center),
              const SizedBox(height: 8),
              if (n > 0)
                const BlockText(
                    'These runs are safe on this phone / in your account, '
                    'but not counted yet (XP, coins, leaderboard).',
                    size: 11,
                    stroke: 2.5,
                    align: TextAlign.center),
              ValueListenableBuilder<String?>(
                valueListenable: RunOutbox.lastError,
                builder: (_, err, __) => err == null || n == 0
                    ? const SizedBox.shrink()
                    : Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A2020),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Text(RunSaver.friendly(err),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFFFFD7CF),
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ),
              ),
              ValueListenableBuilder<List<String>>(
                valueListenable: RunOutbox.notes,
                builder: (_, notes, __) => notes.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(children: [
                          for (final t in notes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text('\u2022 $t',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Color(0xFFD3D5D7),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ]),
                      ),
              ),
              if (_result != null) ...[
                const SizedBox(height: 10),
                BlockText(_result!,
                    size: 13, stroke: 3, color: Rb.neon, align: TextAlign.center),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: PressBlock(
                    color: const Color(0xFF6B7078),
                    edge: const Color(0xFF1B1D20),
                    depth: 5,
                    radius: 12,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onTap: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Center(child: BlockText('CLOSE', size: 14, stroke: 3.5)),
                  ),
                ),
                if (n > 0) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: PressBlock(
                      color: Rb.green,
                      edge: Rb.greenEdge,
                      depth: 5,
                      radius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onTap: _busy ? null : _syncNow,
                      child: Center(
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 3, color: Colors.white))
                            : const BlockText('SYNC NOW', size: 14, stroke: 3.5),
                      ),
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
