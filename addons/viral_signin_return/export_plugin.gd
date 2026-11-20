@tool
extends EditorPlugin

## Google / Facebook sign-in, way back (owner 2026-11-20: "do the FB login option", easy to use).
## The sign-in finishes in the browser on docs/auth-callback.html, which copies a one-time code;
## the app picks it up from the clipboard when it comes back to the front (account_screen.gd).
## This adds an exported activity-alias that a "Return to the app" link
## (viralgaminghub://signin) can open, so the player doesn't have to find the app by hand.
## The link only brings the app forward: nothing in it is read. Gradle builds only (the Play
## AAB); the plain APK has no such alias and the page falls back to "switch back to the app".

var export_plugin: SigninReturnExportPlugin

func _enter_tree() -> void:
	export_plugin = SigninReturnExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null

class SigninReturnExportPlugin extends EditorExportPlugin:
	const SCHEME := "viralgaminghub"
	const HOST := "signin"

	func _supports_platform(platform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_manifest_application_element_contents(platform, debug) -> String:
		return """
        <activity-alias
            android:name=".SigninReturn"
            android:targetActivity=".GodotApp"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="%s" android:host="%s" />
            </intent-filter>
        </activity-alias>
""" % [SCHEME, HOST]

	func _get_name() -> String:
		return "ViralSigninReturn"
