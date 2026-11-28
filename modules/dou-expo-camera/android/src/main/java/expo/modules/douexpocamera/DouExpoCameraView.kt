package expo.modules.douexpocamera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.media.Image
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.util.Size
import android.view.Surface
import android.view.TextureView
import android.widget.FrameLayout
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.viewevent.EventDispatcher
import expo.modules.kotlin.views.ExpoView
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.min

class DouExpoCameraView(context: Context, appContext: AppContext) : ExpoView(context, appContext), TextureView.SurfaceTextureListener {
  val onPhotoCaptured by EventDispatcher()
  val onCameraError by EventDispatcher()
  val onCameraReady by EventDispatcher()

  private val preview = TextureView(context)
  private var cameraManager: CameraManager? = null
  private var device: CameraDevice? = null
  private var session: CameraCaptureSession? = null
  private var jpegReader: ImageReader? = null
  private var thread: HandlerThread? = null
  private var handler: Handler? = null
  private var cameraId: String? = null
  private var previewRequest: CaptureRequest.Builder? = null
  private val capturePending = AtomicBoolean(false)
  private var manualSensor = false
  private var isoRange: android.util.Range<Int>? = null
  private var exposureRange: android.util.Range<Long>? = null
  private var focusMax = 0f
  private var selectedFacing = "back"
  private var selectedIso = 0
  private var selectedExposureNs = 0L
  private var selectedFocusDiopters = -1f
  private var selectedAwb = -1
  private var selectedZoom = 0f
  private var requestedCapture = 0

  init {
    addView(preview, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    preview.surfaceTextureListener = this
    cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
  }

  fun setFacing(value: String) {
    val next = if (value == "front") "front" else "back"
    if (selectedFacing != next) { selectedFacing = next; restartCamera() }
  }

  fun setIso(value: Int) { selectedIso = value.coerceAtLeast(0); updateRepeating() }
  fun setExposureTimeNs(value: Long) { selectedExposureNs = value.coerceAtLeast(0L); updateRepeating() }
  fun setFocusDistance(value: Float) { selectedFocusDiopters = value; updateRepeating() }
  fun setAwbMode(value: Int) { selectedAwb = value; updateRepeating() }
  fun setZoom(value: Float) { selectedZoom = value.coerceIn(0f, 1f); updateRepeating() }

  fun requestCapture(value: Int) {
    if (value <= 0 || value == requestedCapture) return
    requestedCapture = value
    captureStill()
  }

  private fun startThread() {
    if (thread != null) return
    thread = HandlerThread("DouExpo-Camera2").also { it.start() }
    handler = Handler(thread!!.looper)
  }

  private fun restartCamera() {
    closeCamera()
    if (preview.isAvailable && isAttachedToWindow) openCamera()
  }

  private fun openCamera() {
    if (context.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
      onCameraError(mapOf("message" to "Camera permission is not granted"))
      return
    }
    startThread()
    try {
      val manager = cameraManager ?: return
      val wanted = if (selectedFacing == "front") CameraCharacteristics.LENS_FACING_FRONT else CameraCharacteristics.LENS_FACING_BACK
      val id = manager.cameraIdList.firstOrNull { manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == wanted }
        ?: throw IllegalStateException("Requested camera is unavailable")
      val chars = manager.getCameraCharacteristics(id)
      cameraId = id
      isoRange = chars.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
      exposureRange = chars.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
      focusMax = chars.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0f
      val caps = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)?.toList() ?: emptyList()
      manualSensor = caps.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR)
      manager.openCamera(id, object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
          device = camera
          createPreviewSession()
        }
        override fun onDisconnected(camera: CameraDevice) {
          camera.close(); if (device === camera) device = null
          onCameraError(mapOf("message" to "Camera disconnected"))
        }
        override fun onError(camera: CameraDevice, error: Int) {
          camera.close(); if (device === camera) device = null
          onCameraError(mapOf("message" to "Camera2 error: $error"))
        }
      }, handler)
    } catch (e: Exception) {
      onCameraError(mapOf("message" to (e.message ?: "Unable to open Camera2")))
    }
  }

  private fun createPreviewSession() {
    val camera = device ?: return
    val texture = preview.surfaceTexture ?: return
    try {
      val sizes = cameraManager!!.getCameraCharacteristics(cameraId!!).get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        ?.getOutputSizes(SurfaceTexture::class.java)
      val size = sizes?.filter { it.width <= 1920 && it.height <= 1080 }?.maxByOrNull { it.width * it.height }
        ?: Size(1280, 720)
      texture.setDefaultBufferSize(size.width, size.height)
      val previewSurface = Surface(texture)
      jpegReader?.close()
      jpegReader = ImageReader.newInstance(size.width, size.height, android.graphics.ImageFormat.JPEG, 2)
      jpegReader?.setOnImageAvailableListener({ reader ->
        var image: Image? = null
        try {
          image = reader.acquireNextImage() ?: return@setOnImageAvailableListener
          val buffer = image.planes[0].buffer
          val bytes = ByteArray(buffer.remaining())
          buffer.get(bytes)
          val file = File(context.cacheDir, "dou-shot-${System.currentTimeMillis()}.jpg")
          FileOutputStream(file).use { it.write(bytes) }
          capturePending.set(false)
          onPhotoCaptured(mapOf("uri" to file.toURI().toString(), "width" to image.width, "height" to image.height))
        } catch (e: Exception) {
          capturePending.set(false)
          onCameraError(mapOf("message" to (e.message ?: "Photo capture failed")))
        } finally { image?.close() }
      }, handler)
      camera.createCaptureSession(listOf(previewSurface, jpegReader!!.surface), object : CameraCaptureSession.StateCallback() {
        override fun onConfigured(configured: CameraCaptureSession) {
          if (device !== camera) { configured.close(); return }
          session = configured
          try {
            previewRequest = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
              addTarget(previewSurface)
              set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
            }
            applyManualControls(previewRequest!!)
            configured.setRepeatingRequest(previewRequest!!.build(), null, handler)
            onCameraReady(mapOf("cameraId" to (cameraId ?: ""), "manualSensorSupported" to manualSensor))
          } catch (e: Exception) { onCameraError(mapOf("message" to (e.message ?: "Preview request failed"))) }
        }
        override fun onConfigureFailed(failed: CameraCaptureSession) {
          onCameraError(mapOf("message" to "Camera2 preview session configuration failed"))
        }
      }, handler)
    } catch (e: Exception) {
      onCameraError(mapOf("message" to (e.message ?: "Unable to configure preview")))
    }
  }

  private fun applyManualControls(builder: CaptureRequest.Builder) {
    if (manualSensor && selectedIso > 0 && selectedExposureNs > 0L) {
      val iso = isoRange?.let { selectedIso.coerceIn(it.lower, it.upper) } ?: selectedIso
      val exposure = exposureRange?.let { selectedExposureNs.coerceIn(it.lower, it.upper) } ?: selectedExposureNs
      builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
      builder.set(CaptureRequest.SENSOR_SENSITIVITY, iso)
      builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, exposure)
    } else {
      builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
    }
    if (selectedFocusDiopters >= 0f && focusMax > 0f) {
      builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
      builder.set(CaptureRequest.LENS_FOCUS_DISTANCE, selectedFocusDiopters.coerceIn(0f, focusMax))
    } else {
      builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
    }
    if (selectedAwb >= 0) {
      builder.set(CaptureRequest.CONTROL_AWB_MODE, selectedAwb)
    } else {
      builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)
    }
    if (android.os.Build.VERSION.SDK_INT >= 30) {
      val range = cameraId?.let { cameraManager?.getCameraCharacteristics(it)?.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE) }
      if (range != null) builder.set(CaptureRequest.CONTROL_ZOOM_RATIO, range.lower + (range.upper - range.lower) * selectedZoom)
    } else {
      val chars = cameraId?.let { cameraManager?.getCameraCharacteristics(it) }
      val active = chars?.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
      if (active != null) {
        val factor = 1f + selectedZoom * 4f
        val w = (active.width() / factor).toInt()
        val h = (active.height() / factor).toInt()
        val cx = active.centerX(); val cy = active.centerY()
        builder.set(CaptureRequest.SCALER_CROP_REGION, android.graphics.Rect(cx-w/2, cy-h/2, cx+w/2, cy+h/2))
      }
    }
  }

  private fun updateRepeating() {
    val h = handler ?: return
    h.post {
      try {
        val builder = previewRequest ?: return@post
        val activeSession = session ?: return@post
        applyManualControls(builder)
        activeSession.setRepeatingRequest(builder.build(), null, h)
      } catch (e: Exception) { onCameraError(mapOf("message" to (e.message ?: "Unable to update camera controls"))) }
    }
  }

  private fun captureStill() {
    if (!capturePending.compareAndSet(false, true)) return
    val h = handler ?: run { capturePending.set(false); return }
    h.post {
      try {
        val camera = device ?: throw IllegalStateException("Camera is not ready")
        val activeSession = session ?: throw IllegalStateException("Camera session is not ready")
        val reader = jpegReader ?: throw IllegalStateException("Photo output is not ready")
        val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
          addTarget(reader.surface)
          set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
          applyManualControls(this)
        }
        activeSession.capture(request.build(), object : CameraCaptureSession.CaptureCallback() {
          override fun onCaptureFailed(session: CameraCaptureSession, request: CaptureRequest, failure: CaptureFailure) {
            capturePending.set(false)
            onCameraError(mapOf("message" to "Still capture failed: ${failure.reason}"))
          }
        }, h)
      } catch (e: Exception) {
        capturePending.set(false)
        onCameraError(mapOf("message" to (e.message ?: "Still capture failed")))
      }
    }
  }

  private fun closeCamera() {
    try { session?.close() } catch (_: Exception) {}
    session = null
    try { device?.close() } catch (_: Exception) {}
    device = null
    try { jpegReader?.close() } catch (_: Exception) {}
    jpegReader = null
    capturePending.set(false)
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    if (preview.isAvailable) openCamera()
  }

  override fun onDetachedFromWindow() {
    closeCamera()
    thread?.quitSafely()
    try { thread?.join(500) } catch (_: InterruptedException) {}
    thread = null; handler = null
    super.onDetachedFromWindow()
  }

  override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) { openCamera() }
  override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {}
  override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean { closeCamera(); return true }
  override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {}
}
