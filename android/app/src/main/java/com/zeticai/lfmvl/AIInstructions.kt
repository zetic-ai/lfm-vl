package com.zeticai.lfmvl.android

object AIInstructions {
    const val DEFAULT = "You are a concise vision assistant."
    const val MAX_CHARACTERS = 400
    fun validated(text: String): String? = text.trim().takeIf { it.isNotEmpty() && it.length <= MAX_CHARACTERS }
    fun forConversation(saved: String?, hasTurns: Boolean, setting: String): String =
        saved ?: if (hasTurns) DEFAULT else setting
}
