import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/navigation/go_router_pop.dart';
import '../../../core/widgets/clinova_backdrop.dart';
import '../../auth/application/auth_controller.dart';

const _navy = Color(0xFF071B4D);
const _primaryBlue = Color(0xFF1769FF);
const _muted = Color(0xFF64748B);
const _cardBorder = Color(0xFFE6EEF8);

/// Non-diagnostic emergency info; directs user to professional urgent care / 103.
class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  Future<void> _call103(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: '103');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Утасны дугаар руу залгах боломжгүй байна.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final fallback = clinovaNavigationFallback(
      isAuthenticated: auth.isAuthenticated,
      role: auth.user?.role,
    );

    return Scaffold(
      body: ClinovaBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => popOrGo(context, fallback),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Яаралтай тусламж',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: _navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Амь нас, эрүүл мэндэд ноцтой нөхцөл байвал шууд мэргэжлийн тусламж аваарай.',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: const Color(0xFF991B1B),
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Жишээ нь: хүчтэй цээжний өвдөлт, амьсгал давхцах, их хэмжээний цус гарах, инсультын шинж, ухаан алдах, жирэмсний хүнд хэлбэрийн шинж.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7F1D1D),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Монгол Улсын яаралтай тусламжийн нэгдсэн дугаар — 103.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _navy,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Clinova апп нь яаралтай тусламжийн үйлчилгээ биш. Энэ хуудсыг зөвхөн чиглүүлэх зорилгоор харуулж байна.',
                style: theme.textTheme.bodySmall?.copyWith(color: _muted, height: 1.45),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _call103(context),
                child: const Text('103 руу залгах'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryBlue,
                  side: const BorderSide(color: _cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => popOrGo(context, fallback),
                child: const Text('Буцах'),
              ),
              const SizedBox(height: 20),
              Text(
                'Clinova AI нь онош тавихгүй. Эмчийн үзлэг, эмчилгээний шийдвэрийг зөвхөн мэргэжлийн эмч гаргана.',
                style: theme.textTheme.bodySmall?.copyWith(color: _muted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
