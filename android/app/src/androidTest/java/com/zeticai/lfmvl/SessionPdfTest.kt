package com.zeticai.lfmvl.android

import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import androidx.core.content.FileProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SessionPdfTest {
    @Test fun longSessionExportsMultipleReadablePagesThroughTheShareProvider() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val bitmap = Bitmap.createBitmap(128, 64, Bitmap.Config.ARGB_8888)
        val state = VisionUiState(preview = bitmap, sessionStartedAt = 1_700_000_000_000L,
            sessionInstructions = "Describe only visible equipment.",
            turns = (1..20).map { VisionTurn(it.toLong(), "Question $it", "Réponse complète. 한글 日本語. ".repeat(100), TurnPhase.FINISHED) })
        val file = SessionPdf.write(state, File(context.cacheDir, "session-exports"))
        try {
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            requireNotNull(context.contentResolver.openFileDescriptor(uri, "r")).use { descriptor ->
                PdfRenderer(descriptor).use { pdf ->
                    assertTrue(pdf.pageCount > 2)
                    pdf.openPage(pdf.pageCount - 1).use { page ->
                        val rendered = Bitmap.createBitmap(page.width, page.height, Bitmap.Config.ARGB_8888)
                        page.render(rendered, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        rendered.recycle()
                    }
                }
            }
        } finally { file.delete(); bitmap.recycle() }
    }
}
