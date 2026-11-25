
class Workout {
  final String id;
  final String date;
  final int seconds;
  final int steps;
  final double distanceMeters;
  final String intensity;
  final List<List<double>> route;

  // Índices donde comienza un nuevo segmento GPS.
  final List<int> routeBreaks;

  const Workout({
    required this.id,
    required this.date,
    required this.seconds,
    required this.steps,
    required this.distanceMeters,
    required this.intensity,
    required this.route,
    this.routeBreaks = const [],
  });

  // Convertir el entrenamiento a JSON.
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'seconds': seconds,
    'steps': steps,
    'distanceMeters': distanceMeters,
    'intensity': intensity,
    'route': route,
    'routeBreaks': routeBreaks,
  };

  // Recuperar un entrenamiento almacenado.
  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      date: json['date'] as String,
      seconds: (json['seconds'] as num).toInt(),
      steps: (json['steps'] as num).toInt(),
      distanceMeters:
      (json['distanceMeters'] as num).toDouble(),
      intensity: json['intensity'] as String,

      route: (json['route'] as List).map((point) {
        final p = point as List;

        return [
          (p[0] as num).toDouble(),
          (p[1] as num).toDouble(),
        ];
      }).toList(),

      // Los entrenamientos anteriores pueden no tener este campo.
      routeBreaks: (json['routeBreaks'] as List? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}
