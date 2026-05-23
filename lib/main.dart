import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LED Matrix Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F4FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F4FC),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const LedControllerPage(),
    );
  }
}

class LedControllerPage extends StatefulWidget {
  const LedControllerPage({super.key});

  @override
  State<LedControllerPage> createState() => _LedControllerPageState();
}

class _LedControllerPageState extends State<LedControllerPage> {
  final TextEditingController _ipController =
  TextEditingController(text: '10.173.50.50');
  final TextEditingController _textController = TextEditingController();

  bool _isLoading = false;

  double _speed = 75;
  double _brightness = 2;
  double _loops = 1;
  bool _enableBlink = false;
  bool _stopDisplay = false;
  int _textEffect = 0;
  bool _enableTypeEffect = false;
  bool _isEmergencyMode = false;

  TimeOfDay? _selectedTime;
  Timer? _scheduleTimer;

  String? _scheduledText;
  String? _scheduledIp;
  double? _scheduledSpeed;
  double? _scheduledBrightness;
  double? _scheduledLoops;
  bool? _scheduledBlink;
  bool _isScheduled = false;

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    _ipController.dispose();
    _textController.dispose();
    super.dispose();
  }

  String _sanitizeText(String input) {
    String str = input;
    const withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const withoutDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }

    return str.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _sendStopImmediately(String ip) async {
    try {
      final Uri stopUrl = Uri.parse('http://$ip/?stop=1&end=1');
      await http.get(stopUrl).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> _executeRequest({
    required String ip,
    required String text,
    required double speed,
    required double brightness,
    required double loops,
    required bool enableBlink,
    bool stopDisplay = false,
    bool clearInputAfterSend = false,
  }) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final String encodedText = Uri.encodeComponent(text);
      final int effectValue = _enableTypeEffect ? 1 : 0;

      String urlString =
          'http://$ip/?text=$encodedText&speed=${speed.toInt()}&brightness=${brightness.toInt()}&loops=${loops.toInt()}&effect=$effectValue';

      if (enableBlink) urlString += '&blink=1';
      if (stopDisplay) urlString += '&stop=1';
      urlString += '&end=1';

      final Uri url = Uri.parse(urlString);
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _showSnackBar('Đã đồng bộ xuống LED thành công!', isSuccess: true);
        if (clearInputAfterSend) {
          _textController.clear();
        }
      } else {
        _showSnackBar('Lỗi: Server phản hồi mã ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Không kết nối được mạch! (Kiểm tra lại WiFi hoặc IP)');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendNow() async {
    final String ip = _ipController.text.trim();
    final String rawText = _textController.text.trim();

    if (ip.isEmpty) {
      _showSnackBar('Vui lòng nhập địa chỉ IP của ESP8266!');
      return;
    }

    if (rawText.isEmpty && !_stopDisplay) {
      _showSnackBar('Vui lòng nhập nội dung cần hiển thị!');
      return;
    }

    final String finalCleanText = _sanitizeText(rawText);

    await _executeRequest(
      ip: ip,
      text: finalCleanText,
      speed: _speed,
      brightness: _brightness,
      loops: _loops,
      enableBlink: _enableBlink,
      stopDisplay: _stopDisplay,
      clearInputAfterSend: true,
    );
  }

  Future<void> _sendCurrentTime() async {
    final String ip = _ipController.text.trim();

    if (ip.isEmpty) {
      _showSnackBar('Vui lòng nhập địa chỉ IP của ESP8266!');
      return;
    }

    final now = DateTime.now();

    final String currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await _executeRequest(
      ip: ip,
      text: currentTime,
      speed: _speed,
      brightness: _brightness,
      loops: _loops,
      enableBlink: _enableBlink,
      stopDisplay: false,
      clearInputAfterSend: false,
    );
  }

  Future<void> _sendEmergency() async {
    final String ip = _ipController.text.trim();

    if (ip.isEmpty) {
      _showSnackBar('Vui lòng nhập địa chỉ IP của ESP8266!');
      return;
    }

    setState(() {
      _isEmergencyMode = true;
      _enableBlink = true;
      _brightness = 15;
      _speed = 50;
      _loops = 10;
      _stopDisplay = false;
    });

    await _executeRequest(
      ip: ip,
      text: 'SOS SOS',
      speed: 50,
      brightness: 15,
      loops: 10,
      enableBlink: true,
      stopDisplay: false,
      clearInputAfterSend: false,
    );
  }

  Future<void> _stopEmergency() async {
    final String ip = _ipController.text.trim();

    if (ip.isEmpty) {
      _showSnackBar('Vui lòng nhập địa chỉ IP của ESP8266!');
      return;
    }

    setState(() {
      _isEmergencyMode = false;
      _enableBlink = false;
      _stopDisplay = true;
    });

    await _executeRequest(
      ip: ip,
      text: '',
      speed: _speed,
      brightness: _brightness,
      loops: 1,
      enableBlink: false,
      stopDisplay: true,
      clearInputAfterSend: false,
    );
  }

  Future<void> _scheduleSend() async {
    final String ip = _ipController.text.trim();
    final String rawText = _textController.text.trim();

    if (ip.isEmpty) {
      _showSnackBar('Vui lòng nhập địa chỉ IP của ESP8266!');
      return;
    }

    if (_selectedTime == null) {
      _showSnackBar('Bạn chưa chọn giờ hẹn!');
      return;
    }

    if (rawText.isEmpty) {
      _showSnackBar('Vui lòng nhập nội dung cần hiển thị!');
      return;
    }

    final String finalCleanText = _sanitizeText(rawText);

    final now = DateTime.now();
    DateTime target = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    final Duration waitDuration = target.difference(now);

    _scheduleTimer?.cancel();

    _scheduledIp = ip;
    _scheduledText = finalCleanText;
    _scheduledSpeed = _speed;
    _scheduledBrightness = _brightness;
    _scheduledLoops = _loops;
    _scheduledBlink = _enableBlink;

    setState(() {
      _isScheduled = true;
    });

    await _sendStopImmediately(ip);

    _showSnackBar(
      'Đã đặt lịch lúc ${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}. LED sẽ tắt chờ và tự hiển thị đúng giờ.',
      isSuccess: true,
    );

    _scheduleTimer = Timer(waitDuration, () async {
      if (_scheduledIp == null ||
          _scheduledText == null ||
          _scheduledSpeed == null ||
          _scheduledBrightness == null ||
          _scheduledLoops == null ||
          _scheduledBlink == null) {
        return;
      }

      await _executeRequest(
        ip: _scheduledIp!,
        text: _scheduledText!,
        speed: _scheduledSpeed!,
        brightness: _scheduledBrightness!,
        loops: _scheduledLoops!,
        enableBlink: _scheduledBlink!,
        stopDisplay: false,
        clearInputAfterSend: false,
      );

      if (mounted) {
        setState(() {
          _isScheduled = false;
          _selectedTime = null;
        });
      }
    });
  }

  void _cancelSchedule() {
    _scheduleTimer?.cancel();

    setState(() {
      _selectedTime = null;
      _isScheduled = false;
      _scheduledIp = null;
      _scheduledText = null;
      _scheduledSpeed = null;
      _scheduledBrightness = null;
      _scheduledLoops = null;
      _scheduledBlink = null;
      _isLoading = false;
    });

    _showSnackBar('Đã hủy lịch hẹn.', isSuccess: true);
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _sectionCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeader() {
    return _sectionCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LED Control Center',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Điều khiển ma trận LED qua WiFi',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Colors.green, size: 10),
                SizedBox(width: 6),
                Text(
                  'Sẵn sàng',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.deepPurple.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.deepPurple.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 1.4),
        ),
      ),
    );
  }

  Widget _sliderItem({
    required String title,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                valueText,
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueText,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _switchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.deepPurple).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: color ?? Colors.deepPurple),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String scheduleText = _selectedTime == null
        ? 'Chưa hẹn giờ'
        : 'Sẽ hiển thị chữ vào: ${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LED Matrix Controller',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),

                _sectionCard(
                  child: Column(
                    children: [
                      _inputField(
                        controller: _ipController,
                        label: 'IP Mạch LED',
                        icon: Icons.wifi,
                      ),
                      const SizedBox(height: 14),
                      _inputField(
                        controller: _textController,
                        label: 'Văn bản hiển thị',
                        icon: Icons.text_fields,
                        enabled: !_isEmergencyMode,
                        maxLength: 70,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cài đặt hiển thị',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sliderItem(
                        title: 'Tốc độ Delay',
                        valueText: '${_speed.toInt()} ms',
                        value: _speed,
                        min: 10,
                        max: 200,
                        divisions: 190,
                        onChanged: _isEmergencyMode
                            ? null
                            : (val) => setState(() => _speed = val),
                      ),
                      _sliderItem(
                        title: 'Độ sáng',
                        valueText: '${_brightness.toInt()} / 15',
                        value: _brightness,
                        min: 0,
                        max: 15,
                        divisions: 15,
                        onChanged: _isEmergencyMode
                            ? null
                            : (val) => setState(() => _brightness = val),
                      ),
                      _sliderItem(
                        title: 'Số vòng lặp chữ',
                        valueText: '${_loops.toInt()}',
                        value: _loops,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        onChanged: _isEmergencyMode
                            ? null
                            : (val) => setState(() => _loops = val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hiệu ứng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _switchItem(
                        icon: Icons.text_fields,
                        title: 'Hiệu ứng hiện từng chữ',
                        value: _enableTypeEffect,
                        onChanged: _isEmergencyMode
                            ? null
                            : (val) {
                          setState(() {
                            _enableTypeEffect = val;
                            _textEffect = val ? 1 : 0;
                          });
                        },
                      ),
                      _switchItem(
                        icon: Icons.flash_on_rounded,
                        title: 'Hiệu ứng nhấp nháy',
                        value: _enableBlink,
                        onChanged: _isEmergencyMode
                            ? null
                            : (val) => setState(() => _enableBlink = val),
                      ),
                      _switchItem(
                        icon: Icons.stop_circle_outlined,
                        title: 'Dừng hẳn STOP RUNNING',
                        value: _stopDisplay,
                        color: Colors.redAccent,
                        onChanged: _isEmergencyMode
                            ? null
                            : (val) => setState(() => _stopDisplay = val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed:
                    (_isLoading || _isEmergencyMode) ? null : _sendCurrentTime,
                    icon: const Icon(Icons.access_time),
                    label: const Text(
                      'HIỂN THỊ GIỜ HIỆN TẠI',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _isEmergencyMode
                          ? Colors.redAccent
                          : Colors.red.withOpacity(0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isEmergencyMode
                                ? 'CHẾ ĐỘ KHẨN CẤP ĐANG BẬT'
                                : 'Chế độ khẩn cấp',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Khi bật: LED hiển thị SOS SOS, nhấp nháy nhanh, độ sáng tối đa và khóa chỉnh sửa để tránh bấm nhầm.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 52,
                        child: _isEmergencyMode
                            ? OutlinedButton.icon(
                          onPressed: _isLoading ? null : _stopEmergency,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text(
                            'DỪNG KHẨN CẤP',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.4,
                            ),
                          ),
                        )
                            : ElevatedButton.icon(
                          onPressed: _isLoading ? null : _sendEmergency,
                          icon: const Icon(Icons.emergency),
                          label: const Text(
                            'BẬT KHẨN CẤP',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _sectionCard(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(
                      _isScheduled ? '$scheduleText (Đã lưu lịch)' : scheduleText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        if (_selectedTime != null || _isScheduled)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            onPressed:
                            _isEmergencyMode ? null : _cancelSchedule,
                          ),
                        ElevatedButton.icon(
                          onPressed: _isEmergencyMode
                              ? null
                              : () => _selectTime(context),
                          icon: const Icon(Icons.access_time, size: 18),
                          label: const Text('Đặt giờ'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed:
                          (_isLoading || _isEmergencyMode) ? null : _sendNow,
                          icon: _isLoading
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                            CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.send_rounded),
                          label: const Text(
                            'GỬI NGAY ĐẾN LED',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: (_isLoading || _isEmergencyMode)
                              ? null
                              : _scheduleSend,
                          icon: const Icon(Icons.schedule_send),
                          label: const Text(
                            'LƯU LỊCH THỰC THI',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}