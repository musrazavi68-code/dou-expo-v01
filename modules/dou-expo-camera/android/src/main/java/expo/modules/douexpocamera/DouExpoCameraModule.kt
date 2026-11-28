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
      val awb = c.get(CameraCharacteristics.CONTROL_AWB_AVAILABLE_MODES)?.map { it }
        ?: emptyList<Int>()
      val flash = c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
      mapOf(
        "cameraId" to id,
        "facing" to requestedFacing,
        "isoMin" to (iso?.lower ?: 0),
        "isoMax" to (iso?.upper ?: 0),
        "exposureMinNs" to (exposure?.lower ?: 0L),
        "exposureMaxNs" to (exposure?.upper ?: 0L),
        "minimumFocusDistance" to (focus ?: 0f),
        "autofocusSupported" to ((c.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)?.isNotEmpty()) ?: false),
        "awbModes" to awb,
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

    OnDestroy { tone?.release(); tone = null }
  }
}
