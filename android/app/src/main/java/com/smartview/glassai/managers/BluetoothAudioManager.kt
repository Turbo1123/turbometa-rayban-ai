package com.smartview.glassai.managers

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 蓝牙音频管理器
 * 管理 HFP (Hands-Free Profile) 蓝牙麦克风连接
 * 用于 Ray-Ban Meta 眼镜的远程语音输入
 */
class BluetoothAudioManager(private val context: Context) {

    companion object {
        private const val TAG = "BluetoothAudioManager"
    }

    /**
     * 音频源枚举
     */
    enum class AudioSource {
        PHONE_MIC,      // 手机麦克风
        BLUETOOTH_MIC   // 蓝牙麦克风 (HFP)
    }

    private val audioManager: AudioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val bluetoothManager: BluetoothManager? = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager?.adapter

    private var bluetoothHeadset: BluetoothHeadset? = null
    private var isBluetoothScoOn = false

    private val _currentAudioSource = MutableStateFlow(AudioSource.PHONE_MIC)
    val currentAudioSource: StateFlow<AudioSource> = _currentAudioSource.asStateFlow()

    private val _isBluetoothAvailable = MutableStateFlow(false)
    val isBluetoothAvailable: StateFlow<Boolean> = _isBluetoothAvailable.asStateFlow()

    private val _isBluetoothScoConnected = MutableStateFlow(false)
    val isBluetoothScoConnected: StateFlow<Boolean> = _isBluetoothScoConnected.asStateFlow()

    // 同时暴露为 StateFlow<Boolean> 用于 ViewModel
    val isBluetoothScoAvailable: StateFlow<Boolean>
        get() = _isBluetoothAvailable

    // 蓝牙 SCO 状态广播接收器
    private val scoReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val state = intent?.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1)
            Log.d(TAG, "SCO 状态变化: $state")
            when (state) {
                AudioManager.SCO_AUDIO_STATE_CONNECTED -> {
                    Log.d(TAG, "✅ SCO 已连接")
                    isBluetoothScoOn = true
                    _isBluetoothScoConnected.value = true
                    _currentAudioSource.value = AudioSource.BLUETOOTH_MIC
                }
                AudioManager.SCO_AUDIO_STATE_DISCONNECTED -> {
                    Log.d(TAG, "❌ SCO 已断开")
                    isBluetoothScoOn = false
                    _isBluetoothScoConnected.value = false
                    if (_currentAudioSource.value == AudioSource.BLUETOOTH_MIC) {
                        // 自动回退到手机麦克风
                        _currentAudioSource.value = AudioSource.PHONE_MIC
                        Log.d(TAG, "自动回退到手机麦克风")
                    }
                }
                AudioManager.SCO_AUDIO_STATE_CONNECTING -> {
                    Log.d(TAG, "⏳ SCO 连接中...")
                }
                AudioManager.SCO_AUDIO_STATE_ERROR -> {
                    Log.e(TAG, "❌ SCO 错误")
                    isBluetoothScoOn = false
                }
            }
        }
    }

    // 蓝牙 Headset Profile 服务监听器
    private val headsetProfileListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
            if (profile == BluetoothProfile.HEADSET) {
                bluetoothHeadset = proxy as? BluetoothHeadset
                updateBluetoothAvailability()
                Log.d(TAG, "Headset Profile 已连接")
            }
        }

        override fun onServiceDisconnected(profile: Int) {
            if (profile == BluetoothProfile.HEADSET) {
                bluetoothHeadset = null
                _isBluetoothAvailable.value = false
                Log.d(TAG, "Headset Profile 已断开")
            }
        }
    }

    init {
        // 注册 SCO 状态广播接收器
        val filter = IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(scoReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(scoReceiver, filter)
        }

        // 获取 Headset Profile 代理
        if (hasBluetoothPermission()) {
            bluetoothAdapter?.getProfileProxy(context, headsetProfileListener, BluetoothProfile.HEADSET)
        }

        updateBluetoothAvailability()
        Log.d(TAG, "BluetoothAudioManager 初始化完成")
    }

    /**
     * 检查是否有蓝牙权限
     */
    private fun hasBluetoothPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED
        }
    }

    /**
     * 更新蓝牙可用性状态
     */
    private fun updateBluetoothAvailability() {
        val isAvailable = try {
            if (!hasBluetoothPermission()) {
                false
            } else {
                val connectedDevices = bluetoothHeadset?.connectedDevices ?: emptyList()
                connectedDevices.isNotEmpty()
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "蓝牙权限错误: ${e.message}")
            false
        }
        _isBluetoothAvailable.value = isAvailable
        Log.d(TAG, "蓝牙可用性: $isAvailable")
    }

    /**
     * 检查蓝牙 SCO 是否可用
     */
    fun isBluetoothScoAvailable(): Boolean {
        return _isBluetoothAvailable.value && audioManager.isBluetoothScoAvailableOffCall
    }

    /**
     * 切换音频源
     * @param source 目标音频源
     */
    fun switchAudioSource(source: AudioSource) {
        if (_currentAudioSource.value == source) {
            Log.d(TAG, "音频源已经是: $source")
            return
        }

        when (source) {
            AudioSource.BLUETOOTH_MIC -> {
                if (isBluetoothScoAvailable()) {
                    startBluetoothSco()
                } else {
                    Log.w(TAG, "蓝牙 SCO 不可用，保持当前音频源")
                }
            }
            AudioSource.PHONE_MIC -> {
                stopBluetoothSco()
                _currentAudioSource.value = AudioSource.PHONE_MIC
            }
        }
    }

    /**
     * 启动蓝牙 SCO 连接
     */
    fun startBluetoothSco() {
        if (isBluetoothScoOn) {
            Log.d(TAG, "蓝牙 SCO 已经开启")
            return
        }

        try {
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            audioManager.startBluetoothSco()
            audioManager.isBluetoothScoOn = true
            Log.d(TAG, "启动蓝牙 SCO")
        } catch (e: Exception) {
            Log.e(TAG, "启动蓝牙 SCO 失败: ${e.message}")
        }
    }

    /**
     * 停止蓝牙 SCO 连接
     */
    fun stopBluetoothSco() {
        if (!isBluetoothScoOn) {
            Log.d(TAG, "蓝牙 SCO 未开启")
            return
        }

        try {
            audioManager.isBluetoothScoOn = false
            audioManager.stopBluetoothSco()
            audioManager.mode = AudioManager.MODE_NORMAL
            isBluetoothScoOn = false
            Log.d(TAG, "停止蓝牙 SCO")
        } catch (e: Exception) {
            Log.e(TAG, "停止蓝牙 SCO 失败: ${e.message}")
        }
    }

    /**
     * 清理资源
     */
    fun cleanup() {
        try {
            stopBluetoothSco()
            context.unregisterReceiver(scoReceiver)
            bluetoothAdapter?.closeProfileProxy(BluetoothProfile.HEADSET, bluetoothHeadset)
            bluetoothHeadset = null
            Log.d(TAG, "BluetoothAudioManager 已清理")
        } catch (e: Exception) {
            Log.e(TAG, "清理失败: ${e.message}")
        }
    }
}
