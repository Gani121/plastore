package com.orbipay.test6


import com.orbipay.test6.R


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
import android.widget.Toast



class BluetoothPrintService : Service() {

    private val CHANNEL_ID = "bluetooth_print_service"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val data = intent?.extras
        val printDataJson = data?.getString("printData") ?: "[]"
        val orderId = data?.getString("orderId")
        val total = data?.getDouble("total") ?: 0.0

        Log.d("PrintService", "Printing FCM data: $printDataJson")

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Printing Service")
                .setContentText("Printing in progress")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)
                .build()
        } else {
            Notification.Builder(this)
                .setContentTitle("Printing Service")
                .setContentText("Printing in progress")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)
                .build()
        }

        startForeground(1, notification)

       Thread {

    // 1️⃣ Always save or settle first
    saveKOTToFile(printDataJson)

    // 2️⃣ If it was a settle command → stop processing
    if (printDataJson.startsWith("settle-")) {
        Log.d("PrintService", "Settle received. No print required.")
        stopSelf()
        return@Thread
    }



    val jsonArray = JSONArray(printDataJson)

        // "datafor" is inside firstObject.items[0].datafor
            // datafor exists inside the first element of the array
    val firstItem = jsonArray.getJSONObject(0)

    val dataFor = firstItem.optString("datafor", "")
    Log.d("PrintService", "datafor value: $dataFor")
       
   

    if (dataFor=="captain") {
          Log.d("PrintService", "captain fcm receive. No print required.")
 stopSelf()
        return@Thread
    }

    // 3️⃣ Generate bill
    val billText = generateBillFromJson(printDataJson, total)

    // 4️⃣ Print via Bluetooth
    printViaBluetooth(billText)

    // 5️⃣ Optional: Save transaction file
    // saveTransactionLocally(transactionJson)

    stopSelf()

}.start()

        return START_STICKY
    }

fun saveKOTToFile(rawJson: String) {
    try {
        val file = File(filesDir, "pending_kot.json")
        val existing = if (file.exists()) file.readText() else "[]"
        val jsonArray = JSONArray(existing)
        Log.w("PrintService", "Read cart from the file: $jsonArray")

        if (rawJson.startsWith("settle-")) {
            saveSettleToFile(rawJson)
            return
        }

        // Empty KOT
        if (rawJson.isEmpty()) {
            Log.w("PrintService", "Received empty KOT JSON, skipping save.")
            return
        }

        val newKot = JSONObject().apply {
            put("items", JSONArray(rawJson))
        }

        // ---- Prevent duplicates ----
        var isDuplicate = false
        for (i in 0 until jsonArray.length()) {
            val existingKot = jsonArray.getJSONObject(i)
            Log.w("PrintService", "Read cart from the file existingKot: $existingKot")
            Log.w("PrintService", "Read cart from the file newKot: $newKot")
            if (existingKot.toString() == newKot.toString()) {
                isDuplicate = true
                break
            }
        }

        if (isDuplicate) {
            Log.w("PrintService", "Duplicate KOT skipped: $rawJson")
            return
        }

        // Save only unique KOT
        jsonArray.put(newKot)
        Log.w("PrintService", "save cart in pending_kot file: ${jsonArray.toString()}")
        file.writeText(jsonArray.toString())

        Log.d("PrintService", "KOT saved: $rawJson")

    } catch (e: Exception) {
        Log.e("PrintService", "Error saving KOT: ${e.message}")
    }
}






fun saveSettleToFile(rawJson: String) {
    try {
        val file = File(filesDir, "pending_settle.json")  // internal storage

        // Read existing data
        val existingJson = if (file.exists()) file.readText() else "[]"
        val jsonArray = JSONArray(existingJson)

        // Parse incoming message
val tableNo = if (rawJson.startsWith("settle-")) {
    rawJson.removePrefix("settle-").trim()
} else {
    null
}

// Validate: tableNo must be a number

val numericTableNo = tableNo?.toIntOrNull()
if (numericTableNo == null) {
    Log.d("PrintService", "Not required to store in settle as order entered through cashier")
    return   // ← return Unit (OK)
}


        if (tableNo != null) {
            // Check if this table already exists
            var found = false
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                if (obj.optString("tableNo") == tableNo) {
                    found = true
                    break
                }
            }

            if (!found) {
                // Save new settle entry
                val settleEntry = JSONObject()
                settleEntry.put("tableNo", tableNo)
                settleEntry.put("timestamp", System.currentTimeMillis())
                jsonArray.put(settleEntry)
                file.writeText(jsonArray.toString())
                Log.d("PrintService", "✅ Saved settle table $tableNo to pending_settle.json")
            } else {
                Log.d("PrintService", "⚠️ Table $tableNo already exists in pending_settle.json")
            }
        } else {
            Log.d("PrintService", "⚠️ Not a settle message: $rawJson")
        }

    } catch (e: Exception) {
        Log.e("PrintService", "❌ Failed to save settle: ${e.message}")
    }
}


    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Bluetooth Print Service",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }


 fun wrapWords(text: String, maxWidth: Int): List<String> {
    val words = text.split(" ")
    val lines = mutableListOf<String>()
    var currentLine = ""

    for (word in words) {
        if (word.length > maxWidth) {
            // Word too long, hard-wrap but keep readable
            if (currentLine.isNotEmpty()) {
                lines.add(currentLine)
                currentLine = ""
            }
            var start = 0
            while (start < word.length) {
                val end = minOf(start + maxWidth, word.length)
                lines.add(word.substring(start, end))
                start = end
            }
        } else if ((currentLine + word).length + 1 <= maxWidth) {
            currentLine += if (currentLine.isEmpty()) word else " $word"
        } else {
            lines.add(currentLine)
            currentLine = word
        }
    }

    if (currentLine.isNotEmpty()) lines.add(currentLine)

    return lines
}


    private fun generateBillFromJson(printData: String, total: Double): String {
        val sb = StringBuilder()
        val lineWidth = 36

        fun boldOn() = sb.append("\u001B\u0045\u0001")
        fun boldOff() = sb.append("\u001B\u0045\u0000")
        fun center() = sb.append("\u001B\u0061\u0001")
        fun left() = sb.append("\u001B\u0061\u0000")

        fun addLine(text: String) {
            left()
            if (text.length <= lineWidth) {
                sb.append(text.padEnd(lineWidth)).append("\n")
            } else {
                var start = 0
                while (start < text.length) {
                    val end = minOf(start + lineWidth, text.length)
                    sb.append(text.substring(start, end)).append("\n")
                    start = end
                }
            }
        }

        val items = JSONArray(printData)
        val item = items.getJSONObject(0)
        val captain_name = item.getString("captain_name")
        val Table_No = item.getString("tableno")

        
        // ==========================
        // HEADER
        // ==========================
        center()
        boldOn()
        sb.append("KOT\n")
        boldOff()

        center()
        sb.append("==============\n")
        left()


        addLine("captain Name : $captain_name")
        addLine("Table No : $Table_No")
        val kotDateTime = SimpleDateFormat("dd/MM/yyyy hh:mm a", Locale.getDefault()).format(Date())
        addLine("KOT Time : $kotDateTime")
        addLine("--------------------------------")

        // COLUMN HEADER
        boldOn()
        addLine("Item               Note     Qty")
        boldOff()
        addLine("--------------------------------")

        // ==========================
        // ITEMS
        // ==========================

        try {
            val items = JSONArray(printData)

            val nameWidth = 30
            val noteWidth = 4
            val qtyWidth = 4

            for (i in 0 until items.length()) {
                val item = items.getJSONObject(i)

                val name = item.getString("name")
                val qty = item.getInt("qty")
                val note = if (item.has("note")) item.getString("note") else ""

                val qtyStr = qty.toString().padStart(qtyWidth, ' ')

                val wrappedName = wrapWords(name, nameWidth)
                val wrappedNote = wrapWords(note, noteWidth)

                val maxLines = maxOf(wrappedName.size, wrappedNote.size)

                for (lineIndex in 0 until maxLines) {
                    val namePart =
                        if (lineIndex < wrappedName.size)
                            wrappedName[lineIndex].padEnd(nameWidth)
                        else
                            " ".repeat(nameWidth)

                    val notePart =
                        if (lineIndex < wrappedNote.size)
                            wrappedNote[lineIndex].padEnd(noteWidth)
                        else
                            " ".repeat(noteWidth)

                    val qtyPart =
                        if (lineIndex == maxLines - 1)
                            qtyStr
                        else
                            " ".repeat(qtyWidth)

                    addLine(namePart + notePart + qtyPart)
                }
            }

        } catch (e: Exception) {
            addLine("Invalid print data")
        }

        addLine("--------------------------------")
        addLine(".")
        addLine(".")
        return sb.toString()
    }

    private fun printViaBluetooth(text: String) {
        try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            if (adapter == null || !adapter.isEnabled) {
                Log.e("PrintService", "Bluetooth not available or not enabled!")
                return
            }

           val printerMac = getPrinterMacFromJson()
            if (printerMac == null) {
                Log.e("PrintService", "Printer MAC not found in JSON!")
                return
            }

           

            val device = adapter.getRemoteDevice(printerMac)
            val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
            Log.d("PrintService", "uuid: $uuid")
            val socket = device.createRfcommSocketToServiceRecord(uuid)

            adapter.cancelDiscovery()
            Log.d("PrintService", "Connecting to printer: ${uuid} ${device.name} ${device.address} ${device.uuids}")
            socket.connect()
            Log.d("PrintService", "Connected!")

            val output: OutputStream = socket.outputStream
            output.write(text.toByteArray(Charsets.UTF_8))
            output.flush()
            socket.close()

            Log.d("PrintService", "Printed successfully:\n$text")
        } catch (e: Exception) {
            Log.e("PrintService", "Bluetooth print failed: ${e.message}")
            e.printStackTrace()
        }
    }


    private fun getPrinterMacFromJson(): String? {
        return try {
            val file = File(filesDir, "printer.json")   // <-- Yes, this is correct
            if (!file.exists()) {
                Log.e("PrintService", "JSON file not found!")
                return null
            }

            val jsonString = file.readText()
            val jsonObject = JSONObject(jsonString)

            jsonObject.optString("printerAddress", null)   // Replace key name as needed
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }


    private fun saveTransactionLocally(transactionJson: JSONObject) {
        try {
        
            val file = File(filesDir, "pending_transactions.json")
            Log.d("PrintService", "📁 File path: ${file.absolutePath}")
            val existing = if (file.exists()) file.readText() else "[]"
            val jsonArray = JSONArray(existing)
            jsonArray.put(transactionJson)
            file.writeText(jsonArray.toString())
    
            Log.d("PrintService", "Transaction saved to file: $transactionJson")
        } catch (e: Exception) {
            Log.e("PrintService", "Failed to save transaction to file: ${e.message}")
        }
    }
    
    
}
