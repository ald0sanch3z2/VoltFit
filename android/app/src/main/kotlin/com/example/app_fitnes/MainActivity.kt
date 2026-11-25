package com.example.app_fitnes

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "voltfit/step_detector"

    private lateinit var sensorManager: SensorManager

    private var stepListener: SensorEventListener? = null

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager =
            getSystemService(SENSOR_SERVICE) as SensorManager

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setStreamHandler(
            object : EventChannel.StreamHandler {

                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?
                ) {

                    stopStepDetector()

                    // Obtener el sensor de pasos individuales.
                    val sensor = sensorManager.getDefaultSensor(
                        Sensor.TYPE_STEP_DETECTOR
                    )

                    // Verificar que el teléfono tenga el sensor.
                    if (sensor == null) {
                        events?.error(
                            "NO_SENSOR",
                            "Detector de pasos no disponible",
                            null
                        )
                        return
                    }

                    stepListener = object : SensorEventListener {

                        override fun onSensorChanged(
                            event: SensorEvent?
                        ) {

                            if (
                                event?.sensor?.type ==
                                Sensor.TYPE_STEP_DETECTOR
                            ) {
                                // Enviar un evento por cada paso.
                                events?.success(1)
                            }
                        }

                        override fun onAccuracyChanged(
                            sensor: Sensor?,
                            accuracy: Int
                        ) {
                            // No requiere procesamiento adicional.
                        }
                    }

                    try {
                        val registered = sensorManager.registerListener(
                            stepListener,
                            sensor,
                            SensorManager.SENSOR_DELAY_FASTEST,
                            0
                        )

                        if (!registered) {
                            stopStepDetector()
                            events?.error(
                                "REGISTER_ERROR",
                                "No se pudo activar el detector",
                                null
                            )
                        }

                    } catch (e: SecurityException) {
                        stopStepDetector()
                        events?.error(
                            "PERMISSION_ERROR",
                            "Permiso de actividad física requerido",
                            null
                        )
                    }
                }

                override fun onCancel(arguments: Any?) {
                    stopStepDetector()
                }
            }
        )
    }

    // Liberar el sensor para ahorrar batería.
    private fun stopStepDetector() {

        stepListener?.let {
            sensorManager.unregisterListener(it)
        }

        stepListener = null
    }

    override fun onDestroy() {

        if (::sensorManager.isInitialized) {
            stopStepDetector()
        }

        super.onDestroy()
    }
}