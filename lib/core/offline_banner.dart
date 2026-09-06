import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_provider.dart';

/// A widget that wraps its [child] and inserts an animated offline banner
/// at the top whenever the device loses internet connectivity.
///
/// Also shows a green "reconnected" snackbar once when coming back online.
class OfflineAwareScaffoldBody extends ConsumerStatefulWidget {
  final Widget child;

  const OfflineAwareScaffoldBody({super.key, required this.child});

  @override
  ConsumerState<OfflineAwareScaffoldBody> createState() =>
      _OfflineAwareScaffoldBodyState();
}

class _OfflineAwareScaffoldBodyState
    extends ConsumerState<OfflineAwareScaffoldBody>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _slideAnimation;
  bool? _lastOnlineState; // null = not yet determined

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleConnectivityChange(bool isOnlineNow) {
    if (_lastOnlineState == isOnlineNow) return; // no change, skip

    if (!isOnlineNow) {
      // Went offline — slide banner in
      _animCtrl.forward();
    } else if (_lastOnlineState == false) {
      // Came back online — slide banner out, show snackbar
      _animCtrl.reverse().then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.cloud_done_outlined, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('✅ ኔትወርኩ ተመለሰ — ውሂቡ ተመሳሰለ!'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      });
    }

    _lastOnlineState = isOnlineNow;
  }

  @override
  Widget build(BuildContext context) {
    final connectivityAsync = ref.watch(connectivityProvider);

    connectivityAsync.whenData((online) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleConnectivityChange(online);
      });
    });

    return Column(
      children: [
        // ── Animated offline banner ─────────────────────────────────────
        SizeTransition(
          sizeFactor: _slideAnimation,
          axisAlignment: -1.0,
          child: _OfflineBanner(),
        ),
        // ── Main content ────────────────────────────────────────────────
        Expanded(child: widget.child),
      ],
    );
  }
}

/// The visual offline banner widget.
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade800,
            Colors.amber.shade700,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.signal_wifi_connected_no_internet_4_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ኢንተርኔት ግንኙነት የለም',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'ለውጦች ሲገናኙ በራስ-ሰር ይሰናዳሉ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'ከCache',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
