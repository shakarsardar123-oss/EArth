package com.texo.texo

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Torch, nearby Bluetooth scan/pair, local audio search/play, contact dialling. */
object TexoExtras {
    @Volatile private var lastScan: List<Triple<String, String, Int>> = emptyList()

    private fun has(a: Activity, p: String) =
        a.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private val soraniMap = mapOf(
        'ب' to "b", 'پ' to "p", 'ت' to "t", 'ث' to "s", 'ج' to "j", 'چ' to "ch", 'ح' to "h",
        'خ' to "kh", 'د' to "d", 'ذ' to "z", 'ر' to "r", 'ڕ' to "r", 'ز' to "z", 'ژ' to "zh",
        'س' to "s", 'ش' to "sh", 'ص' to "s", 'ض' to "d", 'ط' to "t", 'ظ' to "z", 'غ' to "gh",
        'ف' to "f", 'ڤ' to "v", 'ق' to "q", 'ک' to "k", 'ك' to "k", 'گ' to "g", 'ل' to "l",
        'ڵ' to "l", 'م' to "m", 'ن' to "n", 'ه' to "h",
    )

    /** Consonant skeleton so Kurdish script and Latin spellings can be compared. */
    fun skeleton(s: String): String {
        val sb = StringBuilder()
        for (ch in s.lowercase()) {
            val m = soraniMap[ch]
            if (m != null) sb.append(m)
            else if (ch in 'a'..'z' && "aeiouyw".indexOf(ch) < 0) sb.append(ch)
        }
        val out = StringBuilder()
        for (ch in sb) if (out.isEmpty() || out.last() != ch) out.append(ch)
        return out.toString()
    }

    fun handle(a: Activity, call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "torch" -> torch(a, call, result)
                "scanBluetooth" -> scanBluetooth(a, result)
                "bondBluetooth" -> bondBluetooth(a, call, result)
                "searchAudio" -> searchAudio(a, call, result)
                "playAudio" -> playAudio(a, call, result)
                "dialContact" -> dialContact(a, call, result)
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.success(mapOf("ok" to false, "error" to (e.message ?: e.javaClass.simpleName)))
        }
    }

    private fun torch(a: Activity, call: MethodCall, result: MethodChannel.Result) {
        val on = call.argument<Boolean>("on") ?: true
        val cm = a.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id = cm.cameraIdList.firstOrNull { cid ->
            val ch = cm.getCameraCharacteristics(cid)
            ch.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true &&
                ch.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
        }
        if (id == null) {
            result.success(mapOf("ok" to false, "error" to "no_flash"))
            return
        }
        cm.setTorchMode(id, on)
        result.success(mapOf("ok" to true, "on" to on))
    }

    @Suppress("DEPRECATION")
    private fun deviceFrom(i: Intent): BluetoothDevice? =
        if (Build.VERSION.SDK_INT >= 33) i.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        else i.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)

    private fun scanBluetooth(a: Activity, result: MethodChannel.Result) {
        val needed = if (Build.VERSION.SDK_INT >= 31)
            listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        else listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        val missing = needed.filter { !has(a, it) }
        if (missing.isNotEmpty()) {
            a.requestPermissions(missing.toTypedArray(), 4711)
            result.success(mapOf("ok" to false, "needsPermission" to true))
            return
        }
        val adapter = (a.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.success(mapOf("ok" to false, "error" to "bluetooth_off"))
            return
        }
        val found = LinkedHashMap<String, Triple<String, String, Int>>()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, i: Intent?) {
                if (i == null || i.action != BluetoothDevice.ACTION_FOUND) return
                val d = deviceFrom(i) ?: return
                val rssi = i.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE).toInt()
                val name = (try { d.name } catch (e: SecurityException) { null }) ?: ""
                found[d.address] = Triple(name, d.address, rssi)
            }
        }
        a.registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_FOUND))
        try { adapter.cancelDiscovery() } catch (_: Throwable) {}
        val started = try { adapter.startDiscovery() } catch (_: Throwable) { false }
        if (!started) {
            try { a.unregisterReceiver(receiver) } catch (_: Throwable) {}
            result.success(mapOf("ok" to false, "error" to "scan_not_started"))
            return
        }
        Handler(Looper.getMainLooper()).postDelayed({
            try { adapter.cancelDiscovery() } catch (_: Throwable) {}
            try { a.unregisterReceiver(receiver) } catch (_: Throwable) {}
            val list = found.values.sortedByDescending { it.third }
            lastScan = list
            result.success(
                mapOf(
                    "ok" to true,
                    "devices" to list.map { mapOf("name" to it.first, "address" to it.second, "rssi" to it.third) },
                ),
            )
        }, 7000)
    }

    private fun bondBluetooth(a: Activity, call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= 31 && !has(a, Manifest.permission.BLUETOOTH_CONNECT)) {
            a.requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), 4713)
            result.success(mapOf("ok" to false, "needsPermission" to true))
            return
        }
        val q = skeleton(call.argument<String>("query") ?: "")
        val list = lastScan
        if (list.isEmpty()) {
            result.success(mapOf("ok" to false, "error" to "no_scan"))
            return
        }
        val hits = list.filter {
            val s = skeleton(it.first)
            it.first.isNotBlank() && s.length >= 2 && q.length >= 2 && (q.contains(s) || s.contains(q))
        }
        val target = when {
            hits.size == 1 -> hits[0]
            hits.isEmpty() && list.size == 1 -> list[0]
            else -> null
        }
        if (target == null) {
            val pool = if (hits.isNotEmpty()) hits else list
            result.success(mapOf("ok" to false, "error" to "ambiguous", "names" to pool.take(5).map { it.first }))
            return
        }
        val adapter = (a.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
        val started = adapter.getRemoteDevice(target.second).createBond()
        result.success(mapOf("ok" to started, "name" to target.first, "error" to (if (started) null else "bond_failed")))
    }

    private fun audioPerm() =
        if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO
        else Manifest.permission.READ_EXTERNAL_STORAGE

    private fun searchAudio(a: Activity, call: MethodCall, result: MethodChannel.Result) {
        val perm = audioPerm()
        if (!has(a, perm)) {
            a.requestPermissions(arrayOf(perm), 4712)
            result.success(mapOf("ok" to false, "needsPermission" to true))
            return
        }
        val q = skeleton(call.argument<String>("query") ?: "")
        val minMs = call.argument<Number>("minMs")?.toLong() ?: 0L
        val maxMs = call.argument<Number>("maxMs")?.toLong() ?: 0L
        var selection: String? = null
        var args: Array<String>? = null
        if (maxMs > 0) {
            selection = "${MediaStore.Audio.Media.DURATION} BETWEEN ? AND ?"
            args = arrayOf(minMs.toString(), maxMs.toString())
        }
        val out = ArrayList<Map<String, Any>>()
        a.contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.DISPLAY_NAME,
                MediaStore.Audio.Media.DURATION,
            ),
            selection,
            args,
            "${MediaStore.Audio.Media.DATE_ADDED} DESC",
        )?.use { c ->
            while (c.moveToNext() && out.size < 8) {
                val title = c.getString(1) ?: ""
                val artist = c.getString(2) ?: ""
                val file = c.getString(3) ?: ""
                if (q.length >= 2 && !skeleton("$title $artist $file").contains(q)) continue
                out.add(
                    mapOf(
                        "id" to c.getLong(0),
                        "title" to title.ifBlank { file },
                        "artist" to artist,
                        "durationMs" to c.getLong(4),
                    ),
                )
            }
        }
        result.success(mapOf("ok" to true, "items" to out))
    }

    private fun playAudio(a: Activity, call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Number>("id")?.toLong()
        if (id == null) {
            result.success(mapOf("ok" to false, "error" to "no_id"))
            return
        }
        val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
        val i = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "audio/*")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        a.startActivity(i)
        result.success(mapOf("ok" to true))
    }

    private fun dialContact(a: Activity, call: MethodCall, result: MethodChannel.Result) {
        if (!has(a, Manifest.permission.READ_CONTACTS)) {
            a.requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), 4714)
            result.success(mapOf("ok" to false, "needsPermission" to true))
            return
        }
        val q = skeleton(call.argument<String>("query") ?: "")
        if (q.length < 2) {
            result.success(mapOf("ok" to false, "error" to "no_name"))
            return
        }
        val people = LinkedHashMap<String, String>()
        a.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
            ),
            null, null, null,
        )?.use { c ->
            while (c.moveToNext()) {
                val name = c.getString(0) ?: continue
                val num = c.getString(1) ?: continue
                val sk = skeleton(name)
                if (sk.length >= 2 && (q.contains(sk) || sk.contains(q))) people.putIfAbsent(name, num)
            }
        }
        when {
            people.isEmpty() -> result.success(mapOf("ok" to false, "error" to "not_found"))
            people.size > 1 ->
                result.success(mapOf("ok" to false, "error" to "ambiguous", "names" to people.keys.take(5).toList()))
            else -> {
                val e = people.entries.first()
                a.startActivity(
                    Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + Uri.encode(e.value)))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(mapOf("ok" to true, "name" to e.key))
            }
        }
    }
}
