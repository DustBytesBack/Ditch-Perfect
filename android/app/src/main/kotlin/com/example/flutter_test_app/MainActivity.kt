package com.example.flutter_test_app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "DPBK_INTENT"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        logIntent("onCreate", intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        logIntent("onNewIntent", intent)
    }

    private fun logIntent(source: String, incoming: Intent?) {
        if (incoming == null) {
            Log.d(TAG, "$source: null intent")
            return
        }

        val action = incoming.action ?: "null"
        val type = incoming.type ?: "null"
        val data: Uri? = incoming.data
        val dataString = data?.toString() ?: "null"
        val scheme = data?.scheme ?: "null"
        val host = data?.host ?: "null"
        val path = data?.path ?: "null"
        val flags = incoming.flags

        Log.d(
            TAG,
            "$source action=$action type=$type scheme=$scheme host=$host path=$path data=$dataString flags=$flags"
        )
    }
}
