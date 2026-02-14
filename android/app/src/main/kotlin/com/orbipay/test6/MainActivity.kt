package com.orbipay.test6

import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.ArrayList

// Add these Bluetooth imports:
import android.bluetooth.BluetoothSocket
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothAdapter

import BpPrinter.mylibrary.BluetoothConnectivity
import BpPrinter.mylibrary.BpPrinter
import BpPrinter.mylibrary.CardReader
import BpPrinter.mylibrary.CardScanner
import BpPrinter.mylibrary.Scrybe

class MainActivity : FlutterActivity(), Scrybe, CardScanner {
    
    private val CHANNEL = "com.orbipay.test6/printer"
    private lateinit var bluetoothConn: BluetoothConnectivity
    private var printer: BpPrinter? = null
    private var socket: BluetoothSocket? = null
    
    companion object {
        private const val TAG = "MainActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity created")
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "Configuring Flutter engine")

        try {
            // 'this' implements Scrybe interface
            bluetoothConn = BluetoothConnectivity(this)
            Log.d(TAG, "bluetoothConn $bluetoothConn ")
            // Don't create printer here - it will be created after connection
            Log.d(TAG, "BluetoothConnectivity initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing BluetoothConnectivity", e)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "Method call received: ${call.method}")
            
            when (call.method) {
                // ==================== CONNECTION METHODS ====================
                "getPairedPrinters" -> {
                    try {
                        val printers = bluetoothConn.getPairedPrinters() as? ArrayList<String>
                        Log.d(TAG, "Found ${printers?.size ?: 0} paired printers")
                        result.success(printers ?: arrayListOf<String>())
                    } catch (e: Exception) {
                        Log.e(TAG, "Get paired printers error", e)
                        result.error("PRINTER_ERROR", "Failed to get printers", e.message)
                    }
                }

                "connectToPrinterUsingMac" -> {
                    try {
                        val macAddress = call.argument<String>("macAddress")
                        if (macAddress != null) {
                            Log.d(TAG, "Connecting to MAC: $macAddress  $bluetoothConn")
                            val success = bluetoothConn.connectToPrinterusingMac(macAddress)
                            Log.d(TAG, "Connect using MAC result: $success")
                            if (success) {
                                printer = bluetoothConn.getAemPrinter()
                                Log.d(TAG, "printer $printer")
                                Log.d(TAG, "Printer object obtained: ${printer != null}")
                                initialize()
                            }
                            result.success(success)
                        } else {
                            Log.w(TAG, "MAC address is null")
                            result.error("INVALID_ARG", "macAddress is null", null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Connect using MAC error", e)
                        result.error("CONNECTION_ERROR", "Failed to connect using MAC: ${e.message}", null)
                    }
                }

                "Initialize_Printer" -> {
                    val currentPrinter = printer
                    try {
                        if (currentPrinter != null) {
                            currentPrinter.Initialize_Printer()
                            Log.d(TAG, "Printer Reset sucsessfully")
                            result.success(true)
                        } else {
                            Log.d(TAG, "Printer Fail To Reset")
                            result.error("INVALID_ARG", "currentPrinter is $currentPrinter", null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Connect using MAC error", e)
                        result.error("CONNECTION_ERROR", "Failed to connect using MAC: ${e.message}", null)
                    }
                }

                "isPrinterConnected" -> {
                    try {
                        val isConnected = bluetoothConn.isPrinterConnectedFlag()
                        val hasPrinterObject = printer != null

                        if(isConnected && hasPrinterObject){
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("STATUS_ERROR", e.message, null)
                    }
                }
                
                "disconnectPrinter" -> {
                    try {
                        Log.d(TAG, "Disconnecting printer...")
                        
                        // 1. First check if we have an active connection
                        val wasConnected = bluetoothConn.isPrinterConnectedFlag()
                        Log.d(TAG, "Was connected before disconnect: $wasConnected")
                        
                        // 2. Try to disconnect using the library method
                        var disconnectSuccess = false
                        try {
                            disconnectSuccess = bluetoothConn.disConnectPrinter()
                            Log.d(TAG, "Library disconnect result: $disconnectSuccess")
                        } catch (e: IOException) {
                            Log.w(TAG, "Library disconnect threw IOException (may be normal): ${e.message}")
                            disconnectSuccess = true // If we get an exception, connection was likely already closed
                        } catch (e: Exception) {
                            Log.e(TAG, "Library disconnect error", e)
                        }
                        
                        // 3. Clear printer object
                        printer = null
                        Log.d(TAG, "Printer object cleared")
                        
                        // 4. Check if actually disconnected
                        val isNowConnected = bluetoothConn.isPrinterConnectedFlag()
                        Log.d(TAG, "Is connected after disconnect attempt: $isNowConnected")
                        
                        // Return success even if library method fails, as long as connection is gone
                        val finalSuccess = !isNowConnected || disconnectSuccess
                        result.success(finalSuccess)
                        
                    } catch (e: Exception) {
                        Log.e(TAG, "Disconnect printer error", e)
                        // Even if error occurs, clear the printer object
                        printer = null
                        result.error("DISCONNECT_ERROR", "Failed to disconnect: ${e.message}", null)
                    }
                }
                // ==================== IMAGE PRINTING ====================
                "printImage" -> {
                    try {
                        val imageBytes = call.argument<ByteArray>("imageBytes")
                        val paperSize = call.argument<Int>("paperSize") ?: 0 // 0=2-inch, 1=3-inch
                        val currentPrinter = printer // Use local variable
                        
                        
                        if (currentPrinter != null && imageBytes != null) {
                            // Convert byte array to Bitmap
                            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)

                            Log.d(TAG, "Print image result: $currentPrinter, paper size: ${currentPrinter}")
                            Log.d(TAG, "Print image result: $bitmap, paper size: ${bitmap.byteCount}")
                            
                            // Call the printImage method from BpPrinter
                            val success = currentPrinter.printImage(bitmap, paperSize)
                            
                            Log.d(TAG, "Print image result: , paper size: $paperSize")
                            result.success(true)
                        } else {
                            val errorMsg = if (currentPrinter == null) "Printer not connected" else "Image bytes is null"
                            Log.w(TAG, errorMsg)
                            result.error("PRINT_ERROR", errorMsg, null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Print image error", e)
                        result.error("PRINT_ERROR", "Failed to print image: ${e.message}", null)
                    }
                }
                
                "print" -> {
                    try {
                        // 1. Extract the byte array from Flutter
                        // In Kotlin, Flutter's Uint8List comes in as a ByteArray
                        val bytes = call.argument<ByteArray>("bytes")
                        
                        if (bytes != null) {
                            // result.error("INVALID_ARGUMENT", "Bytes cannot be null", null)
                            // return@let
                        // }

                        val currentPrinter = printer
                        
                        // Optional: Debugging the socket state via reflection
                        if (currentPrinter != null) {
                            try {
                                val bluetoothSocketField = currentPrinter.javaClass.getDeclaredField("bluetoothSocket")
                                bluetoothSocketField.isAccessible = true
                                val socket = bluetoothSocketField.get(currentPrinter) as? BluetoothSocket
                                
                                val status = mapOf(
                                    "socketExists" to (socket != null),
                                    "socketConnected" to (socket?.isConnected ?: false),
                                    "device" to (socket?.remoteDevice?.name ?: "Unknown")
                                )
                                Log.d(TAG, "Printer Object Status: $status")
                            } catch (e: Exception) {
                                Log.e(TAG, "Reflection failed", e)
                            }
                        }

                        if (bluetoothConn != null) {
                            try {
                                val bluetoothSocketField = bluetoothConn.javaClass.getDeclaredField("bluetoothSocket")
                                bluetoothSocketField.isAccessible = true
                                val socket = bluetoothSocketField.get(bluetoothConn) as? BluetoothSocket
                                
                                val status = mapOf(
                                    "bluetoothConn socketExists" to (socket != null),
                                    "bluetoothConn socketConnected" to (socket?.isConnected ?: false),
                                    "bluetoothConn device" to (socket?.remoteDevice?.name ?: "Unknown")
                                )
                                Log.d(TAG, "Printer Object Status: $status")
                            } catch (e: Exception) {
                                Log.e(TAG, "Reflection failed", e)
                            }
                        }
                        
                        // 2. Direct Bluetooth Write
                        // We use the 'bytes' received from Flutter directly
                        val success = bluetoothConn.writeToBluetooth(bytes)
                        
                        if (success) {
                            Log.d(TAG, "Bytes sent successfully to printer. Length: ${bytes.size}")
                            result.success(true)
                        } else {
                            Log.e(TAG, "Direct Bluetooth write failed")
                            result.error("PRINTER_ERROR", "Bluetooth write failed", null)
                        }
                        }

                    } catch (e: Exception) {
                        Log.e(TAG, "Print error", e)
                        result.error("PRINT_ERROR", e.message, null)
                    }
                }

                
                else -> {
                    Log.w(TAG, "Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }
    
    // ======================== Scrybe Interface ========================
    override fun onUsbConnected() {
        Log.d(TAG, "USB Printer connected")
    }
    
    override fun onDiscoveryComplete(printerList: ArrayList<String>?) {
        Log.d(TAG, "Discovery complete: ${printerList?.size ?: 0} devices found")
    }
    
    // ======================== CardScanner Interface ========================
    override fun onScanMSR(trackData: String?, track: CardReader.CARD_TRACK?) {
        Log.d(TAG, "MSR Scan: $trackData, Track: $track")
    }
    
    override fun onScanDLCard(data: String?) {
        Log.d(TAG, "DL Card Scan: $data")
    }
    
    override fun onScanRCCard(data: String?) {
        Log.d(TAG, "RC Card Scan: $data")
    }
    
    override fun onScanRFD(data: String?) {
        Log.d(TAG, "RFD Scan: $data")
    }
    
    override fun onScanPacket(data: String?) {
        Log.d(TAG, "Packet Scan: $data")
    }
    
    override fun onScanFwUpdateRespPacket(bytes: ByteArray?) {
        Log.d(TAG, "FW Update Response: ${bytes?.size ?: 0} bytes")
    }

    private fun initialize() {
        try {
            // 1. Get printer from BluetoothConnectivity
            printer = bluetoothConn.getAemPrinter()
            
            if (printer == null) {
                Log.e(TAG, "Failed to get printer from BluetoothConnectivity")
                return
            }
            
            // 2. Get the socket from BluetoothConnectivity using reflection
            val socketField = bluetoothConn.javaClass.getDeclaredField("bluetoothSocket")
            socketField.isAccessible = true
            socket = socketField.get(bluetoothConn) as? BluetoothSocket
            
            if (socket == null) {
                Log.w(TAG, "BluetoothSocket is null in BluetoothConnectivity")
                return
            }
            
            // 3. Set the socket in BpPrinter using reflection
            val printerSocketField = printer!!.javaClass.getDeclaredField("bluetoothSocket")
            printerSocketField.isAccessible = true
            printerSocketField.set(printer, socket)
            
            Log.d(TAG, "BpPrinterWrapper initialized successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize BpPrinterWrapper: ${e.message}")
        }
    }
}