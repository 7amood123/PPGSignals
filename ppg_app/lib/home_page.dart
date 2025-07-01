import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
// import 'helpers/excel_helper.dart';  // Comment out Excel
import 'helpers/simple_excel_helper.dart'; // Use CSV instead

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
                filePath.contains('Download') 
                  ? "Downloads folder → ppg_user_data.csv"
                  : "App Documents → ppg_user_data.csv",
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

  @override
  void dispose() {
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
            // Camera preview with color bar border
            Container(
              height: 300,
              width: double.infinity,
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
