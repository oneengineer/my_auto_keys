#Requires AutoHotkey v2.0
#SingleInstance Force
#Include findtext.ahk

; ============================================================
; Auto Cursor Runner - GUI Version (FindText Edition)
; ============================================================
; Auto-click Cursor IDE Run/Execute button with visual feedback
; Uses FindText library for robust image recognition
; ============================================================
;
; SETUP INSTRUCTIONS - How to capture the Run button pattern:
; ============================================================
; 1. Run this script or click "Capture Pattern" button in GUI
; 2. In FindText GUI, click "Capture" button
; 3. Use mouse to select the Run button area on screen
;    - First click: set center point
;    - Move mouse and second click: define range
; 4. In the capture window:
;    a. Select "Gray" tab (recommended for text)
;    b. Click "Gray2Two" button to convert to black/white
;    c. Adjust "Threshold" if needed (default usually works)
;    d. Click "Auto" to trim edges automatically
;    e. Click "OK" to generate the code
; 5. Copy the generated Text string (looks like: |<Run>*105$17.zzz...)
; 6. Paste it into the runButtonText variable below
;
; Alternative modes:
; - "Color" tab: for matching specific colors
; - "GrayDiff" tab: for edge detection
; - "MultiColor" tab: for multiple color points
; ============================================================

; ============================================================
; Request Admin Privileges (for global hotkeys to work)
; ============================================================
if !A_IsAdmin {
    try {
        Run '*RunAs "' A_ScriptFullPath '"'
        ExitApp
    } catch {
        MsgBox("Warning: Running without admin privileges.`nHotkeys may not work when other apps are focused.`n`nRight-click the script and select 'Run as administrator'.", "Auto Cursor Runner", "Icon!")
    }
}

; Global settings
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"

; ============================================================
; Configuration Variables
; ============================================================
global isRunning := false
global debugMode := true         ; Debug mode - show detailed info
global checkInterval := 2000     ; Check interval (ms)
global clickDelay := 1000        ; Delay after click (ms)
; 输入继续模式配置
global continueModeEnabled := false
global continueInputText := "继续"
global continueClickX := ""
global continueClickY := ""
global continueAfterClickDelayMs := 150
global stopCheckIntervalMs := 20000     ; “继续+回车”整体动作间隔
global lastStopCheckFound := false
global lastContinueInputTime := 0

; ============================================================
; Click Hint (Visual cue) Settings
; ============================================================
; 在"瞬移/点击"前后显示红色圆环闪烁提示
global clickHintEnabled := true
global clickHintDurationMs := 500        ; 每个位置闪烁时长 (ms)
global clickHintBlinkMs := 100           ; 闪烁间隔（越小闪得越快）
global clickHintDiameter := 40           ; 圆环外径（像素）
global clickHintThickness := 4           ; 圆环线宽（像素）
global clickHintAlpha := 220             ; 透明度 0-255（255 不透明）

; Path variables
global scriptDir := A_ScriptDir
global logFile := scriptDir "\auto_cursor_log.txt"

; ============================================================
; FindText Patterns - EDIT THESE AFTER CAPTURING
; ============================================================
; Generate patterns using: GUI "Capture Pattern" button OR run findtext.ahk directly
; After capturing, replace the PLACEHOLDER text below with your captured pattern
;
; Example pattern format: |<comment>*threshold$width.base64data
; Example: |<Run>*105$22.zzzzzzzzzzzzzzk1E3VU1E3zzzzzzzzzzzzzzzz
; ============================================================

; Run button pattern - REPLACE THIS WITH YOUR CAPTURED PATTERN
global runButtonText := "|<>*89$69.zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz00000000DzzU00000000Tzw000000003zz000000000Dzs000000001zz000000000Dzs000000001zz07k000000Dzs0X0000001zz048000000Dzs0VA9Q0001zz04FVAE000Dzs0wA920001zz04lV8E000Dzs0WA920001zz048X8E000Dzs0V4N20001zz044x8E000Dzs000000001zz000000000Dzs000000001zz000000000Dzw000000003zzU00000000Tzz00000000Dzzzzzzzzzzzzzzzzzzzzzzzzw"

; Resume button pattern (optional)
; This is a fallback target: when RUN is NOT found, the script will try this pattern and click it.
global resumeButtonText := "|<>**50$85.000000000000001zzzzzzzzzzzzy3U000000000001lU000000000000NU0000000000006U0000000000001E0000000000000c0000000000000I0000000000000+0TU000000000050AM00000000002U6A000000001U1E36D7Y9ysC0000c1W8aG4ta8U000I0yAP12Ml8M000+0N7wkVAEbw0M050AH0CEa8G00002U6BU18H49U0001E32E8aNW4F0/k0c1VbbVol2DU000I0000000000000+0000000000000500000000000002U0000000000001M0000000000001a0000000000001XU000000000001kTzzzzzzzzzzzzU00000000000001"

; Accept button pattern (optional)
; This is another fallback target: when RUN is NOT found, the script will try this pattern and click it.
global acceptButtonText := "|<>**50$87.000000000000000Dzzzzzzzzzzzzw70000000000000sk0000000000003A00000000000009000000000000008000000000000010000000000000080000000000000101U0000000000080C00000200000101E00000E000k080O3lswLbU1000102MkMAn6E0000080F4212Mm000001068UEDm2E0230080zY210EG000001044UE826E0000081Uq31WMX001S01086SD7WsA000008000000E0000001000000200000008000000E000000100000000000000A00000000000008k000000000000370000000000000w"

; Stop button pattern (waiting state)
; When STOP is visible, we consider it as waiting state and do NOT input "继续".
global stopButtonText := "|<>**50$31.03zs007kT00701k0600A0600306000k6000A3000630001VU7y0kk63UME20k48108240U4120E20V0810Ek41UMM31kAA0zk6300061U0030M0030600301U0300Q07007kT000zy04"



; Statistics tracking
global searchCount := 0
global clickCount := 0
global startTime := 0
global lastClickTime := "N/A"

; Monitor configuration
global monitorList := []         ; Array of monitor info objects
global selectedMonitor := 1      ; Selected monitor index (1-based)
global searchLeft := 0           ; Search area bounds
global searchTop := 0
global searchRight := 0
global searchBottom := 0

; GUI Controls (global references)
global guiObj := ""
global statusText := ""
global statsClicksText := ""
global statsSearchesText := ""
global statsRuntimeText := ""
global statsLastClickText := ""
global logListView := ""
global startBtn := ""
global stopBtn := ""
global intervalDropdown := ""
global delayDropdown := ""
global monitorDropdown := ""
global monitorInfoText := ""
global debugCheckbox := ""
global alwaysOnTopCheckbox := ""
global continueModeCheckbox := ""
global continuePosText := ""
global selectContinuePosBtn := ""
global imageStatusText := ""

; ============================================================
; Monitor Detection Functions
; ============================================================

; Get all monitor information
GetMonitorInfo() {
    global monitorList, selectedMonitor, searchLeft, searchTop, searchRight, searchBottom
    
    monitorList := []
    monitorCount := MonitorGetCount()
    primaryMonitor := MonitorGetPrimary()
    
    Loop monitorCount {
        MonitorGet(A_Index, &left, &top, &right, &bottom)
        width := right - left
        height := bottom - top
        isPrimary := (A_Index = primaryMonitor)
        
        monitorList.Push({
            index: A_Index,
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            width: width,
            height: height,
            isPrimary: isPrimary
        })
    }
    
    ; Also add "All Monitors" option using virtual screen
    virtualLeft := SysGet(76)    ; SM_XVIRTUALSCREEN
    virtualTop := SysGet(77)     ; SM_YVIRTUALSCREEN
    virtualWidth := SysGet(78)   ; SM_CXVIRTUALSCREEN
    virtualHeight := SysGet(79)  ; SM_CYVIRTUALSCREEN
    
    monitorList.Push({
        index: 0,
        left: virtualLeft,
        top: virtualTop,
        right: virtualLeft + virtualWidth,
        bottom: virtualTop + virtualHeight,
        width: virtualWidth,
        height: virtualHeight,
        isPrimary: false,
        isAll: true
    })
    
    ; Set initial search bounds to primary monitor
    UpdateSearchBounds(primaryMonitor)
    selectedMonitor := primaryMonitor
}

; Build dropdown list items for monitors
GetMonitorDropdownList() {
    global monitorList
    
    items := []
    for mon in monitorList {
        if mon.HasProp("isAll") && mon.isAll {
            items.Push("All Monitors (" mon.width "x" mon.height ")")
        } else {
            primaryTag := mon.isPrimary ? " *Primary*" : ""
            items.Push("Monitor " mon.index " (" mon.width "x" mon.height ")" primaryTag)
        }
    }
    return items
}

; Update search bounds based on selected monitor
UpdateSearchBounds(monitorIndex) {
    global monitorList, searchLeft, searchTop, searchRight, searchBottom
    
    ; If index is 0 or greater than count, use "All Monitors" (last item)
    if monitorIndex = 0 || monitorIndex > monitorList.Length - 1 {
        mon := monitorList[monitorList.Length]  ; Last item is "All Monitors"
    } else {
        mon := monitorList[monitorIndex]
    }
    
    searchLeft := mon.left
    searchTop := mon.top
    searchRight := mon.right
    searchBottom := mon.bottom
}

; Get monitor info string for display
GetMonitorInfoString(monitorIndex) {
    global monitorList
    
    if monitorIndex = 0 || monitorIndex > monitorList.Length - 1 {
        mon := monitorList[monitorList.Length]
        return "All: (" mon.left ", " mon.top ") to (" mon.right ", " mon.bottom ")"
    } else {
        mon := monitorList[monitorIndex]
        return "Bounds: (" mon.left ", " mon.top ") to (" mon.right ", " mon.bottom ")"
    }
}

; ============================================================
; Startup
; ============================================================

; First detect monitors
GetMonitorInfo()

WriteLog("========== Script Started ==========")
WriteLog("Script Path: " A_ScriptDir)
WriteLog("Using FindText library for image recognition")
WriteLog("Monitor Count: " (monitorList.Length - 1))  ; -1 for "All" option
WriteLog("Primary Monitor: " MonitorGetPrimary())
WriteLog("Running as Admin: " (A_IsAdmin ? "Yes" : "No"))

; Create and show GUI
CreateMainGUI()
guiObj.Show("w420 h670")
AddLogEntry("info", "Script started" (A_IsAdmin ? " [Admin]" : " [No Admin]"))
UpdateImageStatus()

; ============================================================
; Hotkey Definitions (Global hotkeys)
; ============================================================

; F9 - Toggle auto-click (global)
F9:: {
    ToggleAutoClick()
}

; (Only Start/Stop keep hotkeys; others removed)

; ============================================================
; GUI Creation Function
; ============================================================
CreateMainGUI() {
    global guiObj, statusText, statsClicksText, statsSearchesText
    global statsRuntimeText, statsLastClickText, logListView
    global startBtn, stopBtn, intervalDropdown, delayDropdown
    global monitorDropdown, monitorInfoText
    global debugCheckbox, alwaysOnTopCheckbox
    global continueModeCheckbox, continuePosText, selectContinuePosBtn
    global imageStatusText, checkInterval, clickDelay, debugMode, continueModeEnabled
    global selectedMonitor
    
    ; Create main window with AlwaysOnTop
    guiObj := Gui("+AlwaysOnTop", "Auto Cursor Runner" (A_IsAdmin ? " [Admin]" : ""))
    guiObj.BackColor := "F5F5F5"
    guiObj.SetFont("s10", "Segoe UI")
    guiObj.OnEvent("Close", OnGuiClose)
    
    ; ---- Status Section ----
    guiObj.SetFont("s11 bold")
    guiObj.Add("GroupBox", "x10 y10 w400 h50", "Status")
    guiObj.SetFont("s10 norm")
    statusText := guiObj.Add("Text", "x25 y32 w370 h20 cRed", "● STOPPED")
    
    ; ---- Statistics Section ----
    guiObj.SetFont("s11 bold")
    guiObj.Add("GroupBox", "x10 y70 w400 h100", "Statistics")
    guiObj.SetFont("s9 norm")
    
    guiObj.Add("Text", "x25 y95 w80", "Clicks:")
    statsClicksText := guiObj.Add("Text", "x110 y95 w80", "0")
    
    guiObj.Add("Text", "x200 y95 w80", "Searches:")
    statsSearchesText := guiObj.Add("Text", "x285 y95 w100", "0")
    
    guiObj.Add("Text", "x25 y120 w80", "Runtime:")
    statsRuntimeText := guiObj.Add("Text", "x110 y120 w100", "00:00:00")
    
    guiObj.Add("Text", "x200 y120 w80", "Last Click:")
    statsLastClickText := guiObj.Add("Text", "x285 y120 w120", "N/A")
    
    ; ---- Settings Section ----
    guiObj.SetFont("s11 bold")
    guiObj.Add("GroupBox", "x10 y180 w400 h170", "Settings")
    guiObj.SetFont("s9 norm")
    
    ; Monitor Selection
    guiObj.Add("Text", "x25 y205 w80", "Monitor:")
    monitorDropdown := guiObj.Add("DropDownList", "x110 y202 w200", GetMonitorDropdownList())
    monitorDropdown.Choose(selectedMonitor)  ; Select primary by default
    monitorDropdown.OnEvent("Change", OnMonitorChange)
    
    ; Monitor Info Display
    monitorInfoText := guiObj.Add("Text", "x25 y230 w380 h18 c666666", GetMonitorInfoString(selectedMonitor))
    
    ; Check Interval
    guiObj.Add("Text", "x25 y255 w120", "Check Interval (ms):")
    intervalDropdown := guiObj.Add("DropDownList", "x150 y252 w80", ["100", "200", "300", "500", "1000", "2000"])
    intervalDropdown.Text := String(checkInterval)
    intervalDropdown.OnEvent("Change", OnIntervalChange)
    
    ; Click Delay
    guiObj.Add("Text", "x250 y255 w100", "Click Delay (ms):")
    delayDropdown := guiObj.Add("DropDownList", "x350 y252 w55", ["500", "1000", "1500", "2000", "3000"])
    delayDropdown.Text := String(clickDelay)
    delayDropdown.OnEvent("Change", OnDelayChange)
    
    ; Debug Mode checkbox
    debugCheckbox := guiObj.Add("CheckBox", "x25 y283 w100", "Debug Mode")
    debugCheckbox.Value := debugMode
    debugCheckbox.OnEvent("Click", OnDebugToggle)
    
    ; Always On Top checkbox
    alwaysOnTopCheckbox := guiObj.Add("CheckBox", "x150 y283 w120 Checked", "Always On Top")
    alwaysOnTopCheckbox.OnEvent("Click", OnAlwaysOnTopToggle)

    ; 输入继续模式
    continueModeCheckbox := guiObj.Add("CheckBox", "x25 y305 w140", "输入继续模式")
    continueModeCheckbox.Value := continueModeEnabled
    continueModeCheckbox.OnEvent("Click", OnContinueModeToggle)

    selectContinuePosBtn := guiObj.Add("Button", "x180 y302 w90 h22", "选择位置")
    selectContinuePosBtn.OnEvent("Click", OnSelectContinuePos)

    continuePosText := guiObj.Add("Text", "x25 y328 w360 h18 c666666", GetContinuePosText())
    
    ; ---- Live Log Section ----
    guiObj.SetFont("s11 bold")
    guiObj.Add("GroupBox", "x10 y360 w400 h190", "Live Log")
    guiObj.SetFont("s9 norm")
    
    ; ListView for log entries
    logListView := guiObj.Add("ListView", "x20 y385 w380 h155 NoSortHdr", ["Time", "Message"])
    logListView.ModifyCol(1, 70)
    logListView.ModifyCol(2, 300)
    
    ; ---- Control Buttons ----
    guiObj.SetFont("s10")
    startBtn := guiObj.Add("Button", "x10 y560 w95 h35", "Start (F9)")
    startBtn.OnEvent("Click", OnStartClick)
    
    stopBtn := guiObj.Add("Button", "x110 y560 w95 h35", "Stop (F9)")
    stopBtn.OnEvent("Click", OnStopClick)
    stopBtn.Enabled := false
    
    guiObj.Add("Button", "x210 y560 w95 h35", "Stop Button Test").OnEvent("Click", OnStopButtonTestClick)
    guiObj.Add("Button", "x310 y560 w95 h35", "Clear Log").OnEvent("Click", OnClearLogClick)
    
    guiObj.Add("Button", "x10 y600 w95 h35", "Exit").OnEvent("Click", OnExitClick)
    
    ; ---- Image Status Bar ----
    guiObj.SetFont("s9")
    imageStatusText := guiObj.Add("Text", "x10 y640 w400 h20", "Images: Checking...")
}

; ============================================================
; GUI Update Functions
; ============================================================

; Update status display (Running/Stopped)
UpdateStatusDisplay() {
    global statusText, isRunning, startBtn, stopBtn
    
    if isRunning {
        statusText.Text := "● RUNNING"
        statusText.Opt("cGreen")
        startBtn.Enabled := false
        stopBtn.Enabled := true
    } else {
        statusText.Text := "● STOPPED"
        statusText.Opt("cRed")
        startBtn.Enabled := true
        stopBtn.Enabled := false
    }
}

; Update statistics display
UpdateStatistics() {
    global statsClicksText, statsSearchesText, statsRuntimeText, statsLastClickText
    global clickCount, searchCount, lastClickTime
    
    statsClicksText.Text := String(clickCount)
    statsSearchesText.Text := String(searchCount)
    statsRuntimeText.Text := GetRuntimeString()
    statsLastClickText.Text := lastClickTime
}

; Add log entry to ListView
AddLogEntry(logType, message) {
    global logListView
    
    timestamp := FormatTime(, "HH:mm:ss")
    
    ; Add new row at the top
    logListView.Insert(1, , timestamp, message)
    
    ; Limit to 100 entries to prevent memory issues
    if logListView.GetCount() > 100 {
        logListView.Delete(101)
    }
    
    ; Also write to file log
    WriteLog(message)
}

; Update status bar for FindText patterns
UpdateImageStatus() {
    global imageStatusText, runButtonText, resumeButtonText, acceptButtonText, stopButtonText
    
    runStatus := (runButtonText != "" && !InStr(runButtonText, "PLACEHOLDER")) ? "✓ Configured" : "✗ Not set"
    stopStatus := (stopButtonText != "" && !InStr(stopButtonText, "PLACEHOLDER")) ? "✓ Configured" : "✗ Not set"
    acceptStatus := (acceptButtonText != "") ? "✓" : "(optional)"
    nextStatus := (resumeButtonText != "") ? "✓" : "(optional)"
    
    imageStatusText.Text := "FindText: Run " runStatus "  |  Stop " stopStatus "  |  Accept " acceptStatus "  |  Resume " nextStatus
}

; Get runtime as formatted string
GetRuntimeString() {
    global isRunning, startTime
    
    if !isRunning || !startTime
        return "00:00:00"
    
    elapsed := (A_TickCount - startTime) // 1000
    hours := elapsed // 3600
    mins := Mod(elapsed // 60, 60)
    secs := Mod(elapsed, 60)
    return Format("{:02d}:{:02d}:{:02d}", hours, mins, secs)
}

; Timer to update runtime display every second
UpdateRuntimeTimer() {
    UpdateStatistics()
}

; ============================================================
; Button Event Handlers
; ============================================================

OnStartClick(*) {
    global isRunning
    if !isRunning {
        ToggleAutoClick()
    }
}

OnStopClick(*) {
    global isRunning
    if isRunning {
        ToggleAutoClick()
    }
}

OnStopButtonTestClick(*) {
    global stopButtonText

    if (stopButtonText = "" || InStr(stopButtonText, "PLACEHOLDER")) {
        MsgBox("Stop button 图像未配置。", "Stop Button Test", "Icon!")
        return
    }

    result := TryFindTextButton(stopButtonText, false)
    if result["found"] {
        AddLogEntry("debug", "STOP found at (" result["clickX"] ", " result["clickY"] ")")
        FindText().MouseTip(result["clickX"], result["clickY"])
        MsgBox("Stop button: FOUND`n位置: (" result["clickX"] ", " result["clickY"] ")", "Stop Button Test", "Icon!")
    } else {
        AddLogEntry("debug", "STOP pattern not found")
        MsgBox("Stop button: NOT FOUND", "Stop Button Test", "Icon!")
    }
}

OnClearLogClick(*) {
    global logListView
    logListView.Delete()
    AddLogEntry("info", "Log cleared")
}

OnExitClick(*) {
    ExitApp
}

OnGuiClose(*) {
    ExitApp
}

; ============================================================
; Settings Event Handlers
; ============================================================

OnMonitorChange(ctrl, *) {
    global selectedMonitor, monitorInfoText, monitorList
    
    ; Get selected index (1-based)
    selectedIndex := ctrl.Value
    
    ; If "All Monitors" is selected (last item), set to 0
    if selectedIndex = monitorList.Length {
        selectedMonitor := 0
    } else {
        selectedMonitor := selectedIndex
    }
    
    ; Update search bounds
    UpdateSearchBounds(selectedMonitor)
    
    ; Update info text
    monitorInfoText.Text := GetMonitorInfoString(selectedMonitor)
    
    ; Log the change
    if selectedMonitor = 0 {
        AddLogEntry("config", "Monitor: All Monitors")
    } else {
        AddLogEntry("config", "Monitor: " selectedMonitor " (" searchRight - searchLeft "x" searchBottom - searchTop ")")
    }
}

OnIntervalChange(ctrl, *) {
    global checkInterval, isRunning
    checkInterval := Integer(ctrl.Text)
    AddLogEntry("config", "Check interval set to " checkInterval " ms")
    
    ; If running, restart timer with new interval
    if isRunning {
        SetTimer(CheckAndClick, 0)
        SetTimer(CheckAndClick, checkInterval)
    }
}

OnDelayChange(ctrl, *) {
    global clickDelay
    clickDelay := Integer(ctrl.Text)
    AddLogEntry("config", "Click delay set to " clickDelay " ms")
}

OnDebugToggle(ctrl, *) {
    global debugMode
    debugMode := ctrl.Value
    AddLogEntry("config", "Debug mode " (debugMode ? "enabled" : "disabled"))
}

OnAlwaysOnTopToggle(ctrl, *) {
    global guiObj
    if ctrl.Value {
        guiObj.Opt("+AlwaysOnTop")
        AddLogEntry("config", "Always on top enabled")
    } else {
        guiObj.Opt("-AlwaysOnTop")
        AddLogEntry("config", "Always on top disabled")
    }
}

OnContinueModeToggle(ctrl, *) {
    global continueModeEnabled, continueClickX, continueClickY, stopButtonText

    if ctrl.Value {
        if (continueClickX = "" || continueClickY = "") {
            ctrl.Value := 0
            continueModeEnabled := false
            MsgBox("请先设置继续点击位置。", "Auto Cursor Runner", "Icon!")
            return
        }
        continueModeEnabled := true
        if (stopButtonText = "" || InStr(stopButtonText, "PLACEHOLDER")) {
            AddLogEntry("warn", "Stop button 未配置，输入继续可能误触")
        } else {
            AddLogEntry("config", "输入继续模式 enabled")
        }
    } else {
        continueModeEnabled := false
        AddLogEntry("config", "输入继续模式 disabled")
    }
}

OnSelectContinuePos(*) {
    global continueClickX, continueClickY, continuePosText, guiObj, isRunning

    if isRunning {
        MsgBox("请先停止自动点击再设置位置。", "Auto Cursor Runner", "Icon!")
        return
    }

    guiObj.Hide()
    ToolTip("请将鼠标移到目标位置并单击左键")
    KeyWait "LButton", "D"
    MouseGetPos &continueClickX, &continueClickY
    KeyWait "LButton"
    ToolTip()
    guiObj.Show()

    continuePosText.Text := GetContinuePosText()
    AddLogEntry("config", "Continue position set: (" continueClickX ", " continueClickY ")")
}

GetContinuePosText() {
    global continueClickX, continueClickY
    if (continueClickX = "" || continueClickY = "")
        return "继续位置: 未设置"
    return "继续位置: (" continueClickX ", " continueClickY ")"
}

HandleContinueInputIfNeeded() {
    global continueModeEnabled, continueClickX, continueClickY
    global stopButtonText, stopCheckIntervalMs, lastStopCheckFound
    global lastContinueInputTime

    if !continueModeEnabled
        return false
    if (continueClickX = "" || continueClickY = "")
        return false
    if (stopButtonText = "" || InStr(stopButtonText, "PLACEHOLDER"))
        return false

    now := A_TickCount

    ; “继续+回车”整体动作限频
    if (stopCheckIntervalMs > 0 && lastContinueInputTime != 0
        && (now - lastContinueInputTime) < stopCheckIntervalMs) {
        return false
    }

    ; 动作前必须检查 STOP
    stopResult := TryFindTextButton(stopButtonText, false)
    lastStopCheckFound := stopResult["found"]
    if lastStopCheckFound
        return false

    DoContinueInput()
    lastContinueInputTime := now
    AddLogEntry("action", "输入继续: 已发送")
    return true
}

DoContinueInput() {
    global continueClickX, continueClickY, continueInputText, continueAfterClickDelayMs

    VisualClickWithHint(continueClickX, continueClickY, 0)
    if (continueAfterClickDelayMs > 0)
        Sleep(continueAfterClickDelayMs)
    SendText(continueInputText)
    Send("{Enter}")
}

; ============================================================
; Core Toggle Function
; ============================================================

ToggleAutoClick() {
    global isRunning, checkInterval, runButtonText, clickCount, searchCount, startTime, lastStopCheckFound, lastContinueInputTime
    global selectedMonitor, searchLeft, searchTop, searchRight, searchBottom
    
    isRunning := !isRunning
    
    if isRunning {
        ; Check if FindText pattern is configured
        if (runButtonText = "" || InStr(runButtonText, "PLACEHOLDER")) {
            AddLogEntry("error", "FindText pattern not configured!")
            MsgBox("Run pattern not configured!`n`nHow to set:`n1) Run findtext.ahk directly`n2) Click Capture -> Select Run button area`n3) Gray tab -> Gray2Two -> Auto -> OK`n4) Copy the Text string (|<...>$...)`n5) Paste into runButtonText variable in this script", "Auto Cursor Runner", "Icon!")
            isRunning := false
            UpdateStatusDisplay()
            return
        }
        
        ; Reset counters
        clickCount := 0
        searchCount := 0
        startTime := A_TickCount
        lastStopCheckFound := false
        lastContinueInputTime := 0
        
        ; Start timers
        SetTimer(CheckAndClick, checkInterval)
        SetTimer(UpdateRuntimeTimer, 1000)
        
        ; Log with monitor info
        monLabel := selectedMonitor = 0 ? "All" : String(selectedMonitor)
        AddLogEntry("info", "STARTED on Monitor " monLabel)
        TrayTip("Auto-click enabled", "Auto Cursor Runner", "Icon!")
    } else {
        ; Stop timers
        SetTimer(CheckAndClick, 0)
        SetTimer(UpdateRuntimeTimer, 0)
        
        AddLogEntry("info", "Auto-click STOPPED")
        TrayTip("Auto-click disabled", "Auto Cursor Runner", "Icon!")
    }
    
    UpdateStatusDisplay()
    UpdateStatistics()
}

; ============================================================
; Core Functions
; ============================================================

; Check and click button using FindText
CheckAndClick() {
    global runButtonText, resumeButtonText, acceptButtonText, clickDelay
    global clickCount, lastClickTime, searchCount, debugMode
    
    ; Search for Run button using FindText
    result := TryFindTextButton(runButtonText, true)
    if result["found"] {
        clickCount++
        lastClickTime := FormatTime(, "HH:mm:ss")
        AddLogEntry("click", "Clicked RUN at (" result["clickX"] ", " result["clickY"] ")")
        UpdateStatistics()
        return
    }
    
    ; If acceptButtonText is defined, try searching for it
    if (acceptButtonText != "") {
        result := TryFindTextButton(acceptButtonText, true)
        if result["found"] {
            clickCount++
            lastClickTime := FormatTime(, "HH:mm:ss")
            AddLogEntry("click", "Clicked ACCEPT at (" result["clickX"] ", " result["clickY"] ")")
            UpdateStatistics()
            return
        }
    }

    ; If resumeButtonText is defined, try searching for it
    if (resumeButtonText != "") {
        result := TryFindTextButton(resumeButtonText, true)
        if result["found"] {
            clickCount++
            lastClickTime := FormatTime(, "HH:mm:ss")
            AddLogEntry("click", "Clicked RESUME at (" result["clickX"] ", " result["clickY"] ")")
            UpdateStatistics()
            return
        }
    }
    
    ; Not found - update search count
    searchCount++
    if debugMode && Mod(searchCount, 10) = 0 {
        ; Only log every 10th search to reduce spam
        AddLogEntry("search", "Searching... #" searchCount)
    }
    if HandleContinueInputIfNeeded() {
        UpdateStatistics()
        return
    }
    UpdateStatistics()
}

; Try to find and click specified button using FindText
TryFindTextButton(textPattern, doClick := true) {
    global clickDelay, debugMode
    global searchLeft, searchTop, searchRight, searchBottom
    
    if (textPattern = "")
        return Map("found", false, "error", "Empty text pattern")
    
    try {
        ; Use FindText to search for the button pattern
        ; FindText returns array of results, each with {1:X, 2:Y, 3:W, 4:H, x:centerX, y:centerY, id:comment}
        ok := FindText(&X, &Y, searchLeft, searchTop, searchRight, searchBottom, 0, 0, textPattern)
        
        if (ok && ok.Length > 0) {
            ; Found button - FindText returns center coordinates in X, Y
            ; ok[1].1, ok[1].2 = top-left corner
            ; ok[1].x, ok[1].y = center coordinates (recommended for clicking)
            foundX := ok[1].1      ; Top-left X
            foundY := ok[1].2      ; Top-left Y
            clickX := ok[1].x      ; Center X (best for clicking)
            clickY := ok[1].y      ; Center Y (best for clicking)
            
            if doClick {
                ; 点击前后加“红圈闪烁提示”并将鼠标位置恢复
                VisualClickWithHint(clickX, clickY)
            }
            return Map("found", true, "x", foundX, "y", foundY, "clickX", clickX, "clickY", clickY, "width", ok[1].3, "height", ok[1].4)
        }
    } catch Error as e {
        ; FindText search failed
        return Map("found", false, "error", e.Message)
    }
    
    return Map("found", false)
}

; ============================================================
; Visual Click Hint Helpers (red flashing circle)
; ============================================================

; 执行一次“瞬移点击”：点击前闪烁（当前鼠标位置 0.5s + 目标位置 0.5s）
; 点击后再闪烁一次（目标位置 0.5s + 原鼠标位置 0.5s），最后把鼠标移回原位
VisualClickWithHint(targetX, targetY, postDelayMs := "") {
    global clickDelay, clickHintEnabled
    global clickHintDurationMs, clickHintBlinkMs

    if (postDelayMs = "")
        postDelayMs := clickDelay

    MouseGetPos &origX, &origY

    try {
        if clickHintEnabled {
            FlashRedCircle(origX, origY, clickHintDurationMs, clickHintBlinkMs)
            FlashRedCircle(targetX, targetY, clickHintDurationMs, clickHintBlinkMs)
        }

        ; “瞬移”到目标位置再点击（避免 Click x,y 自带移动造成时序不可控）
        MouseMove targetX, targetY, 0
        Click

        if clickHintEnabled {
            FlashRedCircle(targetX, targetY, clickHintDurationMs, clickHintBlinkMs)
            FlashRedCircle(origX, origY, clickHintDurationMs, clickHintBlinkMs)
        }

        ; 把鼠标位置变回来
        MouseMove origX, origY, 0

        ; Wait before continuing detection
        if (postDelayMs > 0)
            Sleep(postDelayMs)
    } catch Error as e {
        ; 尽量保证出错时也能把鼠标移回去
        try MouseMove origX, origY, 0
        throw e
    }
}

; 在指定屏幕坐标显示"红色圆环闪烁"
FlashRedCircle(centerX, centerY, durationMs := 500, blinkMs := 100) {
    global clickHintDiameter, clickHintAlpha, clickHintThickness
    gui := GetClickHintGui()

    d := clickHintDiameter
    x := Round(centerX - d // 2)
    y := Round(centerY - d // 2)

    ; 先定位并显示（NA = 不激活窗口）
    gui.Show("NA x" x " y" y " w" d " h" d)
    ApplyRingRegion(gui.Hwnd, d, clickHintThickness)
    try WinSetTransparent(clickHintAlpha, "ahk_id " gui.Hwnd)

    start := A_TickCount
    visible := true
    while (A_TickCount - start < durationMs) {
        if visible
            gui.Hide()
        else
            gui.Show("NA x" x " y" y " w" d " h" d)
        visible := !visible
        Sleep(blinkMs)
    }
    gui.Hide()
}

; 获取/复用提示 GUI（避免频繁创建销毁）
GetClickHintGui() {
    global __clickHintGui
    if IsSet(__clickHintGui) && (__clickHintGui != "") {
        return __clickHintGui
    }

    ; +E0x20: 让窗口“点穿”，避免影响鼠标点击/拖拽
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "ClickHint")
    g.BackColor := "FF0000"
    __clickHintGui := g
    return g
}

; 将窗口裁成圆环形状（外圆 - 内圆 = 圆环）
; 参考 findtext.ahk 的 RangeTip，用 GDI Region 组合实现
ApplyRingRegion(hwnd, outerD, thickness := 4) {
    ; 外圆
    outerRgn := DllCall("CreateEllipticRgn", "int", 0, "int", 0, "int", outerD, "int", outerD, "ptr")
    ; 内圆（居中）
    innerD := outerD - thickness * 2
    offset := thickness
    innerRgn := DllCall("CreateEllipticRgn", "int", offset, "int", offset
        , "int", offset + innerD, "int", offset + innerD, "ptr")
    ; CombineRgn: RGN_XOR=3 => 外圆 XOR 内圆 = 圆环
    DllCall("CombineRgn", "ptr", outerRgn, "ptr", outerRgn, "ptr", innerRgn, "int", 3)
    DllCall("DeleteObject", "ptr", innerRgn)
    ; SetWindowRgn 成功后系统接管 outerRgn，无需 DeleteObject
    DllCall("SetWindowRgn", "ptr", hwnd, "ptr", outerRgn, "int", true)
}

; Debug search function (GUI version) - using FindText
DebugSearchGUI() {
    global runButtonText, resumeButtonText, acceptButtonText, scriptDir
    global searchLeft, searchTop, searchRight, searchBottom, selectedMonitor
    
    AddLogEntry("debug", "Starting FindText debug search...")
    WriteLog("DebugSearch started (FindText)")
    
    ; Check if pattern is configured
    if (runButtonText = "" || InStr(runButtonText, "PLACEHOLDER")) {
        WriteLog("Error: FindText pattern not configured")
        AddLogEntry("error", "Pattern not configured!")
        MsgBox("FindText pattern not configured!`n`nRun findtext.ahk to capture the Run button.", "Debug", "Icon!")
        return
    }
    
    monLabel := selectedMonitor = 0 ? "All" : String(selectedMonitor)
    WriteLog("Testing FindText on monitor " monLabel "...")
    
    ; Test FindText search (RUN + optional ACCEPT/RESUME)
    foundAny := false
    results := ""
    
    runFoundAny := false
    runFirstFoundX := 0
    runFirstFoundY := 0
    runFoundWidth := 0
    runFoundHeight := 0

    acceptFoundAny := false
    acceptFirstFoundX := 0
    acceptFirstFoundY := 0
    acceptFoundWidth := 0
    acceptFoundHeight := 0

    altFoundAny := false
    altFirstFoundX := 0
    altFirstFoundY := 0
    altFoundWidth := 0
    altFoundHeight := 0

    ; ---- RUN pattern ----
    t1 := A_TickCount
    try {
        ; FindText with FindAll=1 to get all matches
        okRun := FindText(&X, &Y, searchLeft, searchTop, searchRight, searchBottom, 0, 0, runButtonText, 1, 1)
        runSearchTime := A_TickCount - t1

        results .= "RUN:`n"
        if (okRun && okRun.Length > 0) {
            foundAny := true
            runFoundAny := true
            runFirstFoundX := okRun[1].1
            runFirstFoundY := okRun[1].2
            runFoundWidth := okRun[1].3
            runFoundHeight := okRun[1].4

            results .= "Found " okRun.Length " match(es) in " runSearchTime "ms`n"
            Loop Min(okRun.Length, 5) {
                results .= "  - (" okRun[A_Index].1 ", " okRun[A_Index].2 ") "
                results .= "Center: (" okRun[A_Index].x ", " okRun[A_Index].y ") "
                results .= "Size: " okRun[A_Index].3 "x" okRun[A_Index].4 "`n"
            }
            if (okRun.Length > 5)
                results .= "  ... and " (okRun.Length - 5) " more`n"

            AddLogEntry("debug", "RUN found " okRun.Length " at (" runFirstFoundX ", " runFirstFoundY ")")
            WriteLog("FindText RUN: Found " okRun.Length " matches, first at (" runFirstFoundX ", " runFirstFoundY ")")
        } else {
            results .= "NOT FOUND (searched in " runSearchTime "ms)`n"
            AddLogEntry("debug", "RUN pattern not found")
            WriteLog("FindText RUN: Pattern not found")
        }
        results .= "`n"
    } catch Error as e {
        results .= "RUN: ERROR: " e.Message "`n`n"
        AddLogEntry("error", "FindText RUN error: " e.Message)
        WriteLog("FindText RUN Error: " e.Message)
    }

    ; ---- ACCEPT pattern (optional) ----
    if (acceptButtonText != "") {
        t2 := A_TickCount
        try {
            okAccept := FindText(&X, &Y, searchLeft, searchTop, searchRight, searchBottom, 0, 0, acceptButtonText, 1, 1)
            acceptSearchTime := A_TickCount - t2

            results .= "ACCEPT:`n"
            if (okAccept && okAccept.Length > 0) {
                foundAny := true
                acceptFoundAny := true
                acceptFirstFoundX := okAccept[1].1
                acceptFirstFoundY := okAccept[1].2
                acceptFoundWidth := okAccept[1].3
                acceptFoundHeight := okAccept[1].4

                results .= "Found " okAccept.Length " match(es) in " acceptSearchTime "ms`n"
                Loop Min(okAccept.Length, 5) {
                    results .= "  - (" okAccept[A_Index].1 ", " okAccept[A_Index].2 ") "
                    results .= "Center: (" okAccept[A_Index].x ", " okAccept[A_Index].y ") "
                    results .= "Size: " okAccept[A_Index].3 "x" okAccept[A_Index].4 "`n"
                }
                if (okAccept.Length > 5)
                    results .= "  ... and " (okAccept.Length - 5) " more`n"

                AddLogEntry("debug", "ACCEPT found " okAccept.Length " at (" acceptFirstFoundX ", " acceptFirstFoundY ")")
                WriteLog("FindText ACCEPT: Found " okAccept.Length " matches, first at (" acceptFirstFoundX ", " acceptFirstFoundY ")")
            } else {
                results .= "NOT FOUND (searched in " acceptSearchTime "ms)`n"
                AddLogEntry("debug", "ACCEPT pattern not found")
                WriteLog("FindText ACCEPT: Pattern not found")
            }
            results .= "`n"
        } catch Error as e {
            results .= "ACCEPT: ERROR: " e.Message "`n`n"
            AddLogEntry("error", "FindText ACCEPT error: " e.Message)
            WriteLog("FindText ACCEPT Error: " e.Message)
        }
    } else {
        results .= "ACCEPT:`n(optional) not configured (acceptButtonText is empty)`n`n"
    }

    ; ---- RESUME pattern (optional) ----
    if (resumeButtonText != "") {
        t3 := A_TickCount
        try {
            okAlt := FindText(&X, &Y, searchLeft, searchTop, searchRight, searchBottom, 0, 0, resumeButtonText, 1, 1)
            altSearchTime := A_TickCount - t3

            results .= "RESUME:`n"
            if (okAlt && okAlt.Length > 0) {
                foundAny := true
                altFoundAny := true
                altFirstFoundX := okAlt[1].1
                altFirstFoundY := okAlt[1].2
                altFoundWidth := okAlt[1].3
                altFoundHeight := okAlt[1].4

                results .= "Found " okAlt.Length " match(es) in " altSearchTime "ms`n"
                Loop Min(okAlt.Length, 5) {
                    results .= "  - (" okAlt[A_Index].1 ", " okAlt[A_Index].2 ") "
                    results .= "Center: (" okAlt[A_Index].x ", " okAlt[A_Index].y ") "
                    results .= "Size: " okAlt[A_Index].3 "x" okAlt[A_Index].4 "`n"
                }
                if (okAlt.Length > 5)
                    results .= "  ... and " (okAlt.Length - 5) " more`n"

                AddLogEntry("debug", "RESUME found " okAlt.Length " at (" altFirstFoundX ", " altFirstFoundY ")")
                WriteLog("FindText RESUME: Found " okAlt.Length " matches, first at (" altFirstFoundX ", " altFirstFoundY ")")
            } else {
                results .= "NOT FOUND (searched in " altSearchTime "ms)`n"
                AddLogEntry("debug", "RESUME pattern not found")
                WriteLog("FindText RESUME: Pattern not found")
            }
            results .= "`n"
        } catch Error as e {
            results .= "RESUME: ERROR: " e.Message "`n`n"
            AddLogEntry("error", "FindText RESUME error: " e.Message)
            WriteLog("FindText RESUME Error: " e.Message)
        }
    } else {
        results .= "RESUME:`n(optional) not configured (resumeButtonText is empty)`n`n"
    }
    
    WriteLog("DebugSearch completed")
    
    searchWidth := searchRight - searchLeft
    searchHeight := searchBottom - searchTop
    
    ; Extract pattern info for display
    runPatternInfo := SubStr(runButtonText, 1, 50)
    if (StrLen(runButtonText) > 50)
        runPatternInfo .= "..."
    acceptPatternInfo := ""
    if (acceptButtonText != "") {
        acceptPatternInfo := SubStr(acceptButtonText, 1, 50)
        if (StrLen(acceptButtonText) > 50)
            acceptPatternInfo .= "..."
    } else {
        acceptPatternInfo := "(not set)"
    }
    altPatternInfo := ""
    if (resumeButtonText != "") {
        altPatternInfo := SubStr(resumeButtonText, 1, 50)
        if (StrLen(resumeButtonText) > 50)
            altPatternInfo .= "..."
    } else {
        altPatternInfo := "(not set)"
    }
    
    msg := "
    (
    =======================================
    FindText Debug Results
    =======================================
    
    RUN Pattern: " runPatternInfo "
    ACCEPT Pattern: " acceptPatternInfo "
    RESUME Pattern: " altPatternInfo "
    
    Search Area (Monitor " monLabel "):
    - From: (" searchLeft ", " searchTop ")
    - To: (" searchRight ", " searchBottom ")
    - Size: " searchWidth " x " searchHeight "
    
    =======================================
    Test Results:
    =======================================
    " results "
    =======================================
    Tips:
    - If not found, re-capture with findtext.ahk
    - Use Gray mode for text recognition
    - Use Color mode for colored icons
    - Click 'Auto' to trim edges after capture
    =======================================
    )"
    
    MsgBox(msg, "FindText Debug Results", "Icon!")
    
    ; If found, offer to show visual marker
    if foundAny {
        result := MsgBox("Show visual marker at found position?", "Debug", "YesNo")
        if (result = "Yes") {
            ; Prefer showing RUN marker if RUN was found, otherwise show ACCEPT/RESUME marker.
            if runFoundAny {
                FindText().MouseTip(runFirstFoundX + runFoundWidth // 2, runFirstFoundY + runFoundHeight // 2)
            } else if acceptFoundAny {
                FindText().MouseTip(acceptFirstFoundX + acceptFoundWidth // 2, acceptFirstFoundY + acceptFoundHeight // 2)
            } else if altFoundAny {
                FindText().MouseTip(altFirstFoundX + altFoundWidth // 2, altFirstFoundY + altFoundHeight // 2)
            }
        }
    }
}

; Write log to file (UTF-8 encoding)
WriteLog(message) {
    global logFile
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    try {
        FileAppend(timestamp " | " message "`n", logFile, "UTF-8")
    }
}

