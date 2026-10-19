package com.zeticai.lfmvl.android

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.text.Layout
import android.text.SpannableStringBuilder
import android.text.StaticLayout
import android.text.TextPaint
import android.text.Spanned
import android.text.style.StyleSpan
import java.io.File
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.Date
import java.util.UUID

/** Searchable, paginated transcript. The original conversation is never shortened for export. */
object SessionPdf {
    fun write(state: VisionUiState, directory: File): File {
        val photo = requireNotNull(state.preview) { "The session photo is unavailable." }
        require(state.turns.isNotEmpty()) { "Ask a question before exporting this session." }
        check(directory.isDirectory || directory.mkdirs()) { "Could not create the export folder." }
        directory.listFiles().orEmpty().filter { (it.isDirectory || it.extension == "pdf") && it.lastModified() < System.currentTimeMillis() - 86_400_000L }.forEach { it.deleteRecursively() }
        val folder = File(directory, UUID.randomUUID().toString())
        check(folder.mkdirs()) { "Could not prepare the PDF export." }
        val stamp = SimpleDateFormat("yyyy-MM-dd-HHmm", Locale.ROOT).format(Date(state.sessionStartedAt))
        val file = File(folder, "Apercu-$stamp.pdf")
        val text = transcript(state)
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 11f; color = Color.rgb(37, 70, 95) }
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, 515)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL).setIncludePad(false).setLineSpacing(4f, 1f).build()
        try {
            val pdf = PdfDocument()
            try {
                var firstLine = 0
                var pageNumber = 0
                while (firstLine < layout.lineCount) {
                    pageNumber++
                    val page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, pageNumber).create())
                    val canvas = page.canvas
                    val header = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(37, 70, 95); textSize = 22f; typeface = Typeface.DEFAULT_BOLD }
                    canvas.drawColor(Color.WHITE)
                    canvas.drawText("Aperçu", 40f, 46f, header)
                    header.strokeWidth = 1f; canvas.drawLine(40f, 60f, 555f, 60f, header)
                    var top = 78f
                    if (pageNumber == 1) {
                        val scale = minOf(515f / photo.width, 210f / photo.height)
                        val width = photo.width * scale; val height = photo.height * scale
                        canvas.drawBitmap(photo, null, RectF(40f + (515f - width) / 2, top, 40f + (515f + width) / 2, top + height), Paint(Paint.FILTER_BITMAP_FLAG))
                        top += height + 18f
                    }
                    val lineTop = layout.getLineTop(firstLine)
                    var endLine = firstLine
                    while (endLine < layout.lineCount && layout.getLineBottom(endLine) - lineTop <= 790 - top) endLine++
                    check(endLine > firstLine) { "Could not lay out this transcript." }
                    // Keep short role headings with the next paragraph, when there is room.
                    if (endLine < layout.lineCount && endLine - firstLine > 1) {
                        val lastText = text.subSequence(layout.getLineStart(endLine - 1), layout.getLineEnd(endLine - 1)).toString().trim()
                        if (lastText.matches(Regex("(Question|Answer) [0-9]+.*"))) endLine--
                    }
                    canvas.save()
                    canvas.clipRect(40f, top, 555f, top + layout.getLineBottom(endLine - 1) - lineTop)
                    canvas.translate(40f, top - lineTop)
                    layout.draw(canvas)
                    canvas.restore()
                    header.textSize = 9f; header.typeface = Typeface.DEFAULT; header.color = Color.DKGRAY
                    canvas.drawText("Aperçu · $pageNumber", 40f, 817f, header)
                    pdf.finishPage(page)
                    firstLine = endLine
                }
                file.outputStream().use(pdf::writeTo)
            } finally { pdf.close() }
            check(file.length() > 0) { "The PDF could not be written. Check available storage." }
            return file
        } catch (error: Exception) {
            folder.deleteRecursively()
            throw error
        }
    }

    internal fun transcript(state: VisionUiState): SpannableStringBuilder {
        val text = SpannableStringBuilder()
        fun append(value: String, bold: Boolean = false) {
            val start = text.length
            text.append(value).append("\n\n")
            if (bold) text.setSpan(StyleSpan(Typeface.BOLD), start, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        append("Photo conversation", true)
        val date = DateFormat.getDateTimeInstance(DateFormat.LONG, DateFormat.SHORT)
        append("${date.format(Date(state.sessionStartedAt))} · ${state.turns.size} question${if (state.turns.size == 1) "" else "s"}")
        append("AI instructions", true)
        append(state.sessionInstructions ?: AIInstructions.DEFAULT)
        state.turns.forEachIndexed { index, turn ->
            append("Question ${index + 1}", true)
            append(turn.question)
            val status = when (turn.phase) {
                TurnPhase.FINISHED -> ""
                TurnPhase.FAILED -> " · failed"
                TurnPhase.INTERRUPTED -> " · interrupted"
                TurnPhase.READING, TurnPhase.ANSWERING -> " · partial copy"
            }
            append("Answer ${index + 1}$status", true)
            append(turn.answer.ifEmpty { "No answer saved." })
            turn.failure?.let { append(it) }
        }
        return text
    }
}
