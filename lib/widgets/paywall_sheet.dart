import 'package:flutter/material.dart';

// Función global para mostrar el paywall desde cualquier pantalla
Future<bool> mostrarDialogoPremium(BuildContext context) async {
  final resultado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PremiumSheet(),
  );
  return resultado == true;
}

class PremiumSheet extends StatefulWidget {
  const PremiumSheet({super.key});

  @override
  State<PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends State<PremiumSheet> {
  // 0 = mensual, 1 = anual (pre-seleccionado por defecto)
  int _planSeleccionado = 1;

  @override
  Widget build(BuildContext context) {
    final btnText = _planSeleccionado == 0
        ? 'Suscribirme por S/. 4/mes'
        : 'Suscribirme por S/. 29/año';

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
      child: SingleChildScrollView(
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE85D3A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('✦',
                    style: TextStyle(fontSize: 28, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('QuizDeck Premium',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Desbloquea todo el potencial de QuizDeck',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF7A7770))),
            const SizedBox(height: 20),
            // Lista de beneficios
            ...[
              '✦ Mazos ilimitados',
              '✦ Estudio ilimitado por día',
              '✦ Sincroniza tus mazos en la nube ☁️',
              '✦ Publica y comparte con la comunidad',
              '✦ Multi-mazo: estudia varios a la vez',
              '✦ Duelos con amigos',
              '✦ Sin anuncios',
            ].map((beneficio) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Text(beneficio,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF3A3832))),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
            // Cards de planes
            Row(
              children: [
                // Plan mensual
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _planSeleccionado = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _planSeleccionado == 0
                              ? const Color(0xFFE85D3A)
                              : const Color(0xFFE4E0D6),
                          width: _planSeleccionado == 0 ? 2 : 1,
                        ),
                        color: _planSeleccionado == 0
                            ? const Color(0xFFFFF8F6)
                            : Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Mensual',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3A3832))),
                          SizedBox(height: 4),
                          Text('S/. 4',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F0E0C))),
                          Text('/mes',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF7A7770))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Plan anual
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _planSeleccionado = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _planSeleccionado == 1
                              ? const Color(0xFFE85D3A)
                              : const Color(0xFFE4E0D6),
                          width: _planSeleccionado == 1 ? 2 : 1,
                        ),
                        color: _planSeleccionado == 1
                            ? const Color(0xFFFFF8F6)
                            : Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Anual',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3A3832))),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF7F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Ahorra 40%',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2D9E6B))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('S/. 29',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F0E0C))),
                          const Text('/año',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF7A7770))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Botón CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Pago próximamente disponible')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85D3A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(btnText,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Función próximamente disponible')),
                );
              },
              child: const Text('Restaurar compra',
                  style: TextStyle(fontSize: 13, color: Color(0xFF7A7770))),
            ),
          ],
        ),
      ),
    );
  }
}
