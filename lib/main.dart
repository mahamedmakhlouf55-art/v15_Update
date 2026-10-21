
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'robot_link.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const CelyahApp()); }
const bg = Color(0xFF0D0B15), panel = Color(0xFF1B1629);
const lavender = Color(0xFFF08DEB), soft = Color(0xFFB9AEC9);

class CelyahApp extends StatelessWidget {
  const CelyahApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'Celyah Robot',
    theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,
      scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:lavender,brightness:Brightness.dark),
      fontFamily:'sans-serif', inputDecorationTheme:InputDecorationTheme(
      filled:true,fillColor:panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(22),borderSide:BorderSide.none))),
    home:const Dashboard());
}
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard> {
  final RobotLink link=RobotLink();
  final TextEditingController chat=TextEditingController();
  final TextEditingController camera=TextEditingController(text:'http://192.168.1.100');
  StreamSubscription<String>? incoming;
  Timer? visionTimer;
  int visionFrame = 0;
  bool visionEnabled = false;
  String visionUrl = '';
  int tab=0;
  bool busy=false;
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  bool listening=false;
  String robotState='idle';
  bool speakReplies=true;
  bool showFullChat=false;
  String lastRobotMessage='جاهزة للكلام 💜';
  Future<void> listen() async {
    if(listening){await speech.stop();if(mounted)setState(()=>listening=false);return;}
    final ok=await speech.initialize(onError:(e){if(mounted){setState(()=>listening=false);_notice('الميكروفون: $e');}},
      onStatus:(status){if(mounted&&status=='done')setState(()=>listening=false);});
    if(!ok){_notice('التعرف على الكلام غير متاح على الجهاز');return;}
    if(link.connected) await link.sendState('listening');
    setState((){listening=true;face='curious';robotState='listening';});
    await speech.listen(localeId:'ar_EG',onResult:(r){
      if(mounted){setState(()=>chat.text=r.recognizedWords);}
      if(r.finalResult){setState(()=>listening=false);_chat();}
    });
  }
  Future<void> readAloud(String text) async {
    if(!speakReplies)return;
    final languages = await tts.getLanguages;
    final available = (languages is List) ? languages.map((e)=>e.toString().toLowerCase()).toList() : <String>[];
    await tts.setLanguage(available.contains('ar-eg') ? 'ar-EG' : 'ar');
    await tts.setSpeechRate(.44);
    await tts.setPitch(1.05);
    await tts.speak(text);
  }

  final List<(bool,String)> messages=[(false,'أهلاً! أنا Celyah 💜 اتصلي بيا عشان نبدأ مغامرتنا.')];
  String face='normal';
  @override void initState(){super.initState();link.addListener(_refresh);
    incoming=link.lines.listen((line){if(!mounted)return;
      setState((){
        messages.add((false,line));
        if(line.startsWith('FACE:')) { face=line.substring(5).trim().toLowerCase(); }
        else if(!line.startsWith('VISION:') && !line.startsWith('BAT:')) {
          lastRobotMessage=line; robotState='speaking';
          if(!line.startsWith('APP:') && !line.startsWith('WiFi:')) face='happy';
        }
      });
      if(line.startsWith('VISION:URL ')) {
        final url=line.substring('VISION:URL '.length).trim();
        camera.text=url;
        visionTimer?.cancel();
        visionTimer=Timer.periodic(const Duration(milliseconds:900),(_){
          if(mounted && tab==2 && visionEnabled) setState(()=>visionFrame++);
        });
        setState(() {visionUrl=url;visionEnabled=true;visionFrame++;});
      }
      if(line=='VISION:OFF') {visionTimer?.cancel();setState(()=>visionEnabled=false);}
      if(!line.startsWith('BAT:') && !line.startsWith('VISION:')) readAloud(line);
    });}
  void _refresh(){if(mounted)setState((){});}
  Future<void> command(String cmd) async {
    if(!link.connected){_notice('وصّلي الروبوت بالبلوتوث الأول');return;}
    try{await link.send(cmd);_notice('تم إرسال الأمر: $cmd');}
    catch(e){_notice('فشل إرسال الأمر: $e');}
  }
  Widget _brand()=>Row(mainAxisSize:MainAxisSize.min,children:[
    const Text('Celyah',style:TextStyle(fontSize:31,fontWeight:FontWeight.w800,letterSpacing:-1.8)),
    const Text('♡',style:TextStyle(color:lavender,fontSize:29)),
    const SizedBox(width:9),
    const Text('R O B O T',style:TextStyle(color:soft,fontSize:9,letterSpacing:1.2))
  ]);
  void _notice(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  Future<void> _chat() async {
    final s=chat.text.trim();if(s.isEmpty)return;
    setState((){messages.add((true,s));chat.clear();lastRobotMessage='Celyah بتفكر...';face='thinking';});
    if(!link.connected){setState(()=>messages.add((false,'الروبوت غير متصل. اتصلي به أولاً.')));return;}
    try{await link.send(s);}catch(e){setState(()=>messages.add((false,'تعذّر الإرسال: $e')));}
  }
  @override void dispose(){speech.cancel();tts.stop();visionTimer?.cancel();incoming?.cancel();link.removeListener(_refresh);link.dispose();chat.dispose();camera.dispose();super.dispose();}
  Widget _card(Widget child,{EdgeInsets? pad})=>Container(
    padding:pad??const EdgeInsets.all(20),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(26),
      border:Border.all(color:lavender.withValues(alpha:.12))),child:child);
  Widget _button(String label,IconData icon,VoidCallback tap,{bool primary=false})=>FilledButton.icon(
    onPressed:tap,icon:Icon(icon,size:19),label:Text(label),
    style:FilledButton.styleFrom(backgroundColor:primary?lavender:const Color(0xFF30253F),
      foregroundColor:primary?bg:Colors.white,padding:const EdgeInsets.symmetric(horizontal:17,vertical:14)));
  Widget _title(String t,String subtitle)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(t,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w700)),
    const SizedBox(height:5),Text(subtitle,style:const TextStyle(color:soft)),const SizedBox(height:20)]);
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(backgroundColor:bg,toolbarHeight:76,
      title:_brand(),
      actions:[Padding(padding:const EdgeInsets.only(right:16),child:Icon(link.connected?Icons.bluetooth_connected:Icons.bluetooth_disabled,
        color:link.connected?lavender:soft))]),
    body:SafeArea(child:IndexedStack(index:tab,children:[_home(),_messages(),_vision(),_control(),_settings()])),
    bottomNavigationBar:NavigationBar(backgroundColor:panel,indicatorColor:lavender.withValues(alpha:.22),
      selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
      destinations:const [
        NavigationDestination(icon:Icon(Icons.favorite_border),selectedIcon:Icon(Icons.favorite),label:'Celyah'),
        NavigationDestination(icon:Icon(Icons.chat_bubble_outline),label:'شات'),
        NavigationDestination(icon:Icon(Icons.visibility_outlined),label:'الرؤية'),
        NavigationDestination(icon:Icon(Icons.gamepad_outlined),label:'تحكم'),
        NavigationDestination(icon:Icon(Icons.tune),label:'إعدادات'),
      ]));
  Widget _home()=>LayoutBuilder(builder:(context,constraints){
    final height=constraints.maxHeight;
    return Column(children:[
      Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(12,6,12,5),child:Container(
        width:double.infinity,decoration:BoxDecoration(color:Colors.black,
          borderRadius:BorderRadius.circular(30),border:Border.all(color:lavender.withValues(alpha:.25))),
        child:LayoutBuilder(builder:(context,box)=>CustomPaint(
          painter:EyePainter(face),size:Size(box.maxWidth,box.maxHeight)))))),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Row(children:[
        Icon(Icons.circle,size:9,color:link.connected?Colors.greenAccent:Colors.orangeAccent),
        const SizedBox(width:7),Expanded(child:Text(link.status,maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontSize:11,color:soft))),
        TextButton.icon(onPressed:()=>setState(()=>showFullChat=!showFullChat),
          icon:Icon(showFullChat?Icons.expand_less:Icons.forum_outlined,size:17),
          label:Text(showFullChat?'إخفاء':'كل الشات')),
        IconButton(onPressed:()async{if(link.connected){await link.disconnect();}else{await link.connect();}},
          icon:Icon(link.connected?Icons.bluetooth_connected:Icons.bluetooth,color:lavender))
      ])),
      AnimatedContainer(duration:const Duration(milliseconds:200),
        height:showFullChat ? height*.31 : 64,
        margin:const EdgeInsets.symmetric(horizontal:12),padding:const EdgeInsets.all(10),
        decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(19)),
        child:showFullChat ? ListView.builder(reverse:true,itemCount:messages.length,
          itemBuilder:(context,i){final m=messages[messages.length-1-i];
            return Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Text(
              '${m.$1?'أنت':'Celyah'}: ${m.$2}',maxLines:3,overflow:TextOverflow.ellipsis,
              style:TextStyle(fontSize:13,color:m.$1?lavender:Colors.white)));})
          : Align(alignment:Alignment.centerRight,child:Text(lastRobotMessage,
            maxLines:2,overflow:TextOverflow.ellipsis,textDirection:TextDirection.rtl,
            style:const TextStyle(fontSize:13)))),
      Padding(padding:const EdgeInsets.fromLTRB(12,7,12,8),child:Row(children:[
        Expanded(child:TextField(controller:chat,onSubmitted:(_)=>_chat(),
          textInputAction:TextInputAction.send,maxLines:1,
          decoration:const InputDecoration(hintText:'اتكلم مع Celyah...',
            isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:16,vertical:14)))),
        const SizedBox(width:6),IconButton.filledTonal(onPressed:listen,
          icon:Icon(listening?Icons.stop:Icons.mic,color:lavender)),
        IconButton.filled(onPressed:_chat,icon:const Icon(Icons.send))
      ])),
    ]);
  });
  Widget _quickTile(String label,IconData icon,VoidCallback action)=>InkWell(
    onTap:action,borderRadius:BorderRadius.circular(20),
    child:Container(padding:const EdgeInsets.symmetric(vertical:18,horizontal:5),
      decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(20)),
      child:Column(children:[Icon(icon,color:lavender,size:27),const SizedBox(height:8),Text(label)])));
  Widget _messages()=>Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(18,8,18,4),
      child:Row(children:[
        Container(width:55,height:55,decoration:BoxDecoration(color:Colors.black,borderRadius:BorderRadius.circular(16)),
          child:CustomPaint(painter:EyePainter(face))),
        const SizedBox(width:12),
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Celyah ♡',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
          Text(listening?'بتسمعك دلوقتي...':robotState=='speaking'?'بترد عليك...':'جاهزة للكلام',
            style:const TextStyle(color:soft,fontSize:12))]),
      ])),
    Expanded(child:ListView.builder(reverse:true,padding:const EdgeInsets.all(18),itemCount:messages.length,
      itemBuilder:(context,i){final m=messages[messages.length-1-i];
        return Align(alignment:m.$1?Alignment.centerRight:Alignment.centerLeft,
          child:Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(15),
            constraints:BoxConstraints(maxWidth:MediaQuery.sizeOf(context).width*.8),
            decoration:BoxDecoration(color:m.$1?const Color(0xFF503467):panel,
              borderRadius:BorderRadius.circular(20)),child:Text(m.$2)));})),
    Padding(padding:const EdgeInsets.all(12),child:Row(children:[
      Expanded(child:TextField(controller:chat,onSubmitted:(_)=>_chat(),textInputAction:TextInputAction.send,
        decoration:const InputDecoration(hintText:'اكتبي رسالة لـ Celyah...'))),
      const SizedBox(width:5),
      IconButton.filledTonal(onPressed:listen,icon:Icon(listening?Icons.stop:Icons.mic,color:lavender)),
      IconButton.filled(onPressed:_chat,icon:const Icon(Icons.send))
    ]))
  ]);
  Widget _vision()=>ListView(padding:const EdgeInsets.all(18),children:[
    _title('Celyah Vision','البث المباشر من كاميرا OV3660'),
    Container(height:260,clipBehavior:Clip.antiAlias,
      decoration:BoxDecoration(color:Colors.black,borderRadius:BorderRadius.circular(24),
        border:Border.all(color:lavender.withValues(alpha:.35))),
      child:visionEnabled && visionUrl.isNotEmpty
        ? Image.network('$visionUrl?t=$visionFrame',fit:BoxFit.contain,
            gaplessPlayback:true,
            errorBuilder:(_,error,stack)=>Center(child:Text('تعذر استقبال الصورة\nتأكد أن الموبايل والروبوت على نفس Wi-Fi',
              textAlign:TextAlign.center,style:const TextStyle(color:soft))))
        : const Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Icon(Icons.videocam_off_outlined,color:lavender,size:52),
            SizedBox(height:12),Text('اضغط تشغيل الكاميرا',style:TextStyle(color:soft))]))),
    const SizedBox(height:18),
    _card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      TextField(controller:camera,decoration:const InputDecoration(
        labelText:'رابط الكاميرا (يُملأ تلقائيًا)',hintText:'http://192.168.1.182:81/jpg')),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        _button('تشغيل البث',Icons.play_arrow,()=>command('STREAM:ON'),primary:true),
        _button('إيقاف البث',Icons.stop,(){command('STREAM:OFF');visionTimer?.cancel();setState(()=>visionEnabled=false);}),
        _button('اختبار CAM',Icons.camera_alt_outlined,()=>command('CAM')),
        _button('عرض الرابط يدويًا',Icons.link,(){
          final url=camera.text.trim();
          if(url.startsWith('http://')){
            visionTimer?.cancel();
            visionTimer=Timer.periodic(const Duration(milliseconds:900),(_){
              if(mounted && tab==2 && visionEnabled)setState(()=>visionFrame++);
            });
            setState((){visionUrl=url;visionEnabled=true;visionFrame++;});
          }
        })
      ]),
      const SizedBox(height:12),
      const Text('يتطلب اتصال الموبايل والروبوت بنفس شبكة Wi-Fi. الصورة محلية ولا تُرفع لخدمة سحابية.',
        style:TextStyle(color:soft))
    ])),
    const SizedBox(height:18),
    _card(const Text('الرؤية المباشرة لا تعني التعرف على الأشخاص أو اكتشاف الحواف بعد. لا تشغّل حركة ذاتية قرب حواف أو سلالم.',
      style:TextStyle(color:soft)))
  ]);
  Widget _control()=>ListView(padding:const EdgeInsets.all(18),children:[
    _title('Celyah Control','لوحة التحكم في الحركة والتعبيرات'),
    _card(Column(children:[
      const Icon(Icons.smart_toy_outlined,color:lavender,size:38),
      const SizedBox(height:10),
      const Text('حركة Celyah V14',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
      const SizedBox(height:8),
      const Text('AUTO فقط في مساحة أرضية محاطة بحواجز وتحت إشراف؛ لا توجد حساسات حواف أو عوائق.',textAlign:TextAlign.center,style:TextStyle(color:soft)),
      const SizedBox(height:16),
      Wrap(spacing:8,runSpacing:8,alignment:WrapAlignment.center,children:[
        _button('AUTO',Icons.shuffle,()=>command('MODE:AUTO')),
        _button('MANUAL',Icons.gamepad,()=>command('MODE:MANUAL')),
        _button('OFF',Icons.pause_circle,()=>command('MODE:OFF')),
        _button('STOP',Icons.stop_circle,()=>command('STOP'),primary:true),
      ]),
      const SizedBox(height:12),
      _button('↑ أمام',Icons.keyboard_arrow_up,()=>command('DRIVE:F')),
      const SizedBox(height:8),
      Wrap(spacing:8,alignment:WrapAlignment.center,children:[
        _button('← شمال',Icons.keyboard_arrow_left,()=>command('DRIVE:L')),
        _button('يمين →',Icons.keyboard_arrow_right,()=>command('DRIVE:R')),
      ]),
      const SizedBox(height:8),
      _button('↓ خلف',Icons.keyboard_arrow_down,()=>command('DRIVE:B')),
      const SizedBox(height:12),
      _button('إلغاء المحادثة',Icons.cancel_outlined,()=>command('CANCEL')),
      const SizedBox(height:15),
      _button('اختبار الذراع 45°',Icons.front_hand_outlined,()=>command('SERVO:45')),
      const SizedBox(height:10),
      _button('الذراع 90°',Icons.back_hand_outlined,()=>command('SERVO:90')),
      const SizedBox(height:10),
      _button('الذراع 135°',Icons.pan_tool_outlined,()=>command('SERVO:135')),
    ]))
  ]);
  Widget _settings()=>ListView(padding:const EdgeInsets.all(18),children:[
    _title('إعدادات Celyah','الربط والتشخيص'),
    _card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Bluetooth: ${link.status}'),
      const SizedBox(height:16),
      _button(link.connected?'قطع الاتصال':'البحث والاتصال',Icons.bluetooth,
        ()async{if(link.connected){await link.disconnect();}else{await link.connect();}}),
      const Divider(height:32),
      const Text('Gemini',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('قراءة ردود الروبوت بصوت'),
        subtitle:const Text('استخدام تحويل النص إلى كلام على الموبايل',style:TextStyle(color:soft)),
        value:speakReplies,onChanged:(v)=>setState(()=>speakReplies=v)),
      const Text('هذه النسخة ترسل الرسائل إلى firmware عبر BLE. '
        'لا تحفظ مفاتيح API داخل التطبيق أو الكود. أضف إدارة آمنة للمفتاح في مرحلة التكامل.',
        style:TextStyle(color:soft)),
      const Divider(height:32),
      const Text('إصدار V14 — وجه ومحادثة في شاشة واحدة',style:TextStyle(color:soft)),
      const Text('تم الحفاظ على بروتوكول Nordic UART الخاص بـ V7.',style:TextStyle(color:soft))
    ]))
  ]);
}
class EyePainter extends CustomPainter {
  final String face;
  EyePainter(this.face);
  @override void paint(Canvas canvas,Size size){
    final scale=(size.width/360).clamp(.5,2.0);
    final center=Offset(size.width/2,size.height/2);
    canvas.save();canvas.translate(center.dx,center.dy);
    canvas.scale(scale,scale);
    final paint=Paint()..color=lavender..isAntiAlias=true;
    final glow=Paint()..color=lavender.withValues(alpha:.22)
      ..maskFilter=const MaskFilter.blur(BlurStyle.normal,12);
    final stroke=Paint()..color=const Color(0xFFD9A4FF)..style=PaintingStyle.stroke
      ..strokeWidth=5..strokeCap=StrokeCap.round;
    final f=face.toLowerCase();
    final closed=['happy','laugh','laughing','satisfied','sleepy','sleep','dancing','blink','blinking'].contains(f);
    final hearts=['love','heart','heart_big'].contains(f);
    final sad=['sad','crying','scared','shy'].contains(f);
    final angry=['angry','annoyed','determined'].contains(f);
    final winkL=['wink','wink_left','cheeky'].contains(f);
    final winkR=['wink_right'].contains(f);
    final looking=['curious','thinking','confused'].contains(f);
    final eyesY=-4.0;
    for(var i=0;i<2;i++){
      final x=i==0?-82.0:82.0;
      final brow=Path()..moveTo(x-33,-80)
        ..quadraticBezierTo(x,-104+(sad?15:0)+(angry?20:0),x+33,-80+(angry?-10:0));
      canvas.drawPath(brow,stroke);
      if(hearts){
        final heart=Path()..moveTo(x,eyesY+40)
          ..cubicTo(x-70,eyesY-6,x-31,eyesY-51,x,eyesY-24)
          ..cubicTo(x+31,eyesY-51,x+70,eyesY-6,x,eyesY+40);
        canvas.drawPath(heart,glow);canvas.drawPath(heart,paint);continue;
      }
      if(closed || (i==0&&winkL) || (i==1&&winkR)){
        final arc=Path()..moveTo(x-35,eyesY+20)
          ..quadraticBezierTo(x,eyesY-31,x+35,eyesY+20);
        canvas.drawPath(arc,Paint()..color=lavender..style=PaintingStyle.stroke
          ..strokeWidth=10..strokeCap=StrokeCap.round);continue;
      }
      // Soft rounded vertical eyes, not plain ellipses: tapered top and rounded bottom.
      final eye=Path()..moveTo(x,eyesY-52)
        ..cubicTo(x-35,eyesY-52,x-44,eyesY-20,x-42,eyesY+10)
        ..cubicTo(x-40,eyesY+49,x-19,eyesY+54,x,eyesY+54)
        ..cubicTo(x+19,eyesY+54,x+40,eyesY+49,x+42,eyesY+10)
        ..cubicTo(x+44,eyesY-20,x+35,eyesY-52,x,eyesY-52)..close();
      canvas.drawPath(eye,glow);canvas.drawPath(eye,paint);
      final shift=looking?(i==0?10.0:-10.0):0.0;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(
        center:Offset(x+shift,eyesY+7),width:32,height:60),const Radius.circular(16)),
        Paint()..color=const Color(0xFF16091F));
      canvas.drawOval(Rect.fromCenter(center:Offset(x+shift-9,eyesY-21),width:15,height:20),
        Paint()..color=Colors.white);
      canvas.drawCircle(Offset(x+shift+11,eyesY+24),5,
        Paint()..color=const Color(0xFFFFE3FF));
    }
    final mouth=Path()..moveTo(-13,86)..quadraticBezierTo(0,96,13,86);
    if(['excited','laugh','laughing','playful','surprised'].contains(f)){
      canvas.drawOval(Rect.fromCenter(center:const Offset(0,89),width:28,height:25),paint);
    } else if(sad){
      final down=Path()..moveTo(-14,96)..quadraticBezierTo(0,79,14,96);
      canvas.drawPath(down,stroke);
    } else if(!['sleepy','sleep','bored','angry'].contains(f)){
      canvas.drawPath(mouth,stroke);
    }
    if(['shy','embarrassed','cute','playful'].contains(f)){
      for(final x in [-133.0,133.0]){
        for(var j=0;j<3;j++)canvas.drawLine(Offset(x+j*6-6,62),Offset(x+j*6-12,75),
          Paint()..color=const Color(0xFFFF83D9)..strokeWidth=3..strokeCap=StrokeCap.round);
      }
    }
    canvas.restore();
  }
  @override bool shouldRepaint(covariant EyePainter old)=>old.face!=face;
}
