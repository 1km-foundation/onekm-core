import 'package:flutter/material.dart';

import 'retry.dart';

/// Offline banner driven by [ConnectivityStatus.stream]: collapses to
/// zero height while online, shows a Material error-colored strip while
/// offline. Place above the screen body (inside the Scaffold).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityStatus.stream,
      initialData: true,
      builder: (context, snap) {
        if (snap.data != false) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.error,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: const Text(
            'Offline — actions will retry when reconnected',
            style: TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
