package com.zeticai.lfmvl.android

import org.junit.Assert.assertEquals
import org.junit.Test

class ZoomStateTest {
    @Test fun zoomIsClampedAndDoubleTapToggles() {
        assertEquals(6f, ZoomState().zoomBy(20f).scale)
        assertEquals(2.5f, ZoomState().doubleTap().scale)
        assertEquals(1f, ZoomState(2.5f).doubleTap().scale)
    }
}
