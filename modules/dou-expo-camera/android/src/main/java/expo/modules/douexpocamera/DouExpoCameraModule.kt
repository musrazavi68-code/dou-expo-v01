package expo.modules.douexpocamera

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class DouExpoCameraModule : Module() {
  private var tone: ToneGenerator? = null

  override fun definition() = ModuleDefinition {
    Name("DouExpoCamera")

    AsyncFunction("getCapabilities") { requestedFacing: String ->
      val context = appContext.reactContext ?: throw Exception("Android context unavailable")
      val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
      val wanted = if (requestedFacing == "front") CameraCharacteristics.LENS_FACING_FRONT else CameraCharacteristics.LENS_FACING_BACK
      val id = manager.cameraIdList.firstOrNull { cameraId ->
        manager.getCameraCharacteristics(cameraId).get(CameraCharacteristics.LENS_FACING) == wanted
      } ?: manager.cameraIdList.firstOrNull() ?: throw Exception("No camera available")
      val c = manager.getCameraCharacteristics(id)
      val iso = c.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
      val exposure = c.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
      val focus = c.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE)
      val awb = c.get(CameraCharacteristics.CONTROL_AWB_AVAILABLE_MODES)?.map { it } ?: emptyList<Int>()
      val af = c.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)?.map { it } ?: emptyList<Int>()
      val capabilities = c.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)?.toList() ?: emptyList<Int>()
      val aeComp = c.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
      val focalLengths = c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
      val zoomRatio = if (Build.VERSION.SDK_INT >= 30) c.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE) else null
      val flash = c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
      val manualSensor = capabilities.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR)
      val manualPost = capabilities.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_POST_PROCESSING)
      mapOf(
        "cameraId" to id,
        "facing" to requestedFacing,
        "isoMin" to (iso?.lower ?: 0),
        "isoMax" to (iso?.upper ?: 0),
        "exposureMinNs" to (exposure?.lower ?: 0L),
        "exposureMaxNs" to (exposure?.upper ?: 0L),
        "manualSensorSupported" to manualSensor,
        "manualPostProcessingSupported" to manualPost,
        "minimumFocusDistanceDiopters" to (focus ?: 0f),
        "autofocusModes" to af,
        "manualFocusSupported" to ((focus ?: 0f) > 0f),
        "awbModes" to awb,
        "aeCompensationMin" to (aeComp?.lower ?: 0),
        "aeCompensationMax" to (aeComp?.upper ?: 0),
        "focalLengthsMm" to (focalLengths?.toList() ?: emptyList<Float>()),
        "zoomRatioMin" to (zoomRatio?.lower ?: 1f),
        "zoomRatioMax" to (zoomRatio?.upper ?: 1f),
        "flashAvailable" to flash,
        "hardwareLevel" to (c.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL) ?: -1)
      )
    }

    Function("playZoomTick") {
      val context = appContext.reactContext ?: return@Function false
      try {
        if (tone == null) tone = ToneGenerator(AudioManager.STREAM_SYSTEM, 24)
        tone?.startTone(ToneGenerator.TONE_PROP_BEEP, 24)
        true
      } catch (_: Exception) { false }
    }

    Function("shutterHaptic") {
      val context = appContext.reactContext ?: return@Function false
      try {
        if (Build.VERSION.SDK_INT >= 31) {
          val vibrator = context.getSystemService(VibratorManager::class.java).defaultVibrator
          vibrator.vibrate(VibrationEffect.createOneShot(22, 90))
        } else {
          @Suppress("DEPRECATION")
          val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
          if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createOneShot(22, 90))
          else @Suppress("DEPRECATION") vibrator.vibrate(22)
        }
        true
      } catch (_: Exception) { false }
    }

    View(DouExpoCameraView::class) {
      Events("onPhotoCaptured", "onCameraError", "onCameraReady")
      Prop("facing") { view: DouExpoCameraView, value: String -> view.setFacing(value) }
      Prop("iso") { view: DouExpoCameraView, value: Int -> view.setIso(value) }
      Prop("exposureTimeNs") { view: DouExpoCameraView, value: Long -> view.setExposureTimeNs(value) }
      Prop("focusDistance") { view: DouExpoCameraView, value: Float -> view.setFocusDistance(value) }
      Prop("awbMode") { view: DouExpoCameraView, value: Int -> view.setAwbMode(value) }
      Prop("zoom") { view: DouExpoCameraView, value: Float -> view.setZoom(value) }
      Prop("captureRequest") { view: DouExpoCameraView, value: Int -> view.requestCapture(value) }
    }

    OnDestroy { tone?.release(); tone = null }
  }
}
