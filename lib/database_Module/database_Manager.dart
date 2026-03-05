import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:objectbox/objectbox.dart';
import '../objectbox.g.dart'; 
import '../utilities.dart';
import 'package:provider/provider.dart';
import 'ObjectBoxService.dart';
import 'package:dio/dio.dart'; // Using Dio for stable large file transfers

class ObjectBoxManager {
  late String _dbDirectoryPath;
  BuildContext? context;
  String baseurl = 'https://nextorbitals.in/hotelBackup';

  // Initialize Dio instance
  final Dio _dio = Dio();

  ObjectBoxManager({this.context});

  Future<void> init() async {
    _dbDirectoryPath = AppConstants.objectbox_path;
  }

  /// --- UPLOAD WITH DIO ---
  Future<bool> uploadBackupToServer(String filePath, BuildContext context) async {
    final String uploadUrl = '$baseurl/upload.php';

    try {
      // Create FormData for Multipart upload
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: p.basename(filePath),
        ),
      });

      print_log("Starting Upload via Dio...");

      var response = await _dio.post(
        uploadUrl,
        data: formData,
        onSendProgress: (sent, total) {
          if (total != -1) {
            String progress = (sent / total * 100).toStringAsFixed(0);
            print_log("Upload Progress: $progress% of total $total");
          }
        },
      );

      if (response.statusCode == 200) {
        print_log("Upload Successful: ${response.data}");
        return true;
      } else {
        print_log_red("Upload failed: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print_log_red("Dio Upload Error: $e");
      print_log_red("Cloud upload failed. Please check internet.");
      return false;
    }
  }

  /// --- DOWNLOAD WITH DIO ---
  Future<String?> downloadBackupFile(String fileName, BuildContext context) async {
    // Note: If your PHP script saves files in an 'uploads' folder, add /uploads/ here
    final String url = '$baseurl/uploads/$fileName';
    
    try {
      final tempDir = await getTemporaryDirectory();
      final localFileName = fileName.endsWith('.mdb') ? fileName : '$fileName.mdb';
      final savePath = p.join(tempDir.path, localFileName);

      print_log("Downloading from: $url");

      var response = await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            String progress = (received / total * 100).toStringAsFixed(0);
            print_log("Download Progress: $progress% of total $total");
          }
        },
      );

      if (response.statusCode == 200) {
        File downloadedFile = File(savePath);
        
        // Security Check: If server returns an error page, it's often small HTML text
        if (await downloadedFile.length() < 1000) {
          String content = await downloadedFile.readAsString();
          if (content.contains("<html>")) {
            print_log_red("Download failed: URL returned HTML (404), not a database.");
            return null;
          }
        }

        print_log("File downloaded successfully to: $savePath");
        return savePath;
      }
      return null;
    } catch (e) {
      print_log_red("Dio Download Error: $e");
      print_log_red("Failed to download backup.");
      return null;
    }
  }

  /// --- BACKUP LOGIC ---
  Future<String?> backupDatabase(BuildContext context, String backupPath) async {
    final objectBoxService = Provider.of<ObjectBoxService>(context, listen: false);
    Store store = objectBoxService.store;

    try {
      final dbDirectoryPath = store.directoryPath;
      store.close(); // Close before copying

      final srcFile = File(p.join(dbDirectoryPath, 'data.mdb'));
      if (!srcFile.existsSync()) {
        objectBoxService.store = await openStore(directory: dbDirectoryPath);
        return null;
      }

      final backupFile = File(backupPath);
      if (!await backupFile.parent.exists()) {
        await backupFile.parent.create(recursive: true);
      }

      await srcFile.copy(backupPath);

      // Re-open and update provider
      objectBoxService.store = await openStore(directory: dbDirectoryPath);
      return backupPath;
    } catch (e) {
      print_log_red("Local Backup failed: $e");
      return null;
    }
  }

  /// --- RESTORE LOGIC ---
  Future<bool> restoreDatabase(BuildContext context, String backupFilePath) async {
    final objectBoxService = Provider.of<ObjectBoxService>(context, listen: false);
    Store store = objectBoxService.store;

    try {
      final dbDirectoryPath = store.directoryPath;
      store.close(); 

      // Remove lock file if it exists
      final lockFile = File(p.join(dbDirectoryPath, 'lock.mdb'));
      if (await lockFile.exists()) await lockFile.delete();

      final currentDbFile = File(p.join(dbDirectoryPath, 'data.mdb'));
      await File(backupFilePath).copy(currentDbFile.path);

      objectBoxService.store = await openStore(directory: dbDirectoryPath);
      return true;
    } catch (e) {
      print_log_red("Restore failed: $e");
      return false;
    }
  }

  /// --- HANDLERS ---
  void handleBackup(BuildContext context) async {
    final tempDir = await getTemporaryDirectory();
    final backupPath = p.join(tempDir.path, "backup", '${AppConstants.username}.mdb');

    final resultPath = await backupDatabase(context, backupPath);

    if (resultPath != null) {
      print_log("Local backup ready. Uploading...");
      bool isUploaded = await uploadBackupToServer(resultPath, context);
      
      if (isUploaded) {
        print_log("Cloud Backup Successful!");
      }
    }
  }

  void handleCloudRestore(BuildContext context) async {
    String fileName = "${AppConstants.username}.mdb"; 
    print_log("Downloading from cloud...");

    final localPath = await downloadBackupFile(fileName, context);

    if (localPath != null) {
      bool success = await restoreDatabase(context, localPath);
      if (success) {
        print_log("Restore complete! Restarting app is recommended.");
      }
    }
  }
}