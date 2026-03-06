import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<ThemeProvider>().isDark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
      highlightColor: dark ? const Color(0xFF3A3A3C) : const Color(0xFFF2F2F7),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: 8,
        separatorBuilder: (_, __) =>
            Divider(color: dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA), height: 1, indent: 74),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7))),
                    const SizedBox(height: 8),
                    Container(height: 11, width: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ),
              Container(height: 30, width: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30))),
            ],
          ),
        ),
      ),
    );
  }
}
