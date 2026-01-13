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

; Next button pattern (optional) - capture if you have a Next button to click
global nextButtonText := ""

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
guiObj.Show("w420 h630")
AddLogEntry("info", "Script started" (A_IsAdmin ? " [Admin]" : " [No Admin]"))
UpdateImageStatus()

; ============================================================
; Hotkey Definitions (Global hotkeys)
; ============================================================

; F9 - Toggle auto-click (global)
F9:: {
    ToggleAutoClick()
}

; F10 - Exit script (global)
F10:: {
    ExitApp
}

; F11 - Show status (now focuses GUI)
F11:: {
    guiObj.Show()
}

; F12 - Debug: manual search test
F12:: {
    WriteLog("F12 pressed - Starting debug search")
    DebugSearchGUI()
}

; ============================================================
; GUI Creation Function
; ============================================================
CreateMainGUI() {
    global guiObj, statusText, statsClicksText, statsSearchesText
    global statsRuntimeText, statsLastClickText, logListView
    global startBtn, stopBtn, intervalDropdown, delayDropdown
    global monitorDropdown, monitorInfoText
    global debugCheckbox, alwaysOnTopCheckbox
    global imageStatusText, checkInterval, clickDelay, debugMode
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
    guiObj.Add("GroupBox", "x10 y180 w400 h130", "Settings")
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
    
    ; ---- Live Log Section ----
    guiObj.SetFont("s11 bold")
    guiObj.Add("GroupBox", "x10 y320 w400 h190", "Live Log")
    guiObj.SetFont("s9 norm")
    
    ; ListView for log entries
    logListView := guiObj.Add("ListView", "x20 y345 w380 h155 NoSortHdr", ["Time", "Message"])
    logListView.ModifyCol(1, 70)
    logListView.ModifyCol(2, 300)
    
    ; ---- Control Buttons ----
    guiObj.SetFont("s10")
    startBtn := guiObj.Add("Button", "x10 y520 w95 h35", "Start (F9)")
    startBtn.OnEvent("Click", OnStartClick)
    
    stopBtn := guiObj.Add("Button", "x110 y520 w95 h35", "Stop (F9)")
    stopBtn.OnEvent("Click", OnStopClick)
    stopBtn.Enabled := false
    
    guiObj.Add("Button", "x210 y520 w95 h35", "Test (F12)").OnEvent("Click", OnTestClick)
    guiObj.Add("Button", "x310 y520 w95 h35", "Clear Log").OnEvent("Click", OnClearLogClick)
    
    guiObj.Add("Button", "x10 y560 w95 h35", "Exit (F10)").OnEvent("Click", OnExitClick)
    
    ; ---- Image Status Bar ----
    guiObj.SetFont("s9")
    imageStatusText := guiObj.Add("Text", "x10 y600 w400 h20", "Images: Checking...")
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
    global imageStatusText, runButtonText, nextButtonText
    
    runStatus := (runButtonText != "" && !InStr(runButtonText, "PLACEHOLDER")) ? "✓ Configured" : "✗ Not set"
    nextStatus := (nextButtonText != "") ? "✓" : "(optional)"
    
    imageStatusText.Text := "FindText: Run " runStatus "  |  Next " nextStatus
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

OnTestClick(*) {
    DebugSearchGUI()
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

; ============================================================
; Core Toggle Function
; ============================================================

ToggleAutoClick() {
    global isRunning, checkInterval, runButtonText, clickCount, searchCount, startTime
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
    global runButtonText, nextButtonText, clickDelay
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
    
    ; If nextButtonText is defined, try searching for it
    if (nextButtonText != "") {
        result := TryFindTextButton(nextButtonText, true)
        if result["found"] {
            clickCount++
            lastClickTime := FormatTime(, "HH:mm:ss")
            AddLogEntry("click", "Clicked NEXT at (" result["clickX"] ", " result["clickY"] ")")
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
                Click clickX, clickY
                
                ; Wait before continuing detection
                Sleep(clickDelay)
            }
            return Map("found", true, "x", foundX, "y", foundY, "clickX", clickX, "clickY", clickY, "width", ok[1].3, "height", ok[1].4)
        }
    } catch Error as e {
        ; FindText search failed
        return Map("found", false, "error", e.Message)
    }
    
    return Map("found", false)
}

; Debug search function (GUI version) - using FindText
DebugSearchGUI() {
    global runButtonText, scriptDir
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
    
    ; Test FindText search
    foundAny := false
    firstFoundX := 0
    firstFoundY := 0
    foundWidth := 0
    foundHeight := 0
    resultCount := 0
    results := ""
    
    t1 := A_TickCount
    try {
        ; FindText with FindAll=1 to get all matches
        ok := FindText(&X, &Y, searchLeft, searchTop, searchRight, searchBottom, 0, 0, runButtonText, 1, 1)
        searchTime := A_TickCount - t1
        
        if (ok && ok.Length > 0) {
            foundAny := true
            resultCount := ok.Length
            firstFoundX := ok[1].1
            firstFoundY := ok[1].2
            foundWidth := ok[1].3
            foundHeight := ok[1].4
            
            results .= "Found " resultCount " match(es) in " searchTime "ms`n`n"
            
            ; List first 5 matches
            Loop Min(ok.Length, 5) {
                results .= "Match " A_Index ": (" ok[A_Index].1 ", " ok[A_Index].2 ") "
                results .= "Center: (" ok[A_Index].x ", " ok[A_Index].y ") "
                results .= "Size: " ok[A_Index].3 "x" ok[A_Index].4 "`n"
            }
            if (ok.Length > 5)
                results .= "... and " (ok.Length - 5) " more`n"
            
            AddLogEntry("debug", "Found " resultCount " at (" firstFoundX ", " firstFoundY ")")
            WriteLog("FindText: Found " resultCount " matches, first at (" firstFoundX ", " firstFoundY ")")
        } else {
            results .= "NOT FOUND (searched in " searchTime "ms)`n"
            AddLogEntry("debug", "Pattern not found")
            WriteLog("FindText: Pattern not found")
        }
    } catch Error as e {
        results .= "ERROR: " e.Message "`n"
        AddLogEntry("error", "FindText error: " e.Message)
        WriteLog("FindText Error: " e.Message)
    }
    
    WriteLog("DebugSearch completed")
    
    searchWidth := searchRight - searchLeft
    searchHeight := searchBottom - searchTop
    
    ; Extract pattern info for display
    patternInfo := SubStr(runButtonText, 1, 50)
    if (StrLen(runButtonText) > 50)
        patternInfo .= "..."
    
    msg := "
    (
    =======================================
    FindText Debug Results
    =======================================
    
    Pattern: " patternInfo "
    
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
            FindText().MouseTip(firstFoundX + foundWidth // 2, firstFoundY + foundHeight // 2)
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

