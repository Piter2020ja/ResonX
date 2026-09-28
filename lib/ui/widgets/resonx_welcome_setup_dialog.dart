import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResonXWelcomeSetupDialog extends StatefulWidget {
  const ResonXWelcomeSetupDialog({super.key});

  @override
  State<ResonXWelcomeSetupDialog> createState() => _ResonXWelcomeSetupDialogState();
}

class _ResonXWelcomeSetupDialogState extends State<ResonXWelcomeSetupDialog>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isInstalling = false;
  double _installProgress = 0.0;
  String _installStatusText = 'Inicjalizacja silnika audio DirectSound...';

  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  final List<String> changelogNotes = [
    'Wdrożono 30 funkcji klasy Enterprise (Equalizer 10-pasmowy, Reverb Studio, Audio 3D)',
    'Inteligentne pomijanie ciszy na początku utworów oraz edytor punktów startu piosenek',
    'Zsynchronizowany tekst na żywo (Live LRCLIB Lyrics) ze wsparciem autoscrolla',
    'Pełny lokalny system zarządzania playlistami (tworzenie, usuwanie, zmiana kolejności)',
    'Prawdziwy silnik statystyk ResonX Wrapped działający w 100% lokalnie',
    'Wyeliminowano wszelkie błędy układu i paski overflow na urządzeniach mobilnych',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startInstallation() async {
    setState(() {
      _isInstalling = true;
      _installProgress = 0.05;
      _installStatusText = 'Inicjalizacja dekoderów FLAC / M4A / MP3...';
    });

    const statusUpdates = [
      'Inicjalizacja dekoderów FLAC / M4A / MP3...',
      'Konfigurowanie bufora wyjściowego audio DirectSound...',
      'Kalibracja 10-pasmowego korektora parametrycznego DSP...',
      'Ładowanie lokalnego silnika bazy danych SQLite i Playlist...',
      'Przygotowywanie profilu dźwiękowego ResonX Cyber-OLED...',
      'Finalizowanie konfiguracji środowiska...',
    ];

    for (int step = 0; step < statusUpdates.length; step++) {
      await Future.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      setState(() {
        _installStatusText = statusUpdates[step];
        _installProgress = ((step + 1) / statusUpdates.length).clamp(0.0, 1.0);
      });
    }

    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isMobile = screenSize.width < 650;
    final bool isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape && !_isInstalling) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter && !_isInstalling) {
            if (_currentStep == 0) {
              setState(() => _currentStep = 1);
            } else {
              _startInstallation();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: isMobile ? 16 : 32,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 640 : 540,
                  maxHeight: screenSize.height * 0.88,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0E14).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
                  border: Border.all(
                    color: const Color(0xFF00F2FE).withValues(alpha: _glowAnimation.value),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.15),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF9B51E0).withValues(alpha: 0.12),
                      blurRadius: 48,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile, isDesktop),
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0xFF00F2FE),
                        Color(0xFF00E676),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: _isInstalling
                      ? _buildInstallingView()
                      : (_currentStep == 0
                          ? _buildOverviewStep(isMobile)
                          : _buildLicenseStep(isMobile)),
                ),
                const SizedBox(height: 16),
                _buildFooter(isMobile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: isMobile ? 38 : 46,
                height: isMobile ? 38 : 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F2FE), Color(0xFF00E676)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.4),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'R',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isDesktop ? 'ResonX Suite (Windows Edition)' : 'ResonX Mobile Hub',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 15 : 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            'v2.4',
                            style: TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        const Text('autor:', style: TextStyle(color: Color(0xFF8E95A5), fontSize: 11)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00F2FE), Color(0xFF9B51E0)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Piter2020ja',
                            style: TextStyle(color: Colors.black, fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.discord, color: Color(0xFF5865F2), size: 13),
                            SizedBox(width: 3),
                            Text('piter2020ja', style: TextStyle(color: Color(0xFF8E95A5), fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!_isInstalling)
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF8E95A5), size: 20),
            tooltip: 'Zamknij setup',
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }

  Widget _buildInstallingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed_rounded, color: Color(0xFF00F2FE), size: 40),
            const SizedBox(height: 14),
            const Text(
              'Konfigurowanie silnika audio...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _installStatusText,
              style: const TextStyle(color: Color(0xFF8E95A5), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _installProgress,
                backgroundColor: const Color(0xFF161922),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${(_installProgress * 100).toInt()}%',
              style: const TextStyle(
                color: Color(0xFF00E676),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStep(bool isMobile) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Witaj w ResonX Ultimate Player',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Niezależny odtwarzacz high-definition z autorskim silnikiem parametrycznym DSP, lokalnym Wrapped i zsynchronizowanymi tekstami piosenek.',
            style: TextStyle(color: Color(0xFF8E95A5), fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.offline_bolt_rounded, color: Color(0xFF00F2FE), size: 16),
              const SizedBox(width: 6),
              const Text(
                'AKTUALIZACJA SILNIKA I NOWOŚCI:',
                style: TextStyle(
                  color: Color(0xFF00F2FE),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...changelogNotes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2.0),
                    child: Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseStep(bool isMobile) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Warunki Hobbystyczne & Użytkowania',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10121A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2232)),
            ),
            child: const Text(
              '1. ResonX to niezależny projekt muzyczny stworzony przez Piter2020ja na licencji Open Source do celów hobbystycznych.\n\n'
              '2. Aplikacja nie gromadzi Twoich prywatnych danych. Wszystkie playlisty, ustawienia prędkości oraz statystyki ResonX Wrapped zapisywane są w 100% lokalnie na Twoim urządzeniu.\n\n'
              '3. Wszystkie strumienie audio, miniatury oraz teksty LRCLIB są buforowane bezpośrednio przez zoptymalizowany potok sieciowy bez reklam.\n\n'
              '4. Kontakt z twórcą oraz zgłaszanie propozycji i feedbacku technicznego: Discord: piter2020ja.',
              style: TextStyle(color: Colors.white70, fontSize: 11.8, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!_isInstalling && _currentStep > 0)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1E2232)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 14, color: Colors.white70),
            label: const Text('Wstecz', style: TextStyle(color: Colors.white70, fontSize: 12)),
            onPressed: () => setState(() => _currentStep--),
          )
        else
          const Text(
            'DirectSound • Lossless FLAC/MP3',
            style: TextStyle(color: Color(0xFF555B6E), fontSize: 10.5, fontWeight: FontWeight.bold),
          ),
        if (!_isInstalling)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  colors: [Color(0xFF00F2FE), Color(0xFF00E676)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentStep == 0 ? 'Dalej' : 'Akceptuj i Rozpocznij',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 14),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}