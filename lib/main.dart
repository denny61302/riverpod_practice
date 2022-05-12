import 'dart:async';
import 'dart:math';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:vector_math/vector_math.dart';

class AccelerometerAngles {
  final String xAngle;
  final String yAngle;
  final String zAngle;

  AccelerometerAngles(this.xAngle, this.yAngle, this.zAngle);
}

class Heading {
  final double headingAngles;

  Heading(this.headingAngles);
}

// We create a "provider", which will store a value (here "Hello world").
// By using a provider, this allows us to mock/override the value exposed.
final accStreamProvider = StreamProvider.autoDispose<AccelerometerAngles>((_) {
  Stream<AccelerometerAngles> stream;

  stream = accelerometerEvents.map((accData) {
    var x = (-1*degrees(atan2(-accData.y, -accData.z) - pi)).toStringAsFixed(2);
    var y = (-1*degrees(atan2(-accData.x, -accData.z) - pi)).toStringAsFixed(2);
    var z = (-1*degrees(atan2(-accData.y, -accData.x) - pi)).toStringAsFixed(2);
    return AccelerometerAngles(x,y,z);
  });

  // stream = accelerometerEvents.map((accData) {
  //   var x = degrees(atan2(accData.x, sqrt((accData.y * accData.y) + (accData.z * accData.z)))).toStringAsFixed(2);
  //   var y = degrees(atan2(accData.y, sqrt((accData.x * accData.x) + (accData.z * accData.z)))).toStringAsFixed(2);
  //   var z = degrees(atan2(sqrt((accData.x * accData.x) + (accData.y * accData.y)), accData.z)).toStringAsFixed(2);
  //   return AccelerometerAngles(x,y,z);
  // });

  return stream;
});

final accStreamProvider2 = StreamProvider.autoDispose<AccelerometerEvent>((_) {
  return accelerometerEvents;
});

final gyroStreamProvider = StreamProvider.autoDispose<GyroscopeEvent>((_) {
  return gyroscopeEvents;
});

final magnetoStreamProvider = StreamProvider.autoDispose<MagnetometerEvent>((_) {
  return magnetometerEvents;
});

double calculateHeading(AccelerometerEvent A, MagnetometerEvent E) {

  //cross product of the magnetic field vector and the gravity vector
  double Hx = E.y * A.z - E.z * A.y;
  double Hy = E.z * A.x - E.x * A.z;
  double Hz = E.x * A.y - E.y * A.x;

  //normalize the values of resulting vector
  double invH = 1.0 / sqrt(Hx * Hx + Hy * Hy + Hz * Hz);
  Hx = Hx * invH;
  Hy = Hy * invH;
  Hz = Hz * invH;

  //normalize the values of gravity vector
  double invA = 1.0 / sqrt(A.x * A.x + A.y * A.y + A.z * A.z);
  double Ax = A.x * invA;
  double Ay = A.y * invA;
  double Az = A.z * invA;

  //cross product of the gravity vector and the new vector H
  double Mx = Ay * Hz - Az * Hy;
  double My = Az * Hx - Ax * Hz;
  double Mz = Ax * Hy - Ay * Hx;

  //arctangent to obtain heading in radians
  return atan2(Hy, My);
}

double convertRadtoDeg(double rad) {
  return (rad / pi) * 180;
}

//map angle from [-180,180] range to [0,360] range
double map180to360(double angle) {
  return (angle + 360) % 360;
}

final headingStreamProvider = StreamProvider.autoDispose<Heading>((ref) {

  final controller = StreamController<Heading>();

  final Stream<AccelerometerEvent> accStream = accelerometerEvents;
  final Stream<MagnetometerEvent> magnetoStream = magnetometerEvents;

  CombineLatestStream.list([accStream, magnetoStream]).listen((value) {
    var temp = calculateHeading(value.elementAt(0) as AccelerometerEvent, value.elementAt(1) as MagnetometerEvent);
    //print(map180to360(convertRadtoDeg(temp)));
    if(!controller.isClosed){
    controller.add(Heading(map180to360(convertRadtoDeg(temp))));
    }
  });

  ref.onDispose(() {
    // Closes the StreamController when the state of this provider is destroyed.
    controller.close();
  });

  // CombineLatestStream.list([accStream, magnetoStream]).map((value) {
  //   print(value);
  //   return Heading(1);
  // });

  return controller.stream;
  
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MaterialApp(
        home: MyApp(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}

// Extend ConsumerWidget instead of StatelessWidget, which is exposed by Riverpod
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Practices',
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const AccWidget(),
              const Acc2Widget(),
              //const GyroWidget(),
              //const MagnetoWidget(),
              ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SecondRoute()),
                      (route) => false,
                    );
                  },
                  child: const Text('Next page')),
            ],
          ),
        ),
      ),
    );
  }
}

class SecondRoute extends StatelessWidget {
  const SecondRoute({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Practices page 2',
          ),
        ),
        body: Center(
          child: Column(
            children: [
              const HeadingWidget(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MyApp()),
                    (route) => false,
                  );
                },
                child: const Text('Main page'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GyroWidget extends ConsumerWidget {
  const GyroWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<GyroscopeEvent> gyroStream = ref.watch(gyroStreamProvider);

    return gyroStream.when(
      data: (data) {
        return Text(data.toString());
      },
      error: (err, stack) => Text('Error: $err'),
      loading: () => const CircularProgressIndicator(),
    );
  }
}

class Acc2Widget extends ConsumerWidget {
  const Acc2Widget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<AccelerometerEvent> acc2Stream = ref.watch(accStreamProvider2);

    return acc2Stream.when(
      data: (data) {
        return Text("X: ${(data.x / 9.8).toStringAsFixed(2)}g, Y: ${(data.y / 9.8).toStringAsFixed(2)}g, Z: ${(data.z / 9.8).toStringAsFixed(2)}g");
      },
      error: (err, stack) => Text('Error: $err'),
      loading: () => const CircularProgressIndicator(),
    );
  }
}

class MagnetoWidget extends ConsumerWidget {
  const MagnetoWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<MagnetometerEvent> magnetoStream = ref.watch(magnetoStreamProvider);

    return magnetoStream.when(
      data: (data) {
        return Text(data.toString());
      },
      error: (err, stack) => Text('Error: $err'),
      loading: () => const CircularProgressIndicator(),
    );
  }
}

class HeadingWidget extends ConsumerWidget {
  const HeadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<Heading> headingStream = ref.watch(headingStreamProvider);

    return headingStream.when(
      data: (data) {
        return Column(
          children: [
            Text("Compass: ${data.headingAngles.toStringAsFixed(2)}"),
            SleekCircularSlider(
              initialValue: data.headingAngles,
              min: 0,
              max: 360,
              appearance: CircularSliderAppearance(
                animationEnabled: false,
                startAngle: 0,
                angleRange: 360,
                infoProperties: InfoProperties(
                  modifier: (value) {
                    String output = "";
                    if (value > 337.25 || value < 22.5) {
                      output = "N";
                    } else if (292.5 < value && value < 337.25) {
                      output = "NW";
                    } else if (247.5 < value && value < 292.5) {
                      output = "W";
                    } else if (202.5 < value && value < 247.5) {
                      output = "SW";
                    } else if (157.5 < value && value < 202.5) {
                      output = "S";
                    } else if (112.5 < value && value < 157.5) {
                      output = "SE";
                    } else if (67.5 < value && value < 112.5) {
                      output = "E";
                    } else if (0 < value && value < 67.5) {
                      output = "NE";
                    }
                    return output;
                  },
                ),
              ),
              onChange: null,
            ),
          ],
        );
      },
      error: (err, stack) => Text('Error: $err'),
      loading: () => const CircularProgressIndicator(),
    );
  }
}

class AccWidget extends ConsumerWidget {
  const AccWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<AccelerometerAngles> accStream = ref.watch(accStreamProvider);

    return Center(
      child: Column(
        children: [
          const Text("XYZ Degree:"),
          accStream.when(
            data: (data) {
              //return Text("X: ${data.xAngle}\u00B0, Y: ${data.yAngle}\u00B0, Z: ${data.zAngle}\u00B0");
            return Column(
              children: [
                const Text("X Degree:"),
                SleekCircularSlider(
                  initialValue: double.parse(data.xAngle),
                  min: 0,
                  max: 360,
                  appearance: CircularSliderAppearance(
                    animationEnabled: false,
                    startAngle: 0,
                    angleRange: 360,
                    infoProperties: InfoProperties(
                      modifier: (value) {
                        return "${value.toStringAsFixed(2)}\u00B0";
                      },
                    ),
                  ),
                  onChange: null,
                ),
                const Text("Y Degree:"),
                SleekCircularSlider(
                  initialValue: double.parse(data.yAngle),
                  min: 0,
                  max: 360,
                  appearance: CircularSliderAppearance(
                    animationEnabled: false,
                    startAngle: 0,
                    angleRange: 360,
                    infoProperties: InfoProperties(
                      modifier: (value) {
                        return "${value.toStringAsFixed(2)}\u00B0";
                      },
                    ),
                  ),
                  onChange: null,
                ),
                const Text("Z Degree:"),
                SleekCircularSlider(
                  initialValue: double.parse(data.zAngle),
                  min: 0,
                  max: 360,
                  appearance: CircularSliderAppearance(
                    animationEnabled: false,
                    startAngle: 0,
                    angleRange: 360,
                    infoProperties: InfoProperties(
                      modifier: (value) {
                        return "${value.toStringAsFixed(2)}\u00B0";
                      },
                    ),
                  ),
                  onChange: null,
                ),
              ],
            );
            },
            error: (err, stack) => Text('Error: $err'),
            loading: () => const CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}
