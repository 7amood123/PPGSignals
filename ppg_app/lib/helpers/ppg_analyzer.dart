import 'dart:typed_data';
import 'dart:math';

class PPGPoint {
  final double timestamp;
  final double intensity;
  
  PPGPoint(this.timestamp, this.intensity);
}

class PPGAnalyzer {
  List<PPGPoint> _ppgData = [];
  List<double> _heartRates = [];
  final int maxDataPoints = 300; // Keep last 10 seconds at 30fps
  final int windowSize = 10; // Moving average window
  double _lastPeakTime = 0;
  double _currentHeartRate = 0;
  
  // ROI (Region of Interest) coordinates
  int roiX = 100;
  int roiY = 100;
  int roiWidth = 50;
  int roiHeight = 50;
  
  double get currentHeartRate => _currentHeartRate;
  List<PPGPoint> get ppgData => _ppgData;
  
  // Simplified frame processing (simulation for demo)
  double processSimulatedFrame(double timestamp) {
    // Simulate PPG signal with heart rate around 70 BPM
    double baseFreq = 1.2; // ~72 BPM
    double intensity = 120 + 15 * sin(timestamp * 2 * pi * baseFreq) + 
                      5 * sin(timestamp * 2 * pi * baseFreq * 2) +
                      Random().nextDouble() * 3; // Add some noise
    
    addPPGPoint(timestamp, intensity);
    calculateHeartRate(timestamp);
    
    return intensity;
  }
  
  void addPPGPoint(double timestamp, double intensity) {
    // Apply simple moving average filter
    double filteredIntensity = _applyMovingAverage(intensity);
    
    _ppgData.add(PPGPoint(timestamp, filteredIntensity));
    
    // Keep only recent data
    if (_ppgData.length > maxDataPoints) {
      _ppgData.removeAt(0);
    }
  }
  
  double _applyMovingAverage(double newValue) {
    if (_ppgData.length < windowSize) {
      return newValue;
    }
    
    double sum = newValue;
    for (int i = _ppgData.length - windowSize + 1; i < _ppgData.length; i++) {
      sum += _ppgData[i].intensity;
    }
    
    return sum / windowSize;
  }
  
  void calculateHeartRate(double currentTime) {
    if (_ppgData.length < 30) return; // Need enough data
    
    // Simple peak detection
    List<double> recentIntensities = _ppgData
        .skip(max(0, _ppgData.length - 30))
        .map((p) => p.intensity)
        .toList();
    
    double threshold = _calculateThreshold(recentIntensities);
    
    // Check if current point is a peak
    if (_ppgData.length >= 3) {
      int currentIndex = _ppgData.length - 1;
      int prevIndex = currentIndex - 1;
      int prev2Index = currentIndex - 2;
      
      double current = _ppgData[currentIndex].intensity;
      double prev = _ppgData[prevIndex].intensity;
      double prev2 = _ppgData[prev2Index].intensity;
      
      // Peak detection: current value is higher than neighbors and above threshold
      if (current > prev && prev > prev2 && current > threshold) {
        double timeSinceLastPeak = currentTime - _lastPeakTime;
        
        // Valid peak (between 0.5 and 2 seconds since last peak)
        if (timeSinceLastPeak > 0.5 && timeSinceLastPeak < 2.0 && _lastPeakTime > 0) {
          double instantHeartRate = 60.0 / timeSinceLastPeak;
          
          // Reasonable heart rate range (40-200 BPM)
          if (instantHeartRate >= 40 && instantHeartRate <= 200) {
            _heartRates.add(instantHeartRate);
            
            // Keep recent heart rates
            if (_heartRates.length > 10) {
              _heartRates.removeAt(0);
            }
            
            // Calculate average heart rate
            _currentHeartRate = _heartRates.reduce((a, b) => a + b) / _heartRates.length;
          }
        }
        
        _lastPeakTime = currentTime;
      }
    }
  }
  
  double _calculateThreshold(List<double> intensities) {
    if (intensities.isEmpty) return 0;
    
    double sum = intensities.reduce((a, b) => a + b);
    double mean = sum / intensities.length;
    
    double variance = 0;
    for (double value in intensities) {
      variance += pow(value - mean, 2);
    }
    variance /= intensities.length;
    double stdDev = sqrt(variance);
    
    return mean + (stdDev * 0.5); // Threshold above mean
  }
  
  void reset() {
    _ppgData.clear();
    _heartRates.clear();
    _currentHeartRate = 0;
    _lastPeakTime = 0;
  }
  
  void updateROI(int x, int y, int width, int height) {
    roiX = x;
    roiY = y;
    roiWidth = width;
    roiHeight = height;
  }
}