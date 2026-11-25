
import 'package:flutter_test/flutter_test.dart';
import 'package:app_fitnes/models/workout.dart';

void main() {
  // Prueba del almacenamiento de entrenamientos.
  test('Verificar datos de entrenamiento de VoltFit', () {
    const workout = Workout(
      id: '1',
      date: '2026-11-23',
      seconds: 60,
      steps: 100,
      distanceMeters: 74.0,
      intensity: 'Caminata',
      route: [],
    );

    // Convertir los datos a JSON.
    final json = workout.toJson();

    // Recuperar los datos almacenados.
    final recovered = Workout.fromJson(json);

    // Comprobar que los datos sean correctos.
    expect(recovered.id, '1');
    expect(recovered.steps, 100);
    expect(recovered.seconds, 60);
    expect(recovered.distanceMeters, 74.0);
    expect(recovered.intensity, 'Caminata');
    expect(recovered.route, isEmpty);
    expect(recovered.routeBreaks, isEmpty);
  });
}
