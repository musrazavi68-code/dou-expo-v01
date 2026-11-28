package expo.modules.douexpocamera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Color
import android.view.View
import android.hardware.camera2.*
import android.media.Image
import android.media.ImageReader
import android.net.Uri
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
  private val peakingOverlay = FocusPeakingOverlay(context)
  private var yuvReader: ImageReader? = null
  private var previewSurface: Surface? = null
  private var peakingEnabled = false
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
  private var flashAvailable = false
  private var isoRange: android.util.Range<Int>? = null
  private var exposureRange: android.util.Range<Long>? = null
  private var focusMax = 0f
  private var selectedFacing = "back"
  private var selectedIso = 0
  private var selectedExposureNs = 0L
  private var selectedFocusDiopters = -1f
  private var selectedAwb = -1
  private var selectedZoom = 0f
  private var selectedTorch = false
  private var requestedCapture = 0
  private var opening = false
  private var yuvOutputActive = false

  init {
    addView(preview, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    addView(peakingOverlay, FrameLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
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
  fun setTorch(value: Boolean) { selectedTorch = value; updateRepeating() }
  fun setFocusPeaking(value: Boolean) {
    if (peakingEnabled == value) return
    peakingEnabled = value
    peakingOverlay.visibility = if (value) View.VISIBLE else View.GONE
    handler?.post {
      try { session?.close() } catch (_: Exception) {}
      session = null
      createPreviewSession()
    }
  }

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
    if (device != null || opening || !preview.isAvailable) return
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
      flashAvailable = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false
      val caps = chars.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)?.toList() ?: emptyList()
      manualSensor = caps.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR)
      manager.openCamera(id, object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
          opening = false
          device = camera
          createPreviewSession()
        }
        override fun onDisconnected(camera: CameraDevice) {
          opening = false
          camera.close(); if (device === camera) device = null
          onCameraError(mapOf("message" to "Camera disconnected"))
        }
        override fun onError(camera: CameraDevice, error: Int) {
          opening = false
          camera.close(); if (device === camera) device = null
          onCameraError(mapOf("message" to "Camera2 error: $error"))
        }
      }, handler)
    } catch (e: Exception) {
      opening = false
      onCameraError(mapOf("message" to (e.message ?: "Unable to open Camera2")))
    }
  }

  private fun createPreviewSession() {
    val camera = device ?: return
    val texture = preview.surfaceTexture ?: return
    try {
      val streamMap = cameraManager!!.getCameraCharacteristics(cameraId!!).get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        ?: throw IllegalStateException("Camera output formats are unavailable")
      val previewSizes = streamMap.getOutputSizes(SurfaceTexture::class.java)
      val size = previewSizes?.filter { it.width <= 1920 && it.height <= 1080 }?.maxByOrNull { it.width * it.height }
        ?: previewSizes?.maxByOrNull { it.width * it.height }
        ?: Size(1280, 720)
      val jpegSizes = streamMap.getOutputSizes(android.graphics.ImageFormat.JPEG)
      val jpegSize = jpegSizes?.filter { it.width.toLong() * it.height.toLong() <= 12_000_000L }
        ?.maxByOrNull { it.width * it.height } ?: jpegSizes?.maxByOrNull { it.width * it.height }
        ?: size
      texture.setDefaultBufferSize(size.width, size.height)
      val newPreviewSurface = Surface(texture)
      previewSurface?.release()
      previewSurface = newPreviewSurface
      jpegReader?.close()
      jpegReader = ImageReader.newInstance(jpegSize.width, jpegSize.height, android.graphics.ImageFormat.JPEG, 2)
      jpegReader?.setOnImageAvailableListener({ reader ->
        var image: Image? = null
        try {
          image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
          val capturedImage = image
          val buffer = capturedImage.planes[0].buffer
          val bytes = ByteArray(buffer.remaining())
          buffer.get(bytes)
          val file = File(context.cacheDir, "dou-shot-${System.currentTimeMillis()}.jpg")
          FileOutputStream(file).use { it.write(bytes) }
          capturePending.set(false)
          onPhotoCaptured(mapOf("uri" to Uri.fromFile(file).toString(), "width" to capturedImage.width, "height" to capturedImage.height))
        } catch (e: Exception) {
          capturePending.set(false)
          onCameraError(mapOf("message" to (e.message ?: "Photo capture failed")))
        } finally { image?.close() }
      }, handler)
      yuvReader?.close()
      yuvReader = null
      yuvOutputActive = false
      if (peakingEnabled) {
        try {
          yuvReader = ImageReader.newInstance(640, 480, android.graphics.ImageFormat.YUV_420_888, 2).also { reader ->
            reader.setOnImageAvailableListener({ source ->
              var frame: Image? = null
              try {
                frame = source.acquireLatestImage()
                if (frame != null) peakingOverlay.updateFromLuma(frame!!)
              } catch (_: Exception) {
              } finally { frame?.close() }
            }, handler)
          }
          yuvOutputActive = true
        } catch (_: Exception) { yuvReader = null; yuvOutputActive = false }
      }
      val previewOutput = previewSurface ?: throw IllegalStateException("Preview surface is unavailable")
      val outputSurfaces = mutableListOf(previewOutput, jpegReader!!.surface)
      if (yuvOutputActive) outputSurfaces.add(yuvReader!!.surface)
      camera.createCaptureSession(outputSurfaces, object : CameraCaptureSession.StateCallback() {
        override fun onConfigured(configured: CameraCaptureSession) {
          if (device !== camera) { configured.close(); return }
          session = configured
          try {
            previewRequest = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
              addTarget(previewOutput)
              if (yuvOutputActive) addTarget(yuvReader!!.surface)
              set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
            }
            applyManualControls(previewRequest!!)
            configured.setRepeatingRequest(previewRequest!!.build(), null, handler)
            onCameraReady(mapOf("cameraId" to (cameraId ?: ""), "manualSensorSupported" to manualSensor))
          } catch (e: Exception) { onCameraError(mapOf("message" to (e.message ?: "Preview request failed"))) }
        }
        override fun onConfigureFailed(failed: CameraCaptureSession) {
          if (yuvOutputActive) { yuvReader?.close(); yuvReader = null; yuvOutputActive = false; createPreviewSession() } else onCameraError(mapOf("message" to "Camera2 preview session configuration failed"))
        }
      }, handler)
    } catch (e: Exception) {
      onCameraError(mapOf("message" to (e.message ?: "Unable to configure preview")))
    }
  }

  private fun applyManualControls(builder: CaptureRequest.Builder) {
    builder.set(CaptureRequest.FLASH_MODE, if (selectedTorch && flashAvailable) CaptureRequest.FLASH_MODE_TORCH else CaptureRequest.FLASH_MODE_OFF)
    if (manualSensor && (selectedIso > 0 || selectedExposureNs > 0L)) {
      val isoBounds = isoRange
      val exposureBounds = exposureRange
      val defaultIso = isoBounds?.let { (it.lower + it.upper) / 2 } ?: 100
      val defaultExposure = exposureBounds?.let { 10_000_000L.coerceIn(it.lower, it.upper) } ?: 10_000_000L
      val iso = isoBounds?.let { (if (selectedIso > 0) selectedIso else defaultIso).coerceIn(it.lower, it.upper) } ?: defaultIso
      val exposure = exposureBounds?.let { (if (selectedExposureNs > 0L) selectedExposureNs else defaultExposure).coerceIn(it.lower, it.upper) } ?: defaultExposure
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
          val characteristics = cameraManager?.getCameraCharacteristics(cameraId ?: "")
          val sensorOrientation = characteristics?.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
          val rotation = (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).defaultDisplay.rotation
          val deviceDegrees = when (rotation) { Surface.ROTATION_90 -> 90; Surface.ROTATION_180 -> 180; Surface.ROTATION_270 -> 270; else -> 0 }
          val facing = characteristics?.get(CameraCharacteristics.LENS_FACING)
          val jpegOrientation = if (facing == CameraCharacteristics.LENS_FACING_FRONT) (sensorOrientation + deviceDegrees) % 360 else (sensorOrientation - deviceDegrees + 360) % 360
          set(CaptureRequest.JPEG_ORIENTATION, jpegOrientation)
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
    try { yuvReader?.close() } catch (_: Exception) {}
    yuvReader = null
    try { previewSurface?.release() } catch (_: Exception) {}
    previewSurface = null
    capturePending.set(false)
    opening = false
    cameraId = null
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

  private class FocusPeakingOverlay(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(255, 48, 48); style = Paint.Style.FILL; alpha = 220 }
    @Volatile private var points: FloatArray = FloatArray(0)
    fun updateFromLuma(image: Image) {
      if (image.planes.isEmpty()) return
      val plane = image.planes[0]; val data = plane.buffer
      val w = image.width; val h = image.height; val row = plane.rowStride; val pixel = plane.pixelStride
      val out = ArrayList<Float>(256); val step = 8
      for (y in step until h - step step step) for (x in step until w - step step step) {
        val index = y * row + x * pixel
        val left = data.get(index - pixel).toInt() and 255
        val right = data.get(index + pixel).toInt() and 255
        val up = data.get(index - row).toInt() and 255
        val down = data.get(index + row).toInt() and 255
        if (kotlin.math.abs(right - left) + kotlin.math.abs(down - up) > 105) { out.add(x.toFloat() / w); out.add(y.toFloat() / h) }
      }
      val result = FloatArray(out.size)
      for (i in out.indices) result[i] = out[i]
      points = result; postInvalidateOnAnimation()
    }
    override fun onDraw(canvas: Canvas) {
      super.onDraw(canvas); val current = points; val radius = 2f * resources.displayMetrics.density
      var i = 0
      while (i + 1 < current.size) { canvas.drawCircle(current[i] * width, current[i + 1] * height, radius, paint); i += 2 }
    }
  }
}
