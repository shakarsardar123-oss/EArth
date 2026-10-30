package com.texo.texo

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper

/**
 * Receives the system assistant gesture (long press on Home). It is invisible:
 * it plays the screen flash over whatever app is open and finishes at once.
 * The app itself is NOT opened (unless it was not running at all, in which
 * case it starts behind the flash and goes back to the background).
 */
class TexoAssistActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val canOverlay = TexoGlow.canShow(applicationContext)
        val cold = !AssistBus.alive
        AssistBus.begin(cold, canOverlay)

        if (cold) {
            try {
                startActivity(
                    Intent(this, MainActivity::class.java).addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION,
                    ),
                )
            } catch (_: Throwable) {
            }
        }

        // Start the conversation while the flash is still fading (not after it),
        // so the overlay is on screen the moment the flash ends.
        TexoGlow.play(applicationContext) { }
        Handler(Looper.getMainLooper()).postDelayed({ AssistBus.fire() }, 550L)

        finish()
        overridePendingTransition(0, 0)
    }
}
