import 'package:flutter/material.dart';
import 'package:flutter_fft/flutter_fft.dart';
import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';
import 'dart:math';


void main() => runApp(Application());

class Application extends StatefulWidget {
  @override
  ApplicationState createState() => ApplicationState();
}

class ApplicationState extends State<Application> {
  double? frequency;
  String? note;
  int? octave;
  bool? isRecording;
  int? samplerate;
  int? heartrate;

  FlutterFft flutterFft = new FlutterFft();

  _initialize() async {
    print("Starting recorder...");
    // print("Before");
    // bool hasPermission = await flutterFft.checkPermission();
    // print("After: " + hasPermission.toString());

    // Keep asking for mic permission until accepted
    while (!(await flutterFft.checkPermission())) {
      flutterFft.requestPermission();
      // IF DENY QUIT PROGRAM
    }

    // await flutterFft.checkPermissions();
    await flutterFft.startRecorder();
    print("Recorder started...");
    setState(() => isRecording = flutterFft.getIsRecording);

    flutterFft.onRecorderStateChanged.listen(
        (data) => {
              print("Changed state, received: $data"),
              setState(
                () => {
                  frequency = data[1] as double,
                  note = data[2] as String,
                  octave = data[5] as int,
                  heartrate = calculateHeartRate(data[0] as List<double>),
                },
              ),
              flutterFft.setNote = note!,
              flutterFft.setFrequency = frequency!,
              flutterFft.setOctave = octave!,
              print("Octave: ${octave!.toString()}")
            },
        onError: (err) {
          print("Error: $err");
        },
        onDone: () => {print("Is done")});
  }

  Array numListToArray(List<num> numList) {
    List<double> doubleList = numList.map((num value) => value.toDouble()).toList();
    return Array(doubleList);
  }
  Array lowPassFilter(Array data, int order, int samplerate, double cutoffFrequency) {
    List<num> bList = firwin(order, Array([cutoffFrequency / (samplerate / 2)]));
    List<double> bDoubleList = bList.map((num value) => value.toDouble()).toList();
    Array b = Array(bDoubleList);
    Array filteredData = convolution(data, b);
    return filteredData;
  }
  Array arrayMovingAverage(Array array, int windowSize) {
    List<double> inputList = array.toList();
    List<double> result = List<double>.filled(inputList.length, 0.0);

    for (int i = 0; i < inputList.length - windowSize + 1; i++) {
      double sum = 0.0;
      for (int j = 0; j < windowSize; j++) {
        sum += inputList[i + j];
      }
      result[i] = sum / windowSize;
    }

    return Array(result);
  }

  int calculateHeartRate(List<double> audioData) {
    Array inputSignal = Array(audioData);
    Array filteredSignal = lowPassFilter(inputSignal, 4, samplerate!, 30);
    Array squaredSignal = arrayPow(filteredSignal, 2);

    int windowSize = (samplerate! * 0.2).round(); // 200 ms window
    Array integratedSignal = arrayMovingAverage(squaredSignal, windowSize);

    List<dynamic> peakIndicesDynamic = findPeaks(integratedSignal, threshold: 0.8);
    List<int> peakIndices = peakIndicesDynamic.map((dynamic element) => element as int).toList();

    if (peakIndices.length >= 2) {
      int totalTimeMs = (((peakIndices.last - peakIndices.first) / samplerate!) * 1000).round();
      int numHeartBeats = peakIndices.length - 1;
      int heartRate = ((numHeartBeats / totalTimeMs) * 60000).round();
      return heartRate;
    } else {
      return 0;
    }
  }
  @override
  void initState() {
    isRecording = flutterFft.getIsRecording;
    frequency = flutterFft.getFrequency;
    note = flutterFft.getNote;
    octave = flutterFft.getOctave;
    samplerate = flutterFft.getSampleRate;
    super.initState();
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: "Simple flutter fft example",
        theme: ThemeData.dark(),
        color: Colors.blueGrey,
        home: Scaffold(
          backgroundColor: Colors.red,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isRecording!
                    ? Text("Current note: ${note!},${octave!.toString()}",
                    style: TextStyle(fontSize: 30))
                    : Text("Not Recording", style: TextStyle(fontSize: 35)),
                isRecording!
                    ? Text(
                    "Current frequency: ${frequency!.toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 30))
                    : Text("Not Recording", style: TextStyle(fontSize: 35))
              ],
            ),
          ),
        ));
  }
}