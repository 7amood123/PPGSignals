import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SimpleExcelHelper {
  static Future<void> saveUserData(Map<String, String> userData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/user_data.csv';
      final file = File(filePath);
      
      // Check if file exists to add headers
      bool fileExists = await file.exists();
      
      // Create CSV content
      String csvContent = '';
      
      if (!fileExists) {
        // Add headers
        csvContent += 'Tarih,Ad,Yaş,Cinsiyet,Boy,Kilo,Kan Grubu\n';
      }
      
      // Add data row
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}';
      
      csvContent += '$dateStr,${userData['Ad'] ?? ''},${userData['Yaş'] ?? ''},${userData['Cinsiyet'] ?? ''},${userData['Boy'] ?? ''},${userData['Kilo'] ?? ''},${userData['Kan Grubu'] ?? ''}\n';
      
      // Write to file (append mode)
      await file.writeAsString(csvContent, mode: FileMode.append);
      
      print('Data saved to CSV at: $filePath');
      
    } catch (e) {
      print('Error saving to CSV: $e');
      throw Exception('Failed to save data: $e');
    }
  }
  
  static Future<String> getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/user_data.csv';
  }
}