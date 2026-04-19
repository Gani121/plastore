package com.orbipay.test8

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStream
import java.util.*
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

import androidx.core.app.NotificationCompat

import android.os.Handler
import android.os.Looper
import android.widget.Toast  // Add this import

class BluetoothPrintService : Service() {

    private val CHANNEL_ID = "bluetooth_print_service"
    private val TAG = "BluetoothPrintService"
    private val UUID_SERIAL = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    
    private lateinit var notificationManager: NotificationManager
    private var isPrinting = false

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(NotificationManager::class.java)
        createNotificationChannel()
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand called")
        
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        val data = intent.extras
        val printDataJson = data?.getString("printData") ?: "[]"
        val replaceData = data?.getString("replaceData") ?: ""  // Get replaceData
        val total = data?.getDouble("total") ?: 0.0

        Log.d(TAG, "Received print data printDataJson: $printDataJson")
        Log.d(TAG, "Received print data replaceDataJson: $replaceData")

        // Create persistent notification
        val notification = createNotification("Preparing to print...")
        startForeground(1, notification)

        Thread {
            try {
                // Check for settle command
                if (printDataJson.startsWith("settle-")) {
                    Log.d(TAG, "Settle received, no print required")
                    saveSettleToFile(printDataJson)
                    stopSelf()
                    return@Thread
                }
                // Save KOT first
                val replaceDataJson = if (replaceData.isNotEmpty()) replaceData else printDataJson
                saveKOTToFile(replaceDataJson)

                
                val jsonArray = JSONArray(printDataJson)
                if (jsonArray.length() == 0) {
                    Log.d(TAG, "Empty data array, stopping")
                    stopSelf()
                    return@Thread
                }

                val firstItem = jsonArray.getJSONObject(0)
                val dataFor = firstItem.optString("datafor", "")
                val isprint = firstItem.optBoolean("isprint", false) // Use optBoolean instead of optString
                if (dataFor == "captain" || isprint) {
                    Log.d(TAG, "Captain FCM received, no print required")
                    stopSelf()
                    return@Thread
                }

                // Generate bill
                updateNotification("Generating bill...")
                val billText = generateBillFromJson(printDataJson, total)
                Log.d(TAG, "Generated bill text length: ${billText.length}")

                // Print via Bluetooth
                updateNotification("Printing...")
                val success = printViaBluetooth(billText)
                
                if (success) {
                    updateNotification("Print successful")
                    Log.d(TAG, "Print successful")
                    // Show toast on main thread
                    Handler(Looper.getMainLooper()).post {
                        Toast.makeText(applicationContext, "Print successful", Toast.LENGTH_SHORT).show()
                    }
                } else {
                    updateNotification("Print failed")
                    Log.e(TAG, "Print failed")
                    Handler(Looper.getMainLooper()).post {
                        Toast.makeText(applicationContext, "Print failed", Toast.LENGTH_LONG).show()
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error in print thread: ${e.message}", e)
                updateNotification("Print error")
                Handler(Looper.getMainLooper()).post {
                    Toast.makeText(applicationContext, "Print error: ${e.message}", Toast.LENGTH_LONG).show()
                }
            } finally {
                // Delay stopping to ensure everything completes
                Handler(Looper.getMainLooper()).postDelayed({
                    stopSelf()
                }, 2000)
            }
        }.start()

        return START_REDELIVER_INTENT
    }

    private fun createNotification(message: String): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Print Service")
                .setContentText(message)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)
                .setPriority(Notification.PRIORITY_HIGH)
                .build()
        } else {
            return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Print Service")
                .setContentText(message)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .build()
        }
    }

    private fun updateNotification(message: String) {
        val notification = createNotification(message)
        notificationManager.notify(1, notification)
    }

    private fun saveKOTToFile(rawJson: String) {
        try {
            val file = File(filesDir, "pending_kot.json")
            
            // Parse incoming data as JSONObject
            val incomingData = JSONObject(rawJson)
            
            // Load existing data
            val existingData = if (file.exists()) {
                try {
                    JSONObject(file.readText())
                } catch (e: Exception) {
                    JSONObject()
                }
            } else {
                JSONObject()
            }
            
            Log.d(TAG, "Existing tables: ${existingData}")
            
            // Process each table
            val keys = incomingData.keys()
            while (keys.hasNext()) {
                val tableNo = keys.next()
                val tableValue = incomingData.get(tableNo)
                
                // Get the items array (handle both array and object formats)
                val itemsArray = when (tableValue) {
                    is JSONArray -> tableValue
                    is JSONObject -> {
                        if (tableValue.has("items")) {
                            tableValue.getJSONArray("items")
                        } else {
                            Log.e(TAG, "Table $tableNo: no items array found")
                            continue
                        }
                    }
                    else -> {
                        Log.e(TAG, "Table $tableNo: unexpected type ${tableValue.javaClass}")
                        continue
                    }
                }
                
                // Replace or add the table data
                existingData.put(tableNo, itemsArray)
                Log.d(TAG, "Saved table $tableNo with ${itemsArray} items")
            }
            
            // Save to file
            file.writeText(existingData.toString())
            Log.d(TAG, "Successfully saved ${existingData} tables to ${file.absolutePath}")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error saving KOT: ${e.message}", e)
        }
    }

    private fun saveSettleToFile(rawJson: String) {
        try {
            val file = File(filesDir, "pending_settle.json")
            val existingJson = if (file.exists()) file.readText() else "[]"
            val jsonArray = JSONArray(existingJson)

            val tableNo = if (rawJson.startsWith("settle-")) {
                rawJson.removePrefix("settle-").trim()
            } else {
                null
            }

            val numericTableNo = tableNo?.toIntOrNull()
            if (numericTableNo == null) {
                Log.d(TAG, "Not required to store in settle as order entered through cashier")
                return
            }

            if (tableNo != null) {
                var found = false
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    if (obj.optString("tableNo") == tableNo) {
                        found = true
                        break
                    }
                }

                if (!found) {
                    val settleEntry = JSONObject()
                    settleEntry.put("tableNo", tableNo)
                    settleEntry.put("timestamp", System.currentTimeMillis())
                    jsonArray.put(settleEntry)
                    file.writeText(jsonArray.toString())
                    Log.d(TAG, "Saved settle table $tableNo")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save settle: ${e.message}")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Bluetooth Print Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Service for Bluetooth printing"
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(serviceChannel)
        }
    }

    private fun generateBillFromJson(printData: String, total: Double): String {
        val sb = StringBuilder()
        val lineWidth = 50

        // ESC/POS commands
        fun setStyle(n: Int) = sb.append("\u001B\u0021").append(n.toChar())
        fun boldBig() = setStyle(0x08 or 0x10 or 0x20) // bold + double height + double width [web:4]
        fun normal() = setStyle(0x00)
        fun boldOn() = sb.append("\u001B\u0045\u0001")
        fun boldOff() = sb.append("\u001B\u0045\u0000")
        fun center() = sb.append("\u001B\u0061\u0001")
        fun left() = sb.append("\u001B\u0061\u0000")

        fun addLine(text: String) {
            left()
            if (text.length <= lineWidth) {
                sb.append(text).append("\n")
            } else {
                var start = 0
                while (start < text.length) {
                    val end = minOf(start + lineWidth, text.length)
                    sb.append(text.substring(start, end)).append("\n")
                    start = end
                }
            }
        }

        try {
            val items = JSONArray(printData)
            val firstItem = items.getJSONObject(0)
            val captain_name = firstItem.optString("captain_name", "Unknown")
            val tableNo = firstItem.optString("tableno", "0")

            // Reset printer
            sb.append("\u001B\u0040") // Initialize printer
            
            // HEADER
            center()
            boldOn()
            sb.append("KOT\n")
            boldOff()
            // center()
            // sb.append("==============\n")
            left()

            addLine("Captain Name : $captain_name")
            addLine("Table No : $tableNo")
            val kotDateTime = SimpleDateFormat("dd/MM/yyyy hh:mm a", Locale.getDefault()).format(Date())
            addLine("KOT Time : $kotDateTime")
            // addLine("--------------------------------")

            // COLUMN HEADER
            boldOn()
            addLine("QTY x Item        Note")
            addLine("--------------------------------")

            // ITEMS
            for (i in 0 until items.length()) {
                val item = items.getJSONObject(i)
                val name = item.optString("name", "")
                val qty = item.optInt("qty", 1)
                val note = item.optString("note", "")

                // Add item with quantity
                boldOn()
                addLine("$qty x $name")
                
                // Add note if present
                if (note.isNotBlank()) {
                    addLine("  Note: $note")
                }
                
                // Add separator between items
                if (i < items.length() - 1) {
                    addLine("")
                }
            }
            boldOff()
            addLine("--------------------------------")
            
            sb.append("\u001D\u0056\u0000") // Full cut
            
        } catch (e: Exception) {
            Log.e(TAG, "Error generating bill: ${e.message}")
            sb.append("\u001B\u0040") // Reset printer
            center()
            boldOn()
            sb.append("ERROR\n")
            boldOff()
            addLine("Error generating bill")
            addLine(e.message ?: "Unknown error")
            sb.append("\n\n\n\u001D\u0056\u0000") // Cut
        }

        return sb.toString()
    }

    private fun printViaBluetooth(text: String): Boolean {
        var socket: BluetoothSocket? = null
        var outputStream: OutputStream? = null
        
        return try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            if (adapter == null || !adapter.isEnabled) {
                Log.e(TAG, "Bluetooth not available or not enabled!")
                return false
            }

            val printerMac = getPrinterMacFromJson()
            if (printerMac == null) {
                Log.e(TAG, "Printer MAC not found!")
                return false
            }

            Log.d(TAG, "Attempting to connect to printer: $printerMac")
            
            // Cancel discovery before connecting
            adapter.cancelDiscovery()
            
            val device: BluetoothDevice = adapter.getRemoteDevice(printerMac)
            socket = device.createRfcommSocketToServiceRecord(UUID_SERIAL)
            
            // Set connection timeout
            socket.connect()
            Log.d(TAG, "Connected to printer: ${device.name}")
            
            outputStream = socket.outputStream
            
            // Send data in chunks
            val bytes = text.toByteArray(Charsets.UTF_8)
            val chunkSize = 1024
            var offset = 0
            
            while (offset < bytes.size) {
                val end = minOf(offset + chunkSize, bytes.size)
                outputStream.write(bytes, offset, end - offset)
                outputStream.flush()
                offset = end
                Log.d(TAG, "Sent ${end - offset} bytes")
            }
            
            Log.d(TAG, "Total bytes sent: ${bytes.size}")
            
            // Wait a bit before closing
            Thread.sleep(500)
            
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "Bluetooth print failed: ${e.message}", e)
            false
        } finally {
            try {
                outputStream?.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing output stream: ${e.message}")
            }
            
            try {
                socket?.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing socket: ${e.message}")
            }
        }
    }

    private fun getPrinterMacFromJson(): String? {
        return try {
            val file = File(filesDir, "printer.json")
            if (!file.exists()) {
                Log.e(TAG, "printer.json file not found!")
                return null
            }

            val jsonString = file.readText()
            val jsonObject = JSONObject(jsonString)
            
            // Try different possible keys
            jsonObject.optString("printerAddress", null) ?: 
            jsonObject.optString("macAddress", null) ?:
            jsonObject.optString("address", null) ?:
            jsonObject.optString("mac", null)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error reading printer MAC: ${e.message}")
            null
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "Service destroyed")
        isPrinting = false
        super.onDestroy()
    }
}