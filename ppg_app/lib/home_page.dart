import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:fl_chart/fl_chart.dart';
// import 'helpers/excel_helper.dart';  // Comment out Excel
import 'helpers/simple_excel_helper.dart'; // Use CSV instead
import 'helpers/ppg_analyzer.dart'; // Add PPG analyzer

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? _cameraController; // Changed from late to nullable
  bool _isRecording = false;
  bool _isCameraInitialized = false; // Add this flag
  late List<CameraDescription> cameras;
  int _selectedCameraIndex = 0; // Track current camera

  // Color bar properties
  Color _selectedColor = Colors.blue;
  double _brightness = 1.0; // Range from 0.0 to 1.0

  // PPG Analysis properties
  final PPGAnalyzer _ppgAnalyzer = PPGAnalyzer();
  Timer? _ppgTimer;
  bool _isPPGRunning = false;

  // Computed color with brightness applied
  Color get _adjustedColor {
    HSLColor hslColor = HSLColor.fromColor(_selectedColor);
    return hslColor.withLightness((_brightness * 0.8) + 0.1).toColor();
  }

  final TextEditingController name = TextEditingController();
  final TextEditingController age = TextEditingController();
  final TextEditingController gender = TextEditingController();
  final TextEditingController height = TextEditingController();
  final TextEditingController weight = TextEditingController();
  final TextEditingController bloodType = TextEditingController();

  @override
  void initState() {
    super.initState();
    requestPermissions();
    initCamera();
  }

  Future<void> requestPermissions() async {
    await Permission.camera.request();
    await Permission.storage.request();
    await Permission.photos.request();
    // Removed manageExternalStorage permission to avoid issues
  }

  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();
      _cameraController = CameraController(
          cameras[_selectedCameraIndex], ResolutionPreset.medium);
      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Error initializing camera: $e');
      // Handle camera initialization error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Camera initialization failed: $e")),
      );
    }
  }

  Future<void> switchCamera() async {
    if (cameras.length <= 1) return;

    setState(() {
      _isCameraInitialized = false;
    });

    await _cameraController?.dispose();

    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;

    _cameraController = CameraController(
        cameras[_selectedCameraIndex], ResolutionPreset.medium);
    await _cameraController!.initialize();

    setState(() {
      _isCameraInitialized = true;
    });
  }

  Future<void> startRecording() async {
    if (_cameraController == null || !_isCameraInitialized) return;

    try {
      await _cameraController!.prepareForVideoRecording();
      await _cameraController!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error starting recording: $e")),
      );
    }
  }

  Future<void> stopRecording() async {
    if (_cameraController == null || !_isRecording) return;

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      setState(() => _isRecording = false);

      // Save video to gallery using Gal package
      await Gal.putVideo(videoFile.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Video saved to gallery")),
      );
    } catch (e) {
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving video: $e")),
      );
    }
  }

  void saveToExcel() async {
    try {
      await SimpleExcelHelper.saveUserData({
        'Ad': name.text,
        'Yaş': age.text,
        'Cinsiyet': gender.text,
        'Boy': height.text,
        'Kilo': weight.text,
        'Kan Grubu': bloodType.text,
      });

      // Get file path to show user
      String filePath = await SimpleExcelHelper.getFilePath();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("✅ Data saved successfully!"),
              const SizedBox(height: 4),
              Text(
                "📁 File location:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "App Documents → ppg_user_data.csv",
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error saving data: $e"),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // Color picker methods
  Future<void> _showColorPicker() async {
    final Color? newColor = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: _selectedColor,
            onColorChanged: (Color color) {
              setState(() {
                _selectedColor = color;
              });
            },
            width: 40,
            height: 40,
            borderRadius: 20,
            spacing: 5,
            runSpacing: 5,
            wheelDiameter: 155,
            heading: Text(
              'Select color',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subheading: Text(
              'Select color shade',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            wheelSubheading: Text(
              'Selected color and its shades',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            showMaterialName: true,
            showColorName: true,
            showColorCode: true,
            copyPasteBehavior: const ColorPickerCopyPasteBehavior(
              longPressMenu: true,
            ),
            materialNameTextStyle: Theme.of(context).textTheme.bodySmall,
            colorNameTextStyle: Theme.of(context).textTheme.bodySmall,
            colorCodeTextStyle: Theme.of(context).textTheme.bodySmall,
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: false,
              ColorPickerType.primary: true,
              ColorPickerType.accent: true,
              ColorPickerType.bw: false,
              ColorPickerType.custom: false,
              ColorPickerType.wheel: true,
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selectedColor),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (newColor != null) {
      setState(() {
        _selectedColor = newColor;
      });
    }
  }

  void _updateBrightness(double value) {
    setState(() {
      _brightness = value;
    });
  }

  void showFileLocation() async {
    try {
      String filePath = await SimpleExcelHelper.getFilePath();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.folder, color: Colors.blue),
              SizedBox(width: 8),
              Text("File Location"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your data is saved as:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "ppg_user_data.csv",
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text("📱 How to find it:"),
              const SizedBox(height: 8),
              if (Platform.isAndroid) ...[
                const Text("1. Open File Manager"),
                const Text("2. Go to Android/data/"),
                const Text("3. Find your app folder"),
                const Text("4. Look for ppg_user_data.csv"),
              ] else ...[
                const Text("1. Open Files app"),
                const Text("2. Go to 'On My iPhone'"),
                const Text("3. Find app folder"),
                const Text("4. Look for ppg_user_data.csv"),
              ],
              const SizedBox(height: 12),
              Text(
                "Full path:\n$filePath",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error getting file location: $e"),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // PPG Analysis Methods
  void _startPPGAnalysis() {
    if (!_isPPGRunning && _cameraController != null) {
      _ppgAnalyzer.reset();
      _isPPGRunning = true;

      // Start frame processing timer
      _ppgTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _processCameraFrame();
      });

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("📈 PPG Analysis Started"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _stopPPGAnalysis() {
    if (_isPPGRunning) {
      _ppgTimer?.cancel();
      _isPPGRunning = false;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⏹️ PPG Analysis Stopped"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _processCameraFrame() async {
    if (!_isPPGRunning || _cameraController == null) return;

    try {
      double timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;

      // Use simulated PPG data for demo
      _ppgAnalyzer.processSimulatedFrame(timestamp);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error processing frame: $e');
    }
  }

  // PPG Chart Widget
  Widget _buildPPGChart() {
    return Container(
      height: 300, // Same height as camera preview
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: _adjustedColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header with heart rate
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _adjustedColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "📈 PPG Signal Analysis",
                  style: TextStyle(
                    color: _adjustedColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "${_ppgAnalyzer.currentHeartRate.toStringAsFixed(0)} BPM",
                  style: TextStyle(
                    color: _adjustedColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          // Chart area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _ppgAnalyzer.ppgData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.monitor_heart,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isPPGRunning
                                ? "Collecting PPG data..."
                                : "Press START to begin analysis",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          drawHorizontalLine: true,
                          horizontalInterval: 10,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade300,
                              strokeWidth: 0.5,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade300,
                              strokeWidth: 0.5,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: false,
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _ppgAnalyzer.ppgData
                                .asMap()
                                .entries
                                .map((entry) => FlSpot(
                                      entry.key.toDouble(),
                                      entry.value.intensity,
                                    ))
                                .toList(),
                            isCurved: true,
                            color: _adjustedColor,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: _adjustedColor.withOpacity(0.1),
                            ),
                          ),
                        ],
                        minY: _ppgAnalyzer.ppgData.isNotEmpty
                            ? _ppgAnalyzer.ppgData
                                    .map((p) => p.intensity)
                                    .reduce(min) -
                                5
                            : 0,
                        maxY: _ppgAnalyzer.ppgData.isNotEmpty
                            ? _ppgAnalyzer.ppgData
                                    .map((p) => p.intensity)
                                    .reduce(max) +
                                5
                            : 100,
                      ),
                    ),
            ),
          ),
          // Control buttons
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isPPGRunning ? _stopPPGAnalysis : _startPPGAnalysis,
                    icon: Icon(_isPPGRunning ? Icons.stop : Icons.play_arrow),
                    label: Text(_isPPGRunning ? "STOP" : "START"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isPPGRunning ? Colors.red : _adjustedColor,
                      foregroundColor: _isPPGRunning
                          ? Colors.white
                          : (_adjustedColor.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    _ppgAnalyzer.reset();
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("RESET"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ppgTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if camera is initialized properly
    if (!_isCameraInitialized || _cameraController == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("PPGSignalCollector")),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Initializing camera..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _adjustedColor,
        elevation: 8,
        shadowColor: _adjustedColor.withOpacity(0.5),
        title: Container(
          height: 60,
          child: Stack(
            children: [
              // Main color bar content
              Center(
                child: Text(
                  'PPG Signal Collector',
                  style: TextStyle(
                    color: _adjustedColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Color picker button (right side)
              Positioned(
                right: 0,
                top: 10,
                child: GestureDetector(
                  onTap: _showColorPicker,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.palette,
                      size: 24,
                      color: _selectedColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Brightness Slider (right below app bar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.brightness_low, color: Colors.grey.shade600),
                      Expanded(
                        child: Slider(
                          value: _brightness,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          label: '${(_brightness * 100).round()}%',
                          onChanged: _updateBrightness,
                          activeColor: _adjustedColor,
                          thumbColor: _adjustedColor,
                        ),
                      ),
                      Icon(Icons.brightness_high, color: Colors.grey.shade600),
                    ],
                  ),
                  Text(
                    'Brightness: ${(_brightness * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Camera preview and PPG chart side by side
            Row(
              children: [
                // Camera preview
                Expanded(
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: _adjustedColor, width: 4),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _adjustedColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // PPG Analysis chart
                Expanded(
                  child: _buildPPGChart(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Camera switch button
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: cameras.length > 1 ? switchCamera : null,
                icon: const Icon(Icons.flip_camera_ios, size: 24),
                label: Text(
                  cameras.length > 1
                      ? (_selectedCameraIndex == 0
                          ? "🔄 Switch to Front Camera"
                          : "🔄 Switch to Back Camera")
                      : "Only one camera available",
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor:
                      cameras.length > 1 ? _adjustedColor : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Recording controls
            if (!_isRecording)
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: startRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _adjustedColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    "🔴 START RECORDING",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _adjustedColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: stopRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    "⏹️ STOP RECORDING",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Form Fields
            _buildTextField('Ad', name),
            _buildTextField('Yaş', age),
            _buildTextField('Cinsiyet', gender),
            _buildTextField('Boy', height),
            _buildTextField('Kilo', weight),
            _buildTextField('Kan grubu', bloodType),
            const SizedBox(height: 20),

            // Save data button
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveToExcel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _adjustedColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  "💾 SAVE DATA TO EXCEL",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _adjustedColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Show file location button
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: showFileLocation,
                icon: const Icon(Icons.folder_open),
                label: const Text("📁 SHOW FILE LOCATION"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
