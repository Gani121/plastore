package com.orbipay.test8




import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import android.widget.Toast
import android.content.Context
import org.json.JSONObject
import java.io.File
import android.os.Looper
import android.os.Handler




class MyFirebaseMessagingService : FirebaseMessagingService() {

    // Called when a new FCM token is generated
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d("FCM_TOKEN", "New FCM Token: $token")
        
    }


    private fun saveTokenToJson(token: String) {
        
    }


    fun showUserMessage(context: Context, message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(context, message, Toast.LENGTH_LONG).show()
        }
    }
    


    // Called when a message is received (foreground/background/killed)
    override fun onMessageReceived(message: RemoteMessage) {
        Log.d("FCM_MSG", "FCM Received: $message")
        //showUserMessage(this, "FCM Received: $message")
        val printData = message.data["printData"] ?: ""
        Log.d("FCM_MSG", "FCM Received: $printData")

        val intent = Intent(this, BluetoothPrintService::class.java)
        intent.putExtra("printData", printData)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
       
    showUserMessage(this, "Background print triggered")
    }

    // Optional: fetch the current token anytime
    fun fetchCurrentToken() {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                val token = task.result
               
                Log.d("FCM_TOKEN", "Current token: $token")
            } else {
                Log.e("FCM_TOKEN", "Failed to get token")
            }
        }
    }
}
