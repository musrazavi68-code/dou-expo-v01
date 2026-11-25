import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'exposure_composer.dart';
import 'studio_modes.dart';

void main() {
 WidgetsFlutterBinding.ensureInitialized();
 runApp(const DouExpoApp());
}
class DouExpoApp extends StatelessWidget {
 const DouExpoApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(
  title:'Dou Expo',debugShowCheckedModeBanner:false,
  theme:ThemeData(brightness:Brightness.dark,scaffoldBackgroundColor:const Color(0xFF09090B),
   colorScheme:const ColorScheme.dark(primary:Color(0xFFFACC15)),useMaterial3:true),
  home:const DouExpoShell());
}

class DouExpoShell extends StatefulWidget {
 const DouExpoShell({super.key});
 @override State<DouExpoShell> createState()=>_DouExpoShellState();
}
class _DouExpoShellState extends State<DouExpoShell> {
 int _index=0;
 @override Widget build(BuildContext context) {
  final pages=<Widget>[
   const OrdinaryCameraScreen(),
   const DouExpoEditor(),
   const DarkroomScreen(),
  ];
  return Scaffold(
   body:pages[_index],
   bottomNavigationBar:NavigationBar(
    backgroundColor:const Color(0xFF100D0C),
    indicatorColor:const Color(0xFFFACC15).withValues(alpha:.18),
    selectedIndex:_index,
    onDestinationSelected:(v)=>setState(()=>_index=v),
    destinations:const [
     NavigationDestination(icon:Icon(Icons.camera_alt_outlined),selectedIcon:Icon(Icons.camera_alt),label:'ORDINARY'),
     NavigationDestination(icon:Icon(Icons.layers_outlined),selectedIcon:Icon(Icons.layers),label:'DOUBLE'),
     NavigationDestination(icon:Icon(Icons.tune),selectedIcon:Icon(Icons.tune),label:'DARKROOM'),
    ],
   ),
  );
 }
}

class DouExpoEditor extends StatefulWidget {
 const DouExpoEditor({super.key});
 @override State<DouExpoEditor> createState()=>_DouExpoEditorState();
}
class _DouExpoEditorState extends State<DouExpoEditor> with WidgetsBindingObserver {
 final _picker=ImagePicker();
 final GlobalKey _previewKey=GlobalKey();
 CameraController? _camera;
 List<CameraDescription> _cameras=[];
 ui.Image? _base,_overlay;
 bool _cameraOpen=false,_cameraReady=false,_busy=false,_capturePending=false,_cameraStarting=false;
 double _cameraEv=0;
 int _selfTimer=0;
 double _mix=.78,_baseEv=-.7,_overlayEv=.15,_scale=1,_gestureStartScale=1;
 Offset _offset=Offset.zero,_gestureStartOffset=Offset.zero,_gestureStartFocalPoint=Offset.zero;
 final List<MaskStroke> _maskStrokes=[];
 Path? _activeMaskPath;
 bool _maskEdit=false,_eraseBrush=false;
 double _brushSize=.035,_maskFeather=0;
 StencilKind _stencil=StencilKind.none;
 StencilFillMode _stencilFill=StencilFillMode.photo;
 Color _stencilTint=const Color(0xFFFF8A00);
 double _contrast=1,_saturation=1,_effectAmount=.35;
 FilmEffect _filmEffect=FilmEffect.none;
 int _blend=0,_cameraIndex=0;
 OverlayMaskMode _maskMode=OverlayMaskMode.fullFrame;
 static const _modes=< (String,BlendMode) >[
  ('BRIGHT / SCREEN',BlendMode.screen),('LIGHTEN',BlendMode.lighten),('ADD',BlendMode.plus),
  ('OVERLAY',BlendMode.overlay),('SOFT LIGHT',BlendMode.softLight),('MULTIPLY',BlendMode.multiply),
  ('DIFFERENCE',BlendMode.difference),('NORMAL',BlendMode.srcOver)];
 static const _ratios=< (String,double) >[
  ('Original',0),('1:1',1),('3:2',1.5),('4:5',.8),('16:9',16/9)];
 @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_startCamera();}
 @override void dispose(){WidgetsBinding.instance.removeObserver(this);_camera?.dispose();_base?.dispose();_overlay?.dispose();super.dispose();}
 @override void didChangeAppLifecycleState(AppLifecycleState s){
  if(s==AppLifecycleState.paused||s==AppLifecycleState.inactive){final c=_camera;_camera=null;_cameraReady=false;c?.dispose();if(mounted)setState((){});}
  if(s==AppLifecycleState.resumed&&_cameraOpen&&_camera==null)_startCamera();
 }
 Future<void> _startCamera() async {
  if(_cameraStarting||_camera!=null)return;
  _cameraStarting=true;_cameraOpen=true;
  CameraController? candidate;
  try{
   _cameras=await availableCameras();if(_cameras.isEmpty){_cameraOpen=false;return;}
   candidate=CameraController(_cameras[_cameraIndex % _cameras.length],ResolutionPreset.high,enableAudio:false);
   await candidate.initialize();
   if(!mounted||!_cameraOpen){await candidate.dispose();return;}
   setState(()=>_camera=candidate);
   setState(()=>_cameraReady=true);
  }catch(e){await candidate?.dispose();_cameraOpen=false;_toast('Camera: '+e.toString());}
  finally{_cameraStarting=false;}
 }
 void _toast(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 Future<void> _load(bool second) async {
  final x=await _picker.pickImage(source:ImageSource.gallery,imageQuality:100);if(x==null)return;
  try{final im=await ExposureComposer.decode(await File(x.path).readAsBytes());if(!mounted){im.dispose();return;}
   setState((){if(second){_overlay?.dispose();_overlay=im;_offset=Offset.zero;_scale=1;}else{_base?.dispose();_base=im;}});
   if(!second){final c=_camera;_camera=null;_cameraOpen=false;_cameraReady=false;await c?.dispose();}
  }catch(e){_toast('Image load failed: '+e.toString());}
 }
 Future<void> _setCameraEv(double value) async {
  final c=_camera;if(c==null||!c.value.isInitialized)return;
  try{final actual=await c.setExposureOffset(value);if(mounted)setState(()=>_cameraEv=actual);}
  catch(e){_toast('Exposure compensation unavailable: '+e.toString());}
 }
 Future<void> _capture() async {
  final c=_camera;if(c==null||!c.value.isInitialized||_capturePending){_toast('Camera not ready');return;}
  try{
   if(_selfTimer>0){setState(()=>_capturePending=true);_toast('Capture in '+_selfTimer.toString()+' seconds');await Future.delayed(Duration(seconds:_selfTimer));}
   if(!mounted||_camera!=c)return;
   final x=await c.takePicture();final im=await ExposureComposer.decode(await File(x.path).readAsBytes());
   if(!mounted){im.dispose();return;}
   setState((){if(_base==null){_base=im;}else{_overlay?.dispose();_overlay=im;_offset=Offset.zero;_scale=1;}});
   _camera=null;_cameraOpen=false;_cameraReady=false;await c.dispose();
  }catch(e){_toast('Capture failed: '+e.toString());}finally{if(mounted)setState(()=>_capturePending=false);}
 }
 Future<void> _toggleCamera() async {
  if(_cameraOpen){final c=_camera;_camera=null;setState((){_cameraOpen=false;_cameraReady=false;});await c?.dispose();}
  else{_cameraOpen=true;await _startCamera();}
 }
 Future<void> _switchLens() async {
  if(_cameras.length<2){_toast('No second camera lens');return;}
  final old=_camera;_camera=null;await old?.dispose();
  _cameraIndex=(_cameraIndex+1)%_cameras.length;
  final next=CameraController(_cameras[_cameraIndex],ResolutionPreset.high,enableAudio:false);
  try{await next.initialize();if(!mounted){await next.dispose();return;}
   setState((){_camera=next;_cameraOpen=true;_cameraReady=true;});
  }catch(e){await next.dispose();_toast('Lens switch failed: '+e.toString());}
 }
 Future<Uint8List> _render(double ratio,int maxSide) async {
  final b=_base;if(b==null)throw StateError('Choose first photo');
  final r=ratio==0?b.width/b.height:ratio;
  final side=maxSide==0?math.max(b.width,b.height):maxSide;
  final w=(r>=1?side:math.max(1,(side*r).round())).toInt();
  final h=(r>=1?math.max(1,(side/r).round()):side).toInt();
  return ExposureComposer.renderPng(base:b,overlay:_overlay,width:w,height:h,
   blendMode:_modes[_blend].$2,mix:_mix,baseEv:_baseEv,overlayEv:_overlayEv,
   overlayOffset:_offset,overlayScale:_scale,maskMode:_maskMode,maskFeather:_maskFeather*40,maskStrokes:_maskStrokes,stencil:_stencil,stencilFillMode:_stencilFill,stencilTint:_stencilTint,contrast:_contrast,saturation:_saturation,filmEffect:_filmEffect,effectAmount:_effectAmount);
 }
 Future<void> _export() async {
  if(_base==null||_busy){_toast('Choose first photo');return;}
  var ri=0,si=0;var unit='px',cm=30.0,dpi=300,format='PNG';const sizes=< (String,int) >[('Original size',0),('2048 px',2048),('4096 px',4096)];
  await showModalBottomSheet<void>(context:context,backgroundColor:const Color(0xFF17171B),
   builder:(ctx)=>StatefulBuilder(builder:(ctx,ss)=>SafeArea(child:Padding(padding:const EdgeInsets.all(18),
    child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     const Text('EXPORT · RATIO · SIZE',style:TextStyle(fontWeight:FontWeight.bold)),
     const SizedBox(height:12),const Text('Aspect ratio'),
     Wrap(spacing:6,children:List.generate(_ratios.length,(i)=>ChoiceChip(label:Text(_ratios[i].$1),
      selected:ri==i,onSelected:(_)=>ss(()=>ri=i)))),
     const SizedBox(height:10),const Text('Output size unit'),
     Wrap(spacing:6,children:[
      ChoiceChip(label:const Text('Pixels'),selected:unit=='px',onSelected:(_)=>ss(()=>unit='px')),
      ChoiceChip(label:const Text('Centimeters'),selected:unit=='cm',onSelected:(_)=>ss(()=>unit='cm')),
     ]),
     if(unit=='px') DropdownButton<int>(value:sizes[si].$2,isExpanded:true,
      items:sizes.map((x)=>DropdownMenuItem(value:x.$2,child:Text(x.$1))).toList(),
      onChanged:(v){if(v!=null)ss(()=>si=sizes.indexWhere((x)=>x.$2==v));}),
     if(unit=='cm') ...[
      Text('Long edge: ${cm.toStringAsFixed(1)} cm · ${(cm/2.54*dpi).round()} px'),
      Slider(value:cm,min:5,max:60,divisions:55,onChanged:(v)=>ss(()=>cm=v)),
      Row(children:[const Text('Print DPI'),const Spacer(),DropdownButton<int>(value:dpi,
       items:const [72,150,300,600].map((v)=>DropdownMenuItem(value:v,child:Text('$v DPI'))).toList(),
       onChanged:(v){if(v!=null)ss(()=>dpi=v);})]),
     ],
     const SizedBox(height:8),const Text('File format'),
     Wrap(spacing:6,children:[
      ChoiceChip(label:const Text('PNG · lossless'),selected:format=='PNG',onSelected:(_)=>ss(()=>format='PNG')),
      ChoiceChip(label:const Text('JPEG · quality 95'),selected:format=='JPEG',onSelected:(_)=>ss(()=>format='JPEG')),
     ]),
     FilledButton.icon(onPressed:(){final outputSize=unit=='cm'?(cm/2.54*dpi).round():sizes[si].$2;
      final selectedFormat=format;Navigator.pop(ctx);_save(_ratios[ri].$2,outputSize,selectedFormat);},
      icon:const Icon(Icons.file_download),label:Text('EXPORT $format'))
    ])))));
 }
 Future<void> _save(double ratio,int size,String format) async {
  if(_busy)return;setState(()=>_busy=true);
  try{
   final pngBytes=await _render(ratio,size);
   Uint8List outputBytes=pngBytes;
   final extension=format=='JPEG'?'jpg':'png';
   if(format=='JPEG'){
    final decoded=img.decodeImage(pngBytes);
    if(decoded==null)throw StateError('Could not decode rendered image for JPEG export');
    outputBytes=Uint8List.fromList(img.encodeJpg(decoded,quality:95));
   }
   await Gal.putImageBytes(outputBytes,
    name:'dou_expo_'+DateTime.now().millisecondsSinceEpoch.toString()+'.'+extension,album:'Dou Expo');
   _toast(format+' saved to Gallery'+(format=='JPEG'?' · quality 95':' · lossless'));
  }catch(e){_toast('Export failed: '+e.toString());}finally{if(mounted)setState(()=>_busy=false);}
 }
 Future<void> _share() async {
  if(_base==null||_busy)return;setState(()=>_busy=true);
  try{final bytes=await _render(0,4096);final d=await getTemporaryDirectory();
   final f=File(d.path+'/dou_expo_'+DateTime.now().millisecondsSinceEpoch.toString()+'.png');
   await f.writeAsBytes(bytes,flush:true);await SharePlus.instance.share(ShareParams(files:[XFile(f.path)]));}
  catch(e){_toast('Share failed: '+e.toString());}finally{if(mounted)setState(()=>_busy=false);}
 }
 void _chooseBlend(){showModalBottomSheet<void>(context:context,backgroundColor:const Color(0xFF17171B),
  builder:(ctx)=>SafeArea(child:ListView(shrinkWrap:true,children:[
   const ListTile(title:Text('BLEND MODE'),subtitle:Text('How image two combines with image one')),
   for(var i=0;i<_modes.length;i++)ListTile(title:Text(_modes[i].$1),
    trailing:_blend==i?const Icon(Icons.check,color:Color(0xFFFACC15)):null,
    onTap:(){setState(()=>_blend=i);Navigator.pop(ctx);})
  ])));}
 void _reset(){setState((){_mix=.78;_baseEv=-.7;_overlayEv=.15;_contrast=1;_saturation=1;_filmEffect=FilmEffect.none;_effectAmount=.35;_scale=1;_offset=Offset.zero;_blend=0;_maskMode=OverlayMaskMode.fullFrame;_maskStrokes.clear();_activeMaskPath=null;});}
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('DOU EXPO',style:TextStyle(letterSpacing:2,fontWeight:FontWeight.bold)),
   actions:[IconButton(tooltip:'Export dimensions',onPressed:_export,icon:const Icon(Icons.ios_share)),
    IconButton(tooltip:'Share',onPressed:_share,icon:const Icon(Icons.share))]),
  body:SafeArea(child:LayoutBuilder(builder:(ctx,c){
   final wide=c.maxWidth>720;final preview=_preview();final controls=_controls();
   return wide?Row(children:[Expanded(flex:6,child:preview),const VerticalDivider(width:1),Expanded(flex:4,child:controls)])
    :Column(children:[Expanded(child:preview),controls]);
  })));
 Widget _preview(){
  final b=_base;
  return Column(children:[Expanded(child:Padding(padding:const EdgeInsets.all(12),
   child:ClipRRect(borderRadius:BorderRadius.circular(18),child:GestureDetector(
    onDoubleTap:_reset,
    onScaleStart:(d){
     _gestureStartScale=_scale;_gestureStartOffset=_offset;_gestureStartFocalPoint=d.focalPoint;
     if(!_maskEdit||_overlay==null)return;
     final box=_previewKey.currentContext?.findRenderObject() as RenderBox?;
     if(box==null||box.size.isEmpty)return;
     final point=box.globalToLocal(d.focalPoint);
     final normalized=Offset((point.dx/box.size.width).clamp(0.0,1.0),(point.dy/box.size.height).clamp(0.0,1.0));
     setState((){
      _activeMaskPath=Path()..moveTo(normalized.dx,normalized.dy);
      _maskStrokes.add(MaskStroke(path:_activeMaskPath!,width:_brushSize,erase:_eraseBrush));
     });
    },
    onScaleUpdate:(d){
     final box=_previewKey.currentContext?.findRenderObject() as RenderBox?;
     if(box==null||box.size.isEmpty)return;
     if(_maskEdit&&_overlay!=null){
      final point=box.globalToLocal(d.focalPoint);
      final normalized=Offset((point.dx/box.size.width).clamp(0.0,1.0),(point.dy/box.size.height).clamp(0.0,1.0));
      setState(()=>_activeMaskPath?.lineTo(normalized.dx,normalized.dy));
     }else if(_overlay!=null){
      setState((){
       _scale=(_gestureStartScale*d.scale).clamp(.2,5).toDouble();
       _offset=_gestureStartOffset+Offset((d.focalPoint.dx-_gestureStartFocalPoint.dx)/box.size.width,(d.focalPoint.dy-_gestureStartFocalPoint.dy)/box.size.height);
      });
     }
    },
    onScaleEnd:(d){_activeMaskPath=null;},
    child:CustomPaint(key:_previewKey,size:Size.infinite,painter:ExposurePreviewPainter(base:b,overlay:_overlay,
     blendMode:_modes[_blend].$2,mix:_mix,baseEv:_baseEv,overlayEv:_overlayEv,
     overlayOffset:_offset,overlayScale:_scale,maskMode:_maskMode,maskFeather:_maskFeather*40,maskStrokes:List<MaskStroke>.unmodifiable(_maskStrokes),stencil:_stencil,stencilFillMode:_stencilFill,stencilTint:_stencilTint,contrast:_contrast,saturation:_saturation,filmEffect:_filmEffect,effectAmount:_effectAmount),
     child:_cameraOpen && _cameraReady && _camera!=null
      ? CameraPreview(_camera!)
      :b==null?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
       const Icon(Icons.add_photo_alternate_outlined,size:48,color:Colors.white54),
       const Text('Choose your first photo'),FilledButton(onPressed:()=>_load(false),child:const Text('FIRST PHOTO'))]))
      :const SizedBox.expand())
   )))),
   if(b!=null)const Padding(padding:EdgeInsets.only(bottom:8),
    child:Text('Drag or pinch to move and scale image two · double tap to reset',
     style:TextStyle(fontSize:10,color:Colors.white54)))]);
 }
 Widget _button(IconData icon,String label,VoidCallback? fn)=>Expanded(child:TextButton(
  onPressed:fn,child:Column(mainAxisSize:MainAxisSize.min,children:[
   Icon(icon,color:const Color(0xFFFACC15)),Text(label,style:const TextStyle(fontSize:9),maxLines:1)])));
 Widget _slider(String name,double value,ValueChanged<double> fn,{String? text}){
  return Row(children:[SizedBox(width:105,child:Text(name,style:const TextStyle(fontSize:9,color:Colors.white60))),
   Expanded(child:Slider(value:value.clamp(0,1),onChanged:fn)),
   SizedBox(width:48,child:Text(text??(value*100).round().toString()+'%',
    textAlign:TextAlign.end,style:const TextStyle(fontSize:9)))]);
 }
 void _applyRecipe(String recipe){setState((){switch(recipe){
  case 'Classic':_filmEffect=FilmEffect.grain;_effectAmount=.22;_contrast=1.08;_saturation=.92;_baseEv=0;break;
  case 'Cinematic':_filmEffect=FilmEffect.grain;_effectAmount=.38;_contrast=1.28;_saturation=.78;_baseEv=-.25;break;
  case 'Noir':_filmEffect=FilmEffect.grain;_effectAmount=.32;_contrast=1.55;_saturation=0;_baseEv=-.35;break;
  case 'Vintage':_filmEffect=FilmEffect.grain;_effectAmount=.48;_contrast=1.12;_saturation=.82;_baseEv=.1;break;
  case 'Motion':_filmEffect=FilmEffect.scanlines;_effectAmount=.18;_contrast=1.12;_saturation=1;break;
  case 'Clean':_filmEffect=FilmEffect.none;_effectAmount=0;_contrast=1;_saturation=1;break;
 }});}
 Widget _controls()=>Container(padding:const EdgeInsets.fromLTRB(10,8,10,12),
  decoration:const BoxDecoration(color:Color(0xFF151519),borderRadius:BorderRadius.vertical(top:Radius.circular(18))),
  child:Column(mainAxisSize:MainAxisSize.min,children:[
   if(_cameraReady)...[
    Row(children:[const SizedBox(width:105,child:Text('CAMERA EV',style:TextStyle(fontSize:9,color:Colors.white60))),Expanded(child:Slider(value:_cameraEv.clamp(-2,2),min:-2,max:2,divisions:16,onChanged:_setCameraEv)),SizedBox(width:42,child:Text(_cameraEv.toStringAsFixed(1)+' EV',style:const TextStyle(fontSize:9)))]),
    Row(children:[const SizedBox(width:105,child:Text('SELF TIMER',style:TextStyle(fontSize:9,color:Colors.white60))),Expanded(child:Wrap(spacing:4,children:[0,3,5,10].map((v)=>ChoiceChip(label:Text(v==0?'OFF':v.toString()+'s'),selected:_selfTimer==v,onSelected:(_)=>setState(()=>_selfTimer=v))).toList()))]),
    const Padding(padding:EdgeInsets.only(bottom:5),child:Text('Single shutter capture · one camera exposure per tap',style:TextStyle(fontSize:9,color:Colors.white54))),
   ],
   Row(children:[
    _button(Icons.image_outlined,'FIRST PHOTO',()=>_load(false)),
    _button(Icons.layers_outlined,'PATTERN / 2ND',()=>_load(true)),
    _button(Icons.blender_outlined,'BLEND',_overlay==null?null:_chooseBlend),
    _button(Icons.camera_alt_outlined,'CAMERA',_toggleCamera),
    _button(Icons.flip_camera_android,'FLIP LENS',_switchLens),
    _button(Icons.camera,'CAPTURE',_cameraReady?_capture:null),
   ]),
   if(_overlay!=null)...[
    _slider('MIX / OPACITY',_mix,(v)=>setState(()=>_mix=v)),
    _slider('BASE EXPOSURE',(_baseEv+2)/4,(v)=>setState(()=>_baseEv=v*4-2),text:_baseEv.toStringAsFixed(1)+' EV'),
    _slider('SECOND EXPOSURE',(_overlayEv+2)/4,(v)=>setState(()=>_overlayEv=v*4-2),text:_overlayEv.toStringAsFixed(1)+' EV'),
    Row(children:[
     const SizedBox(width:105,child:Text('STENCIL',style:TextStyle(fontSize:9,color:Colors.white60))),
     Expanded(child:DropdownButton<StencilKind>(isExpanded:true,value:_stencil,
      items:const [
       DropdownMenuItem(value:StencilKind.none,child:Text('No stencil')),
       DropdownMenuItem(value:StencilKind.tree,child:Text('Tree silhouette')),
       DropdownMenuItem(value:StencilKind.cypress,child:Text('Cypress')),
       DropdownMenuItem(value:StencilKind.lotus,child:Text('Achaemenid lotus')),
       DropdownMenuItem(value:StencilKind.arch,child:Text('Persian arch')),
       DropdownMenuItem(value:StencilKind.wingedBull,child:Text('Winged bull')),
       DropdownMenuItem(value:StencilKind.senmurv,child:Text('Senmurv / Simurgh')),
       DropdownMenuItem(value:StencilKind.map,child:Text('Regional map')),
       DropdownMenuItem(value:StencilKind.flag,child:Text('Flag / banner')),
       DropdownMenuItem(value:StencilKind.monument,child:Text('Monument')),
       DropdownMenuItem(value:StencilKind.flame,child:Text('Flame')),
       DropdownMenuItem(value:StencilKind.hand,child:Text('Hand symbol')),
       DropdownMenuItem(value:StencilKind.brokenChain,child:Text('Broken chain')),
       DropdownMenuItem(value:StencilKind.people,child:Text('People / community')),
       DropdownMenuItem(value:StencilKind.skyline,child:Text('City skyline')),
       DropdownMenuItem(value:StencilKind.tower,child:Text('Tower')),
       DropdownMenuItem(value:StencilKind.carpet,child:Text('Carpet medallion')),
       DropdownMenuItem(value:StencilKind.lute,child:Text('Lute')),
       DropdownMenuItem(value:StencilKind.pomegranate,child:Text('Pomegranate')),
       DropdownMenuItem(value:StencilKind.laurel,child:Text('Laurel branch')),
       DropdownMenuItem(value:StencilKind.wreath,child:Text('Laurel wreath')),
       DropdownMenuItem(value:StencilKind.persianGuard,child:Text('Persian guard silhouette')),
       DropdownMenuItem(value:StencilKind.royalHead,child:Text('Royal profile')),
       DropdownMenuItem(value:StencilKind.lionShield,child:Text('Lion shield')),
      ],onChanged:(v)async{if(v==null)return;setState(()=>_stencil=v);
       final image=_overlay;if(image!=null){final color=await StencilLibrary.complementaryColor(image,stencil:_stencil);
        if(mounted)setState(()=>_stencilTint=color);}})),
     IconButton(tooltip:'Suggest stencil color from second image',onPressed:_overlay==null?null:()async{
      final color=await StencilLibrary.complementaryColor(_overlay!,stencil:_stencil);
      if(mounted){setState(()=>_stencilTint=color);_toast('Complementary color suggested');}
     },icon:const Icon(Icons.colorize,size:18)),
    ]),
    if(_stencil!=StencilKind.none)
     Row(children:[
      const SizedBox(width:105,child:Text('STENCIL MODE',style:TextStyle(fontSize:9,color:Colors.white60))),
      Expanded(child:Wrap(spacing:4,children:[
       ChoiceChip(label:const Text('PHOTO'),selected:_stencilFill==StencilFillMode.photo,onSelected:(_)=>setState(()=>_stencilFill=StencilFillMode.photo)),
       ChoiceChip(label:const Text('WHITE'),selected:_stencilFill==StencilFillMode.pureWhite,onSelected:(_)=>setState(()=>_stencilFill=StencilFillMode.pureWhite)),
       ChoiceChip(label:const Text('TINT'),selected:_stencilFill==StencilFillMode.tinted,onSelected:(_)=>setState(()=>_stencilFill=StencilFillMode.tinted)),
      ]))
     ]),
    if(_stencil!=StencilKind.none)
     Row(children:[
      const SizedBox(width:105,child:Text('SUGGESTED COLOR',style:TextStyle(fontSize:9,color:Colors.white60))),
      Container(width:25,height:25,decoration:BoxDecoration(color:_stencilTint,shape:BoxShape.circle,border:Border.all(color:Colors.white54))),
      const SizedBox(width:8),Text('#'+_stencilTint.toARGB32().toRadixString(16).substring(2).toUpperCase()),
      const Spacer(),TextButton(onPressed:()=>setState(()=>_stencilTint=Colors.white),child:const Text('SET WHITE')),
     ]),
    Row(children:[
     const SizedBox(width:105,child:Text('2ND IMAGE MASK',style:TextStyle(fontSize:9,color:Colors.white60))),
     Expanded(child:Wrap(spacing:4,children:[
      ChoiceChip(label:const Text('FULL'),selected:_maskMode==OverlayMaskMode.fullFrame,
       onSelected:(_)=>setState(()=>_maskMode=OverlayMaskMode.fullFrame)),
      ChoiceChip(label:const Text('INSIDE'),selected:_maskMode==OverlayMaskMode.insidePortrait,
       onSelected:(_)=>setState(()=>_maskMode=OverlayMaskMode.insidePortrait)),
      ChoiceChip(label:const Text('OUTSIDE'),selected:_maskMode==OverlayMaskMode.outsidePortrait,
       onSelected:(_)=>setState(()=>_maskMode=OverlayMaskMode.outsidePortrait)),
     ]))
    ]),
    Row(children:[
     const SizedBox(width:105,child:Text('MASK EDIT',style:TextStyle(fontSize:9,color:Colors.white60))),
     Expanded(child:SwitchListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text(_maskEdit?'Brush active':'Edit mask'),value:_maskEdit,onChanged:(v)=>setState(()=>_maskEdit=v))),
     IconButton(tooltip:'Undo mask stroke',onPressed:_maskStrokes.isEmpty?null:()=>setState(()=>_maskStrokes.removeLast()),icon:const Icon(Icons.undo,size:18)),
     IconButton(tooltip:'Clear mask strokes',onPressed:_maskStrokes.isEmpty?null:()=>setState(()=>_maskStrokes.clear()),icon:const Icon(Icons.delete_outline,size:18)),
    ]),
    Row(children:[
     Expanded(child:TextButton(onPressed:()=>setState(()=>_eraseBrush=false),child:Text('BRUSH',style:TextStyle(color:_eraseBrush?Colors.white54:const Color(0xFFFACC15))))),
     Expanded(child:TextButton(onPressed:()=>setState(()=>_eraseBrush=true),child:Text('ERASER',style:TextStyle(color:_eraseBrush?const Color(0xFFFACC15):Colors.white54)))),
    ]),
    _slider('BRUSH SIZE',_brushSize/.12,(v)=>setState(()=>_brushSize=v*.12),text:(_brushSize*100).round().toString()+'%'),
    _slider('EDGE FEATHER',_maskFeather,(v)=>setState(()=>_maskFeather=v)),
    if(_maskMode!=OverlayMaskMode.fullFrame)
     const Padding(padding:EdgeInsets.only(bottom:4),child:Text('Portrait silhouette mask · brush to reveal or erase image two · undo supported',style:TextStyle(fontSize:9,color:Colors.white54))),
    const Divider(height:12),
    const Align(alignment:Alignment.centerLeft,child:Text('FILM RECIPES',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:Colors.white70))),
    Wrap(spacing:5,runSpacing:2,children:['Classic','Cinematic','Noir','Vintage','Motion','Clean'].map((name)=>ActionChip(label:Text(name),onPressed:()=>_applyRecipe(name))).toList()),
    const Align(alignment:Alignment.centerLeft,child:Text('PHOTO FINISH',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:Colors.white70))),
    _slider('CONTRAST',_contrast/2,(v)=>setState(()=>_contrast=v*2),text:_contrast.toStringAsFixed(2)),
    _slider('SATURATION',_saturation/2,(v)=>setState(()=>_saturation=v*2),text:_saturation.toStringAsFixed(2)),
    Row(children:[
     const SizedBox(width:105,child:Text('FILM EFFECT',style:TextStyle(fontSize:9,color:Colors.white60))),
     Expanded(child:DropdownButton<FilmEffect>(isExpanded:true,value:_filmEffect,
      items:const [
       DropdownMenuItem(value:FilmEffect.none,child:Text('None')),
       DropdownMenuItem(value:FilmEffect.grain,child:Text('Film grain')),
       DropdownMenuItem(value:FilmEffect.scanlines,child:Text('Scanlines / shutter')),
      ],onChanged:(v){if(v!=null)setState(()=>_filmEffect=v);})),
    ]),
    if(_filmEffect!=FilmEffect.none)
     _slider('EFFECT AMOUNT',_effectAmount,(v)=>setState(()=>_effectAmount=v)),
    Row(children:[Expanded(child:Text('MODE: '+_modes[_blend].$1,style:const TextStyle(fontSize:9,color:Colors.white60))),
     TextButton(onPressed:_reset,child:const Text('RESET')),
     TextButton(onPressed:(){setState((){_overlay?.dispose();_overlay=null;});},child:const Text('REMOVE 2ND'))])
   ]else const Padding(padding:EdgeInsets.all(10),child:Text('PATTERN / 2ND PHOTO adds the second exposure image',
    style:TextStyle(fontSize:10,color:Colors.white54))),
   Row(children:[Expanded(child:OutlinedButton.icon(onPressed:_base==null?null:_export,icon:const Icon(Icons.file_download),
    label:const Text('EXPORT · RATIO · SIZE'))),const SizedBox(width:8),
    FilledButton(onPressed:_share,child:_busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.share))]),
   if(_busy)const LinearProgressIndicator()
  ]));
}
