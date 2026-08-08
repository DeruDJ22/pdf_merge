package com.example.pdf_merge

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val INTENT_CHANNEL = "com.example.pdf_merge/intent"
    private val MERGE_CHANNEL = "com.example.pdf_merge/merge"
    private var intentChannel: MethodChannel? = null
    private var pendingIntentFiles: MutableList<String> = mutableListOf()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        // Merge channel for PDF merging
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MERGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "mergePdfs" -> {
                        val paths = call.argument<List<String>>("paths")
                        val output = call.argument<String>("output")
                        if (paths != null && output != null) {
                            try {
                                val success = mergePdfFiles(paths, output)
                                result.success(success)
                            } catch (e: Exception) {
                                result.error("MERGE_ERROR", e.message, null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "Missing paths or output", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Handle initial intent
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
                    val path = copyUriToLocal(uri)
                    if (path != null) files.add(path)
                }
            }
            Intent.ACTION_SEND -> {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (uri != null) {
                    val path = copyUriToLocal(uri)
                    if (path != null) files.add(path)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                uris?.forEach { uri ->
                    val path = copyUriToLocal(uri)
                    if (path != null) files.add(path)
                }
            }
        }

        return files
    }

    private fun copyUriToLocal(uri: Uri): String? {
        try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            
            // Get filename from URI
            var fileName = "imported_${System.currentTimeMillis()}.pdf"
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

    private fun mergePdfFiles(inputPaths: List<String>, outputPath: String): Boolean {
        try {
            val document = PdfDocument()
            var pageOffset = 0

            for (filePath in inputPaths) {
                val file = File(filePath)
                if (!file.exists()) continue

                val fileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                val renderer = PdfRenderer(fileDescriptor)

                for (i in 0 until renderer.pageCount) {
                    val sourcePage = renderer.openPage(i)

                    val pageInfo = PdfDocument.PageInfo.Builder(
                        sourcePage.width,
                        sourcePage.height,
                        pageOffset + i
                    ).create()

                    val destPage = document.startPage(pageInfo)

                    // Render the source page onto the destination page's canvas
                    sourcePage.render(
                        destPage.canvas,
                        null, null,
                        PdfRenderer.Page.RENDER_MODE_FOR_PRINT
                    )

                    document.finishPage(destPage)
                    sourcePage.close()
                }

                pageOffset += renderer.pageCount
                renderer.close()
                fileDescriptor.close()
            }

            // Write to output file
            val outputFile = File(outputPath)
            outputFile.parentFile?.mkdirs()
            FileOutputStream(outputFile).use { output ->
                document.writeTo(output)
            }
            document.close()

            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
}
