import 'package:flutter/material.dart';

class ResonXWelcomeSetupDialog extends StatefulWidget {
  const ResonXWelcomeSetupDialog({super.key});

  @override
  State<ResonXWelcomeSetupDialog> createState() => _ResonXWelcomeSetupDialogState();
}

class _ResonXWelcomeSetupDialogState extends State<ResonXWelcomeSetupDialog> {
  int _currentStep = 0;
  bool _isInstalling = false;
  double _installProgress = 0.0;

  final List<String> changelogNotes = [
    'Wdrożono 30 funkcji klasy Enterprise (Equalizer 10-pasmowy, Reverb Studio, Audio 3D)',
    'Całkowicie wyeliminowano błąd bufora EOF i startu utworów od końca',
    'Dodano zsynchronizowane teksty karaoke LRCLIB z czyszczeniem tytułów',
    'Bezpieczna kompilacja z obfuskacją kodu maszynowego x64 i blokadą DevTools',
    'Obsługa lokalnych bibliotek audio FLAC / WAV / MP3 na Windows',
  ];

  void _startInstallation() async {
    setState(() {
      _isInstalling = true;
      _installProgress = 0.05;
    });

    for (int i = 1; i <= 20; i++) {
      await Future.delayed(const Duration(milliseconds: 70));
      if (mounted) {
        setState(() {
          _installProgress = i * 0.05;
        });
      }
    }

    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 720,
        height: 540,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1016),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF00F2FE).withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9B51E0).withOpacity(0.2),
              blurRadius: 35,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(0xFF00F2FE).withOpacity(0.12),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nagłówek w stylu logo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00F2FE), Color(0xFF9B51E0), Color(0xFF4A00E0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00F2FE).withOpacity(0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'R',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ResonX Setup & Hub',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'by ',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00F2FE), Color(0xFF9B51E0)],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Piter2020ja',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.discord, color: Color(0xFF5865F2), size: 16),
                            const SizedBox(width: 5),
                            const Text(
                              'discord: piter2020ja',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xFF00F2FE), Color(0xFF9B51E0), Colors.transparent],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Treść okna
            Expanded(
              child: _isInstalling
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Konfigurowanie silnika audio ResonX...',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _installProgress,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${(_installProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Color(0xFF00F2FE),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Wydanie hobbystyczne: Piter2020ja | Discord: piter2020ja',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    )
                  : _currentStep == 0
                      ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Witaj w ResonX Ultimate Player',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Niezależny odtwarzacz muzyczny high-definition z autorskim silnikiem DSP, karaoke LRCLIB oraz integracją z systemem Windows.',
                                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'NAJWAŻNIEJSZE NOWOŚCI:',
                                style: TextStyle(
                                  color: Color(0xFF00F2FE),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...changelogNotes.map(
                                (note) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle_outline, color: Color(0xFF9B51E0), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          note,
                                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Warunki Hobbystyczne & Użytkowania',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 210,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: const SingleChildScrollView(
                                child: Text(
                                  '1. ResonX to projekt hobbystyczny stworzony przez Piter2020ja na licencji niekomercyjnej.\n\n'
                                  '2. Aplikacja nie zbiera żadnych prywatnych danych i jest w 100% bezpłatna.\n\n'
                                  '3. Wszystkie strumienie audio oraz teksty LRCLIB są pobierane wyłącznie na użytek osobisty użytkownika.\n\n'
                                  '4. Kontakt z twórcą i zgłaszanie uwag: Discord: piter2020ja.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.6),
                                ),
                              ),
                            ),
                          ],
                        ),
            ),

            const SizedBox(height: 16),
            // Dolny pasek akcji
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_isInstalling && _currentStep > 0)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => setState(() => _currentStep--),
                    child: const Text('Wstecz', style: TextStyle(color: Colors.white)),
                  )
                else
                  const Text(
                    'ResonX v2.4 Enterprise',
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                Row(
                  children: [
                    if (!_isInstalling)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Pomiń', style: TextStyle(color: Colors.white60)),
                      ),
                    const SizedBox(width: 12),
                    if (!_isInstalling)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ).copyWith(
                          elevation: ButtonStyleButton.allOrNull(0.0),
                        ),
                        onPressed: () {
                          if (_currentStep == 0) {
                            setState(() => _currentStep = 1);
                          } else {
                            _startInstallation();
                          }
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00F2FE), Color(0xFF9B51E0)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Text(
                              _currentStep == 0 ? 'Dalej' : 'Akceptuj i Rozpocznij',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}