package com.zeticai.lfmvl.android

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathBuilder
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.FileProvider
import com.zeticai.mlange.core.background.BackgroundDownloadState
import java.io.File
import java.util.Locale

@Composable
fun VisionScreen(viewModel: VisionViewModel) {
    val state by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    var replacementUri by remember { mutableStateOf<Uri?>(null) }
    var zoom by remember { mutableStateOf(false) }
    var settingsOpen by remember { mutableStateOf(false) }
    var removalConfirmationOpen by remember { mutableStateOf(false) }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        uri?.let { if (state.hasTranscript) replacementUri = it else viewModel.selectImage(it) }
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { saved ->
        if (saved) cameraUri(context)?.let { if (state.hasTranscript) replacementUri = it else viewModel.selectImage(it) }
    }

    VisionContent(
        state = state,
        onPromptChanged = viewModel::updatePrompt,
        onLibrary = { pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
        onCamera = { cameraUri(context)?.let(camera::launch) },
        onAsk = viewModel::ask,
        onStop = viewModel::stopGeneration,
        onRetry = viewModel::retryInitialize,
        onRegenerate = viewModel::regenerateLast,
        onZoom = { zoom = true },
        onDownloadModel = viewModel::approveModelDownload,
        onDeferModelDownload = viewModel::deferModelDownload,
        onShowModelDownloadConsent = viewModel::showModelDownloadConsent,
        onOpenSettings = { settingsOpen = true },
        cameraAvailable = cameraAvailable(context),
    )

    replacementUri?.let { candidate ->
        AlertDialog(
            onDismissRequest = { replacementUri = null },
            title = { Text("Replace this photo?") },
            text = { Text("The answers for the current photo will be cleared.") },
            confirmButton = {
                TextButton(onClick = { viewModel.selectImage(candidate); replacementUri = null }) {
                    Text("Replace", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = { TextButton(onClick = { replacementUri = null }) { Text("Keep current") } },
        )
    }
    state.imageError?.let { message ->
        AlertDialog(
            onDismissRequest = viewModel::clearImageError,
            title = { Text("Could not load that photo") },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = viewModel::clearImageError) { Text("OK") } },
        )
    }
    state.modelStorageMessage?.let { message ->
        AlertDialog(
            onDismissRequest = viewModel::clearModelStorageMessage,
            title = { Text("Model storage") },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = viewModel::clearModelStorageMessage) { Text("OK") } },
        )
    }
    if (zoom) state.preview?.let { FullScreenImage(it) { zoom = false } }
    if (settingsOpen) {
        ModelSettingsDialog(
            canRemoveDownloadedModel = state.canRemoveDownloadedModel,
            modelStatus = state.status,
            onRemove = {
                settingsOpen = false
                removalConfirmationOpen = true
            },
            onDismiss = { settingsOpen = false },
        )
    }
    if (removalConfirmationOpen) {
        ModelRemovalConfirmation(
            onRemove = {
                removalConfirmationOpen = false
                viewModel.removeDownloadedModel()
            },
            onDismiss = { removalConfirmationOpen = false },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun VisionContent(
    state: VisionUiState,
    onPromptChanged: (String) -> Unit,
    onLibrary: () -> Unit,
    onCamera: () -> Unit,
    onAsk: (String?) -> Unit,
    onStop: () -> Unit,
    onRetry: () -> Unit,
    onRegenerate: () -> Unit,
    onZoom: () -> Unit,
    onDownloadModel: () -> Unit = {},
    onDeferModelDownload: () -> Unit = {},
    onShowModelDownloadConsent: () -> Unit = {},
    onOpenSettings: () -> Unit = {},
    cameraAvailable: Boolean = true,
) {
    LfmVisionTheme {
        Scaffold(
            contentWindowInsets = WindowInsets.safeDrawing,
            topBar = {
                TopAppBar(
                    title = { Text("Ask about a photo") },
                    actions = {
                        IconButton(onClick = onOpenSettings) {
                            Icon(AppIcons.More, contentDescription = "Model settings")
                        }
                    },
                )
            },
            bottomBar = {
                if (state.status == ModelStatus.READY || state.status == ModelStatus.GENERATING) {
                    Composer(state, onPromptChanged, onAsk, onStop)
                }
            },
        ) { padding ->
            when (state.status) {
                ModelStatus.FAILURE -> FailureView(state.message, onRetry, Modifier.padding(padding))
                ModelStatus.AWAITING_CONSENT -> DownloadConsentView(onDownloadModel, onDeferModelDownload, Modifier.padding(padding))
                ModelStatus.DOWNLOAD_DEFERRED -> DeferredDownloadView(onShowModelDownloadConsent, Modifier.padding(padding))
                ModelStatus.DOWNLOADING -> DownloadingView(state, Modifier.padding(padding))
                ModelStatus.INITIALIZING -> LoadingView(state, Modifier.padding(padding))
                ModelStatus.REMOVING -> RemovingModelView(Modifier.padding(padding))
                else -> MainView(state, onLibrary, onCamera, onAsk, onRegenerate, onZoom, cameraAvailable, Modifier.padding(padding))
            }
        }
    }
}

@Composable
private fun DownloadConsentView(download: () -> Unit, defer: () -> Unit, modifier: Modifier) =
    CenteredStateView(modifier) {
        Icon(AppIcons.Download, contentDescription = null, modifier = Modifier.size(44.dp), tint = MaterialTheme.colorScheme.primary)
        Text("Download the vision model?", style = MaterialTheme.typography.titleMedium)
        Text(
            "The model downloads in the background only after you agree. It may use 1–2 GB of data and storage, and stays on this phone.",
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Button(onClick = download) { Text("Download model") }
        TextButton(onClick = defer) { Text("Not now") }
    }

@Composable
private fun DeferredDownloadView(showConsent: () -> Unit, modifier: Modifier) = CenteredStateView(modifier) {
    Icon(AppIcons.Download, contentDescription = null, modifier = Modifier.size(44.dp), tint = MaterialTheme.colorScheme.primary)
    Text("Vision model required", style = MaterialTheme.typography.titleMedium)
    Text(
        "Download the on-device model when you are ready to ask about a photo.",
        textAlign = TextAlign.Center,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Button(onClick = showConsent) { Text("Download model") }
}

@Composable
private fun DownloadingView(state: VisionUiState, modifier: Modifier) = CenteredStateView(modifier) {
    val download = state.backgroundDownload
    val progress = download?.totalBytes?.takeIf { it > 0L }?.let { total ->
        (download.bytesDownloaded.toFloat() / total).coerceIn(0f, 1f)
    }
    if (progress != null && download.state == BackgroundDownloadState.DOWNLOADING) {
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier.width(260.dp).testTag("download_determinate_progress"),
        )
    } else {
        CircularProgressIndicator(Modifier.testTag("download_indeterminate_progress"))
    }
    Text(downloadTitle(download?.state), style = MaterialTheme.typography.titleMedium)
    Text(
        state.message,
        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    if (download?.state == BackgroundDownloadState.DOWNLOADING && download.bytesDownloaded > 0L) {
        Text(
            formatDownloadSize(download.bytesDownloaded, download.totalBytes),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
    if (state.downloadElapsedMillis > 0L) {
        Text(
            buildString {
                append(formatDuration(state.downloadElapsedMillis))
                append(" elapsed")
                state.downloadEtaMillis?.let { append(" · about ${formatDuration(it)} left") }
            },
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
    Text(
        "You can keep this app open or leave it. Asking about a photo will be available when the download finishes.",
        style = MaterialTheme.typography.bodySmall,
        textAlign = TextAlign.Center,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun LoadingView(state: VisionUiState, modifier: Modifier) = CenteredStateView(modifier) {
    state.initializationProgress?.let { progress ->
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier.width(260.dp).testTag("initialization_progress"),
        )
    } ?: CircularProgressIndicator()
    Text("Initializing model…", style = MaterialTheme.typography.titleMedium)
    Text(
        state.message,
        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Text("Preparing the on-device model.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
private fun RemovingModelView(modifier: Modifier) = CenteredStateView(modifier) {
    CircularProgressIndicator()
    Text("Removing downloaded model…", style = MaterialTheme.typography.titleMedium)
}

@Composable
private fun FailureView(message: String, retry: () -> Unit, modifier: Modifier) = CenteredStateView(modifier) {
    Icon(AppIcons.Warning, contentDescription = null, modifier = Modifier.size(44.dp), tint = MaterialTheme.colorScheme.error)
    Text("Model unavailable", style = MaterialTheme.typography.titleLarge)
    Text(message, textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.onSurfaceVariant)
    Button(onClick = retry) { Text("Try again") }
}

@Composable
private fun CenteredStateView(modifier: Modifier, content: @Composable ColumnScope.() -> Unit) = Box(
    modifier.fillMaxSize().padding(horizontal = 28.dp),
    contentAlignment = Alignment.Center,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
        content = content,
    )
}

@Composable
private fun ModelSettingsDialog(
    canRemoveDownloadedModel: Boolean,
    modelStatus: ModelStatus,
    onRemove: () -> Unit,
    onDismiss: () -> Unit,
) = AlertDialog(
    onDismissRequest = onDismiss,
    title = { Text("Model settings") },
    text = {
        Text(
            if (canRemoveDownloadedModel) {
                "Remove the downloaded model. Downloading it again will require your consent."
            } else if (modelStatus in setOf(ModelStatus.GENERATING, ModelStatus.INITIALIZING, ModelStatus.REMOVING)) {
                "Finish the active response before removing the downloaded model."
            } else {
                "There is no downloaded model to remove."
            },
        )
    },
    confirmButton = {
        TextButton(onClick = onRemove, enabled = canRemoveDownloadedModel) {
            Text("Remove downloaded model", color = if (canRemoveDownloadedModel) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f))
        }
    },
    dismissButton = { TextButton(onClick = onDismiss) { Text("Close") } },
)

@Composable
private fun ModelRemovalConfirmation(onRemove: () -> Unit, onDismiss: () -> Unit) = AlertDialog(
    onDismissRequest = onDismiss,
    title = { Text("Remove downloaded model?") },
    text = { Text("Only the downloaded model will be removed. Your photos, prompts, and conversations will stay on this phone.") },
    confirmButton = { TextButton(onClick = onRemove) { Text("Remove model", color = MaterialTheme.colorScheme.error) } },
    dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
)

@Composable
private fun MainView(
    state: VisionUiState,
    library: () -> Unit,
    camera: () -> Unit,
    ask: (String?) -> Unit,
    regenerate: () -> Unit,
    zoom: () -> Unit,
    cameraAvailable: Boolean,
    modifier: Modifier,
) {
    val listState = rememberLazyListState()
    LaunchedEffect(state.turns.size) {
        if (state.turns.isNotEmpty()) listState.animateScrollToItem(state.turns.size)
    }
    val lastAnswer = state.turns.lastOrNull()?.answer
    LaunchedEffect(lastAnswer) {
        if (!lastAnswer.isNullOrEmpty()) listState.scrollToItem(state.turns.size)
    }
    Column(modifier.fillMaxSize()) {
        Box(Modifier.testTag("photo_section")) {
            if (state.preview == null) {
                EmptyPhoto(library, camera, cameraAvailable, state.imageUpdating || state.status == ModelStatus.GENERATING)
            } else {
                SelectedPhoto(state.preview, library, camera, cameraAvailable, state.imageUpdating || state.status == ModelStatus.GENERATING, zoom)
            }
        }
        if (state.preview != null) SuggestionRow(state.status == ModelStatus.READY, ask)
        HorizontalDivider(color = MaterialTheme.colorScheme.outline)
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .testTag("transcript_list")
                .semantics {
                    contentDescription = "Photo conversation transcript"
                    liveRegion = LiveRegionMode.Polite
                },
            state = listState,
            contentPadding = PaddingValues(vertical = 8.dp),
        ) {
            items(state.turns, key = { it.id }) { turn ->
                TurnBubbles(turn, state.turns.lastOrNull()?.id == turn.id, regenerate)
            }
            item(key = "transcript_tail") {
                Spacer(Modifier.size(1.dp).testTag("transcript_tail"))
            }
        }
    }
}

@Composable
private fun EmptyPhoto(library: () -> Unit, camera: () -> Unit, cameraAvailable: Boolean, disabled: Boolean) = Column(
    Modifier.fillMaxWidth().padding(vertical = 36.dp, horizontal = 24.dp),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(14.dp),
) {
    Icon(
        AppIcons.Photo,
        contentDescription = null,
        modifier = Modifier.size(44.dp),
        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.55f),
    )
    Text(
        "Take a photo or choose one from your library.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    SourceButtons(library, camera, cameraAvailable, disabled)
}

@Composable
private fun SelectedPhoto(
    bitmap: Bitmap,
    library: () -> Unit,
    camera: () -> Unit,
    cameraAvailable: Boolean,
    disabled: Boolean,
    zoom: () -> Unit,
) = Column(
    Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
    verticalArrangement = Arrangement.spacedBy(8.dp),
) {
    Image(
        bitmap = bitmap.asImageBitmap(),
        contentDescription = "Selected photo. Double-tap to view full screen.",
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(max = 220.dp)
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = zoom),
    )
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        if (maxWidth >= 310.dp) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SourceButtons(library, camera, cameraAvailable, disabled)
                Spacer(Modifier.weight(1f))
                ModelImageSizeLabel()
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SourceButtons(library, camera, cameraAvailable, disabled)
                ModelImageSizeLabel()
            }
        }
    }
}

@Composable
private fun ModelImageSizeLabel() = Text(
    "Model sees 512 px",
    style = MaterialTheme.typography.labelSmall,
    color = MaterialTheme.colorScheme.onSurfaceVariant,
)

@Composable
private fun SourceButtons(library: () -> Unit, camera: () -> Unit, cameraAvailable: Boolean, disabled: Boolean) = Row(
    horizontalArrangement = Arrangement.spacedBy(10.dp),
) {
    if (cameraAvailable) {
        Button(
            onClick = camera,
            enabled = !disabled,
            modifier = Modifier.widthIn(min = 88.dp).heightIn(min = 44.dp).testTag("camera_button"),
            contentPadding = PaddingValues(horizontal = 14.dp),
        ) {
            Icon(AppIcons.Camera, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
            Text("Camera")
        }
    }
    OutlinedButton(
        onClick = library,
        enabled = !disabled,
        modifier = Modifier.widthIn(min = 88.dp).heightIn(min = 44.dp).testTag("library_button"),
        contentPadding = PaddingValues(horizontal = 14.dp),
    ) {
        Icon(AppIcons.Photo, contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(6.dp))
        Text("Library")
    }
}

@Composable
private fun SuggestionRow(enabled: Boolean, ask: (String?) -> Unit) = Row(
    Modifier
        .fillMaxWidth()
        .horizontalScroll(rememberScrollState())
        .padding(horizontal = 16.dp, vertical = 10.dp)
        .testTag("suggestion_row"),
    horizontalArrangement = Arrangement.spacedBy(8.dp),
) {
    VisionViewModel.suggestions.forEach { suggestion ->
        Surface(
            onClick = { ask(suggestion) },
            enabled = enabled,
            shape = CircleShape,
            color = MaterialTheme.colorScheme.surfaceVariant,
        ) {
            Text(
                suggestion,
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Composable
private fun Composer(state: VisionUiState, prompt: (String) -> Unit, ask: (String?) -> Unit, stop: () -> Unit) = Row(
    Modifier
        .fillMaxWidth()
        .background(MaterialTheme.colorScheme.surface)
        .navigationBarsPadding()
        .imePadding()
        .padding(horizontal = 16.dp, vertical = 10.dp)
        .testTag("composer"),
    verticalAlignment = Alignment.CenterVertically,
    horizontalArrangement = Arrangement.spacedBy(8.dp),
) {
    TextField(
        value = state.prompt,
        onValueChange = prompt,
        modifier = Modifier.weight(1f),
        placeholder = { Text("Ask about this image") },
        enabled = state.preview != null,
        maxLines = 4,
        shape = RoundedCornerShape(18.dp),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
            unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
            disabledContainerColor = MaterialTheme.colorScheme.surfaceVariant,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            disabledIndicatorColor = Color.Transparent,
        ),
    )
    if (state.status == ModelStatus.GENERATING) {
        FilledIconButton(onClick = stop) {
            Icon(AppIcons.Stop, contentDescription = "Stop generating")
        }
    } else {
        FilledIconButton(onClick = { ask(null) }, enabled = state.canAsk) {
            Icon(AppIcons.Send, contentDescription = "Send question")
        }
    }
}

@Composable
private fun TurnBubbles(turn: VisionTurn, isLast: Boolean, regenerate: () -> Unit) {
    val context = LocalContext.current
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Surface(
            modifier = Modifier.fillMaxWidth(0.85f).align(Alignment.End),
            shape = RoundedCornerShape(16.dp),
            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
        ) {
            Text(turn.question, modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp))
        }
        Surface(
            modifier = Modifier.fillMaxWidth(0.85f).align(Alignment.Start).testTag("answer_bubble_${turn.id}"),
            shape = RoundedCornerShape(16.dp),
            color = if (turn.failure != null) MaterialTheme.colorScheme.error.copy(alpha = 0.10f) else MaterialTheme.colorScheme.surfaceVariant,
        ) {
            Column(Modifier.padding(horizontal = 14.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                when {
                    turn.failure != null -> Text(turn.failure, color = MaterialTheme.colorScheme.error)
                    turn.answer.isEmpty() && turn.isStreaming -> StreamingStatus(turn)
                    else -> {
                        SelectionContainer { Text(turn.answer) }
                        if (turn.isStreaming) StreamingStatus(turn)
                    }
                }
            }
        }
        if (turn.phase == TurnPhase.FINISHED && turn.answer.isNotBlank()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth(0.85f)
                    .align(Alignment.Start)
                    .testTag("turn_metadata_${turn.id}"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                turn.performance?.let {
                    Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Spacer(Modifier.weight(1f))
                IconButton(onClick = {
                    (context.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager)
                        .setPrimaryClip(ClipData.newPlainText("Answer", turn.answer))
                }) {
                    Icon(AppIcons.Copy, contentDescription = "Copy answer")
                }
                IconButton(onClick = {
                    context.startActivity(
                        Intent.createChooser(
                            Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, turn.answer)
                            },
                            "Share answer",
                        ),
                    )
                }) {
                    Icon(AppIcons.Share, contentDescription = "Share answer")
                }
                if (isLast) {
                    IconButton(onClick = regenerate) {
                        Icon(AppIcons.Refresh, contentDescription = "Ask again")
                    }
                }
            }
        }
    }
}

@Composable
private fun StreamingStatus(turn: VisionTurn) = Row(
    verticalAlignment = Alignment.CenterVertically,
    horizontalArrangement = Arrangement.spacedBy(8.dp),
) {
    CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
    Text(
        if (turn.phase == TurnPhase.READING) "Reading image…" else "Answering…",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun FullScreenImage(bitmap: Bitmap, close: () -> Unit) {
    var zoomState by remember { mutableStateOf(ZoomState()) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    val transform = rememberTransformableState { zoom, pan, _ ->
        zoomState = zoomState.zoomBy(zoom)
        offset = if (zoomState.scale == 1f) Offset.Zero else offset + pan
    }
    Dialog(onDismissRequest = close, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black)
                .semantics { contentDescription = "Full screen photo. Pinch to zoom. Double-tap to reset." }
                .pointerInput(Unit) {
                    detectTapGestures(onDoubleTap = {
                        zoomState = zoomState.doubleTap()
                        if (zoomState.scale == 1f) offset = Offset.Zero
                    })
                },
            Alignment.Center,
        ) {
            Image(
                bitmap.asImageBitmap(),
                contentDescription = "Full screen photo",
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer(
                        scaleX = zoomState.scale,
                        scaleY = zoomState.scale,
                        translationX = offset.x,
                        translationY = offset.y,
                    )
                    .transformable(transform),
            )
            Surface(
                modifier = Modifier.align(Alignment.TopEnd).safeDrawingPadding().padding(12.dp),
                shape = CircleShape,
                color = Color.Black.copy(alpha = 0.65f),
            ) {
                IconButton(onClick = close) {
                    Icon(AppIcons.Close, contentDescription = "Close photo", tint = Color.White)
                }
            }
        }
    }
}

private fun cameraUri(context: Context): Uri? = runCatching {
    val dir = File(context.cacheDir, "camera").apply { mkdirs() }
    FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", File(dir, "capture.jpg"))
}.getOrNull()

private fun cameraAvailable(context: Context): Boolean =
    context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)

private fun downloadTitle(state: BackgroundDownloadState?) = when (state) {
    BackgroundDownloadState.QUEUED -> "Download queued"
    BackgroundDownloadState.RESOLVING -> "Preparing download"
    BackgroundDownloadState.DOWNLOADING -> "Downloading model"
    BackgroundDownloadState.VERIFYING -> "Verifying model"
    else -> "Download in progress"
}

private fun formatDownloadSize(downloaded: Long, total: Long?): String {
    val downloadedText = formatBytes(downloaded)
    return total?.takeIf { it > 0L }?.let { "$downloadedText of ${formatBytes(it)}" } ?: downloadedText
}

private fun formatBytes(bytes: Long): String {
    val gigabytes = bytes / (1024.0 * 1024.0 * 1024.0)
    return if (gigabytes >= 1.0) {
        String.format(Locale.US, "%.1f GB", gigabytes)
    } else {
        String.format(Locale.US, "%.0f MB", bytes / (1024.0 * 1024.0))
    }
}

private fun formatDuration(milliseconds: Long): String {
    val seconds = milliseconds.coerceAtLeast(0L) / 1_000L
    return "${seconds / 60}m ${seconds % 60}s"
}

private object AppIcons {
    val Camera = icon("Camera") {
        moveTo(4f, 7f); lineTo(7f, 7f); lineTo(9f, 4f); lineTo(15f, 4f); lineTo(17f, 7f); lineTo(20f, 7f)
        lineTo(20f, 19f); lineTo(4f, 19f); close()
        moveTo(12f, 9f); curveTo(9.8f, 9f, 8f, 10.8f, 8f, 13f); curveTo(8f, 15.2f, 9.8f, 17f, 12f, 17f)
        curveTo(14.2f, 17f, 16f, 15.2f, 16f, 13f); curveTo(16f, 10.8f, 14.2f, 9f, 12f, 9f); close()
    }
    val Photo = icon("Photo") {
        moveTo(3f, 5f); lineTo(21f, 5f); lineTo(21f, 19f); lineTo(3f, 19f); close()
        moveTo(5f, 17f); lineTo(9f, 12f); lineTo(12f, 15f); lineTo(15f, 11f); lineTo(19f, 17f); close()
        moveTo(8f, 8f); curveTo(6.9f, 8f, 6f, 8.9f, 6f, 10f); curveTo(6f, 11.1f, 6.9f, 12f, 8f, 12f)
        curveTo(9.1f, 12f, 10f, 11.1f, 10f, 10f); curveTo(10f, 8.9f, 9.1f, 8f, 8f, 8f); close()
    }
    val Send = icon("Send") { moveTo(12f, 3f); lineTo(4f, 11f); lineTo(9f, 11f); lineTo(9f, 21f); lineTo(15f, 21f); lineTo(15f, 11f); lineTo(20f, 11f); close() }
    val Stop = icon("Stop") { moveTo(6f, 6f); lineTo(18f, 6f); lineTo(18f, 18f); lineTo(6f, 18f); close() }
    val Close = icon("Close") { moveTo(6f, 4.6f); lineTo(12f, 10.6f); lineTo(18f, 4.6f); lineTo(19.4f, 6f); lineTo(13.4f, 12f); lineTo(19.4f, 18f); lineTo(18f, 19.4f); lineTo(12f, 13.4f); lineTo(6f, 19.4f); lineTo(4.6f, 18f); lineTo(10.6f, 12f); lineTo(4.6f, 6f); close() }
    val More = icon("More") {
        moveTo(5f, 10f); lineTo(9f, 10f); lineTo(9f, 14f); lineTo(5f, 14f); close()
        moveTo(10f, 10f); lineTo(14f, 10f); lineTo(14f, 14f); lineTo(10f, 14f); close()
        moveTo(15f, 10f); lineTo(19f, 10f); lineTo(19f, 14f); lineTo(15f, 14f); close()
    }
    val Download = icon("Download") { moveTo(10f, 3f); lineTo(14f, 3f); lineTo(14f, 12f); lineTo(18f, 12f); lineTo(12f, 18f); lineTo(6f, 12f); lineTo(10f, 12f); close(); moveTo(4f, 19f); lineTo(20f, 19f); lineTo(20f, 22f); lineTo(4f, 22f); close() }
    val Warning = icon("Warning") { moveTo(12f, 2f); lineTo(23f, 21f); lineTo(1f, 21f); close(); moveTo(11f, 8f); lineTo(13f, 8f); lineTo(13f, 15f); lineTo(11f, 15f); close(); moveTo(11f, 17f); lineTo(13f, 17f); lineTo(13f, 19f); lineTo(11f, 19f); close() }
    val Copy = icon("Copy") { moveTo(8f, 8f); lineTo(20f, 8f); lineTo(20f, 20f); lineTo(8f, 20f); close(); moveTo(4f, 4f); lineTo(16f, 4f); lineTo(16f, 6f); lineTo(6f, 6f); lineTo(6f, 16f); lineTo(4f, 16f); close() }
    val Share = icon("Share") { moveTo(18f, 3f); lineTo(23f, 8f); lineTo(18f, 13f); lineTo(18f, 9f); curveTo(12f, 9f, 8f, 11f, 5f, 16f); curveTo(6f, 9f, 10f, 5f, 18f, 5f); close(); moveTo(4f, 8f); lineTo(7f, 8f); lineTo(7f, 19f); lineTo(19f, 19f); lineTo(19f, 15f); lineTo(22f, 15f); lineTo(22f, 22f); lineTo(4f, 22f); close() }
    val Refresh = icon("Refresh") { moveTo(17f, 7f); lineTo(17f, 3f); lineTo(22f, 8f); lineTo(17f, 13f); lineTo(17f, 9f); curveTo(11f, 6f, 6f, 10f, 6f, 15f); curveTo(6f, 18f, 8f, 20f, 11f, 21f); curveTo(5f, 21f, 2f, 17f, 3f, 12f); curveTo(4f, 6f, 10f, 3f, 17f, 7f); close() }
}

private fun icon(name: String, block: PathBuilder.() -> Unit): ImageVector =
    ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f).apply {
        path(
            fill = null,
            stroke = SolidColor(Color.Black),
            strokeLineWidth = 2f,
            strokeLineCap = StrokeCap.Round,
            strokeLineJoin = StrokeJoin.Round,
            pathBuilder = block,
        )
    }.build()
