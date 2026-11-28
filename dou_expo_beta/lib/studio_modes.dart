import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'core/project_document.dart';
import 'core/project_session.dart';
import 'core/project_store.dart';

const _ink=Color(0xFF100C0B);
const _yellow=Color(0xFFFACC15);

Uint8List _developOrdinaryPhoto(Map<String,Object> args){
 final bytes=args['bytes'] as Uint8List;
 final recipe=args['recipe'] as String;
 final decoded=img.decodeImage(bytes);
 if(decoded==null)throw StateError('Captured image could not be decoded');
 final random=math.Random(31);
 for(var y=0;y<decoded.height;y++){
  for(var x=0;x<decoded.width;x++){
   final pixel=decoded.getPixel(x,y);
   var r=pixel.r.toDouble(),g=pixel.g.toDouble(),b=pixel.b.toDouble();
   if(recipe=='MONO'){
    final luminance=.2126*r+.7152*g+.0722*b;r=luminance;g=luminance;b=luminance;
   }else if(recipe=='WARM'){
    r=(r*1.08+7).clamp(0,255);g=(g*1.015).clamp(0,255);b=(b*.88).clamp(0,255);
   }else if(recipe=='COOL'){
    r=(r*.90).clamp(0,255);g=(g*1.01).clamp(0,255);b=(b*1.09+5).clamp(0,255);
   }
   final grain=recipe=='COLOR'?0:random.nextInt(7)-3;
   decoded.setPixelRgba(x,y,(r+grain).round().clamp(0,255),(g+grain).round().clamp(0,255),(b+grain).round().clamp(0,255),pixel.a.toInt());
  }
 }
 return Uint8List.fromList(img.encodeJpg(decoded,quality:95));
}

class OrdinaryCameraScreen extends StatefulWidget {
 const OrdinaryCameraScreen({super.key,required this.session});
 final ProjectSession session;
 @override State<OrdinaryCameraScreen> createState()=>_OrdinaryCameraScreenState();
}
class _OrdinaryCameraScreenState extends State<OrdinaryCameraScreen> with WidgetsBindingObserver {
 CameraController? _camera;
 List<CameraDescription> _available=[];
 bool _ready=false,_manual=false,_busy=false;
 int _timerSeconds=0,_countdown=0;
 double _ev=0,_minEv=-2,_maxEv=2,_zoom=1,_maxZoom=4;
 bool _cameraInitializing=false,_appActive=true;
 final AudioPlayer _zoomPlayer=AudioPlayer();
 DateTime _lastZoomSound=DateTime.fromMillisecondsSinceEpoch(0);
 double _joystickStartZoom=1,_joystickStartEv=0,_pinchStartZoom=1;
 Offset _joystickOrigin=Offset.zero;
 String _film='COLOR';
 Uint8List? _lastShotBytes;
 String? _loadedOrdinaryPath;int _restoreToken=0;
 @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);widget.session.addListener(_onProjectChanged);_restoreOrdinary();_init();}
 @override void dispose(){widget.session.removeListener(_onProjectChanged);_restoreToken++;WidgetsBinding.instance.removeObserver(this);_camera?.dispose();unawaited(_zoomPlayer.dispose());super.dispose();}
 void _onProjectChanged(){_restoreOrdinary();}
 Future<void> _restoreOrdinary() async {
  final token=++_restoreToken;final project=widget.session.document;
  final layers=project.layers.where((v)=>v.name.startsWith('Ordinary camera')).toList();
  final layer=layers.isEmpty?null:layers.last;final path=layer?.assetPath;
  try{
   Uint8List? bytes;
   if(path!=null&&path!=_loadedOrdinaryPath){final file=await ProjectStore().resolveAsset(project.id,path);bytes=await file.readAsBytes();}
   if(token!=_restoreToken||!mounted)return;
   setState((){
    if(path==null){_lastShotBytes=null;_loadedOrdinaryPath=null;}
    else{
     if(bytes!=null){_lastShotBytes=bytes;_loadedOrdinaryPath=path;}
     final film=layer?.settings['film'];if(film is String)_film=film;
    }
   });
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Camera project restore failed: $e')));}
 }
 @override void didChangeAppLifecycleState(AppLifecycleState state){
  if(state==AppLifecycleState.inactive||state==AppLifecycleState.paused){_appActive=false;final c=_camera;_camera=null;_ready=false;c?.dispose();if(mounted)setState((){});}
  if(state==AppLifecycleState.resumed){_appActive=true;_init();}
 }
 Future<void> _init() async {
  if(!_appActive||_cameraInitializing||_camera!=null)return;
  _cameraInitializing=true;
  CameraController? candidate;
  try{
   _available=await availableCameras();if(_available.isEmpty)return;
   final back=_available.where((x)=>x.lensDirection==CameraLensDirection.back).toList();
   final selected=back.isNotEmpty?back.first:_available.first;
   candidate=CameraController(selected,ResolutionPreset.high,enableAudio:false);
   await candidate.initialize();final z=await candidate.getMaxZoomLevel();
   final minEv=await candidate.getMinExposureOffset();final maxEv=await candidate.getMaxExposureOffset();
   if(!mounted||!_appActive){await candidate.dispose();return;}
   setState(() {_camera=candidate;_ready=true;_maxZoom=z;_minEv=minEv;_maxEv=maxEv;_ev=0;_zoom=1;});
  }catch(e){await candidate?.dispose();if(mounted&&_appActive)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Camera unavailable: $e')));}
  finally{_cameraInitializing=false;}
 }
 Future<void> _setEv(double v) async {final c=_camera;if(c==null)return;try{final a=await c.setExposureOffset(v);if(mounted)setState(()=>_ev=a);}catch(_){}}
 Uint8List _zoomMotorWave({required bool zoomIn,required double intensity}) {
  const rate=22050;const samples=rate~/7;final data=ByteData(44+samples*2);
  void ascii(int offset,String value){for(var i=0;i<value.length;i++){data.setUint8(offset+i,value.codeUnitAt(i));}}
  ascii(0,'RIFF');data.setUint32(4,36+samples*2,Endian.little);ascii(8,'WAVE');ascii(12,'fmt ');
  data.setUint32(16,16,Endian.little);data.setUint16(20,1,Endian.little);data.setUint16(22,1,Endian.little);
  data.setUint32(24,rate,Endian.little);data.setUint32(28,rate*2,Endian.little);data.setUint16(32,2,Endian.little);
  data.setUint16(34,16,Endian.little);ascii(36,'data');data.setUint32(40,samples*2,Endian.little);
  final start=zoomIn?210.0:145.0,end=zoomIn?145.0:95.0;
  for(var i=0;i<samples;i++){
   final t=i/samples;
   final envelope=math.pow(math.sin(math.pi*t),.65).toDouble();
   final fundamental=math.sin(2*math.pi*(start*t+(end-start)*t*t/2)*samples/rate);
   final harmonic=.28*math.sin(2*math.pi*(start*t+(end-start)*t*t/2)*2*samples/rate);
   final value=((fundamental+harmonic)*envelope*intensity*5000).round().clamp(-32768,32767);
   data.setInt16(44+i*2,value,Endian.little);
  }
  return data.buffer.asUint8List();
 }
 Future<void> _playZoomMotor(double previous,double next) async {
  final now=DateTime.now();
  if((next-previous).abs()<.045||now.difference(_lastZoomSound).inMilliseconds<95)return;
  _lastZoomSound=now;
  try{
   await _zoomPlayer.stop();
   await _zoomPlayer.play(BytesSource(_zoomMotorWave(zoomIn:next>previous,intensity:(.22+(next-1)/math.max(1,_maxZoom-1)*.35).clamp(.18,.6))));
  }catch(error){debugPrint('Zoom motor sound unavailable: $error');}
 }
 Future<void> _setZoom(double v) async {final c=_camera;if(c==null)return;try{final next=v.clamp(1,_maxZoom).toDouble();await c.setZoomLevel(next);if(mounted){setState(()=>_zoom=next);unawaited(_playZoomMotor(_zoom,next));}}catch(_){}}
 Future<void> _focus(Offset p, Size size) async {final c=_camera;if(c==null)return;try{await c.setFocusPoint(Offset(p.dx/size.width,p.dy/size.height));await c.setExposurePoint(Offset(p.dx/size.width,p.dy/size.height));}catch(_){}}
 Future<Uint8List> _applyFilm(Uint8List bytes,String recipe)=>compute(_developOrdinaryPhoto,{'bytes':bytes,'recipe':recipe});
 Future<void> _capture() async {
  final c=_camera;if(c==null||!c.value.isInitialized||_busy)return;
  setState(()=>_busy=true);
  try{
   for(var remaining=_timerSeconds;remaining>0;remaining--){
    if(!mounted)return;
    setState(()=>_countdown=remaining);
    await Future.delayed(const Duration(seconds:1));
   }
   if(!mounted)return;
   final shot=await c.takePicture();
   final sourceBytes=await File(shot.path).readAsBytes();
   final developed=await _applyFilm(sourceBytes,_film);
   final stamp=DateTime.now().microsecondsSinceEpoch;
   final assetPath=await widget.session.addAsset('ordinary_$stamp.jpg',sourceBytes);
   final current=widget.session.document;
   final layerId='ordinary_$stamp';
   _loadedOrdinaryPath=assetPath;
   widget.session.replace(current.copyWith(
    layers:[...current.layers,LayerDocument(id:layerId,name:'Ordinary camera · $_film',assetPath:assetPath,settings:{'mode':'ordinary','film':_film,'singleExposure':true})],
    activeLayerId:layerId,canvas:{...current.canvas,'lastEditedIn':'ordinaryCamera'}));
   await Gal.putImageBytes(developed,name:'ordinary_'+DateTime.now().millisecondsSinceEpoch.toString()+'.jpg',album:'Dou Expo');
   if(mounted){
    setState(() { _lastShotBytes = developed; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Saved $_film · one exposure')));
   }
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Capture failed: $e')));
  }finally{if(mounted)setState(() { _busy = false; _countdown = 0; });}
 }
 Future<void> _flip() async {
  if(_available.length<2||_cameraInitializing||!_appActive)return;_cameraInitializing=true;final old=_camera;_camera=null;_ready=false;await old?.dispose();
  final current=_available.indexWhere((x)=>x.lensDirection==old?.description.lensDirection);
  final next=_available[(current+1)%_available.length];
  CameraController? candidate;
  try{candidate=CameraController(next,ResolutionPreset.high,enableAudio:false);await candidate.initialize();if(!mounted||!_appActive){await candidate.dispose();return;}setState(() {_camera=candidate;_ready=true;});}
  catch(e){await candidate?.dispose();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Lens switch failed: $e')));}
  finally{_cameraInitializing=false;}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:_ink,
  appBar:AppBar(backgroundColor:_ink,title:const Text('ORDINARY CAMERA',style:TextStyle(fontSize:13,letterSpacing:2,fontWeight:FontWeight.w700)),
   actions:[IconButton(tooltip:'Switch lens',onPressed:_flip,icon:const Icon(Icons.flip_camera_ios)),TextButton(onPressed:()=>setState(()=>_manual=!_manual),child:Text(_manual?'EV CONTROLS':'AUTO',style:TextStyle(color:_manual?_yellow:Colors.white))) ]),
  body:SafeArea(child:Column(children:[
   Expanded(flex:7,child:Padding(padding:const EdgeInsets.fromLTRB(12,6,12,8),child:ClipRRect(borderRadius:BorderRadius.circular(18),
    child:LayoutBuilder(builder:(ctx,box)=>GestureDetector(
     onTapDown:(d)=>_focus(d.localPosition,box.biggest),
     onScaleStart:(d){if(d.pointerCount>1)_pinchStartZoom=_zoom;},
     onScaleUpdate:(d){if(d.pointerCount>1)_setZoom((_pinchStartZoom*d.scale).clamp(1,_maxZoom).toDouble());},
     child:Stack(fit:StackFit.expand,children:[
      if(_ready&&_camera!=null)CameraPreview(_camera!) else const ColoredBox(color:Color(0xFF24201E),child:Center(child:CircularProgressIndicator(color:_yellow))),
      const IgnorePointer(child:Center(child:Icon(Icons.add,size:34,color:Colors.white70))),
      Positioned(left:14,top:14,child:Text(_countdown>0?'${_countdown}s':_manual?'EV  ${_ev.toStringAsFixed(1)}':'ONE PRESS · ONE EXPOSURE',style:const TextStyle(fontSize:11,color:Colors.white,shadows:[Shadow(blurRadius:5,color:Colors.black)]))),
      Positioned(right:14,bottom:14,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.all(Radius.circular(22))),child:Text('${_zoom.toStringAsFixed(1)}x',style:const TextStyle(color:Colors.black,fontWeight:FontWeight.bold)))),
     ]),
    )),
   ))),
   if(_manual)Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Column(children:[
    Row(children:[const SizedBox(width:42,child:Text('EV',style:TextStyle(color:_yellow))),Expanded(child:Slider(min:_minEv,max:_maxEv,value:_ev.clamp(_minEv,_maxEv),onChanged:_setEv)),Text(_ev.toStringAsFixed(1),style:const TextStyle(fontSize:11))]),
    Row(children:[const SizedBox(width:42,child:Text('ZOOM',style:TextStyle(color:_yellow))),Expanded(child:Slider(min:1,max:math.max(1.01,_maxZoom),value:_zoom.clamp(1,math.max(1.01,_maxZoom)),onChanged:_setZoom)),Text('${_zoom.toStringAsFixed(1)}x',style:const TextStyle(fontSize:11))]),
    const Text('Exposure compensation and tap-to-focus · ISO and shutter are not yet exposed by this camera driver',style:TextStyle(fontSize:10,color:Colors.white54)),
   ])),
   const Padding(padding:EdgeInsets.only(top:2),child:Text('SHUTTER JOYSTICK · TAP TO SHOOT · DRAG UP/DOWN TO ZOOM · LEFT/RIGHT FOR EV',textAlign:TextAlign.center,style:TextStyle(fontSize:8,color:Colors.white38,letterSpacing:.5))),
   Padding(padding:const EdgeInsets.fromLTRB(18,8,18,18),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
    GestureDetector(onTap:()=>_lastShotBytes==null?null:showDialog(context:context,builder:(ctx)=>Dialog(child:Image.memory(_lastShotBytes!,fit:BoxFit.contain))),child:Container(width:58,height:58,decoration:BoxDecoration(color:const Color(0xFF292422),borderRadius:BorderRadius.circular(9),image:_lastShotBytes==null?null:DecorationImage(image:MemoryImage(_lastShotBytes!),fit:BoxFit.cover)),child:_lastShotBytes==null?const Icon(Icons.photo_library_outlined,color:Colors.white70):null)),
    GestureDetector(
     onTap:_capture,
     onPanStart:(d){_joystickOrigin=d.localPosition;_joystickStartZoom=_zoom;_joystickStartEv=_ev;},
     onPanUpdate:(d){
      final delta=d.localPosition-_joystickOrigin;
      if(delta.dy.abs()>=delta.dx.abs()){
       _setZoom((_joystickStartZoom-delta.dy*.035).clamp(1,_maxZoom).toDouble());
      }else if(_manual){
       _setEv((_joystickStartEv+delta.dx*.035).clamp(_minEv,_maxEv).toDouble());
      }
     },
     child:Container(width:86,height:86,decoration:const BoxDecoration(color:Colors.white,shape:BoxShape.circle),child:Center(child:_busy?const CircularProgressIndicator(color:_ink):const Icon(Icons.add,size:38,color:_ink)))),

    Column(children:[const Text('FILM / TIMER',style:TextStyle(fontSize:9,color:Colors.white54)),DropdownButton<String>(value:_film,dropdownColor:_ink,underline:const SizedBox(),items:const ['COLOR','MONO','WARM','COOL'].map((x)=>DropdownMenuItem(value:x,child:Text(x,style:const TextStyle(fontSize:11)))).toList(),onChanged:(v){if(v!=null)setState(()=>_film=v);}),DropdownButton<int>(value:_timerSeconds,dropdownColor:_ink,underline:const SizedBox(),items:const [0,3,5,10].map((v)=>DropdownMenuItem(value:v,child:Text(v==0?'OFF':'${v}s',style:const TextStyle(fontSize:10)))).toList(),onChanged:(v){if(v!=null)setState(()=>_timerSeconds=v);})])
   ]))
  ])),
 );
}

class DarkroomScreen extends StatefulWidget {
 const DarkroomScreen({super.key,required this.session});
 final ProjectSession session;
 @override State<DarkroomScreen> createState()=>_DarkroomScreenState();
}
class _DarkroomScreenState extends State<DarkroomScreen> {
 final _picker=ImagePicker();XFile? _photo;Uint8List? _photoBytes;
 String? _loadedDarkroomPath;int _restoreToken=0;
 double _brightness=0,_contrast=1,_saturation=1;
 @override void initState(){super.initState();widget.session.addListener(_onProjectChanged);_restoreDarkroom();}
 @override void dispose(){widget.session.removeListener(_onProjectChanged);_restoreToken++;super.dispose();}
 void _onProjectChanged(){_restoreDarkroom();}
 Future<void> _restoreDarkroom() async {
  final token=++_restoreToken;final project=widget.session.document;
  final layers=project.layers.where((v)=>v.name=='Darkroom source').toList();
  final path=layers.isEmpty?null:layers.last.assetPath;
  try{
   Uint8List? bytes;
   if(path!=null&&path!=_loadedDarkroomPath){final file=await ProjectStore().resolveAsset(project.id,path);bytes=await file.readAsBytes();}
   if(token!=_restoreToken||!mounted)return;
   final raw=project.canvas['darkroom'];
   setState((){
    if(raw is Map){final settings=Map<String,Object?>.from(raw);_brightness=(settings['brightness'] as num?)?.toDouble()??_brightness;_contrast=(settings['contrast'] as num?)?.toDouble()??_contrast;_saturation=(settings['saturation'] as num?)?.toDouble()??_saturation;}
    if(path==null){_photoBytes=null;_loadedDarkroomPath=null;}
    else if(bytes!=null){_photoBytes=bytes;_loadedDarkroomPath=path;}
   });
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Darkroom restore failed: $e')));}
 }
 Future<void> _pick() async {
  final x=await _picker.pickImage(source:ImageSource.gallery,imageQuality:100);
  if(x==null)return;
  try{
   final bytes=await x.readAsBytes();
   final stamp=DateTime.now().microsecondsSinceEpoch;
   final assetPath=await widget.session.addAsset('darkroom_$stamp.jpg',bytes);
   final current=widget.session.document;
   final layerId='darkroom_$stamp';
   _loadedDarkroomPath=assetPath;
   widget.session.replace(current.copyWith(
    layers:[...current.layers,LayerDocument(id:layerId,name:'Darkroom source',assetPath:assetPath,settings:{'mode':'darkroom'})],
    activeLayerId:layerId,canvas:{...current.canvas,'lastEditedIn':'darkroom'}));
   if(mounted)setState(() {_photo=x;_photoBytes=bytes;});
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Project import failed: $e')));}
 }
 Future<void> _export() async {
  final photo=_photo;
  final sourceBytes=_photoBytes??(photo==null?null:await photo.readAsBytes());
  if(sourceBytes==null)return;
  try{
   final codec=await ui.instantiateImageCodec(sourceBytes);
   final frame=await codec.getNextFrame();
   final source=frame.image;
   codec.dispose();
   try{
    final recorder=ui.PictureRecorder();
    final canvas=Canvas(recorder);
    final paint=Paint()
      ..filterQuality=FilterQuality.high
      ..colorFilter=ColorFilter.matrix(_matrix());
    canvas.drawImageRect(source,Rect.fromLTWH(0,0,source.width.toDouble(),source.height.toDouble()),
      Rect.fromLTWH(0,0,source.width.toDouble(),source.height.toDouble()),paint);
    final picture=recorder.endRecording();
    final output=await picture.toImage(source.width,source.height);
    picture.dispose();
    try{
     final data=await output.toByteData(format:ui.ImageByteFormat.png);
     if(data==null)throw StateError('Could not encode developed photo');
     final bytes=data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes);
     final current=widget.session.document;
     widget.session.replace(current.copyWith(canvas:{...current.canvas,'lastEditedIn':'darkroom',
      'darkroom':{'brightness':_brightness,'contrast':_contrast,'saturation':_saturation}}));
     await Gal.putImageBytes(bytes,name:'darkroom_'+DateTime.now().millisecondsSinceEpoch.toString()+'.png',album:'Dou Expo');
     if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Developed PNG saved to Gallery')));
    }finally{output.dispose();}
   }finally{source.dispose();}
  }catch(e){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Darkroom export failed: '+e.toString())));
  }
 }
 List<double> _matrix(){
  final c=_contrast,s=_saturation,b=_brightness*255;
  final r=(.213+.787*s)*c,g=(.715-.715*s)*c,bl=(.072-.072*s)*c;
  return [r,g,bl,0,b,(.213-.213*s)*c,(.715+.285*s)*c,(.072-.072*s)*c,0,b,(.213-.213*s)*c,(.715-.715*s)*c,(.072+.928*s)*c,0,b,0,0,0,1,0];
 }
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:_ink,
  appBar:AppBar(backgroundColor:_ink,title:const Text('DARKROOM',style:TextStyle(fontSize:13,letterSpacing:2,fontWeight:FontWeight.w700)),actions:[IconButton(onPressed:_pick,icon:const Icon(Icons.add_photo_alternate_outlined))]),
  body:SafeArea(child:Column(children:[
   Expanded(child:Padding(padding:const EdgeInsets.all(12),child:ClipRRect(borderRadius:BorderRadius.circular(16),child:Center(child:_photoBytes==null?const Text('Choose a photograph to develop',style:TextStyle(color:Colors.white54)):ColorFiltered(colorFilter:ColorFilter.matrix(_matrix()),child:Image.memory(_photoBytes!,fit:BoxFit.contain)))))),
   Padding(padding:const EdgeInsets.fromLTRB(16,4,16,20),child:Column(children:[
    _control('BRIGHTNESS',_brightness,-1,1,(v)=>setState(()=>_brightness=v)),
    _control('CONTRAST',_contrast,0,2,(v)=>setState(()=>_contrast=v)),
    _control('SATURATION',_saturation,0,2,(v)=>setState(()=>_saturation=v)),
    Row(children:[Expanded(child:OutlinedButton.icon(onPressed:_pick,icon:const Icon(Icons.photo_library),label:const Text('OPEN PHOTO'))),const SizedBox(width:8),OutlinedButton(onPressed:()=>setState(() {_brightness=0;_contrast=1;_saturation=1;}),child:const Text('RESET')),const SizedBox(width:8),FilledButton.icon(onPressed:_photoBytes==null?null:_export,icon:const Icon(Icons.save_alt),label:const Text('EXPORT'))])
   ]))
  ])));
 Widget _control(String name,double value,double min,double max,ValueChanged<double> change)=>Row(children:[SizedBox(width:100,child:Text(name,style:const TextStyle(fontSize:10,color:Colors.white60))),Expanded(child:Slider(min:min,max:max,value:value.clamp(min,max),onChanged:change)),SizedBox(width:38,child:Text(value.toStringAsFixed(1),style:const TextStyle(fontSize:10)))]);
}
