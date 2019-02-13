import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sensors/sensors.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

class Exercise extends StatefulWidget {
  @override
  _ExerciseState createState () => _ExerciseState();
}

class _ExerciseState extends State<Exercise> {
  // TODO: Clean up variables and functions inside whole class - most should be private,
  // TODO: some are not needed, some should be placed elsewhere
  var exercises;
  int currentStep = 0;
  int currentEx = 0;
  var stopwatch = new Stopwatch();
  bool finishedLoading = false;
  String _dropdownValue;
  List<String> _exerciseNames;

  List<double> _accelerometerValues;
  List<StreamSubscription<dynamic>> _streamSubscriptions = <StreamSubscription<dynamic>>[];

  @override
  Widget build(BuildContext context) {
//    final List<String> accelerometer =
//      _accelerometerValues?.map((double v) => v.toStringAsFixed(1))?.toList();
    if(finishedLoading) {
      _exerciseNames = exercises?.map<String>((item) => item['name'].toString())?.toList();
      _dropdownValue = _exerciseNames[currentEx];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wobble Board Exercises'),
      ),
      body: finishedLoading ? Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                DropdownButton<String>(
                    value: _dropdownValue,
                    onChanged: (String newValue) {
                      setState(() {
                        // set state to the selected exercise
                        currentEx = _exerciseNames.indexOf(newValue);
                        currentStep = 0;
                      });
                    },
                    items: _exerciseNames.map((location) {
                      return DropdownMenuItem<String>(
                          child: Text(location),
                          value: location
                      );
                    }).toList()
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '$currentStep',
                style: TextStyle(fontSize: 30.0),
              ),
            ],
          ),
          Icon(Icons.keyboard_arrow_up, size: 50, color: getColor(0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.keyboard_arrow_left, size: 50, color: getColor(3)),
              Icon(Icons.keyboard_arrow_right, size: 50, color: getColor(1)),
            ],
          ),
          Icon(Icons.keyboard_arrow_down, size: 50, color: getColor(2)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '${stopwatch.elapsed}',
                style: TextStyle(fontSize: 30.0),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '${exercises[currentEx]['steps'][currentStep]['text']}',
                  style: TextStyle(fontSize: 15.0, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ) :
      // show a progress indicator if still loading in exercise data
      Center(child: CircularProgressIndicator(
        strokeWidth: 3.0,
      )),
    );
  }


  Future<String> _loadExercisesAsset() async {
    return await rootBundle.loadString('assets/exercises.json');
  }

  void loadExercises() async {
    String json = await _loadExercisesAsset();
    _parseJson(json);
  }

  void _parseJson(String jsonString) {
    exercises = json.decode(jsonString);
    finishedLoading = true;
  }

  Color getColor(int rowID) {
    // TODO: Come up with a better way of choosing the color - maybe not needed if using animation
    Color color;
    if(currentEx == 1) {
      color = ((rowID == 1 || rowID == 3) ? Colors.blue : Colors.black);
    }
    else {
      color = (rowID == currentStep ? Colors.blue : Colors.black);
    }
    return color;
  }

  void checkIfComplete() {
    var axisValue;
    var currentGoal;
    var timeToHold;
    var condition;

    if(exercises != null) {
      // check which axis value to monitor
      // TODO: Need better way of determining this
      if(exercises[currentEx]['steps'][currentStep]['axis'] == 'x') {
        axisValue = _accelerometerValues[0];
      }
      else if(exercises[currentEx]['steps'][currentStep]['axis'] == 'xy') {
        axisValue = [_accelerometerValues[0], _accelerometerValues[1]];
      }
      else {
        axisValue = _accelerometerValues[1];
      }

      currentGoal = exercises[currentEx]['steps'][currentStep]['goal'];
      timeToHold = exercises[currentEx]['steps'][currentStep]['time'];

      // TODO: Work on this - figure out how to store and compute different exercises conditions
      condition = exercises[currentEx]['type'] == 'movement' ?
        ((currentGoal < 0 && axisValue <= currentGoal) || (currentGoal > 0 && axisValue >= currentGoal)) :
        ((axisValue[0] < currentGoal && axisValue[0] > -(currentGoal)) && (axisValue[1] < currentGoal && axisValue[1] > -(currentGoal)));

      if(condition) {
        // start the stopwatch
        stopwatch.start();

        // if time elapsed is longer than the required time to hold
        // exercise has been completed
        if(stopwatch.elapsedMilliseconds >= timeToHold) {
          // stop and reset stepwatch
          stopwatch.stop();
          stopwatch.reset();
          // this is the last step of the exercise
          if(currentStep == exercises[currentEx]['steps'].length - 1) {
            // reset step count
            currentStep = 0;
            // reset exercises if this is the last one
            if(currentEx == exercises.length - 1) {
              currentEx = 0;
            }
            // else move on to the next exercise
            else {
              currentEx++;
            }
          }
          // move to next step of the exercise
          else {
            currentStep++;
          }
        }
      }
      // if the accelerometer value is no longer within range then stop and reset the stopwatch
      else {
        if(stopwatch.isRunning) {
          stopwatch.stop();
          stopwatch.reset();
        }
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    for (StreamSubscription<dynamic> subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    loadExercises();
    _streamSubscriptions
        .add(accelerometerEvents.listen((AccelerometerEvent event) {
          setState(() {
            _accelerometerValues = <double>[event.x, event.y, event.z];
          });
          // call the check function every time new values are received
          checkIfComplete();
        })
    );
  }
}