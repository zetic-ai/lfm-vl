package com.zeticai.lfmvl.android

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** Matches the Zetic Relay teal, white, and ink visual system. */
private val LfmColorScheme = lightColorScheme(
    primary = Color(0xFF2DBDB2),
    onPrimary = Color.White,
    secondary = Color(0xFF2DBDB2),
    onSecondary = Color.White,
    background = Color.White,
    onBackground = Color(0xFF0A0A0A),
    surface = Color.White,
    onSurface = Color(0xFF0A0A0A),
    surfaceVariant = Color(0xFFF0F0F0),
    onSurfaceVariant = Color(0xFF6B6B6B),
    outline = Color(0xFFE8E8E8),
    error = Color(0xFFC92A2A),
)

@Composable
fun LfmVisionTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = LfmColorScheme, content = content)
}
