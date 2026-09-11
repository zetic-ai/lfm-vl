package com.zeticai.lfmvl.android

import android.content.Context
import com.zeticai.mlange.core.background.BackgroundDownloadHandle
import com.zeticai.mlange.core.background.BackgroundDownloadState
import com.zeticai.mlange.core.background.BackgroundDownloadStatus
import com.zeticai.mlange.core.background.ModelRemovalResult
import com.zeticai.mlange.core.cache.ModelCacheHandlingPolicy
import com.zeticai.mlange.core.model.llm.LLMModelMode
import com.zeticai.mlange.core.model.llm.ZeticMLangeLLMModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** Only an explicit grant for this version may resume a durable SDK download. */
internal object LfmModelDownloadConsent {
    const val CURRENT_VERSION = "1"

    fun isCurrent(version: String?) = version == CURRENT_VERSION
}

data class BackgroundModelDownloadState(
    val state: BackgroundDownloadState,
    val errorMessage: String? = null,
    val isStatusLookupFailure: Boolean = false,
) {
    val isActive: Boolean
        get() = state in ACTIVE_STATES

    val isInstalled: Boolean
        get() = state == BackgroundDownloadState.INSTALLED

    val canRemove: Boolean
        get() = isActive || isInstalled

    private companion object {
        val ACTIVE_STATES = setOf(
            BackgroundDownloadState.QUEUED,
            BackgroundDownloadState.RESOLVING,
            BackgroundDownloadState.DOWNLOADING,
            BackgroundDownloadState.VERIFYING,
        )
    }
}

/** Persists current-version consent and an SDK background-download handle. */
class LfmBackgroundModelDownload(
    context: Context,
    private val personalKey: String,
) {
    private val applicationContext = context.applicationContext
    private val preferences = applicationContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
    private val operationMutex = Mutex()

    val hasCurrentConsent: Boolean
        get() = LfmModelDownloadConsent.isCurrent(preferences.all[CONSENT_VERSION_KEY] as? String)

    /** A returning user resumes only a transfer approved under the current consent text. */
    suspend fun scheduleIfConsented(): BackgroundModelDownloadState? = withContext(Dispatchers.IO) {
        operationMutex.withLock {
            if (!hasCurrentConsent || personalKey.isBlank()) return@withLock null
            resumeOrScheduleLocked()
        }
    }

    /** Called exclusively after the explicit first-download action. */
    suspend fun grantConsentAndSchedule(): BackgroundModelDownloadState = withContext(Dispatchers.IO) {
        operationMutex.withLock {
            currentCoroutineContext().ensureActive()
            preferences.edit().putString(CONSENT_VERSION_KEY, LfmModelDownloadConsent.CURRENT_VERSION).apply()
            // An older app may have left a durable handle behind. The new consent may resume
            // that SDK transfer, but must not create a duplicate alongside it.
            resumeOrScheduleLocked()
        }
    }

    suspend fun refresh(): BackgroundModelDownloadState? = withContext(Dispatchers.IO) {
        operationMutex.withLock { refreshLocked() }
    }

    /** Stops any active SDK transfer before removing only SDK-managed model artifacts. */
    suspend fun removeDownloadedModel(): ModelRemovalResult = withContext(Dispatchers.IO) {
        operationMutex.withLock {
            currentCoroutineContext().ensureActive()
            storedHandle?.let { handle ->
                runCatching {
                    ZeticMLangeLLMModel.stopBackgroundDownload(applicationContext, handle)
                }
            }
            val result = ZeticMLangeLLMModel.removeDownloadedModel(
                context = applicationContext,
                name = VisionEngine.MODEL_NAME,
            )
            currentCoroutineContext().ensureActive()
            if (!result.isInUse) clearConsentAndHandleLocked()
            result
        }
    }

    private fun resumeOrScheduleLocked(): BackgroundModelDownloadState {
        val existing = refreshLocked()
        return if (existing != null && (existing.isStatusLookupFailure || existing.isActive || existing.isInstalled)) {
            existing
        } else {
            scheduleLocked()
        }
    }

    private fun refreshLocked(): BackgroundModelDownloadState? {
        val handle = storedHandle ?: return null
        return try {
            ZeticMLangeLLMModel.getBackgroundDownloadStatus(applicationContext, handle).toUiState()
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            // Do not create a second transfer while the durable SDK job cannot be inspected.
            BackgroundModelDownloadState(
                state = BackgroundDownloadState.FAILED,
                errorMessage = error.message,
                isStatusLookupFailure = true,
            )
        }
    }

    private fun scheduleLocked(): BackgroundModelDownloadState = try {
        if (!hasCurrentConsent || personalKey.isBlank()) throw CancellationException()
        val handle = ZeticMLangeLLMModel.downloadInBackground(
            context = applicationContext,
            personalKey = personalKey,
            name = VisionEngine.MODEL_NAME,
            version = null,
            modelMode = LLMModelMode.RUN_AUTO,
            cacheHandlingPolicy = ModelCacheHandlingPolicy.KEEP_EXISTING,
        )
        storedHandle = handle
        ZeticMLangeLLMModel.getBackgroundDownloadStatus(applicationContext, handle).toUiState()
    } catch (error: CancellationException) {
        throw error
    } catch (error: Throwable) {
        BackgroundModelDownloadState(
            state = BackgroundDownloadState.FAILED,
            errorMessage = error.message,
            isStatusLookupFailure = true,
        )
    }

    private var storedHandle: BackgroundDownloadHandle?
        get() = preferences.getString(HANDLE_KEY, null)?.let(::BackgroundDownloadHandle)
        set(value) {
            preferences.edit().apply {
                if (value == null) remove(HANDLE_KEY) else putString(HANDLE_KEY, value.id)
            }.apply()
        }

    private fun clearConsentAndHandleLocked() {
        preferences.edit().remove(CONSENT_VERSION_KEY).remove(HANDLE_KEY).apply()
    }

    private companion object {
        const val PREFERENCES_NAME = "lfm-vision-model-download"
        const val CONSENT_VERSION_KEY = "model.downloadConsent.version"
        const val HANDLE_KEY = "model.backgroundDownloadHandle"
    }
}

private fun BackgroundDownloadStatus.toUiState() = BackgroundModelDownloadState(
    state = state,
    errorMessage = errorMessage,
)
