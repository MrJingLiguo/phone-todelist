import 'package:flutter/material.dart';

/// 底部大麦克风按钮：点击开始/停止语音录入。
class MicButton extends StatelessWidget {
  final bool listening;
  final bool loading;
  final VoidCallback onTap;

  const MicButton({
    super.key,
    required this.listening,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = listening ? 78.0 : 68.0;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: listening ? scheme.errorContainer : scheme.primaryContainer,
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                listening ? Icons.stop_rounded : Icons.mic,
                size: 32,
                color: listening ? scheme.onErrorContainer : scheme.onPrimaryContainer,
              ),
      ),
    );
  }
}
