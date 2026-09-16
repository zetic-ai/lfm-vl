package com.zeticai.lfmvl.android

import android.Manifest
import android.content.pm.PackageManager
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import android.graphics.Bitmap
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.zeticai.mlange.core.background.BackgroundDownloadState
import org.junit.Rule
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VisionScreenTest {
    @get:Rule val composeRule = createComposeRule()

    @Test fun missingKeyFailureIsVisibleAndCannotGenerate() {
        composeRule.setContent {
            VisionContent(
                state = VisionUiState(status = ModelStatus.FAILURE, message = "ZETIC_PERSONAL_KEY is required"),
                onPromptChanged = {}, onLibrary = {}, onCamera = {}, onAsk = {}, onStop = {}, onRetry = {}, onRegenerate = {}, onZoom = {},
            )
        }

        composeRule.onNodeWithText("Model unavailable").assertIsDisplayed()
    }

    @Test fun generatingDisablesImageSources() {
        composeRule.setContent {
            VisionContent(
                state = VisionUiState(status = ModelStatus.GENERATING),
                onPromptChanged = {}, onLibrary = {}, onCamera = {}, onAsk = {}, onStop = {}, onRetry = {}, onRegenerate = {}, onZoom = {},
            )
        }

        composeRule.onNodeWithText("Library").assertIsNotEnabled()
        composeRule.onNodeWithText("Camera").assertIsNotEnabled()
    }

    @Test fun firstLaunchShowsDownloadConsentWithoutStartingTransfer() {
        var downloadRequests = 0
        composeRule.setContent {
            VisionContent(
                state = VisionUiState(status = ModelStatus.AWAITING_CONSENT),
                onPromptChanged = {}, onLibrary = {}, onCamera = {}, onAsk = {}, onStop = {}, onRetry = {}, onRegenerate = {}, onZoom = {},
                onDownloadModel = { downloadRequests += 1 },
            )
        }

        composeRule.onNodeWithText("Download the vision model?").assertIsDisplayed()
        composeRule.onNodeWithText("Not now").assertIsDisplayed()
        assertEquals(0, downloadRequests)
    }

    @Test fun selectedPhotoSourceButtonsKeepFingerSizedTargetsOnNarrowLayout() {
        val preview = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        composeRule.setContent {
            Box(Modifier.width(280.dp)) {
                VisionContent(
                    state = VisionUiState(status = ModelStatus.READY, preview = preview),
                    onPromptChanged = {}, onLibrary = {}, onCamera = {}, onAsk = {}, onStop = {}, onRetry = {}, onRegenerate = {}, onZoom = {},
                )
            }
        }

        composeRule.onNodeWithTag("camera_button").assertIsDisplayed().assertHeightIsAtLeast(44.dp)
        composeRule.onNodeWithTag("library_button").assertIsDisplayed().assertHeightIsAtLeast(44.dp)
    }

    @Test fun manifestDeclaresInternetPermission() {
        val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext
        assertEquals(PackageManager.PERMISSION_GRANTED, context.packageManager.checkPermission(Manifest.permission.INTERNET, context.packageName))
    }

    @Test fun photoSectionAndComposerStayFixedWhileTranscriptScrolls() {
        val preview = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
        val turns = (1..8).map { VisionTurn(it.toLong(), "Question $it", "Answer $it", TurnPhase.FINISHED) }
        composeRule.setContent {
            Box(Modifier.height(560.dp)) {
                VisionContent(VisionUiState(status = ModelStatus.READY, preview = preview, turns = turns), {}, {}, {}, {}, {}, {}, {}, {})
            }
        }
        composeRule.onNodeWithTag("composer").assertIsDisplayed()
        composeRule.waitForIdle()
        composeRule.onNodeWithTag("transcript_list").performScrollToIndex(0)
        composeRule.waitForIdle()
        composeRule.onNodeWithContentDescription("Selected photo. Double-tap to view full screen.").assertIsDisplayed()
        composeRule.onNodeWithText("Describe this").assertIsDisplayed()
        composeRule.onNodeWithText("Question 8", useUnmergedTree = true).assertIsNotDisplayed()
        composeRule.onNodeWithTag("transcript_list").performScrollToIndex(7)
        composeRule.waitForIdle()
        composeRule.onNodeWithText("Question 8", useUnmergedTree = true).assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Selected photo. Double-tap to view full screen.").assertIsDisplayed()
        composeRule.onNodeWithText("Describe this").assertIsDisplayed()
        composeRule.onNodeWithTag("composer").assertIsDisplayed()
    }

    @Test fun downloadWithKnownTotalUsesDeterminateProgress() {
        composeRule.setContent {
            VisionContent(
                state = VisionUiState(
                    status = ModelStatus.DOWNLOADING,
                    message = "Downloading model files…",
                    backgroundDownload = BackgroundModelDownloadState(
                        state = BackgroundDownloadState.DOWNLOADING,
                        bytesDownloaded = 50L,
                        totalBytes = 100L,
                    ),
                ),
                onPromptChanged = {}, onLibrary = {}, onCamera = {}, onAsk = {}, onStop = {}, onRetry = {}, onRegenerate = {}, onZoom = {},
            )
        }

        composeRule.onNodeWithTag("download_determinate_progress").assertIsDisplayed()
        composeRule.onNodeWithTag("download_indeterminate_progress").assertDoesNotExist()
    }

    @Test fun downloadWithoutTotalUsesIndeterminateProgress() {
        composeRule.setContent {
            VisionContent(
                state = VisionUiState(
                    status = ModelStatus.DOWNLOADING,
                    message = "Downloading model files…",
                    backgroundDownload = BackgroundModelDownloadState(
                        state = BackgroundDownloadState.DOWNLOADING,
                        bytesDownloaded = 50L,
                        totalBytes = null,
                    ),
                ),
                onPromptChanged = {}, onLibrary = {}, onCamera = {}, onAsk = {}, onStop = {}, onRetry = {}, onRegenerate = {}, onZoom = {},
            )
        }

        composeRule.onNodeWithTag("download_indeterminate_progress").assertIsDisplayed()
        composeRule.onNodeWithTag("download_determinate_progress").assertDoesNotExist()
    }

    @Test fun initializationProgressIsVisibleWhenKnown() {
        composeRule.setContent {
            VisionContent(
                state = VisionUiState(
                    status = ModelStatus.INITIALIZING,
                    message = "Initializing — preparing model 42%",
                    initializationProgress = 0.42f,
                ),
                onPromptChanged = {}, onLibrary = {}, onCamera = {}, onAsk = {}, onStop = {}, onRetry = {}, onRegenerate = {}, onZoom = {},
            )
        }

        composeRule.onNodeWithTag("initialization_progress").assertIsDisplayed()
        composeRule.onNodeWithText("Initializing — preparing model 42%").assertIsDisplayed()
    }

    @Test fun imageErrorDoesNotReplaceReadyContent() {
        val preview = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        composeRule.setContent {
            VisionContent(
                state = VisionUiState(
                    status = ModelStatus.READY,
                    preview = preview,
                    imageError = "That file could not be read as an image.",
                ),
                onPromptChanged = {}, onLibrary = {}, onCamera = {}, onAsk = {}, onStop = {}, onRetry = {}, onRegenerate = {}, onZoom = {},
            )
        }

        composeRule.onNodeWithContentDescription("Selected photo. Double-tap to view full screen.").assertIsDisplayed()
        composeRule.onNodeWithTag("composer").assertIsDisplayed()
        composeRule.onNodeWithText("Model unavailable").assertDoesNotExist()
    }

    @Test fun completedTurnPlacesMetricsAndActionsBelowAnswerBubble() {
        val turn = VisionTurn(
            id = 1L,
            question = "Question",
            answer = "12345678",
            phase = TurnPhase.FINISHED,
            firstTokenMillis = 500L,
            durationMillis = 1_000L,
        )
        composeRule.setContent {
            VisionContent(
                state = VisionUiState(status = ModelStatus.READY, turns = listOf(turn)),
                onPromptChanged = {}, onLibrary = {}, onCamera = {}, onAsk = {}, onStop = {}, onRetry = {}, onRegenerate = {}, onZoom = {},
            )
        }

        val answerBottom = composeRule.onNodeWithTag("answer_bubble_1").fetchSemanticsNode().boundsInRoot.bottom
        val metadataTop = composeRule.onNodeWithTag("turn_metadata_1").fetchSemanticsNode().boundsInRoot.top
        assertTrue(metadataTop >= answerBottom)
        composeRule.onNodeWithText("0.5s to first token · ~4 tok/s").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Copy answer").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Share answer").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Ask again").assertIsDisplayed()
        composeRule.onNodeWithTag("transcript_tail").assertIsDisplayed()
    }

    @Test fun streamingTurnDoesNotShowMetricsOrCompletionActions() {
        val turn = VisionTurn(
            id = 1L,
            question = "Question",
            answer = "Partial answer",
            phase = TurnPhase.ANSWERING,
            firstTokenMillis = 500L,
        )
        composeRule.setContent {
            VisionContent(
                state = VisionUiState(status = ModelStatus.GENERATING, turns = listOf(turn)),
                onPromptChanged = {}, onLibrary = {}, onCamera = {}, onAsk = {}, onStop = {}, onRetry = {}, onRegenerate = {}, onZoom = {},
            )
        }

        composeRule.onNodeWithText("0.5s to first token").assertDoesNotExist()
        composeRule.onNodeWithTag("turn_metadata_1").assertDoesNotExist()
        composeRule.onNodeWithContentDescription("Copy answer").assertDoesNotExist()
        composeRule.onNodeWithTag("transcript_tail").assertIsDisplayed()
    }

    @Test fun unavailableCameraIsHiddenButLibraryRemainsAvailable() {
        composeRule.setContent {
            VisionContent(
                state = VisionUiState(status = ModelStatus.READY),
                onPromptChanged = {}, onLibrary = {}, onCamera = {}, onAsk = {}, onStop = {}, onRetry = {}, onRegenerate = {}, onZoom = {},
                cameraAvailable = false,
            )
        }

        composeRule.onNodeWithTag("camera_button").assertDoesNotExist()
        composeRule.onNodeWithTag("library_button").assertIsDisplayed()
    }
}
