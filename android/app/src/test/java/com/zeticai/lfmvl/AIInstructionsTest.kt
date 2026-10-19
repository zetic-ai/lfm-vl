package com.zeticai.lfmvl.android

import org.junit.Assert.*
import org.junit.Test

class AIInstructionsTest {
    @Test fun `invalid instructions are rejected without truncating`() {
        assertNull(AIInstructions.validated(" \n "))
        assertNull(AIInstructions.validated("x".repeat(401)))
        assertEquals("Use French", AIInstructions.validated("  Use French\n"))
    }
    @Test fun `existing conversation keeps its snapshot after settings change`() {
        assertEquals("Original", AIInstructions.forConversation("Original", true, "Changed"))
        assertEquals("Original", AIInstructions.forConversation("Original", false, "Changed"))
        assertEquals("Changed", AIInstructions.forConversation(null, false, "Changed"))
        assertEquals(AIInstructions.DEFAULT, AIInstructions.forConversation(null, true, "Changed"))
    }
}
