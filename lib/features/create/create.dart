import 'dart:async';
import 'dart:io';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mypug/components/assetthumbnail/assetthumbnail.dart';
import 'package:mypug/components/design/design.dart';
import 'package:mypug/service/themenotifier.dart';
import 'package:mypug/util/util.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:super_tooltip/super_tooltip.dart';

import '../../components/editpug/editpug.dart';

class CreatePug extends StatefulWidget {
  final routeName = '/create';

  const CreatePug({Key? key}) : super(key: key);

  @override
  CreatePugState createState() => CreatePugState();
}

class CreatePugState extends State<CreatePug> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final ImagePicker _picker = ImagePicker();
  File? imageFile;
  Future<File?>? selectedImage;
  StreamController imageStreamController = StreamController();
  List<AssetEntity> assets = [];
  late ThemeModel notifier;
  late SuperTooltip tooltip;
  late bool isCrop = true;
  var varImagesGallery = null;
  late String isNotFirstUse;
  final _controller = CropController();


  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tooltip = SuperTooltip(
        popupDirection: TooltipDirection.up,
        showCloseButton: ShowCloseButton.inside,
        borderRadius: 30,
        minWidth: 200,
        maxWidth: 320,
        maxHeight: 100,
        minHeight: 100,
        shadowColor: APPCOLOR,
        content: Material(
            color: Colors.transparent,
            child: Center(
                child: Text(
                  "Choisissez une image nette",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: notifier.isDark ? Colors.black : Colors.black),
                  softWrap: true,
                ))),
      );

      getUserFirstUse().then((value) async =>
      {
        if (value.isNotEmpty && value.length < 5)
          {
            tooltip.show(context),
          }
      });
    });
    super.initState();
    getGalleryImages();
  }

  requestAccess() async {
    PermissionStatus status;
    status = await Permission.storage.status;
    if (status.isDenied) {
    }
  }

  getGalleryImages() async {
    await _fetchAssets();
    varImagesGallery = imagesGallery();
  }

  _fetchAssets() async {
    final albums = await PhotoManager.getAssetPathList(onlyAll: true);
    final recentAlbum = albums.first;

    final recentAssets = await recentAlbum.getAssetListRange(
      start: 0,
      end: 50,
    );

    await recentAssets[0].file.then((value) => {imageFile = value});

    setState(() =>
    {
      assets = recentAssets,
      imageFile,
      imageStreamController.add(imageFile),
    });
  }

  _imgFromCamera() async {
    XFile? image =
    await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);

    setState(() {
      imageFile = File(image!.path);
    });
  }

  _imgFromGallery() async {
    XFile? image =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    setState(() {
      imageFile = File(image!.path);
    });
  }

  callBack(Future<File?> file) async {
    imageFile = await file;
    file.then((value) =>
    {
      setState(
            () {
          selectedImage = file;
          imageFile;
          imageStreamController.add(imageFile);
        },
      )
    });
  }

  basicRender() {
    return SizedBox(
      //TODO : Double check for image length
      width: 500,
      height: 45 * MediaQuery
          .of(context)
          .size
          .height / 100,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child:
        Image.file(imageFile!, fit: isCrop ? BoxFit.cover : BoxFit.contain),
      ),
    );
  }

  basicRenderCrop() {
    return SizedBox(
      height: 45 * MediaQuery
          .of(context)
          .size
          .height / 100,
      child: Crop(
        controller: _controller,
        key: UniqueKey(),
        //TODO : Double check for image length
        image: imageFile!.readAsBytesSync(),
        //TODO : interractive stand for crop mode
        initialAreaBuilder: (rect) =>
            Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom),
        baseColor: Colors.black54,
        interactive: !isCrop,
        cornerDotBuilder: (size, edgeAlignment) => const SizedBox.shrink(),
        onCropped: (image) async {
          File newfile = await _localFile;
          imageFile = await newfile.writeAsBytes(image);
          setState(() {});
          // navigateTo(context, EditPug.withFile(file: newfile, isCrop: !isCrop));
        },
      ),
    );
  }

  Future<String> createFolderInAppDocDir() async {
    //Get this App Document Directory
    final Directory _appDocDir = await getApplicationDocumentsDirectory();
    // print(_appDocDir);
    //App Document Directory + folder name
    final Directory _appDocDirFolder =
    Directory('${_appDocDir.path}/images_tmp');

    if (await _appDocDirFolder.exists()) {
      //if folder already exists return path
      return _appDocDirFolder.path;
    } else {
      //if folder not exists create folder and then return its path
      final Directory _appDocDirNewFolder =
      await _appDocDirFolder.create(recursive: true);
      return _appDocDirNewFolder.path;
    }
  }

  Widget imageView() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: StreamBuilder<dynamic>(
        stream: imageStreamController.stream,
        builder: (_, snapshot) {
          if (imageFile == null) {
            return Container();
          } else {
            // return basicRenderCrop();
            return basicRender();
          }
        },
      ),
    );
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/tmp_image.png');
  }

  Future<File?> writeData() async {
    final file = await _localFile;
    if (!file.existsSync()) {
      final newFile = await _localFile;
      return newFile.writeAsString("test", mode: FileMode.write);
    }
    ;
    return null;
  }

  Widget imageButtonOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            ElevatedButton(
              style: BaseButtonRoundedColor(60, 40, Colors.indigo[300]),
              onPressed: () {
                _imgFromGallery();
              },
              child: Text('Galerie'),
            ),
            ElevatedButton(
              style: BaseButtonRoundedColor(60, 40, Colors.indigo[300]),
              onPressed: () {
                _imgFromCamera();
              },
              child: Text('Photo'),
            ),
            IconButton(
                onPressed: () {
                  setState(() {
                    isCrop = !isCrop;
                  });
                },
                icon: const Icon(Icons.crop))
          ],
        ),
        ElevatedButton(
            style: BaseButtonRoundedColor(60, 40, Colors.indigo[300]),
            onPressed: () {
              // _controller.crop();
              navigateTo(context, EditPug.withFile(file: imageFile, isCrop: isCrop));
            },
            child: const Text('Valider'))
      ],
    );
  }

  Widget imagesGallery() {
    return Expanded(
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          itemCount: assets.length,
          itemBuilder: (_, index) {
            return AssetThumbnail(
              asset: assets[index],
              callback: callBack,
            );
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModel>(
      builder: (context, ThemeModel notifier, child) {
        this.notifier = notifier;
        return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: Text("Créer"),
              automaticallyImplyLeading: false,
              backgroundColor: Colors.black,
            ),
            body: Container(
              decoration: BoxDecoration(),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  child: Column(
                    children: <Widget>[
                      imageView(),
                      imageButtonOption(),
                      varImagesGallery ??
                          const SizedBox(
                            width: 0,
                          ),
                    ],
                  ),
                  decoration: BoxCircular(notifier),
                ),
              ),
            ));
      },
    );
  }
}
