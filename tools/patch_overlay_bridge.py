"""Patches FloatingTexoBridge.kt for the new TEXO overlay:
  * 'overlayState' method (mode, level, emoji, subtitles ... pushed from Dart)
  * 'setOverlayVisible' method (show/hide the pill without stopping the service)
  * showOverlay accepts {hidden: true} (start the service while the app is visible)
  * the overlay's close button hides it natively and unbinds the service
Run from the project root:  python3 tools/patch_overlay_bridge.py"""
import sys

P = "android/app/src/main/kotlin/com/texo/texo/FloatingTexoBridge.kt"
s = open(P, encoding="utf-8").read()
if "closeFromOverlay" in s:
    print("already patched")
    sys.exit(0)


def rep(old, new, name):
    global s
    if s.count(old) != 1:
        print("FAIL", name, "count =", s.count(old))
        sys.exit(1)
    s = s.replace(old, new)


rep("    private var bound = false\n",
    "    private var bound = false\n    private var activityRef: MainActivity? = null\n", "field")

rep("""            service?.onOverlayAction = { action ->
                mainHandler.post {
                    methodChannel?.invokeMethod("overlayAction", action)
                }
            }""", """            service?.onOverlayAction = { action ->
                mainHandler.post {
                    methodChannel?.invokeMethod("overlayAction", action)
                    if (action == "close") {
                        closeFromOverlay()
                    }
                }
            }""", "onServiceConnected")

rep("        methodChannel = channel\n",
    "        methodChannel = channel\n        activityRef = activity\n", "attach")

rep("        service = null\n        methodChannel = null\n",
    "        service = null\n        methodChannel = null\n        activityRef = null\n", "detach")

rep("""                startAndBind(activity, x, y)

                waitForOverlayReady(result)""", """                val hidden = call.argument<Boolean>("hidden") ?: false
                startAndBind(activity, x, y, hidden)

                if (hidden) {
                    result.success(mapOf("shown" to false, "hidden" to true))
                } else {
                    waitForOverlayReady(result)
                }""", "showOverlay")

rep("""    private fun startAndBind(
        activity: MainActivity,
        xDp: Int,
        yDp: Int,
    ) {""", """    private fun startAndBind(
        activity: MainActivity,
        xDp: Int,
        yDp: Int,
        hidden: Boolean = false,
    ) {""", "startAndBind signature")

rep("""                putExtra(
                    FloatingTexoOverlayService.EXTRA_POS_Y_DP,
                    yDp,
                )
""", """                putExtra(
                    FloatingTexoOverlayService.EXTRA_POS_Y_DP,
                    yDp,
                )
                putExtra(FloatingTexoOverlayService.EXTRA_HIDDEN, hidden)
""", "startAndBind extras")

rep('            "togglePanel" -> {', '''            "overlayState" -> {
                val map = call.arguments as? Map<*, *>
                if (map != null) {
                    service?.applyState(map)
                }
                result.success(null)
            }

            "setOverlayVisible" -> {
                service?.setVisible(call.argument<Boolean>("visible") ?: true)
                result.success(null)
            }

            "togglePanel" -> {''', "cases")

rep("    private fun waitForOverlayReady(", """    private fun closeFromOverlay() {
        service?.onOverlayAction = null
        service?.hide()

        if (bound) {
            try {
                activityRef?.unbindService(connection)
            } catch (_: Throwable) {
            }
            bound = false
        }

        service = null
    }

    private fun waitForOverlayReady(""", "closeFromOverlay")

open(P, "w", encoding="utf-8").write(s)
print("OK")
