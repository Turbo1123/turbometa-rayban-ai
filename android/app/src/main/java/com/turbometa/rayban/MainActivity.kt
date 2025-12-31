package com.turbometa.rayban

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionStatus
import com.turbometa.rayban.managers.LanguageManager
import com.turbometa.rayban.ui.navigation.TurboMetaNavigation
import com.turbometa.rayban.ui.theme.TurboMetaTheme
import com.turbometa.rayban.viewmodels.WearablesViewModel
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class MainActivity : AppCompatActivity() {

    companion object {
        // Required Android permissions for the DAT SDK
        val PERMISSIONS: Array<String> = arrayOf(
            Manifest.permission.BLUETOOTH,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.INTERNET,
            Manifest.permission.RECORD_AUDIO
        )
    }

    val wearablesViewModel: WearablesViewModel by viewModels()

    private var permissionContinuation: CancellableContinuation<PermissionStatus>? = null
    private val permissionMutex = Mutex()
    private var sdkInitialized = false

    // Android permissions launcher - must be registered at creation time
    private val androidPermissionsLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissionsResult ->
        val granted = permissionsResult.entries.all { it.value }
        if (granted) {
            initializeSDK()
        } else {
            wearablesViewModel.setError(getString(R.string.permission_all_required))
        }
    }

    // Requesting wearable device permissions via the Meta AI app
    private val wearablesPermissionLauncher = registerForActivityResult(
        Wearables.RequestPermissionContract()
    ) { result ->
        val permissionStatus = result.getOrDefault(PermissionStatus.Denied)
        permissionContinuation?.resume(permissionStatus)
        permissionContinuation = null
    }

    // Request wearables permission in a sequential manner
    suspend fun requestWearablesPermission(permission: Permission): PermissionStatus {
        return permissionMutex.withLock {
            suspendCancellableCoroutine { continuation ->
                permissionContinuation = continuation
                continuation.invokeOnCancellation { permissionContinuation = null }
                wearablesPermissionLauncher.launch(permission)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Initialize Language Manager (for app language switching)
        LanguageManager.init(this)

        // Check and request permissions
        checkAndRequestPermissions()

        setContent {
            TurboMetaTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    TurboMetaNavigation(
                        wearablesViewModel = wearablesViewModel,
                        onRequestWearablesPermission = ::requestWearablesPermission
                    )
                }
            }
        }
    }

    private fun checkAndRequestPermissions() {
        val permissionsToRequest = PERMISSIONS.filter { permission ->
            ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
        }.toTypedArray()

        if (permissionsToRequest.isEmpty()) {
            // All permissions already granted
            initializeSDK()
        } else {
            // Request missing permissions
            androidPermissionsLauncher.launch(permissionsToRequest)
        }
    }

    private fun initializeSDK() {
        if (sdkInitialized) return
        sdkInitialized = true

        // Initialize the DAT SDK - REQUIRED before using any Wearables APIs
        Wearables.initialize(this)

        // Start observing Wearables state after SDK is initialized
        wearablesViewModel.startMonitoring()
    }
}
