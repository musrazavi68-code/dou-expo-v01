import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DouExpoApp());
}

class DouExpoApp extends StatelessWidget {
  const DouExpoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dou Expo Beta',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF09090B),
      colorScheme: const ColorScheme.dark(primary: Color(0xFFFACC15), surface: Color(0xFF141418)),
      useMaterial3: true,
    ),
    home: const StudioScreen(),
  );
}

class PatternItem {
  final String name, category;
  final List<Color> colors;
  final BlendMode blend;
  const PatternItem(this.name, this.category, this.colors, this.blend);
}

const patterns = <PatternItem>[
  PatternItem('Light Leak','OPTICS',[Color(0xFFFF416C),Color(0xFFFFD166),Color(0xFF4ECDC4)],BlendMode.screen),
  PatternItem('Light Spot','OPTICS',[Color(0xFFFFBE0B),Color(0xFFFB5607),Color(0xFFFF006E)],BlendMode.colorDodge),
  PatternItem('Prism Flare','OPTICS',[Color(0xFF22D3EE),Color(0xFFA855F7),Color(0xFFF43F5E)],BlendMode.screen),
  PatternItem('Anamorphic Streak','OPTICS',[Color(0xFF60A5FA),Color(0xFFFDE047),Color(0xFF38BDF8)],BlendMode.lighten),
  PatternItem('Raindrops','NATURE',[Color(0xFF38BDF8),Color(0xFF818CF8),Color(0xFF0F172A)],BlendMode.softLight),
  PatternItem('Branches','NATURE',[Color(0xFF334155),Color(0xFF94A3B8),Color(0xFF1E293B)],BlendMode.darken),
  PatternItem('Mist & Fog','NATURE',[Color(0xFFE2E8F0),Color(0xFF64748B)],BlendMode.lighten),
  PatternItem('Bokeh Orb','NATURE',[Color(0xFFFBBF24),Color(0xFFEC4899),Color(0xFF6366F1)],BlendMode.screen),
  PatternItem('Vignette','EDITORIAL',[Colors.transparent,Color(0xCC000000)],BlendMode.multiply),
  PatternItem('Duotone Sunset','EDITORIAL',[Color(0xFFF97316),Color(0xFF9333EA)],BlendMode.softLight),
];

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final picker = ImagePicker();
  final random = Random();
  final canvasKey = GlobalKey();
  File? photo;
  PatternItem? pattern = patterns.first;
  double opacity = .65, filterStrength = .5;
  int blendIndex = 0, ratioIndex = 0, gradientIndex = 0;
  bool luminant = false, showGrid = false, watermark = false, postStage = false;
  String filterName = 'NORMAL';
  bool busy = false;

  final blends = <(String,BlendMode)>[
    ('NORMAL',BlendMode.srcOver),('SCREEN',BlendMode.screen),('MULTIPLY',BlendMode.multiply),
    ('OVERLAY',BlendMode.overlay),('SOFT LIGHT',BlendMode.softLight),('HARD LIGHT',BlendMode.hardLight),
    ('COLOR DODGE',BlendMode.colorDodge),('DIFFERENCE',BlendMode.difference),
    ('DARKEN',BlendMode.darken),('LIGHTEN',BlendMode.lighten),('EXCLUSION',BlendMode.exclusion),
    ('LUMINOSITY',BlendMode.saturation),
  ];
  final ratios = <(String,double)>[('1:1',1),('3:2',1.5),('4:3',4/3)];
  final directions = <(Alignment,Alignment)>[
    (Alignment.topCenter,Alignment.bottomCenter),(Alignment.bottomCenter,Alignment.topCenter),
    (Alignment.centerLeft,Alignment.centerRight),(Alignment.centerRight,Alignment.centerLeft),
    (Alignment.topLeft,Alignment.bottomRight),(Alignment.bottomRight,Alignment.topLeft),
    (Alignment.topRight,Alignment.bottomLeft),(Alignment.bottomLeft,Alignment.topRight),
  ];
  final filters = const ['NORMAL','MUME','BORAGO','HYACINTH','FRAGRANS','DISPORUM','GENTIANA','LILY','DELONIX','MYOSOTIS','TULIPA'];

  Future<void> chooseImage(ImageSource source) async {
    try {
      final x = await picker.pickImage(source: source, imageQuality: 100);
      if (x != null) setState(() { photo = File(x.path); postStage = false; });
    } catch (e) { message('Could not open image: $e'); }
  }

  void message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  void cycleBlend(int delta) {
    HapticFeedback.selectionClick();
    setState(() => blendIndex = (blendIndex + delta + blends.length) % blends.length);
  }

  ColorFilter get postFilter {
    if (!postStage || filterName == 'NORMAL') return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    final k = filterStrength;
    final warm = filterName == 'MUME' || filterName == 'BORAGO';
    return ColorFilter.matrix(<double>[
      1 + (warm ? .20 : -.08)*k,0,0,0,(warm ? 12 : 8)*k,
      0,1 + (warm ? .08 : .05)*k,0,0,(warm ? 6 : 10)*k,
      0,0,1 + (warm ? -.12 : .18)*k,0,(warm ? -4 : 14)*k,
      0,0,0,1,0,
    ]);
  }

  Future<Uint8List?> captureCanvas() async {
    try {
      final boundary = canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (e) { message('Export failed: $e'); return null; }
  }

  Future<void> exportImage({bool share = false}) async {
    if (photo == null) { message('ابتدا یک عکس انتخاب کنید'); return; }
    if (busy) return;
    setState(() => busy = true);
    try {
      final bytes = await captureCanvas();
      if (bytes == null) return;
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/dou_expo_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);
      if (share) {
        await Share.shareXFiles([XFile(file.path)], text: 'Created with Dou Expo');
      } else {
        await Gal.putImageBytes(bytes, name: 'dou_expo_${DateTime.now().millisecondsSinceEpoch}');
        message('تصویر با موفقیت در گالری ذخیره شد');
      }
    } catch (e) { message('Save/share error: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  void openPatterns() {
    showModalBottomSheet<void>(
      context: context, backgroundColor: const Color(0xFF141418), isScrollControlled: true,
      builder: (ctx) => SafeArea(child: SizedBox(height: MediaQuery.of(ctx).size.height*.68,
        child: Column(children: [
          const Padding(padding: EdgeInsets.all(18),child: Text('PATTERN BANK',style: TextStyle(fontWeight: FontWeight.bold,letterSpacing:2))),
          Expanded(child: ListView.builder(itemCount: patterns.length,itemBuilder: (_,i) {
            final p=patterns[i];
            return ListTile(
              leading: Container(width:54,height:38,decoration:BoxDecoration(borderRadius:BorderRadius.circular(8),gradient:LinearGradient(colors:p.colors))),
              title:Text(p.name),subtitle:Text(p.category),
              trailing: pattern?.name==p.name?const Icon(Icons.check,color:Color(0xFFFACC15)):null,
              onTap:(){setState((){pattern=p; final idx=blends.indexWhere((b)=>b.$2==p.blend); if(idx>=0) blendIndex=idx;}); Navigator.pop(ctx);},
            );
          })),
          TextButton.icon(onPressed:(){setState((){pattern=patterns[random.nextInt(patterns.length)];gradientIndex=random.nextInt(8);});Navigator.pop(ctx);},icon:const Icon(Icons.casino),label:const Text('RANDOM PATTERN')),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 700;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DOU EXPO',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:2)),
        actions: [
          IconButton(tooltip:'Patterns',onPressed:openPatterns,icon:const Icon(Icons.auto_awesome_mosaic_outlined)),
          IconButton(tooltip:'Grid',onPressed:()=>setState(()=>showGrid=!showGrid),icon:Icon(Icons.grid_on,color:showGrid?const Color(0xFFFACC15):null)),
          IconButton(tooltip:'Watermark',onPressed:()=>setState(()=>watermark=!watermark),icon:Icon(Icons.branding_watermark,color:watermark?const Color(0xFFFACC15):null)),
        ],
      ),
      body: SafeArea(child: wide
        ? Row(children:[Expanded(flex:6,child:_canvas()),const VerticalDivider(width:1),Expanded(flex:4,child:_controls())])
        : Column(children:[Expanded(child:_canvas()),_controls()])),
    );
  }

  Widget _canvas() {
    final grad=directions[gradientIndex], blend=blends[blendIndex];
    return Column(children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),child:Row(children:[
        IconButton(onPressed:()=>setState(()=>luminant=!luminant),icon:Icon(Icons.contrast,color:luminant?const Color(0xFFFACC15):null)),
        IconButton(onPressed:()=>setState(()=>gradientIndex=(gradientIndex+1)%8),icon:const Icon(Icons.gradient)),
        const Spacer(),
        TextButton(onPressed:()=>setState(()=>ratioIndex=(ratioIndex+1)%ratios.length),child:Text(ratios[ratioIndex].$1)),
      ])),
      Expanded(child:Center(child:Padding(padding:const EdgeInsets.all(12),child:AspectRatio(
        aspectRatio:ratios[ratioIndex].$2,
        child:GestureDetector(
          onHorizontalDragEnd:(d){final v=d.primaryVelocity??0;if(v.abs()>100)cycleBlend(v<0?1:-1);},
          child:RepaintBoundary(key:canvasKey,child:ClipRRect(borderRadius:BorderRadius.circular(18),child:ColorFiltered(
            colorFilter:postFilter,
            child:Stack(fit:StackFit.expand,children:[
              if(photo!=null) Image.file(photo!,fit:BoxFit.cover) else Container(color:const Color(0xFF191920),child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
                const Icon(Icons.photo_library_outlined,size:48,color:Colors.white38),const SizedBox(height:12),
                const Text('SELECT A BASE PHOTO'),const SizedBox(height:12),
                FilledButton.icon(onPressed:()=>chooseImage(ImageSource.gallery),icon:const Icon(Icons.add_photo_alternate),label:const Text('Choose photo')),
              ]))),
              if(pattern!=null) Opacity(opacity:opacity,child:ColorFiltered(
                colorFilter:ColorFilter.mode(Colors.white.withOpacity(luminant?.65:1),blend.$2),
                child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:grad.$1,end:grad.$2,colors:pattern!.colors))),
              )),
              if(showGrid) IgnorePointer(child:CustomPaint(painter:GridPainter())),
              Positioned(top:10,left:10,child:_pill('DOU EXPO · BETA')),
              Positioned(top:10,right:10,child:_pill(blend.$1)),
              if(watermark) const Positioned(bottom:10,right:12,child:Text('DOU EXPO',style:TextStyle(letterSpacing:2,color:Colors.white70,fontSize:10))),
            ]),
          ))),
        ),
      )))),
    ]);
  }

  Widget _pill(String label)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(20)),child:Text(label,style:const TextStyle(fontSize:10,letterSpacing:1)));

  Widget _controls() {
    return Container(padding:const EdgeInsets.fromLTRB(16,10,16,16),decoration:const BoxDecoration(color:Color(0xFF141418),borderRadius:BorderRadius.vertical(top:Radius.circular(22))),child:postStage?_postControls():_editControls());
  }

  Widget _editControls()=>Column(mainAxisSize:MainAxisSize.min,children:[
    Row(children:[const Text('PATTERN OPACITY',style:TextStyle(fontSize:10,color:Colors.white60)),Expanded(child:Slider(value:opacity,onChanged:(v)=>setState(()=>opacity=v))),Text('${(opacity*100).round()}%')]),
    Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
      IconButton(tooltip:'Gallery',onPressed:()=>chooseImage(ImageSource.gallery),icon:const Icon(Icons.photo_library_outlined)),
      IconButton(tooltip:'Camera',onPressed:()=>chooseImage(ImageSource.camera),icon:const Icon(Icons.camera_alt_outlined)),
      IconButton(tooltip:'Random pattern',onPressed:(){HapticFeedback.mediumImpact();setState(()=>pattern=patterns[random.nextInt(patterns.length)]);},icon:const Icon(Icons.casino_outlined)),
      GestureDetector(onTap:openPatterns,child:const Icon(Icons.layers_outlined,size:26)),
      IconButton(tooltip:'Clear pattern',onPressed:()=>setState(()=>pattern=null),icon:const Icon(Icons.layers_clear)),
      FilledButton(onPressed:photo==null?null:()=>setState(()=>postStage=true),child:const Text('NEXT')),
    ]),
    Text('Swipe left/right on the image to change blend mode',style:TextStyle(color:Colors.white38,fontSize:10)),
  ]);

  Widget _postControls()=>Column(mainAxisSize:MainAxisSize.min,children:[
    Row(children:[
      IconButton(onPressed:()=>setState(()=>postStage=false),icon:const Icon(Icons.arrow_back)),
      const Text('FINAL LOOK',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:1)),
      const Spacer(),
      IconButton(onPressed:busy?null:()=>exportImage(),icon:const Icon(Icons.save_alt,color:Color(0xFFFACC15))),
      IconButton(onPressed:busy?null:()=>exportImage(share:true),icon:const Icon(Icons.share)),
    ]),
    Row(children:[const Text('INTENSITY',style:TextStyle(fontSize:10,color:Colors.white60)),Expanded(child:Slider(value:filterStrength,onChanged:(v)=>setState(()=>filterStrength=v)))]),
    SizedBox(height:42,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:filters.length,separatorBuilder:(_,__)=>const SizedBox(width:6),itemBuilder:(_,i)=>ChoiceChip(label:Text(filters[i]),selected:filterName==filters[i],onSelected:(_)=>setState(()=>filterName=filters[i])))),
    if(busy) const LinearProgressIndicator(),
  ]);
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas,Size size) {
    final p=Paint()..color=Colors.white.withOpacity(.35)..strokeWidth=.7;
    for(var i=1;i<3;i++){final x=size.width*i/3,y=size.height*i/3;canvas.drawLine(Offset(x,0),Offset(x,size.height),p);canvas.drawLine(Offset(0,y),Offset(size.width,y),p);}
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
