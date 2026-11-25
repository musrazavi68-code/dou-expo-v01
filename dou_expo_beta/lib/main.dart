import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'exposure_composer.dart';

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
  home:const DouExpoEditor());
}
class DouExpoEditor extends StatefulWidget {
 const DouExpoEditor({super.key});
 @override State<DouExpoEditor> createState()=>_DouExpoEditorState();
}
class _DouExpoEditorState extends State<DouExpoEditor> with WidgetsBindingObserver {
 final _picker=ImagePicker();
 CameraController? _camera;
 List<CameraDescription> _cameras=[];
 ui.Image? _base,_overlay;
 bool _cameraOpen=false,_cameraReady=false,_busy=false;
 double _mix=.78,_baseEv=-.7,_overlayEv=.15,_scale=1,_scaleStart=1;
 Offset _offset=Offset.zero;
 int _blend=0,_cameraIndex=0;
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
  if(s==AppLifecycleState.resumed&&_cameraOpen)_startCamera();
 }
 Future<void> _startCamera() async {
  try{_cameras=await availableCameras();if(_cameras.isEmpty)return;
   final c=CameraController(_cameras[_cameraIndex % _cameras.length],ResolutionPreset.high,enableAudio:false);
   await c.initialize();if(!mounted){await c.dispose();return;}
   setState((){_camera=c;_cameraReady=true;_cameraOpen=true;});
  }catch(e){_toast('Camera: '+e.toString());}
 }
 void _toast(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 Future<void> _load(bool second) async {
  final x=await _picker.pickImage(source:ImageSource.gallery,imageQuality:100);if(x==null)return;
  try{final im=await ExposureComposer.decode(await File(x.path).readAsBytes());if(!mounted){im.dispose();return;}
   setState((){if(second){_overlay?.dispose();_overlay=im;_offset=Offset.zero;_scale=1;}else{_base?.dispose();_base=im;}});
   if(!second){final c=_camera;_camera=null;_cameraOpen=false;_cameraReady=false;await c?.dispose();}
  }catch(e){_toast('Image load failed: '+e.toString());}
 }
 Future<void> _capture() async {
  final c=_camera;if(c==null||!c.value.isInitialized){_toast('Camera not ready');return;}
  try{final x=await c.takePicture();final im=await ExposureComposer.decode(await File(x.path).readAsBytes());
   if(!mounted){im.dispose();return;}
   setState((){if(_base==null){_base=im;}else{_overlay?.dispose();_overlay=im;_offset=Offset.zero;_scale=1;}});
   _camera=null;_cameraOpen=false;_cameraReady=false;await c.dispose();
  }catch(e){_toast('Capture failed: '+e.toString());}
 }
 Future<void> _toggleCamera() async {
  if(_cameraOpen){final c=_camera;_camera=null;setState((){_cameraOpen=false;_cameraReady=false;});await c?.dispose();}
  else{await _startCamera();}
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
   overlayOffset:_offset,overlayScale:_scale);
 }
 Future<void> _export() async {
  if(_base==null||_busy){_toast('Choose first photo');return;}
  var ri=0,si=0;const sizes=< (String,int) >[('Original size',0),('2048 px',2048),('4096 px',4096)];
  await showModalBottomSheet<void>(context:context,backgroundColor:const Color(0xFF17171B),
   builder:(ctx)=>StatefulBuilder(builder:(ctx,ss)=>SafeArea(child:Padding(padding:const EdgeInsets.all(18),
    child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     const Text('EXPORT · RATIO · SIZE',style:TextStyle(fontWeight:FontWeight.bold)),
     const SizedBox(height:12),const Text('Aspect ratio'),
     Wrap(spacing:6,children:List.generate(_ratios.length,(i)=>ChoiceChip(label:Text(_ratios[i].$1),
      selected:ri==i,onSelected:(_)=>ss(()=>ri=i)))),
     const SizedBox(height:10),const Text('Maximum output dimension'),
     DropdownButton<int>(value:sizes[si].$2,isExpanded:true,
      items:sizes.map((x)=>DropdownMenuItem(value:x.$2,child:Text(x.$1))).toList(),
      onChanged:(v){if(v!=null)ss(()=>si=sizes.indexWhere((x)=>x.$2==v));}),
     FilledButton.icon(onPressed:(){Navigator.pop(ctx);_save(_ratios[ri].$2,sizes[si].$2);},
      icon:const Icon(Icons.file_download),label:const Text('EXPORT PNG'))
    ])))));
 }
 Future<void> _save(double ratio,int size) async {
  if(_busy)return;setState(()=>_busy=true);
  try{final bytes=await _render(ratio,size);await Gal.putImageBytes(bytes,
   name:'dou_expo_'+DateTime.now().millisecondsSinceEpoch.toString(),album:'Dou Expo');_toast('PNG saved to Gallery');}
  catch(e){_toast('Export failed: '+e.toString());}finally{if(mounted)setState(()=>_busy=false);}
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
 void _reset(){setState((){_mix=.78;_baseEv=-.7;_overlayEv=.15;_scale=1;_offset=Offset.zero;_blend=0;});}
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
    onDoubleTap:_reset,onScaleUpdate:(d){if(_overlay==null)return;setState((){
     _scale=(_scale*d.scale).clamp(.2,5).toDouble();_offset+=Offset(d.focalPointDelta.dx/400,d.focalPointDelta.dy/600);
    });},
    child:CustomPaint(size:Size.infinite,painter:ExposurePreviewPainter(base:b,overlay:_overlay,
     blendMode:_modes[_blend].$2,mix:_mix,baseEv:_baseEv,overlayEv:_overlayEv,
     overlayOffset:_offset,overlayScale:_scale),
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
 Widget _controls()=>Container(padding:const EdgeInsets.fromLTRB(10,8,10,12),
  decoration:const BoxDecoration(color:Color(0xFF151519),borderRadius:BorderRadius.vertical(top:Radius.circular(18))),
  child:Column(mainAxisSize:MainAxisSize.min,children:[
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
