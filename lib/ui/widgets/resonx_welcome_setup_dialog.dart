import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResonXWelcomeSetupDialog extends StatefulWidget {
  const ResonXWelcomeSetupDialog({super.key});

  /// Statyczna metoda pomocnicza do wywołania w głównym ekranie aplikacji (np. w initState()).
  /// Sprawdza, czy setup był już kiedykolwiek uruchomiony. Jeśli nie – wyświetla dialog.
  static Future<void> showIfFirstLaunch(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isCompleted = prefs.getBool('resonx_setup_completed_v4_0_7') ?? false;

    if (!isCompleted && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.75),
        builder: (dialogCtx) => const ResonXWelcomeSetupDialog(),
      );
    }
  }

  @override
  State<ResonXWelcomeSetupDialog> createState() => _ResonXWelcomeSetupDialogState();
}

class _ResonXWelcomeSetupDialogState extends State<ResonXWelcomeSetupDialog>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isInstalling = false;
  double _installProgress = 0.0;
  String _installStatusText = 'Weryfikacja środowiska uruchomieniowego...';

  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  final List<Map<String, dynamic>> engineFeatures = [
    {
      'title': '10-Pasmowy Korektor Parametryczny DSP',
      'desc': 'Precyzyjna regulacja pasm w zakresie 32 Hz – 16 kHz z dynamicznym pre-ampem przeciw przesterowaniom (anti-clipping).',
      'icon': Icons.equalizer_rounded,
    },
    {
      'title': 'Natywny Silnik Audio Niskich Opóźnień',
      'desc': 'DirectSound / WASAPI na systemie Windows oraz zoptymalizowany potok AudioTrack na platformie Android.',
      'icon': Icons.speed_rounded,
    },
    {
      'title': 'Wielofunkcyjna Dynamiczna Wyspa (Android Overlay)',
      'desc': 'Pływający, kompaktowy kontroler systemowy wyświetlany bezpośrednio nad innymi aplikacjami.',
      'icon': Icons.picture_in_picture_alt_rounded,
    },
    {
      'title': 'Obsługa Formatów High-Resolution Audio',
      'desc': 'Natywne dekodowanie bezstratnych formatów FLAC i WAV oraz wysokobitrate’owych plików MP3 i AAC.',
      'icon': Icons.album_rounded,
    },
    {
      'title': 'Lokalna Baza Danych Playlist i ResonX Wrapped',
      'desc': 'Zarządzanie biblioteką, statystyki odsłuchu oraz kolejkowanie przetwarzane w 100% na urządzeniu użytkownika.',
      'icon': Icons.storage_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.70).animate(
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
      _installStatusText = 'Weryfikacja uprawnień i modułów systemowych...';
    });

    final List<Map<String, dynamic>> realStartupStages = [
      {'text': 'Weryfikacja uprawnień pamięci masowej i audio...', 'ms': 300},
      {'text': 'Konfiguracja sprzętowego bufora audio (DirectSound / AudioTrack)...', 'ms': 340},
      {'text': 'Kalibracja 10-pasmowego korektora parametrycznego DSP...', 'ms': 380},
      {'text': 'Ładowanie wbudowanych presetów akustycznych (Rap, Bass Boost, Flat)...', 'ms': 280},
      {'text': 'Inicjalizacja modułu nakładki systemowej (Dynamiczna Wyspa)...', 'ms': 320},
      {'text': 'Indeksowanie lokalnej struktury katalogów i bazy danych playlist...', 'ms': 360},
      {'text': 'Zapisywanie parametrów sesji i profilu Cyber-OLED...', 'ms': 300},
    ];

    for (int i = 0; i < realStartupStages.length; i++) {
      await Future.delayed(Duration(milliseconds: realStartupStages[i]['ms'] as int));
      if (!mounted) return;
      setState(() {
        _installStatusText = realStartupStages[i]['text'] as String;
        _installProgress = ((i + 1) / realStartupStages.length).clamp(0.0, 1.0);
      });
    }

    // Zapisanie w SharedPreferences, że pierwsze uruchomienie zakończyło się pomyślnie
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('resonx_setup_completed_v4_0_7', true);

    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isMobile = screenSize.width < 650;
    final bool isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return PopScope(
      canPop: !_isInstalling,
      child: Focus(
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
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 680 : 540,
                    maxHeight: screenSize.height * 0.88,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0C12).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                    border: Border.all(
                      color: const Color(0xFF00F2FE).withValues(alpha: _glowAnimation.value),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.18),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFF9B51E0).withValues(alpha: 0.14),
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
                    height: 1.2,
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
                width: isMobile ? 42 : 48,
                height: isMobile ? 42 : 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F2FE), Color(0xFF00E676)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.45),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'R',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 26,
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
                            isDesktop ? 'ResonX Suite (Windows)' : 'ResonX Mobile Hub',
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'v4.0.7',
                            style: TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
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
                        const Text('twórca:', style: TextStyle(color: Color(0xFF8E95A5), fontSize: 11)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00F2FE), Color(0xFF9B51E0)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Piter2020ja',
                            style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
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
            tooltip: 'Zamknij',
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                border: Border.all(color: const Color(0xFF00F2FE).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.memory_rounded, color: Color(0xFF00F2FE), size: 38),
            ),
            const SizedBox(height: 16),
            const Text(
              'Przygotowywanie środowiska ResonX...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _installStatusText,
              style: const TextStyle(color: Color(0xFF8E95A5), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
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
            'Architektura Dźwięku High-Definition',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'ResonX to niezależny odtwarzacz muzyczny skupiony na pełnej kontroli pasma akustycznego, zerowej latencji i bezkompromisowej prywatności.',
            style: TextStyle(color: Color(0xFF8E95A5), fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF00F2FE), size: 16),
              const SizedBox(width: 6),
              const Text(
                'AKTUALNY SILNIK & MODUŁY TECHNICZNE:',
                style: TextStyle(
                  color: Color(0xFF00F2FE),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...engineFeatures.map(
            (feat) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1B202D)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(feat['icon'] as IconData, color: const Color(0xFF00E676), size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feat['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            feat['desc'] as String,
                            style: const TextStyle(
                              color: Color(0xFF8E95A5),
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
            'Warunki Korzystania & Zrzeczenie Odpowiedzialności',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Regulamin licencyjny projektu ResonX (Wersja v4.0.7).',
            style: TextStyle(color: Color(0xFF8E95A5), fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10121A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2232)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. CHARAKTER PROJEKTU & PRAWA AUTORSKIE\n'
                  'Aplikacja ResonX jest niezależnym oprogramowaniem stworzonym przez autora Piter2020ja. Wszelkie prawa autorskie, nazwa projektu, identyfikacja wizualna oraz rozwiązania architektoniczne pozostają wyłączną własnością autora.',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                ),
                SizedBox(height: 10),
                Text(
                  '2. ZAKAZ ODSPRZEDAŻY, PODSZYWANIA SIĘ I DYSTRYBUCJI KOMERCYJNEJ\n'
                  'Surowo zabrania się jakiejkolwiek odsprzedaży aplikacji ResonX, jej redystrybucji w celach zarobkowych, pobierania opłat za dostęp do programu oraz sublicencjonowania. Całkowicie zabronione jest podszywanie się pod autora, usuwanie informacji o autorstwie (Piter2020ja) oraz wydawanie aplikacji pod inną nazwą bez uprzedniej pisemnej zgody twórcy.',
                  style: TextStyle(color: Color(0xFFFF5252), fontSize: 11.5, height: 1.45, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 10),
                Text(
                  '3. MODYFIKACJE NA WYŁĄCZNY UŻYTEK WŁASNY\n'
                  'Użytkownik ma pełne prawo do modyfikowania, dostosowywania oraz kompilowania kodu źródłowego na własny, prywatny użytek (na własne potrzeby). Wprowadzane zmiany nie mogą być wykorzystywane na szkodę autora, projektu ResonX, innych użytkowników ani w celu obejścia integralności aplikacji lub naruszenia praw osób trzecich.',
                  style: TextStyle(color: Color(0xFF00E676), fontSize: 11.5, height: 1.45, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 10),
                Text(
                  '4. CAŁKOWITE WYŁĄCZENIE ODPOWIEDZIALNOŚCI (KLAUZULA „AS IS”)\n'
                  'Oprogramowanie jest dostarczane w stanie, w jakim się znajduje („AS IS”), bez jakichkolwiek gwarancji – wyraźnych ani dorozumianych. Autor nie ponosi żadnej odpowiedzialności za jakiekolwiek bezpośrednie, pośrednie lub przypadkowe szkody wynikające z korzystania z aplikacji, w tym za usterki sprzętu nagłaśniającego, utratę danych czy błędy konfiguracji.',
                  style: TextStyle(color: Color(0xFFFFB74D), fontSize: 11.5, height: 1.45, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 10),
                Text(
                  '5. PRYWATNOŚĆ I BRAK TELEMETRII\n'
                  'ResonX szanuje Twoją prywatność. Aplikacja nie gromadzi danych osobowych, nie śledzi odsłuchów ani nie przesyła Twoich plików na zewnętrzne serwery. Baza danych, ustawienia i historia pozostają wyłącznie na Twoim urządzeniu.',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                ),
                SizedBox(height: 10),
                Text(
                  '6. PRAWA DO ODTWARZANYCH TREŚCI & KONTAKT\n'
                  'Użytkownik ponosi wyłączną odpowiedzialność za legalność i prawa autorskie odtwarzanych materiałów dźwiękowych. Kontakt z twórcą: Discord (piter2020ja).',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                ),
              ],
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
            'ResonX v4.0.7 • DSP Engine • Piter2020ja',
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