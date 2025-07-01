import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

class ExcelHelper {
  static Future<void> saveUserData(Map<String, String> userData) async {
    try {
      // Create a new Excel document
      var excel = Excel.createExcel();
      
      // Get the default sheet
      Sheet sheetObject = excel['Sheet1'];
      
      // Check if file already exists to append data
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/user_data.xlsx';
      final file = File(filePath);
      
      int currentRow = 0;
      
      if (await file.exists()) {
        // Read existing file
        var bytes = await file.readAsBytes();
        excel = Excel.decodeBytes(bytes);
        sheetObject = excel['Sheet1'];
        
        // Find the next empty row
        currentRow = sheetObject.maxRows;
      } else {
        // Add headers for new file
        var headerRow = ['Tarih', 'Ad', 'Yaş', 'Cinsiyet', 'Boy', 'Kilo', 'Kan Grubu'];
        for (int i = 0; i < headerRow.length; i++) {
          var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
          cell.value = TextCellValue(headerRow[i]);
        }
        currentRow = 1;
      }
      
      // Add new data row
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}';
      
      var newRow = [
        dateStr,
        userData['Ad'] ?? '',
        userData['Yaş'] ?? '',
        userData['Cinsiyet'] ?? '',
        userData['Boy'] ?? '',
        userData['Kilo'] ?? '',
        userData['Kan Grubu'] ?? '',
      ];
      
      for (int i = 0; i < newRow.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: currentRow));
        cell.value = TextCellValue(newRow[i]);
      }
      
      // Save the file
      var fileBytes = excel.save();
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
        print('Excel file saved at: $filePath');
      }
      
    } catch (e) {
      print('Error saving to Excel: $e');
      throw Exception('Failed to save data to Excel: $e');
    }
  }
  
  static Future<String> getExcelFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/user_data.xlsx';
  }
}