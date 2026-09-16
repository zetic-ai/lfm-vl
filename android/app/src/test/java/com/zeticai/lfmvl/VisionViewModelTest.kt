package com.zeticai.lfmvl.android

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VisionViewModelTest {
    @Test fun blankKeyIsRejected() = assertFalse(VisionViewModel.isUsablePersonalKey(""))
    @Test fun placeholderKeyIsRejected() = assertFalse(VisionViewModel.isUsablePersonalKey("dev_YOUR_KEY_HERE"))
    @Test fun configuredKeyIsAccepted() = assertTrue(VisionViewModel.isUsablePersonalKey("dev_configured_key"))
    @Test fun firstLaunchWaitsForModelDownloadConsent() = assertTrue(VisionUiState().status == ModelStatus.AWAITING_CONSENT)
    @Test fun currentDownloadConsentRequiresExactVersion() {
        assertTrue(LfmModelDownloadConsent.isCurrent(LfmModelDownloadConsent.CURRENT_VERSION))
        assertFalse(LfmModelDownloadConsent.isCurrent("0"))
        assertFalse(LfmModelDownloadConsent.isCurrent("2"))
        assertFalse(LfmModelDownloadConsent.isCurrent(null))
    }
    @Test fun suggestionsMatchPhotoQuestions() = assertTrue(VisionViewModel.suggestions.size == 4)
    @Test fun imageIsBoundedTo512px() = assertTrue(ImageDecoder.scaledSize(2048, 1024) == ImageDecoder.ImageSize(512, 256))
    @Test fun smallImageKeepsDimensions() = assertTrue(ImageDecoder.scaledSize(100, 200) == ImageDecoder.ImageSize(100, 200))

    @Test fun imageDecodeFailureKeepsReadyConversationState() {
        val turns = listOf(VisionTurn(1L, "Existing question", "Existing answer", TurnPhase.FINISHED))
        val before = VisionUiState(
            status = ModelStatus.READY,
            message = "Ready",
            prompt = "Existing prompt",
            turns = turns,
            imageUpdating = true,
        )

        val after = before.withImageDecodeFailure()

        assertEquals(ModelStatus.READY, after.status)
        assertEquals("Ready", after.message)
        assertEquals("Existing prompt", after.prompt)
        assertEquals(turns, after.turns)
        assertFalse(after.imageUpdating)
        assertEquals(IMAGE_DECODE_FAILURE_MESSAGE, after.imageError)
    }
}
