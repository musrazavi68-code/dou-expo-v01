import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

const _ink=Color(0xFF100C0B);
const _yellow=Color(0xFFFACC15);

class OrdinaryCameraScreen extends StatefulWidget {
 const OrdinaryCameraScreen({super.key});
 @override State<OrdinaryCameraScreen> createState()=>_OrdinaryCameraScreenState();
}
class _OrdinaryCameraScreenState extends State<OrdinaryCameraScreen> with WidgetsBindingObserver {
 CameraController? _camera;
 List<CameraDescription> _available=[];
 bool _ready=false,_manual=false,_busy=false;
 double _ev=0,_zoom=1,_maxZoom=4;
 String _film='COLOR';
 XFile? _lastShot;
 @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_init();}
 @override void dispose(){WidgetsBinding.instance.removeObserver(this);_camera?.dispose();super.dispose();}
 @override void didChangeAppLifecycleState(AppLifecycleState state){
  if(state==AppLifecycleState.inactive||state==AppLifecycleState.paused){final c=_camera;_camera=null;_ready=false;c?.dispose();if(mounted)setState((){});}
  if(state==AppLifecycleState.resumed)_init();
 }
 Future<void> _init() async {
  try{
   _available=await availableCameras();if(_available.isEmpty)return;
   final c=CameraController(_available.first,ResolutionPreset.high,enableAudio:false);
   await c.initialize();final z=await c.getMaxZoomLevel();
   if(!mounted){await c.dispose();return;}
   setState(()=>{_camera=c,_ready=true,_maxZoom=z});
  }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Camera unavailable: $e')));}
 }
 Future<void> _setEv(double v) async {final c=_camera;if(c==null)return;try{final a=await c.setExposureOffset(v);if(mounted)setState(()=>_ev=a);}catch(_){}}
 Future<void> _setZoom(double v) async {final c=_camera;if(c==null)return;try{await c.setZoomLevel(v);if(mounted)setState(()=>_zoom=v);}catch(_){}}
 Future<void> _focus(Offset p, Size size) async {final c=_camera;if(c==null)return;try{await c.setFocusPoint(Offset(p.dx/size.width,p.dy/size.height));await c.setExposurePoint(Offset(p.dx/size.width,p.dy/size.height));}catch(_){}}
 Future<void> _capture() async {
  final c=_camera;if(c==null||!c.value.isInitialized||_busy)return;
  setState(()=>_busy=true);
  try{final shot=await c.takePicture();await Gal.putImage(shot.path,album:'Dou Expo');if(mounted)setState(()=>_lastShot=shot);}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Capture failed: $e')));}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 Future<void> _flip() async {
  if(_available.length<2)return;final old=_camera;_camera=null;_ready=false;await old?.dispose();
  final current=_available.indexWhere((x)=>x.lensDirection==old?.description.lensDirection);
  final next=_available[(current+1)%_available.length];
  try{final c=CameraController(next,ResolutionPreset.high,enableAudio:false);await c.initialize();if(!mounted){await c.dispose();return;}setState(()=>{_camera=c,_ready=true});}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Lens switch failed: $e')));}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:_ink,
  appBar:AppBar(backgroundColor:_ink,title:const Text('ORDINARY CAMERA',style:TextStyle(fontSize:13,letterSpacing:2,fontWeight:FontWeight.w700)),
   actions:[IconButton(tooltip:'Switch lens',onPressed:_flip,icon:const Icon(Icons.flip_camera_ios)),TextButton(onPressed:()=>setState(()=>_manual=!_manual),child:Text(_manual?'MANUAL':'AUTO',style:TextStyle(color:_manual?_yellow:Colors.white))) ]),
  body:SafeArea(child:Column(children:[
   Expanded(flex:7,child:Padding(padding:const EdgeInsets.fromLTRB(12,6,12,8),child:ClipRRect(borderRadius:BorderRadius.circular(18),
    child:LayoutBuilder(builder:(ctx,box)=>GestureDetector(
     onTapDown:(d)=>_focus(d.localPosition,box.biggest),
     onVerticalDragUpdate:(d)=>_setZoom((_zoom-d.delta.dy*.01).clamp(1,_maxZoom).toDouble()),
     child:Stack(fit:StackFit.expand,children:[
      if(_ready&&_camera!=null)CameraPreview(_camera!) else const ColoredBox(color:Color(0xFF24201E),child:Center(child:CircularProgressIndicator(color:_yellow))),
      const IgnorePointer(child:Center(child:Icon(Icons.add,size:34,color:Colors.white70))),
      Positioned(left:14,top:14,child:Text(_manual?'EV  ${_ev.toStringAsFixed(1)}':'ONE PRESS · ONE EXPOSURE',style:const TextStyle(fontSize:11,color:Colors.white,shadows:[Shadow(blurRadius:5,color:Colors.black)]))),
      Positioned(right:14,bottom:14,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.all(Radius.circular(22))),child:Text('${_zoom.toStringAsFixed(1)}x',style:const TextStyle(color:Colors.black,fontWeight:FontWeight.bold)))),
     ]),
    )),
   ))),
   if(_manual)Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Column(children:[
    Row(children:[const SizedBox(width:42,child:Text('EV',style:TextStyle(color:_yellow))),Expanded(child:Slider(min:-2,max:2,divisions:16,value:_ev.clamp(-2,2),onChanged:_setEv)),Text(_ev.toStringAsFixed(1),style:const TextStyle(fontSize:11))]),
    Row(children:[const SizedBox(width:42,child:Text('ZOOM',style:TextStyle(color:_yellow))),Expanded(child:Slider(min:1,max:math.max(1.01,_maxZoom),value:_zoom.clamp(1,math.max(1.01,_maxZoom)),onChanged:_setZoom)),Text('${_zoom.toStringAsFixed(1)}x',style:const TextStyle(fontSize:11))]),
    const Text('Focus point: tap the viewfinder · ISO and shutter speed depend on native camera support',style:TextStyle(fontSize:10,color:Colors.white54)),
   ])),
   Padding(padding:const EdgeInsets.fromLTRB(18,8,18,18),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
    GestureDetector(onTap:()=>_lastShot==null?null:showDialog(context:context,builder:(ctx)=>Dialog(child:Image.file(File(_lastShot!.path)))),child:Container(width:58,height:58,decoration:BoxDecoration(color:const Color(0xFF292422),borderRadius:BorderRadius.circular(9),image:_lastShot==null?null:DecorationImage(image:FileImage(File(_lastShot!.path)),fit:BoxFit.cover)),child:_lastShot==null?const Icon(Icons.photo_library_outlined,color:Colors.white70):null)),
    GestureDetector(onTap:_capture,child:Container(width:86,height:86,decoration:const BoxDecoration(color:Colors.white,shape:BoxShape.circle),child:Center(child:_busy?const CircularProgressIndicator(color:_ink):const Icon(Icons.add,size:38,color:_ink)))),
    Column(children:[const Text('FILM',style:TextStyle(fontSize:9,color:Colors.white54)),DropdownButton<String>(value:_film,dropdownColor:_ink,underline:const SizedBox(),items:const ['COLOR','MONO','WARM','COOL'].map((x)=>DropdownMenuItem(value:x,child:Text(x,style:const TextStyle(fontSize:11)))).toList(),onChanged:(v){if(v!=null)setState(()=>_film=v);})])
   ]))
  ])),
 );
}

class DarkroomScreen extends StatefulWidget {
 const DarkroomScreen({super.key});
 @override State<DarkroomScreen> createState()=>_DarkroomScreenState();
}
class _DarkroomScreenState extends State<DarkroomScreen> {
 final _picker=ImagePicker();XFile? _photo;
 double _brightness=0,_contrast=1,_saturation=1;
 Future<void> _pick() async {final x=await _picker.pickImage(source:ImageSource.gallery,imageQuality:100);if(x!=null&&mounted)setState(()=>_photo=x);}
 List<double> _matrix(){
  final c=_contrast,s=_saturation,b=_brightness*255;
  final r=(.213+.787*s)*c,g=(.715-.715*s)*c,bl=(.072-.072*s)*c;
  return [r,g,bl,0,b,(.213-.213*s)*c,(.715+.285*s)*c,(.072-.072*s)*c,0,b,(.213-.213*s)*c,(.715-.715*s)*c,(.072+.928*s)*c,0,b,0,0,0,1,0];
 }
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:_ink,
  appBar:AppBar(backgroundColor:_ink,title:const Text('DARKROOM',style:TextStyle(fontSize:13,letterSpacing:2,fontWeight:FontWeight.w700)),actions:[IconButton(onPressed:_pick,icon:const Icon(Icons.add_photo_alternate_outlined))]),
  body:SafeArea(child:Column(children:[
   Expanded(child:Padding(padding:const EdgeInsets.all(12),child:ClipRRect(borderRadius:BorderRadius.circular(16),child:Center(child:_photo==null?const Text('Choose a photograph to develop',style:TextStyle(color:Colors.white54)):ColorFiltered(colorFilter:ColorFilter.matrix(_matrix()),child:Image.file(File(_photo!.path),fit:BoxFit.contain)))))),
   Padding(padding:const EdgeInsets.fromLTRB(16,4,16,20),child:Column(children:[
    _control('BRIGHTNESS',_brightness,-1,1,(v)=>setState(()=>_brightness=v)),
    _control('CONTRAST',_contrast,0,2,(v)=>setState(()=>_contrast=v)),
    _control('SATURATION',_saturation,0,2,(v)=>setState(()=>_saturation=v)),
    Row(children:[Expanded(child:OutlinedButton.icon(onPressed:_pick,icon:const Icon(Icons.photo_library),label:const Text('OPEN PHOTO'))),const SizedBox(width:10),OutlinedButton(onPressed:()=>setState(()=>{_brightness=0,_contrast=1,_saturation=1}),child:const Text('RESET'))])
   ]))
  ])));
 Widget _control(String name,double value,double min,double max,ValueChanged<double> change)=>Row(children:[SizedBox(width:100,child:Text(name,style:const TextStyle(fontSize:10,color:Colors.white60))),Expanded(child:Slider(min:min,max:max,value:value.clamp(min,max),onChanged:change)),SizedBox(width:38,child:Text(value.toStringAsFixed(1),style:const TextStyle(fontSize:10)))]);
}
