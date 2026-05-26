package com.example.password_manager

import android.app.AlertDialog
import android.content.pm.PackageManager
import android.hardware.fingerprint.FingerprintManager
import android.os.Build
import android.os.CancellationSignal
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterFragmentActivity() {
    private val biometricChannel = "password_manager/device_biometrics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, biometricChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBiometricSupport" -> result.success(getBiometricSupport())
                    "authenticateFingerprint" -> authenticateFingerprint(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun getBiometricSupport(): Map<String, Any> {
        val packageManager = packageManager
        val hasFingerprintHardware = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT) ||
                hasFingerprintHardwareFromSystemService()
        } else {
            false
        }
        val hasBiometricHardware = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            packageManager.hasSystemFeature("android.hardware.biometrics")
        } else {
            hasFingerprintHardware
        }
        return mapOf(
            "platform" to "android",
            "sdkInt" to Build.VERSION.SDK_INT,
            "hasFingerprintHardware" to hasFingerprintHardware,
            "hasBiometricHardware" to hasBiometricHardware,
            "hasEnrolledBiometrics" to hasEnrolledBiometrics(),
            "biometricAuthStatus" to biometricAuthStatus(),
        )
    }

    @Suppress("DEPRECATION")
    private fun hasFingerprintHardwareFromSystemService(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false
        }
        val fingerprintManager = getSystemService(FingerprintManager::class.java)
        return fingerprintManager?.isHardwareDetected == true
    }

    @Suppress("DEPRECATION")
    private fun hasEnrolledBiometrics(): Boolean {
        if (biometricAuthStatus() == BiometricManager.BIOMETRIC_SUCCESS) {
            return true
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false
        }
        return try {
            val fingerprintManager = getSystemService(FingerprintManager::class.java)
            fingerprintManager?.hasEnrolledFingerprints() == true
        } catch (_: SecurityException) {
            false
        }
    }

    private fun biometricAuthStatus(): Int {
        return BiometricManager.from(this)
            .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK)
    }

    private fun authenticateFingerprint(result: MethodChannel.Result) {
        if (biometricAuthStatus() != BiometricManager.BIOMETRIC_SUCCESS) {
            authenticateWithLegacyFingerprint(result)
            return
        }

        val completed = AtomicBoolean(false)
        val executor = ContextCompat.getMainExecutor(this)
        val prompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    authenticationResult: BiometricPrompt.AuthenticationResult
                ) {
                    if (completed.compareAndSet(false, true)) {
                        result.success(true)
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    if (completed.compareAndSet(false, true)) {
                        if (
                            errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON ||
                                errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                                errorCode == BiometricPrompt.ERROR_CANCELED
                        ) {
                            result.success(false)
                        } else if (
                            errorCode == BiometricPrompt.ERROR_HW_NOT_PRESENT &&
                                canUseLegacyFingerprint()
                        ) {
                            authenticateWithLegacyFingerprint(result)
                        } else {
                            result.error(errorCode.toString(), errString.toString(), null)
                        }
                    }
                }
            },
        )
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock vault")
            .setDescription("Use fingerprint to unlock your vault.")
            .setNegativeButtonText("Cancel")
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_WEAK or
                    BiometricManager.Authenticators.BIOMETRIC_STRONG,
            )
            .build()

        prompt.authenticate(promptInfo)
    }

    @Suppress("DEPRECATION")
    private fun canUseLegacyFingerprint(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false
        }
        val fingerprintManager = getSystemService(FingerprintManager::class.java)
        return try {
            fingerprintManager?.isHardwareDetected == true &&
                fingerprintManager.hasEnrolledFingerprints()
        } catch (_: SecurityException) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun authenticateWithLegacyFingerprint(result: MethodChannel.Result) {
        if (!canUseLegacyFingerprint()) {
            result.error(
                "NO_FINGERPRINT",
                "Fingerprint sensor is not ready. Check Android fingerprint settings.",
                null,
            )
            return
        }

        val completed = AtomicBoolean(false)
        val cancellationSignal = CancellationSignal()
        val dialog = AlertDialog.Builder(this)
            .setTitle("Unlock vault")
            .setMessage("Touch the fingerprint sensor.")
            .setNegativeButton("Cancel") { _, _ ->
                cancellationSignal.cancel()
                if (completed.compareAndSet(false, true)) {
                    result.success(false)
                }
            }
            .setOnCancelListener {
                cancellationSignal.cancel()
                if (completed.compareAndSet(false, true)) {
                    result.success(false)
                }
            }
            .create()

        val fingerprintManager = getSystemService(FingerprintManager::class.java)
        fingerprintManager.authenticate(
            null,
            cancellationSignal,
            0,
            object : FingerprintManager.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    authenticationResult: FingerprintManager.AuthenticationResult
                ) {
                    dialog.dismiss()
                    if (completed.compareAndSet(false, true)) {
                        result.success(true)
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    dialog.dismiss()
                    if (completed.compareAndSet(false, true)) {
                        if (cancellationSignal.isCanceled) {
                            result.success(false)
                        } else {
                            result.error(errorCode.toString(), errString.toString(), null)
                        }
                    }
                }

                override fun onAuthenticationFailed() {
                    dialog.setMessage("Fingerprint not recognized. Try again.")
                }
            },
            null,
        )
        dialog.show()
    }
}
