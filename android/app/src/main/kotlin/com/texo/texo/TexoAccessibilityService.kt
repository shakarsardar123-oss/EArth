package com.texo.texo

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityEvent
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * AURA AccessibilityService.
 *
 * Provides:
 *  - REAL gesture dispatch
 *  - FAIL-CLOSED target verification against the active Accessibility tree
 *
 * The service does not log or return the complete screen tree.
 */
class TexoAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: TexoAccessibilityService? = null
            private set
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Intentionally empty.
        // Target verification reads rootInActiveWindow on demand.
    }

    override fun onInterrupt() {
        // No continuous operation to interrupt.
    }

    /**
     * Verifies a screen target against the current Accessibility tree.
     *
     * Returns only the verification result and minimal metadata.
     * It never returns the whole tree or node text collection.
     */
    fun verifyTarget(
        label: String?,
        type: String?,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
    ): Map<String, Any> {
        val root = rootInActiveWindow
            ?: return mapOf(
                "matched" to false,
                "reason" to "no_active_window",
            )

        if (width <= 0.0 || height <= 0.0 ||
            x < 0.0 || y < 0.0 ||
            x + width > 1.0 || y + height > 1.0
        ) {
            return mapOf(
                "matched" to false,
                "reason" to "invalid_bounds",
            )
        }

        val metrics = resources.displayMetrics
        val screenWidth = metrics.widthPixels.toDouble()
        val screenHeight = metrics.heightPixels.toDouble()

        if (screenWidth <= 0.0 || screenHeight <= 0.0) {
            return mapOf(
                "matched" to false,
                "reason" to "invalid_screen_size",
            )
        }

        val expected = RectFNorm(x, y, width, height)
        val normalizedLabel = normalizeText(label)
        val normalizedType = normalizeType(type)

        val candidates = mutableListOf<Candidate>()

        collectCandidates(
            node = root,
            expected = expected,
            expectedLabel = normalizedLabel,
            expectedType = normalizedType,
            screenWidth = screenWidth,
            screenHeight = screenHeight,
            output = candidates,
        )

        if (candidates.isEmpty()) {
            return mapOf(
                "matched" to false,
                "reason" to "target_not_found",
            )
        }

        candidates.sortByDescending { it.score }

        val best = candidates.first()

        // Ambiguous candidates are rejected rather than guessed.
        if (candidates.size > 1) {
            val second = candidates[1]
            if (abs(best.score - second.score) < 0.08) {
                return mapOf(
                    "matched" to false,
                    "reason" to "ambiguous_match",
                )
            }
        }

        if (best.score < 0.72) {
            return mapOf(
                "matched" to false,
                "reason" to "weak_match",
            )
        }

        return mapOf(
            "matched" to true,
            "confidence" to best.score,
            "bounds" to mapOf(
                "left" to best.bounds.left,
                "top" to best.bounds.top,
                "right" to best.bounds.right,
                "bottom" to best.bounds.bottom,
            ),
            "nodeType" to best.nodeType,
            "clickable" to best.clickable,
            "enabled" to best.enabled,
        )
    }

    private fun collectCandidates(
        node: AccessibilityNodeInfo?,
        expected: RectFNorm,
        expectedLabel: String?,
        expectedType: String?,
        screenWidth: Double,
        screenHeight: Double,
        output: MutableList<Candidate>,
    ) {
        if (node == null) return

        try {
            if (node.isVisibleToUser) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)

                if (!bounds.isEmpty) {
                    val normalized = RectFNorm(
                        x = (bounds.left / screenWidth).coerceIn(0.0, 1.0),
                        y = (bounds.top / screenHeight).coerceIn(0.0, 1.0),
                        width = ((bounds.right - bounds.left) / screenWidth)
                            .coerceIn(0.0, 1.0),
                        height = ((bounds.bottom - bounds.top) / screenHeight)
                            .coerceIn(0.0, 1.0),
                    )

                    val nodeLabel = normalizeText(
                        node.text?.toString()
                            ?: node.contentDescription?.toString()
                    )

                    val nodeType = normalizeType(node.className?.toString())

                    val labelScore = labelSimilarity(
                        expectedLabel,
                        nodeLabel,
                    )

                    val typeScore = typeSimilarity(
                        expectedType,
                        nodeType,
                    )

                    val iou = intersectionOverUnion(expected, normalized)
                    val centerScore = centerSimilarity(expected, normalized)

                    val geometryScore = max(iou, centerScore)

                    if (geometryScore >= 0.35 &&
                        (labelScore > 0.0 || expectedLabel.isNullOrEmpty())
                    ) {
                        val score =
                            (labelScore * 0.50) +
                            (typeScore * 0.15) +
                            (geometryScore * 0.35)

                        output.add(
                            Candidate(
                                score = score,
                                bounds = bounds,
                                nodeType = node.className?.toString() ?: "",
                                clickable = node.isClickable,
                                enabled = node.isEnabled,
                            ),
                        )
                    }
                }
            }

            for (i in 0 until node.childCount) {
                collectCandidates(
                    node = node.getChild(i),
                    expected = expected,
                    expectedLabel = expectedLabel,
                    expectedType = expectedType,
                    screenWidth = screenWidth,
                    screenHeight = screenHeight,
                    output = output,
                )
            }
        } finally {
            node.recycle()
        }
    }

    private fun normalizeText(value: String?): String? {
        val normalized = value
            ?.trim()
            ?.lowercase()
            ?.replace(Regex("\\s+"), " ")

        return normalized?.takeIf { it.isNotEmpty() }
    }

    private fun normalizeType(value: String?): String? {
        val raw = normalizeText(value) ?: return null

        return when {
            raw.contains("button") -> "button"
            raw.contains("edittext") ||
                raw.contains("textfield") -> "text"
            raw.contains("checkbox") -> "checkbox"
            raw.contains("switch") -> "switch"
            raw.contains("imagebutton") -> "button"
            raw.contains("imageview") -> "image"
            raw.contains("textview") -> "text"
            raw.contains("scrollview") -> "scroll"
            else -> raw.substringAfterLast('.')
        }
    }

    private fun labelSimilarity(
        expected: String?,
        actual: String?,
    ): Double {
        if (expected.isNullOrEmpty() || actual.isNullOrEmpty()) {
            return 0.0
        }

        if (expected == actual) return 1.0

        if (actual.contains(expected) || expected.contains(actual)) {
            return 0.82
        }

        return 0.0
    }

    private fun typeSimilarity(
        expected: String?,
        actual: String?,
    ): Double {
        if (expected.isNullOrEmpty() || actual.isNullOrEmpty()) {
            return 0.0
        }

        if (expected == actual) return 1.0

        return when {
            expected == "button" && actual.contains("button") -> 0.9
            expected == "text" &&
                (actual.contains("text") || actual.contains("edit")) -> 0.9
            expected == "checkbox" && actual.contains("checkbox") -> 0.9
            expected == "switch" && actual.contains("switch") -> 0.9
            else -> 0.0
        }
    }

    private fun intersectionOverUnion(
        a: RectFNorm,
        b: RectFNorm,
    ): Double {
        val left = max(a.x, b.x)
        val top = max(a.y, b.y)
        val right = min(a.right, b.right)
        val bottom = min(a.bottom, b.bottom)

        val intersectionWidth = max(0.0, right - left)
        val intersectionHeight = max(0.0, bottom - top)
        val intersection = intersectionWidth * intersectionHeight

        if (intersection <= 0.0) return 0.0

        val union =
            (a.width * a.height) +
            (b.width * b.height) -
            intersection

        if (union <= 0.0) return 0.0

        return intersection / union
    }

    private fun centerSimilarity(
        a: RectFNorm,
        b: RectFNorm,
    ): Double {
        val dx = abs(a.centerX - b.centerX)
        val dy = abs(a.centerY - b.centerY)
        val distance = kotlin.math.sqrt(dx * dx + dy * dy)

        return (1.0 - (distance / 0.5)).coerceIn(0.0, 1.0)
    }

    private data class RectFNorm(
        val x: Double,
        val y: Double,
        val width: Double,
        val height: Double,
    ) {
        val right: Double
            get() = x + width

        val bottom: Double
            get() = y + height

        val centerX: Double
            get() = x + width / 2.0

        val centerY: Double
            get() = y + height / 2.0
    }

    private data class Candidate(
        val score: Double,
        val bounds: Rect,
        val nodeType: String,
        val clickable: Boolean,
        val enabled: Boolean,
    )

    /**
     * Dispatches a real gesture through Android AccessibilityService.
     */
    fun performGesture(
        gesture: String,
        x: Double,
        y: Double,
        x2: Double?,
        y2: Double?,
        durationMs: Long,
        onDone: (dispatched: Boolean, completed: Boolean) -> Unit,
    ): Boolean {
        if (Build.VERSION.SDK_INT < 24) return false

        val path = Path()
        val safeDuration = durationMs.coerceIn(10L, 10_000L)

        val stroke: GestureDescription.StrokeDescription = when (gesture) {
            "tap" -> {
                path.moveTo(x.toFloat(), y.toFloat())
                path.lineTo(x.toFloat(), y.toFloat())
                GestureDescription.StrokeDescription(path, 0L, 1L)
            }

            "long_press" -> {
                path.moveTo(x.toFloat(), y.toFloat())
                path.lineTo(x.toFloat(), y.toFloat())
                GestureDescription.StrokeDescription(
                    path,
                    0L,
                    safeDuration.coerceAtLeast(400L),
                )
            }

            "swipe" -> {
                val ex = (x2 ?: x).toFloat()
                val ey = (y2 ?: y).toFloat()
                path.moveTo(x.toFloat(), y.toFloat())
                path.lineTo(ex, ey)
                GestureDescription.StrokeDescription(
                    path,
                    0L,
                    safeDuration,
                )
            }

            else -> return false
        }

        val description =
            GestureDescription.Builder()
                .addStroke(stroke)
                .build()

        val callback = object : GestureResultCallback() {
            override fun onCompleted(
                gestureDescription: GestureDescription?,
            ) {
                onDone(true, true)
            }

            override fun onCancelled(
                gestureDescription: GestureDescription?,
            ) {
                onDone(true, false)
            }
        }

        val accepted =
            dispatchGesture(description, callback, null)

        if (!accepted) {
            onDone(false, false)
        }

        return accepted
    }
}
