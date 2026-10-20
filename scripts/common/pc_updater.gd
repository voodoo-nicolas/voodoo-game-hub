class_name PcUpdater
extends Node
## In-app updater for the Windows build (the Android build opens the APK).
##
## The PC build is Voodoo.exe + Voodoo.pck (every game bundled), and a release
## only changes the .pck. So: download the release's `voodoo-pc-v*.pck` next to
## the running one as `<name>.pck.new`, check it, then start a hidden PowerShell
## that waits for this process to exit (Windows won't replace an open .pck),
## keeps the old one as `<name>.pck.bak`, moves the new one in and relaunches.
## Works for Voodoo.exe and Voodoo-older-PCs.exe alike: the target is whatever
## .pck sits beside the running exe. Called only on Windows exports.
##
## Usage: add_child(PcUpdater.new()); updater.start(url); poll progress() and
## connect `failed(message)`. On success the app quits itself and restarts.

const Config = preload("res://scripts/common/config.gd")

signal failed(message: String)

var _http: HTTPRequest
var _new_path := ""

## True for the Windows export (not the editor), where `OS.shell_open(apk)`
## would be useless. Release assets for it are `voodoo-pc-v*.pck`.
static func is_supported() -> bool:
	return OS.get_name() == "Windows" and not OS.has_feature("editor")

static func target_pck() -> String:
	return OS.get_executable_path().get_basename() + ".pck"

## 0..1 while downloading, -1 when the size isn't known yet.
func progress() -> float:
	if _http == null or not is_instance_valid(_http):
		return -1.0
	var total := _http.get_body_size()
	return float(_http.get_downloaded_bytes()) / float(total) if total > 0 else -1.0

## The running download, so a screen can poll its progress bar.
func get_http() -> HTTPRequest:
	return _http

func start(url: String) -> void:
	_new_path = target_pck() + ".new"
	_http = HTTPRequest.new()
	_http.download_file = _new_path
	_http.timeout = Config.DOWNLOAD_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_completed)
	if _http.request(url) != OK:
		_fail(tr("Download failed. Check your connection and try again."))

func cancel() -> void:
	if _http and is_instance_valid(_http):
		_http.cancel_request()
	DirAccess.remove_absolute(_new_path)
	queue_free()

func _on_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_TIMEOUT:
		_fail(tr("The download timed out. Check your connection and try again."))
	elif result == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN or result == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
		_fail(tr("Couldn't save the download. Check your free space."))
	elif result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail(tr("Download failed. Check your connection and try again."))
	elif not _looks_like_pack(_new_path):
		_fail(tr("The download was damaged. Please try again."))
	else:
		_swap_and_restart()

func _swap_and_restart() -> void:
	var exe := OS.get_executable_path()
	var pck := target_pck()
	var script := "$e='%s';$p='%s';$n='%s';" % [_q(exe), _q(pck), _q(_new_path)]
	# Wait (up to ~60 s) for this process to release the .pck, then swap.
	script += "for($i=0;$i -lt 60;$i++){try{Copy-Item -LiteralPath $p -Destination ($p+'.bak') -Force -ErrorAction Stop;"
	script += "Move-Item -LiteralPath $n -Destination $p -Force -ErrorAction Stop;break}catch{Start-Sleep 1}};"
	script += "Start-Process -FilePath $e -WorkingDirectory (Split-Path $e)"
	var pid := OS.create_process("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-Command", script])
	if pid <= 0:
		_fail(tr("Couldn't start the update. Please try again."))
		return
	get_tree().quit()

func _fail(message: String) -> void:
	DirAccess.remove_absolute(_new_path)
	failed.emit(message)

## A single quote inside a PowerShell single-quoted string is doubled.
static func _q(s: String) -> String:
	return s.replace("'", "''")

static func _looks_like_pack(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	return f != null and f.get_length() > 1024 * 1024 and f.get_buffer(4).get_string_from_ascii() == "GDPC"
