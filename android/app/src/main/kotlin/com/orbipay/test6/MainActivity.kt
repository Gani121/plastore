package com.orbipay.test6



import android.os.Bundle
import android.util.Log
import android.widget.Toast
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        fetchAndSaveFcmToken()
    }

    private fun fetchAndSaveFcmToken() {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (!task.isSuccessful) {
                Log.e("FCM_TOKEN", "Failed to get token")
                Toast.makeText(this, "Failed to get FCM token", Toast.LENGTH_LONG).show()
                return@addOnCompleteListener
            }

            val token = task.result
            Log.d("FCM_TOKEN", "FCM Token: $token")

            Toast.makeText(this, "FCM Token received", Toast.LENGTH_SHORT).show()

            saveFcmToken(token)
        }
    }

    private fun saveFcmToken(token: String) {
        try {
            val file = File(filesDir, "fcm_token.json")
            val json = """{"token":"$token"}"""
            file.writeText(json)

            Log.d("FCM_JSON", "Saved at: ${file.absolutePath}")

            Toast.makeText(this, "FCM token saved successfully", Toast.LENGTH_LONG).show()

        } catch (e: Exception) {
            Log.e("FCM_JSON", "Error: ${e.message}")
            Toast.makeText(this, "Error saving FCM token", Toast.LENGTH_LONG).show()
        }
    }
}
