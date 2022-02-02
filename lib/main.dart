import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebasestoragetest/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
  );
  runApp(const TestApp());
}

class TestApp extends StatefulWidget {
  const TestApp({Key? key}) : super(key: key);

  @override
  _TestAppState createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  final List<UploadTask> task = [];

  Future<void> compressLowRes(String file) async {
    print("Compress low res file");
    await VideoCompress.compressVideo(path: file,
        includeAudio: true, quality: VideoQuality.Res640x480Quality, output: file+"-low-compressed.mp4");
  }

  Future<void> compress(String file) async {
    print("Compress main file");
    await VideoCompress.compressVideo(path: file, output: file + "-compressed.mp4",
        includeAudio: true, quality: VideoQuality.Res960x540Quality);
  }

  Future<String> saveTempFile(
      {required File current, bool lowRes = false}) async {
    print("Saving temp file low res : $lowRes");
    Directory dir = await getApplicationDocumentsDirectory();
    Directory dev = Directory(dir.path + "/dev");
    if (!dev.existsSync()) {
      dev.createSync();
    }
    File file = File(dev.path + "/" + const Uuid().v1() + ".mp4");
    file.writeAsBytes(current.readAsBytesSync());
    return file.path;
  }

  void clearDir() async {
    Directory dir = await getApplicationDocumentsDirectory();
    Directory dev = Directory(dir.path + "/dev");
    if (dev.existsSync()) {
      dev.delete(recursive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              itemBuilder: (ctx, index) {
                return ShowUploadWidget(task: task[index], count: task.length);
              },
              itemCount: task.length,
            ),
            if (task.length <= 30)
              Center(
                child: GestureDetector(
                  onTap: () async {
                    XFile? picked = await ImagePicker()
                        .pickVideo(source: ImageSource.gallery);
                    if (picked != null) {
                      for (int i = 0; i < 30; i++) {
                        String low = await saveTempFile(current: File(picked.path), lowRes: true);
                        String file = await saveTempFile(current: File(picked.path));
                        await compressLowRes(low);
                        await compress(file);
                        UploadTask lowTask = FirebaseStorage.instance
                            .ref()
                            .child("test")
                            .child(const Uuid().v1() + "-low")
                            .putFile(File(low));
                        UploadTask main = FirebaseStorage.instance
                            .ref()
                            .child("test")
                            .child(const Uuid().v1())
                            .putFile(File(file));
                        main.catchError((error) {

                        });
                        task.add(lowTask);
                        task.add(main);
                      }
                      setState(() {});
                    }
                  },
                  child: Container(
                    width: 200,
                    height: 200,
                    color: Colors.blue,
                    child: const Center(child: Text("Pick video")),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ShowUploadWidget extends StatefulWidget {
  const ShowUploadWidget({Key? key, required this.task, required this.count})
      : super(key: key);

  final UploadTask task;
  final int count;

  @override
  State<ShowUploadWidget> createState() => _ShowUploadWidgetState();
}

class _ShowUploadWidgetState extends State<ShowUploadWidget> {
  double progress = 0;
  late StreamSubscription subscription;

  String? error;

  void initListener() {
    subscription = widget.task.snapshotEvents.listen((event) {
      setState(() {
        progress = event.bytesTransferred / event.totalBytes * 100;
        print("Progress for task : ${widget.count} : $progress %");
      });
    });
    widget.task.catchError((e) {
      setState(() {
        error = e;
      });
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  void initState() {
    initListener();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: error != null ? Text("Error : $error") : Text("Uploading : $progress"),
    );
  }
}
