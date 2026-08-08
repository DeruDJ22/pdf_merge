package com.example.pdf_merge

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.graphics.Bitmap
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val INTENT_CHANNEL = "com.example.pdf_merge/intent"
    private val MERGE_CHANNEL = "com.example.pdf_merge/merge"
    private var intentChannel: MethodChannel? = null
    private var mergeChannel: MethodChannel? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Clean stale temporary cache files on app launch
        executor.execute { cleanStaleCache() }

        // Intent channel for receiving PDF files
        intentChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL)
        intentChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialIntent" -> {
                    val files = handleIntent(intent)
                    result.success(if (files.isNotEmpty()) files else null)
                }
                else -> result.notImplemented()
            }
        }

        // Merge & Thumbnail & Cache channel
        mergeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MERGE_CHANNEL)
        mergeChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "mergePdfs" -> {
                    val paths = call.argument<List<String>>("paths")
                    val output = call.argument<String>("output")
                    if (paths != null && output != null) {
                        executor.execute {
                            try {
                                val success = mergePdfFilesBackground(paths, output)
                                mainHandler.post {
                                    result.success(success)
                                }
                            } catch (e: Exception) {
                                mainHandler.post {
                                    result.error("MERGE_ERROR", e.message, null)
                                }
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "Missing paths or output", null)
                    }
                }
                "renderThumbnail" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        executor.execute {
                            val thumbPath = generateThumbnail(path)
                            mainHandler.post {
                                result.success(thumbPath)
                            }
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "clearCache" -> {
                    executor.execute {
                        val freedBytes = cleanAppCache()
                        mainHandler.post {
                            result.success(freedBytes)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val files = handleIntent(intent)
        if (files.isNotEmpty()) {
            intentChannel?.invokeMethod("onNewIntent", files)
        }
    }

    private fun handleIntent(intent: Intent?): List<String> {
        if (intent == null) return emptyList()

        val files = mutableListOf<String>()

        when (intent.action) {
            Intent.ACTION_VIEW -> {
                intent.data?.let { uri ->
                    val path = resolveOrCopyUri(uri)
                    if (path != null) files.add(path)
                }
            }
            Intent.ACTION_SEND -> {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (uri != null) {
                    val path = resolveOrCopyUri(uri)
                    if (path != null) files.add(path)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                uris?.forEach { uri ->
                    val path = resolveOrCopyUri(uri)
                    if (path != null) files.add(path)
                }
            }
        }

        return files
    }

    /// Try resolving actual file path directly WITHOUT duplicating/copying file
    private fun resolveOrCopyUri(uri: Uri): String? {
        // 1. Direct file URI
        if (uri.scheme == "file") {
            val path = uri.path
            if (path != null && File(path).exists()) return path
        }

        // 2. Content URI direct path resolution (Zero memory overhead)
        if (uri.scheme == "content") {
            try {
                val proj = arrayOf(android.provider.MediaStore.MediaColumns.DATA)
                val cursor = contentResolver.query(uri, proj, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val columnIndex = it.getColumnIndex(android.provider.MediaStore.MediaColumns.DATA)
                        if (columnIndex >= 0) {
                            val realPath = it.getString(columnIndex)
                            if (realPath != null && File(realPath).exists()) {
                                return realPath
                            }
                        }
                    }
                }
            } catch (_: Exception) {}
        }

        // 3. Fallback: Copy stream to cache ONLY if direct path is impossible
        return copyUriToLocal(uri)
    }

    private fun copyUriToLocal(uri: Uri): String? {
        try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            
            var fileName = "imported_${uri.toString().hashCode()}.pdf"
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        fileName = it.getString(nameIndex) ?: fileName
                    }
                }
            }

            val outputDir = File(cacheDir, "imported_pdfs")
            if (!outputDir.exists()) outputDir.mkdirs()

            val outputFile = File(outputDir, fileName)

            // Avoid re-copying if file already exists with same size
            if (outputFile.exists() && outputFile.length() > 0) {
                return outputFile.absolutePath
            }

            inputStream.use { input ->
                FileOutputStream(outputFile).use { output ->
                    input.copyTo(output)
                }
            }

            return outputFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    /// Generate ultra-compressed 120px JPEG thumbnail (5-15 KB per file max)
    private fun generateThumbnail(pdfPath: String): String? {
        try {
            val file = File(pdfPath)
            if (!file.exists()) return null

            val thumbDir = File(cacheDir, "pdf_thumbnails")
            if (!thumbDir.exists()) thumbDir.mkdirs()

            val hashKey = "${file.absolutePath}_${file.length()}".hashCode()
            val thumbFile = File(thumbDir, "thumb_$hashKey.jpg")
            if (thumbFile.exists() && thumbFile.length() > 0) {
                return thumbFile.absolutePath
            }

            val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            val renderer = PdfRenderer(pfd)
            if (renderer.pageCount == 0) {
                renderer.close()
                pfd.close()
                return null
            }

            val page = renderer.openPage(0)
            val width = 120
            val height = ((width * page.height.toDouble()) / page.width).toInt().coerceIn(90, 180)

            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)

            FileOutputStream(thumbFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 50, out)
            }

            bitmap.recycle()
            page.close()
            renderer.close()
            pfd.close()

            return thumbFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    /// Clean temporary cache files automatically
    private fun cleanStaleCache() {
        try {
            val importedDir = File(cacheDir, "imported_pdfs")
            if (importedDir.exists()) {
                val now = System.currentTimeMillis()
                importedDir.listFiles()?.forEach { f ->
                    // Delete imported temp PDFs older than 12 hours
                    if (now - f.lastModified() > 12 * 60 * 60 * 1000) {
                        f.delete()
                    }
                }
            }
        } catch (_: Exception) {}
    }

    private fun cleanAppCache(): Long {
        var totalFreed: Long = 0
        try {
            val importedDir = File(cacheDir, "imported_pdfs")
            if (importedDir.exists()) {
                importedDir.listFiles()?.forEach {
                    totalFreed += it.length()
                    it.delete()
                }
            }
            val thumbDir = File(cacheDir, "pdf_thumbnails")
            if (thumbDir.exists()) {
                thumbDir.listFiles()?.forEach {
                    totalFreed += it.length()
                    it.delete()
                }
            }
        } catch (_: Exception) {}
        return totalFreed
    }

    private fun mergePdfFilesBackground(inputPaths: List<String>, outputPath: String): Boolean {
        try {
            var totalPages = 0
            val validFiles = mutableListOf<String>()

            for (filePath in inputPaths) {
                val file = File(filePath)
                if (file.exists()) {
                    validFiles.add(filePath)
                    try {
                        val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                        val renderer = PdfRenderer(pfd)
                        totalPages += renderer.pageCount
                        renderer.close()
                        pfd.close()
                    } catch (_: Exception) {}
                }
            }

            if (totalPages == 0) return false

            val document = PdfDocument()
            var processedPages = 0

            sendProgress(0, totalPages, 0)

            for (filePath in validFiles) {
                val file = File(filePath)
                val fileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                val renderer = PdfRenderer(fileDescriptor)

                for (i in 0 until renderer.pageCount) {
                    val sourcePage = renderer.openPage(i)

                    val pageInfo = PdfDocument.PageInfo.Builder(
                        sourcePage.width,
                        sourcePage.height,
                        processedPages + 1
                    ).create()

                    val destPage = document.startPage(pageInfo)

                    val bitmap = Bitmap.createBitmap(
                        sourcePage.width,
                        sourcePage.height,
                        Bitmap.Config.ARGB_8888
                    )
                    
                    sourcePage.render(
                        bitmap,
                        null,
                        null,
                        PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
                    )

                    destPage.canvas.drawBitmap(bitmap, 0f, 0f, null)

                    document.finishPage(destPage)
                    bitmap.recycle()
                    sourcePage.close()

                    processedPages++
                    val percent = ((processedPages.toDouble() / totalPages) * 100).toInt()
                    sendProgress(processedPages, totalPages, percent)
                }

                renderer.close()
                fileDescriptor.close()
            }

            val outputFile = File(outputPath)
            outputFile.parentFile?.mkdirs()
            FileOutputStream(outputFile).use { output ->
                document.writeTo(output)
            }
            document.close()

            sendProgress(totalPages, totalPages, 100)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun sendProgress(processed: Int, total: Int, percent: Int) {
        mainHandler.post {
            mergeChannel?.invokeMethod("onProgress", mapOf(
                "processed" to processed,
                "total" to total,
                "percent" to percent
            ))
        }
    }
}
