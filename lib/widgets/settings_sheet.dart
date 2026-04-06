import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'paywall_sheet.dart';

Future<void> mostrarConfiguracion(BuildContext context,
    {required bool esPremium}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SettingsSheet(esPremium: esPremium),
  );
}

class _SettingsSheet extends StatelessWidget {
  final bool esPremium;
  const _SettingsSheet({required this.esPremium});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nombre = user?.displayName ?? 'Estudiante';
    final email = user?.email ?? '';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE4E0D6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Avatar circular
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFE85D3A),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(inicial,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          Text(nombre,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(email,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF7A7770))),
          const SizedBox(height: 12),
          // Badge de plan
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: esPremium
                  ? const Color(0xFFEAF7F0)
                  : const Color(0xFFF0EDE6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              esPremium ? '✦ Premium' : 'Plan Gratis',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: esPremium
                      ? const Color(0xFF2D9E6B)
                      : const Color(0xFF7A7770)),
            ),
          ),
          const SizedBox(height: 16),
          if (!esPremium) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (context.mounted) {
                    await mostrarDialogoPremium(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85D3A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('✦ Hazte Premium',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Divider(color: Color(0xFFE4E0D6)),
          ListTile(
            leading: const Icon(Icons.logout,
                color: Color(0xFFE85D3A), size: 20),
            title: const Text('Cerrar sesión',
                style:
                    TextStyle(fontSize: 14, color: Color(0xFFE85D3A))),
            contentPadding: EdgeInsets.zero,
            onTap: () async {
              Navigator.pop(context);
              await GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut();
            },
          ),
          const SizedBox(height: 8),
          const Text('QuizDeck v1.0.0',
              style:
                  TextStyle(fontSize: 11, color: Color(0xFF7A7770))),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
