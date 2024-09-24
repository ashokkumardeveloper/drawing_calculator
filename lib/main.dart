import 'dart:typed_data';
import 'dart:convert'; // For Base64 encoding
import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(DrawingApp());
}

class DrawingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Drawing Calculator')),
        body: const DrawingScreen(),
      ),
    );
  }
}

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final DrawingController _drawingController = DrawingController();
  late final GenerativeModel _model;
  bool loaidng = false;
  String? answer;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _model = GenerativeModel(
      systemInstruction: Content.text(
          '''analyze the drawing image its a maths related image and return the solution , may it contain multiple drawing or math problems so you should be able to solve all of them.,
          eg: if the image is a math problem like 2+2=? or 2+2, the response will be " 2+2 = 4.
              if the image is a drawing of a house with a math problem or has any question , the response will be a formula with solution.
              if the image is a drawing of a man under the apple tree if the apple tree the response will be a newton's law of gravity.

          note : the response will be in maths related to the image also if its not.
          '''),
      model: 'gemini-1.5-flash-latest',
      apiKey: "AIzaSyCFZ4E7GF25afH2aUCyH7wJwH1gWlog5PU",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          ElevatedButton(
              style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.green)),
              onPressed: _saveDrawing,
              child: loaidng
                  ? CircularProgressIndicator()
                  : const Text("  Run  ",
                      style: TextStyle(color: Colors.white))),
          SizedBox(
            width: 40,
          )
        ],
      ),
      body: MediaQuery.of(context).size.width < 600
          ? MobileScreen(
              drawingController: _drawingController,
              answer: answer,
              loading: loaidng,
            )
          : Row(
              children: [
                Expanded(
                  child: Container(
                    child: Stack(
                      children: [
                        DrawingBoard(
                          controller: _drawingController,
                          background: Container(
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width,
                            color: Colors.white,
                          ),
                          //showDefaultActions: true,
                          showDefaultTools: true,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              margin: const EdgeInsets.all(16),
                              child: ElevatedButton(
                                onPressed: () {
                                  _drawingController.undo();
                                },
                                child: const Icon(Icons.undo),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(16),
                              child: ElevatedButton(
                                onPressed: () {
                                  _drawingController.redo();
                                },
                                child: const Icon(Icons.redo),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(16),
                              child: ElevatedButton(
                                onPressed: () {
                                  _drawingController.clear();
                                  setState(() {
                                    answer = null;
                                  });
                                },
                                child: const Icon(Icons.clear),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  color: Colors.black,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[200],
                    child: Column(
                      children: [
                        const Text(
                          'Result',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (loaidng)
                          const Center(
                            child: CircularProgressIndicator(),
                          )
                        else
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 16),
                              if (answer == null)
                                const Text(
                                  'Draw a math problem or any image and click the Run icon to get the solution or description of the image.',
                                  style: TextStyle(fontSize: 16),
                                ),
                              if (answer != null)
                                Text(
                                  'Answer: $answer',
                                  style: const TextStyle(fontSize: 16),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _saveDrawing() async {
    try {
      setState(() {
        loaidng = true;
      });
      // Get the drawing data as ByteData (image data)
      ByteData? byteData = await _drawingController.getImageData();

      if (byteData != null) {
        // Convert ByteData to Uint8List (raw bytes)
        Uint8List pngBytes = byteData.buffer.asUint8List();

        // Print the Uint8List (raw bytes)
        // print("Uint8List: $pngBytes");

        // Convert Uint8List to Base64 string
        String base64Image = base64Encode(pngBytes);
        var res = await _sendToGeminiApi(pngBytes);

        setState(() {
          loaidng = false;
          answer = res;
        });
        print(" from Gemini API: $res");
      } else {
        setState(() {
          loaidng = false;
        });
        print("Error: No drawing data available.");
      }
    } catch (e) {
      loaidng = false;
      print("Error saving drawing: $e");
    }
  }

  Future _sendToGeminiApi(Uint8List bytes) async {
    try {
      final content = [
        Content.multi([
          TextPart(
            "analyze the drawing image its a maths related image and return the solution , may it contain multiple drawing or math problems so you should be able to solve all of them.,",
          ),
          // The only accepted mime types are image/*.
          DataPart('image/jpeg', bytes.buffer.asUint8List()),
          // DataPart('image/jpeg', sconeBytes.buffer.asUint8List()),
        ])
      ];

      var response = await _model.generateContent(content);
      var text = response.text;
      print("Response from Gemini API: $text");
      return text;
    } catch (e) {
      print("Error sending image to Gemini API: $e");
    }
  }
}

class MobileScreen extends StatefulWidget {
  MobileScreen(
      {super.key,
      required this.drawingController,
      this.answer,
      required this.loading});
  DrawingController drawingController;
  String? answer;
  bool loading;

  @override
  State<MobileScreen> createState() => _MobileScreenState();
}

class _MobileScreenState extends State<MobileScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            child: Stack(
              children: [
                DrawingBoard(
                  controller: widget.drawingController,
                  background: Container(
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    color: Colors.white,
                  ),
                  //showDefaultActions: true,
                  showDefaultTools: true,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () {
                        widget.drawingController.undo();
                      },
                      icon: const Icon(Icons.undo),
                    ),
                    IconButton(
                      onPressed: () {
                        widget.drawingController.redo();
                      },
                      icon: const Icon(Icons.redo),
                    ),
                    IconButton(
                      onPressed: () {
                        widget.drawingController.clear();
                        setState(() {
                          widget.answer = null;
                        });
                      },
                      icon: const Icon(Icons.clear),
                    ),
                    SizedBox(
                      width: 12,
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(
          thickness: 2,
          color: Colors.black,
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Text(
                    'Result',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.loading)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        if (widget.answer == null)
                          const Text(
                            'Draw a math problem or any image and click the Run icon to get the solution or description of the image.',
                            style: TextStyle(fontSize: 16),
                          ),
                        if (widget.answer != null)
                          Text(
                            '''Answer: ${widget.answer}, \n To make a mathematical connection, we could say the cloud could represent a set of points in a plane, or a 3D space. We could then use mathematical equations to describe its shape or size.

 from Gemini API: The image is a simple drawing of a cloud.  There is no clear mathematical relationship or problem to solve.

To make a mathematical connection, we could say the cloud could represent a set of points in a plane, or a 3D space. We could then use mathematical equations to describe its shape or size.

Restarted application in 429ms.
Response from Gemini API: The image is a triangle.  The sum of interior angles of a triangle is always 180 degrees.  Therefore, if we know two angles of a triangle, we can calculate the third.
 from Gemini API: The image is a triangle.  The sum of interior angles of a triangle is always 180 degrees.  Therefore, if we know two angles of a triangle, we can calculate the third.''',
                            style: const TextStyle(fontSize: 16),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
