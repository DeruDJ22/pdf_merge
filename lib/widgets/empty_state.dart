import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final VoidCallback onReadPdfPressed;
  final VoidCallback onMergePdfPressed;

  const EmptyState({
    super.key,
    required this.onReadPdfPressed,
    required this.onMergePdfPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 20,
            vertical: isDesktop ? 40 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Manajemen Dokumen PDF',
                    style: TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pilih tindakan untuk membuka, membaca, atau menggabungkan file dokumen.',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            context: context,
                            title: 'Buka & Baca PDF',
                            subtitle: 'Buka satu atau beberapa file PDF sekaligus dengan penampil dokumen vertikal halus.',
                            tag: 'Penampil PDF',
                            accentColor: const Color(0xFF4F46E5),
                            icon: Icons.menu_book_rounded,
                            buttonText: 'Pilih File PDF',
                            onTap: onReadPdfPressed,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildActionCard(
                            context: context,
                            title: 'Gabungkan PDF',
                            subtitle: 'Pilih beberapa file PDF dan atur urutan halaman untuk digabungkan menjadi satu file.',
                            tag: 'Penggabung',
                            accentColor: const Color(0xFF059669),
                            icon: Icons.call_merge_rounded,
                            buttonText: 'Mulai Gabung File',
                            onTap: onMergePdfPressed,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildActionCard(
                      context: context,
                      title: 'Buka & Baca PDF',
                      subtitle: 'Buka satu atau beberapa file PDF sekaligus dengan penampil dokumen vertikal halus.',
                      tag: 'Penampil PDF',
                      accentColor: const Color(0xFF4F46E5),
                      icon: Icons.menu_book_rounded,
                      buttonText: 'Pilih File PDF',
                      onTap: onReadPdfPressed,
                    ),
                    const SizedBox(height: 16),
                    _buildActionCard(
                      context: context,
                      title: 'Gabungkan PDF',
                      subtitle: 'Pilih beberapa file PDF dan atur urutan halaman untuk digabungkan menjadi satu file.',
                      tag: 'Penggabung',
                      accentColor: const Color(0xFF059669),
                      icon: Icons.call_merge_rounded,
                      buttonText: 'Mulai Gabung File',
                      onTap: onMergePdfPressed,
                    ),
                  ],

                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151B26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF222B3D),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Semua proses penggabungan dan pembacaan berjalan secara lokal di perangkat tanpa koneksi internet.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String tag,
    required Color accentColor,
    required IconData icon,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151B26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF222B3D),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2533),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF2D3748),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
