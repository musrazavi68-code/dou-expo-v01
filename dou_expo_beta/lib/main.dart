import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const DouExpoApp());
}

class DouExpoApp extends StatelessWidget {
  const DouExpoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dou expo Beta',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF09090B),
      colorScheme: const ColorScheme.dark(primary: Color(0xFFFACC15), surface: Color(0xFF141418)),
      useMaterial3: true,
    ),
    home: const DouExpoHomeScreen(),
  );
}

class PatternItem {
  const PatternItem({required this.id, required this.name, required this.category, required this.colors, this.defaultBlend = BlendMode.screen});
  final String id, name, category;
  final List<Color> colors;
  final BlendMode defaultBlend;
}

const kPatternBank = <PatternItem>[
  PatternItem(id:'light_leak',name:'Light Leak',category:'Optics',colors:[Color(0xFFFF6B6B),Color(0xFFFFD166),Color(0xFF4ECDC4)]),
  PatternItem(id:'light_spot',name:'Light Spot',category:'Optics',colors:[Color(0xFFFFBE0B),Color(0xFFFB5607),Color(0xFFFF006E)],defaultBlend:BlendMode.colorDodge),
  PatternItem(id:'prism_flare',name:'Prism Flare',category:'Optics',colors:[Color(0xFF22D3EE),Color(0xFFA855F7),Color(0xFFF43F5E)]),
  PatternItem(id:'anamorphic_streak',name:'Anamorphic Streak',category:'Optics',colors:[Color(0xFF60A5FA),Color(0xFFFDE047),Color(0xFF38BDF8)],defaultBlend:BlendMode.lighten),
  PatternItem(id:'raindrops',name:'Raindrops',category:'Nature',colors:[Color(0xFF38BDF8),Color(0xFF818CF8),Color(0xFF0F172A)],defaultBlend:BlendMode.softLight),
  PatternItem(id:'branches',name:'Branches',category:'Nature',colors:[Color(0xFF334155),Color(0xFF94A3B8),Color(0xFF1E293B)],defaultBlend:BlendMode.darken),
  PatternItem(id:'mist_fog',name:'Mist & Fog',category:'Nature',colors:[Color(0xFFE2E8F0),Color(0xFF64748B)],defaultBlend:BlendMode.lighten),
  PatternItem(id:'bokeh_orb',name:'Bokeh Orb',category:'Nature',colors:[Color(0xFFFBBF24),Color(0xFFEC4899),Color(0xFF6366F1)]),
  PatternItem(id:'vignette',name:'Vignette',category:'Editorial',colors:[Colors.transparent,Color(0xCC000000)],defaultBlend:BlendMode.multiply),
  PatternItem(id:'duotone_sunset',name:'Duotone Sunset',category:'Editorial',colors:[Color(0xFFF97316),Color(0xFF9333EA)],defaultBlend:BlendMode.softLight),
];

class DouExpoHomeScreen extends StatefulWidget {
  const DouExpoHomeScreen({super.key});
  @override
  State<DouExpoHomeScreen> createState() => _DouExpoHomeScreenState();
}

class _DouExpoHomeScreenState extends State<DouExpoHomeScreen> with WidgetsBindingObserver {
  final _picker = ImagePicker();
  final _random = Random();
  final _renderBoundaryKey = GlobalKey();
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _cameraReady = false, _useLiveCamera = true, _isExporting = false;
  File? _photo;
  PatternItem? _activePattern = kPatternBank.first;
  double _transparency = .65, _filterIntensity = .5;
  int _blendIndex = 1, _ratioIndex = 0, _gradientDirIndex = 0;
  bool _luminantMode = false, _showGrid = true, _showWatermark = true, _fullResolution = true, _postStage = false;
  String _selectedFilterName = 'NORMAL';

  final _blendModes = const <(String,BlendMode)>[
    ('ALPHA BLEND',BlendMode.srcOver),('SOFT LIGHT',BlendMode.softLight),('MULTIPLY',BlendMode.multiply),
    ('LIGHTEN',BlendMode.lighten),('COLOR DODGE',BlendMode.colorDodge),('DIFFERENCE',BlendMode.difference),
    ('SCREEN',BlendMode.screen),('OVERLAY',BlendMode.overlay),('DARKEN',BlendMode.darken),
  ];
  final _ratios = const <(String,double)>[('1:1',1),('3:2',1.5),('4:3',4/3)];
  final _gradientDirs = const <(Alignment,Alignment)>[
    (Alignment.topCenter,Alignment.bottomCenter),(Alignment.bottomCenter,Alignment.topCenter),
    (Alignment.centerLeft,Alignment.centerRight),(Alignment.centerRight,Alignment.centerLeft),
    (Alignment.topLeft,Alignment.bottomRight),(Alignment.bottomRight,Alignment.topLeft),
    (Alignment.topRight,Alignment.bottomLeft),(Alignment.bottomLeft,Alignment.topRight),
  ];
  final _filterPresets = const ['NORMAL','MUME','BORAGO','HYACINTH','FRAGRANS','DISPORUM','GENTIANA','LILY','DELONIX','MYOSOTIS','TULIPA'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _cameraController;
    _cameraController = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final old = _cameraController;
      _cameraController = null;
      _cameraReady = false;
      old?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _useLiveCamera) {
      _setupCameraAt(_cameraIndex);
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty && _useLiveCamera) {
        await _setupCameraAt(_cameraIndex);
      } else if (mounted) {
        setState(() => _useLiveCamera = false);
      }
    } catch (e) {
      if (mounted) { setState(() => _useLiveCamera = false); _message('Camera unavailable: $e'); }
    }
  }

  Future<void> _setupCameraAt(int index) async {
    if (_cameras.isEmpty || !mounted) return;
    final old = _cameraController;
    _cameraController = null;
    if (mounted) setState(() => _cameraReady = false);
    await old?.dispose();
    final controller = CameraController(
      _cameras[index % _cameras.length],
      _fullResolution ? ResolutionPreset.high : ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      if (!mounted || !_useLiveCamera) { await controller.dispose(); return; }
      _cameraController = controller;
      _cameraIndex = index % _cameras.length;
      setState(() { _cameraReady = true; _useLiveCamera = true; });
    } on CameraException catch (e) {
      await controller.dispose();
      if (mounted) { setState(() { _cameraReady = false; _useLiveCamera = false; }); _message('Camera error: ${e.description ?? e.code}'); }
    }
  }

  Future<void> _toggleLiveCamera() async {
    if (_useLiveCamera) {
      final old = _cameraController;
      _cameraController = null;
      setState(() { _useLiveCamera = false; _cameraReady = false; });
      await old?.dispose();
    } else {
      setState(() => _useLiveCamera = true);
      if (_cameras.isEmpty) {
        await _initCameras();
      } else {
        await _setupCameraAt(_cameraIndex);
      }
    }
  }

  Future<void> _switchCameraLens() async {
    if (_cameras.length < 2) { _message('No second camera lens available'); return; }
    HapticFeedback.selectionClick();
    await _setupCameraAt((_cameraIndex + 1) % _cameras.length);
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (!_useLiveCamera || controller == null || !controller.value.isInitialized) {
      _message('Live camera is not ready'); return;
    }
    try {
      HapticFeedback.mediumImpact();
      final shot = await controller.takePicture();
      if (!mounted) return;
      setState(() { _photo = File(shot.path); _postStage = true; _useLiveCamera = false; _cameraReady = false; });
      _cameraController = null;
      await controller.dispose();
    } on CameraException catch (e) { _message('Capture failed: ${e.description ?? e.code}'); }
  }

  Future<void> _pickBaseImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (file == null || !mounted) return;
    final old = _cameraController;
    _cameraController = null;
    setState(() { _photo = File(file.path); _useLiveCamera = false; _cameraReady = false; _postStage = false; });
    await old?.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _randomizePattern() {
    HapticFeedback.mediumImpact();
    setState(() { _activePattern = kPatternBank[_random.nextInt(kPatternBank.length)]; _gradientDirIndex = _random.nextInt(8); });
  }

  void _cycleBlend(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _blendIndex = (_blendIndex + delta + _blendModes.length) % _blendModes.length);
  }

  ColorFilter _activePostColorFilter() {
    if (!_postStage || _selectedFilterName == 'NORMAL') return const ColorFilter.mode(Colors.transparent,BlendMode.dst);
    final k = _filterIntensity;
    final warm = _selectedFilterName == 'MUME' || _selectedFilterName == 'BORAGO';
    return ColorFilter.matrix(<double>[
      1+(warm ? .20 : -.08)*k,0,0,0,(warm ? 12 : 8)*k,
      0,1+(warm ? .08 : .05)*k,0,0,(warm ? 6 : 10)*k,
      0,0,1+(warm ? -.12 : .18)*k,0,(warm ? -4 : 14)*k,
      0,0,0,1,0,
    ]);
  }

  Future<Uint8List?> _renderPngBytes() async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _renderBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Render boundary is not ready');
      final ratio = _fullResolution ? 3.0 : 1.5;
      final ui.Image image = await boundary.toImage(pixelRatio: ratio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('PNG encoding returned no data');
        return data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes);
      } finally { image.dispose(); }
    } catch (e) { _message('Render failed: $e'); return null; }
  }

  Future<File?> _writePngFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/dou_expo_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes,flush:true);
    return file;
  }

  Future<void> _saveRenderedPhoto() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await _renderPngBytes();
      if (bytes == null) return;
      await Gal.putImageBytes(bytes,name:'dou_expo_${DateTime.now().millisecondsSinceEpoch}',album:'Dou expo Beta');
      _message('Rendered PNG saved to Gallery · Dou expo Beta');
    } catch (e) { _message('Gallery save failed: $e'); }
    finally { if (mounted) setState(() => _isExporting = false); }
  }

  Future<void> _shareRenderedPhoto() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await _renderPngBytes();
      if (bytes == null) return;
      final file = await _writePngFile(bytes);
      if (file != null) {
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)],
          text: 'Created with Dou expo Beta · $_selectedFilterName',
        ));
      }
    } catch (e) { _message('Share failed: $e'); }
    finally { if (mounted) setState(() => _isExporting = false); }
  }

  void _openPatternSheet() {
    showModalBottomSheet<void>(context:context,backgroundColor:const Color(0xFF121216),isScrollControlled:true,
      builder:(ctx)=>SafeArea(child:SizedBox(height:MediaQuery.of(ctx).size.height*.7,child:Column(children:[
        const Padding(padding:EdgeInsets.all(16),child:Text('PATTERN BANK',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:2))),
        Expanded(child:ListView.builder(itemCount:kPatternBank.length,itemBuilder:(_,i){
          final p=kPatternBank[i];
          return ListTile(
            leading:Container(width:54,height:38,decoration:BoxDecoration(borderRadius:BorderRadius.circular(8),gradient:LinearGradient(colors:p.colors))),
            title:Text(p.name),subtitle:Text(p.category),
            trailing:_activePattern?.id==p.id?const Icon(Icons.check_circle,color:Color(0xFFFACC15)):null,
            onTap:(){setState((){_activePattern=p;final idx=_blendModes.indexWhere((b)=>b.$2==p.defaultBlend);if(idx>=0)_blendIndex=idx;});Navigator.pop(ctx);},
          );
        })),
        TextButton.icon(onPressed:(){_randomizePattern();Navigator.pop(ctx);},icon:const Icon(Icons.casino),label:const Text('RANDOM PATTERN')),
      ]))));
  }

  void _openSettings() {
    showModalBottomSheet<void>(context:context,backgroundColor:const Color(0xFF121216),
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setModal)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Padding(padding:EdgeInsets.all(16),child:Text('DOU EXPO · SETTINGS')),
        SwitchListTile(title:const Text('Show Grid'),value:_showGrid,onChanged:(v){setModal(()=>_showGrid=v);setState(()=>_showGrid=v);}),
        SwitchListTile(title:const Text('App Watermark'),value:_showWatermark,onChanged:(v){setModal(()=>_showWatermark=v);setState(()=>_showWatermark=v);}),
        SwitchListTile(title:const Text('High Resolution Render'),value:_fullResolution,onChanged:(v)async{setModal(()=>_fullResolution=v);setState(()=>_fullResolution=v);if(_useLiveCamera)await _setupCameraAt(_cameraIndex);}),
      ]))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body:SafeArea(child:LayoutBuilder(builder:(context,c){
      final wide=c.maxWidth>=700;
      return wide
        ? Row(children:[Expanded(flex:6,child:_buildCanvas()),const VerticalDivider(width:1,color:Colors.white12),Expanded(flex:4,child:_postStage?_buildPostPanel():_buildCapturePanel())])
        : Column(children:[Expanded(child:_buildCanvas()),_postStage?_buildPostPanel():_buildCapturePanel()]);
    })));
  }

  Widget _buildBaseLayer() {
    final c=_cameraController;
    if (_useLiveCamera && _cameraReady && c!=null && c.value.isInitialized) {
      final size = c.value.previewSize;
      if (size == null) return CameraPreview(c);
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(c),
          ),
        ),
      );
    }
    if (_photo!=null) return Image.file(_photo!,fit:BoxFit.cover);
    return Container(color:const Color(0xFF111116),child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.camera_alt_outlined,size:46,color:Colors.white38),
      const SizedBox(height:10),Text(_useLiveCamera?'Starting camera…':'Choose a photo or start camera'),
      const SizedBox(height:10),Wrap(spacing:8,children:[
        OutlinedButton.icon(onPressed:_pickBaseImage,icon:const Icon(Icons.photo_library),label:const Text('Gallery')),
        if(!_useLiveCamera) FilledButton.icon(onPressed:_toggleLiveCamera,icon:const Icon(Icons.videocam),label:const Text('Live camera')),
      ]),
    ])));
  }

  Widget _buildCanvas() {
    final blend=_blendModes[_blendIndex],grad=_gradientDirs[_gradientDirIndex];
    return Column(children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),child:Row(children:[
        IconButton(onPressed:_openSettings,icon:const Icon(Icons.settings_outlined)),
        IconButton(onPressed:_openPatternSheet,icon:const Icon(Icons.auto_awesome_mosaic_outlined)),
        IconButton(onPressed:()=>setState(()=>_luminantMode=!_luminantMode),icon:Icon(Icons.contrast,color:_luminantMode?const Color(0xFFFACC15):null)),
        IconButton(onPressed:()=>setState(()=>_gradientDirIndex=(_gradientDirIndex+1)%8),icon:const Icon(Icons.gradient)),
        IconButton(onPressed:_toggleLiveCamera,icon:Icon(_useLiveCamera?Icons.videocam:Icons.photo_outlined,color:_useLiveCamera?const Color(0xFFFACC15):null)),
        IconButton(onPressed:_switchCameraLens,icon:const Icon(Icons.cameraswitch_outlined)),
        const Spacer(),
        TextButton(onPressed:()=>setState(()=>_ratioIndex=(_ratioIndex+1)%3),child:Text(_ratios[_ratioIndex].$1)),
      ])),
      Expanded(child:Center(child:Padding(padding:const EdgeInsets.all(12),child:AspectRatio(aspectRatio:_ratios[_ratioIndex].$2,
        child:GestureDetector(
          onHorizontalDragEnd:(d){final v=d.primaryVelocity??0;if(v.abs()>120)_cycleBlend(v<0?1:-1);},
          child:RepaintBoundary(key:_renderBoundaryKey,child:ClipRRect(borderRadius:BorderRadius.circular(20),child:ColorFiltered(
            colorFilter:_activePostColorFilter(),
            child:Stack(fit:StackFit.expand,children:[
              _buildBaseLayer(),
              if(_activePattern!=null)AnimatedOpacity(duration:const Duration(milliseconds:160),opacity:_transparency.clamp(.05,1),
                child:ColorFiltered(colorFilter:ColorFilter.mode(Colors.white.withValues(alpha:_luminantMode ? .65 : 1),blend.$2),
                  child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:grad.$1,end:grad.$2,colors:_activePattern!.colors))))),
              if(_showGrid)IgnorePointer(child:CustomPaint(painter:_GridPainter())),
              Positioned(top:10,left:10,child:_pill('DOU EXPO · BETA')),
              Positioned(top:10,right:10,child:_pill(blend.$1)),
              if(_showWatermark)const Positioned(bottom:10,right:12,child:Text('DOU EXPO BETA',style:TextStyle(fontSize:10,letterSpacing:1.5,color:Colors.white54))),
            ]),
          ))),
        ),
      )))),
    ]);
  }

  Widget _pill(String t)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white12)),child:Text(t,style:const TextStyle(fontSize:10,letterSpacing:1)));

  Widget _buildCapturePanel()=>Container(padding:const EdgeInsets.fromLTRB(16,8,16,16),decoration:const BoxDecoration(color:Color(0xFF121216),borderRadius:BorderRadius.vertical(top:Radius.circular(22))),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Row(children:[const Text('PATTERN OPACITY',style:TextStyle(fontSize:10,color:Colors.white60)),Expanded(child:Slider(value:_transparency,onChanged:(v)=>setState(()=>_transparency=v))),Text('${(_transparency*100).round()}%')]),
    Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
      IconButton(onPressed:_pickBaseImage,icon:const Icon(Icons.photo_library_outlined)),
      IconButton(onPressed:_randomizePattern,icon:const Icon(Icons.casino_outlined)),
      GestureDetector(onTap:_useLiveCamera?_capturePhoto:(_photo!=null?()=>setState(()=>_postStage=true):_toggleLiveCamera),child:Container(width:60,height:60,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:Colors.white,width:3),color:const Color(0xFFFACC15).withValues(alpha:.2)),child:Icon(_useLiveCamera?Icons.camera_alt_rounded:Icons.check_rounded))),
      IconButton(onPressed:()=>setState(()=>_activePattern=null),icon:const Icon(Icons.layers_clear)),
      IconButton(onPressed:_openPatternSheet,icon:const Icon(Icons.style_outlined)),
    ]),
    Text(_useLiveCamera?'Live camera · tap shutter to capture':'Photo mode · tap shutter to continue',style:const TextStyle(fontSize:10,color:Colors.white38)),
  ]));

  Widget _buildPostPanel()=>Container(padding:const EdgeInsets.fromLTRB(16,10,16,16),decoration:const BoxDecoration(color:Color(0xFF121216),borderRadius:BorderRadius.vertical(top:Radius.circular(22))),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Row(children:[
      IconButton(onPressed:()=>setState(()=>_postStage=false),icon:const Icon(Icons.undo_rounded)),
      Expanded(child:Slider(value:_filterIntensity,onChanged:(v)=>setState(()=>_filterIntensity=v))),
      IconButton(onPressed:_isExporting?null:_saveRenderedPhoto,icon:const Icon(Icons.save_alt,color:Color(0xFFFACC15))),
      IconButton(onPressed:_isExporting?null:_shareRenderedPhoto,icon:const Icon(Icons.share)),
    ]),
    SizedBox(height:40,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:_filterPresets.length,separatorBuilder:(_, _) => const SizedBox(width:7),itemBuilder:(_,i){
      final n=_filterPresets[i];return ChoiceChip(label:Text(n),selected:_selectedFilterName==n,onSelected:(_)=>setState(()=>_selectedFilterName=n));
    })),
    if(_isExporting)const LinearProgressIndicator(),
  ]));
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas,Size size) {
    final p=Paint()..color=Colors.white24..strokeWidth=.7;
    for(var i=1;i<3;i++){final x=size.width*i/3,y=size.height*i/3;canvas.drawLine(Offset(x,0),Offset(x,size.height),p);canvas.drawLine(Offset(0,y),Offset(size.width,y),p);}
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
