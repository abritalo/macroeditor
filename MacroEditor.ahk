; ============================================================
;  MacroEditor.ahk — Sistema de Macros para Windows
;  AutoHotkey v2.0+
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"
SendMode "Input"
Persistent()

; ---------- Globals ----------
global ConfigFile      := A_ScriptDir "\MacroEditor_config.ini"
global MacroFile       := A_ScriptDir "\MacroEditor_macros.ini"
global Macros          := Map()
global Recording       := false
global RecSteps        := []
global ActiveHKs       := Map()
global MainGui         := 0
global MacroLV         := 0
global MainSB          := 0

; Controle de macros em loop: chave = macroName, valor = true se rodando
global RunningLoops    := Map()

; ---- Clicker Simples ----
global ClickerGui      := 0          ; janela do clicker
global ClickerCfgGui   := 0          ; janela de config do clicker
global ClickerRunning  := false      ; esta clicando agora?
global ClickerHK       := ""         ; keybind atual (formato AHK)
global ClickerCfg      := Map()      ; configuracoes persistidas
global ClickerHKLabel  := 0          ; label keybind na tela principal
global ClickerLoopLabel := 0         ; label loop na tela principal
global ClickerEnabled  := true       ; clicker ativado/desativado
global ClickerEnabledCB := 0         ; checkbox Ativado na tela principal

; ============================================================
;  WRAPPER GLOBAL FIXO PARA GRAVACAO DE CLIQUES
; ============================================================
global G_RecCallback := 0

RecClickWrapper(*) {
    global G_RecCallback
    if G_RecCallback != 0
        G_RecCallback()
}

; Registra o wrapper global para gravacao de cliques e ja deixa desativado.
; O try e necessario: no AHK v2, HotKey "Off" sem a funcao associada pode
; lancar "Nonexistent hotkey" em algumas versoes/builds, matando o script.
try HotKey "~LButton Up", RecClickWrapper
try HotKey "~LButton Up", "Off"

; ---------- Bandeja ----------
A_TrayMenu.Delete()
A_TrayMenu.Add("Abrir MacroEditor", (*) => ShowMainGui())
A_TrayMenu.Add("Recarregar hotkeys",  (*) => ApplyHotkeys())
A_TrayMenu.Add()
A_TrayMenu.Add("Sair", (*) => ExitApp())
A_TrayMenu.Default := "Abrir MacroEditor"
A_IconTip := "MacroEditor — rodando em segundo plano"

; ---------- Init ----------
; Se lancado com argumento "/silent" (atalho do Startup do Windows),
; inicia apenas na bandeja.
; Se lancado normalmente (duplo clique no .ahk), abre a GUI.
LoadMacros()
LoadClickerCfg()

; Instala os hooks de teclado/mouse imediatamente para garantir que
; hotkeys dinamicos funcionem desde o primeiro uso, inclusive ao
; iniciar via bandeja do Windows sem ter aberto a GUI.
InstallKeybdHook
InstallMouseHook

ApplyHotkeys()

; Recria o atalho de startup automaticamente sempre que o script iniciar
; e a opcao Iniciar com Windows estiver ativa no INI.
; Isso corrige atalhos corrompidos de versoes anteriores sem precisar
; que o usuario abra as Configuracoes manualmente.
if IniRead(ConfigFile, "Settings", "Startup", "0") = "1"
    CreateStartupShortcut()

if A_Args.Length > 0 && A_Args[1] = "/silent" {
    SetTimer ApplyHotkeys, -3000
} else {
    ShowMainGui()
}
return

; ============================================================
;  CRIACAO DO ATALHO DE STARTUP (funcao centralizada)
;  Aponta o atalho para A_AhkPath (AutoHotkey.exe) com o
;  script e /silent como argumentos, usando aspas ao redor
;  do caminho do script para suportar espacos no caminho.
;  WorkingDir = A_ScriptDir garante que os INIs sejam
;  encontrados pelo caminho relativo ao script.
; ============================================================
CreateStartupShortcut() {
    lnkPath := A_Startup "\MacroEditor.lnk"
    try FileDelete lnkPath
    FileCreateShortcut(
        A_AhkPath,
        lnkPath,
        A_ScriptDir,
        '"' A_ScriptFullPath '" /silent',
        "MacroEditor"
    )
}

; ============================================================
;  GUI PRINCIPAL
; ============================================================
ShowMainGui(*) {
    global MainGui, MacroLV, MainSB, ConfigFile

    if IsObject(MainGui) {
        try MainGui.Show()
        RefreshList()
        return
    }

    aot    := IniRead(ConfigFile, "Settings", "AlwaysOnTop", "1")
    aotFlg := (aot = "1") ? "+AlwaysOnTop" : "-AlwaysOnTop"
    MainGui := Gui(aotFlg, "MacroEditor")
    MainGui.BackColor := "FFFFFF"
    MainGui.SetFont("s10", "Segoe UI")
    MainGui.Add("Text", "x16 y14 w300", "MacroEditor")
    MainGui.SetFont("s9 cGray")
    MainGui.Add("Text", "x16 y34 w420", "Sistema de macros para Windows — rodando na bandeja")
    MainGui.SetFont("s8 cGray")
    MainGui.Add("Text", "x516 y14 w160 +Right", "Por Italo Brito")
    MainGui.SetFont("s9 cBlack")
    MainGui.Add("Button", "x16 y60 w130 h28",  "Gravar Macro").OnEvent("Click", (*) => OpenRecordDialog())
    MainGui.Add("Button", "x152 y60 w120 h28", "Configurações").OnEvent("Click", (*) => OpenSettingsDialog())
    MainGui.Add("Text", "x16 y98 w660 h1 +0x10")

    MainGui.Add("Text", "x16 y108", "Macros salvas:")
    ; Sem -Multi para permitir selecao multipla (Shift+Clique / Ctrl+Clique)
    MacroLV := MainGui.Add("ListView", "x16 y126 w660 h210", ["Nome","Keybind","Janela alvo","Passos","Repeticao"])
    MacroLV.ModifyCol(1, 160)
    MacroLV.ModifyCol(2, 120)
    MacroLV.ModifyCol(3, 175)
    MacroLV.ModifyCol(4, 55)
    MacroLV.ModifyCol(5, 90)
    MacroLV.OnEvent("DoubleClick", (*) => OpenEditDialog())

    MainGui.Add("Button", "x16 y346 w100 h26",  "Editar").OnEvent("Click",  (*) => OpenEditDialog())
    MainGui.Add("Button", "x122 y346 w100 h26", "Excluir").OnEvent("Click", (*) => DeleteMacro())
    MainGui.Add("Button", "x228 y346 w100 h26", "Executar").OnEvent("Click", (*) => RunSelected())

    ; --- Delimitador e painel de status do Clicker Simples ---
    MainGui.Add("Text", "x16 y380 w660 h1 +0x10")
    MainGui.SetFont("s9 Bold cBlack")
    MainGui.Add("Text", "x16 y388", "Clicker Simples:")
    MainGui.SetFont("s9 norm cBlack")
    MainGui.Add("Text", "x16 y406 w80 cGray", "Keybind:")
    global ClickerHKLabel := MainGui.Add("Text", "x100 y406 w200", "—")
    MainGui.Add("Text", "x16 y424 w80 cGray", "Loop:")
    global ClickerLoopLabel := MainGui.Add("Text", "x100 y424 w200", "—")
    MainGui.Add("Button", "x530 y384 w146 h28", "Config. Clicker Simples").OnEvent("Click", (*) => OpenClickerDialog())
    MainGui.SetFont("s9 norm cBlack")
    global ClickerEnabledCB := MainGui.Add("CheckBox", "x432 y389 w90 Checked" (ClickerEnabled ? 1 : 0), "Ativado")
    ClickerEnabledCB.OnEvent("Click", (*) => ToggleClickerEnabled())

    MainSB := MainGui.Add("StatusBar")
    MainGui.OnEvent("Close", (*) => MainGui.Hide())

    ; Intercepta o clique no botao minimizar via WM_SYSCOMMAND (0x112).
    ; SC_MINIMIZE = 0xF020. Ao inves de minimizar (aparecer na taskbar),
    ; esconde a janela direto — ela some da taskbar e vai para a bandeja.
    OnMessage(0x112, WM_SYSCOMMAND_Handler)

    MainGui.Show("w692 h460")
    RefreshList()
}

; Formata o texto da coluna Repeticao
FormatRepeatDisplay(m) {
    repeatMode := m.Has("repeatMode") ? m["repeatMode"] : "none"
    repeatVal  := m.Has("repeatVal")  ? m["repeatVal"]  : 1
    if repeatMode = "none"
        return "0"
    else if repeatMode = "times"
        return repeatVal "x"
    else if repeatMode = "minutes"
        return repeatVal " min"
    else if repeatMode = "clicks"
        return repeatVal "x"
    return "0"
}

RefreshList() {
    global Macros, MacroLV, MainSB, ClickerCfg, ClickerHKLabel, ClickerLoopLabel
    MacroLV.Delete()
    count := 0
    for name, m in Macros {
        count++
        ; Conta apenas passos que nao sejam WINOPEN (passo interno)
        stepCount := 0
        for s in m["steps"] {
            if !RegExMatch(s, "^WINOPEN ")
                stepCount++
        }
        MacroLV.Add("", name, AhkToDisplay(m["hotkey"]), FormatWindowDisplay(m["window"]), stepCount, FormatRepeatDisplay(m))
    }
    MainSB.SetText("Pronto  -  " count " macro(s) carregada(s)")

    ; Atualiza painel do Clicker Simples
    try {
        if IsObject(ClickerHKLabel) {
            hkDisp := (IsObject(ClickerCfg) && ClickerCfg.Has("hkDisplay") && ClickerCfg["hkDisplay"] != "") ? ClickerCfg["hkDisplay"] : "Nenhuma"
            ClickerHKLabel.Value := hkDisp
        }
        if IsObject(ClickerLoopLabel) {
            if !IsObject(ClickerCfg) || !ClickerCfg.Has("repeatMode") {
                ClickerLoopLabel.Value := "—"
            } else {
                mode := ClickerCfg["repeatMode"]
                val  := ClickerCfg.Has("repeatVal") ? ClickerCfg["repeatVal"] : 0
                ivl  := ClickerCfg.Has("interval")  ? ClickerCfg["interval"]  : 100
                if mode = "infinite"
                    ClickerLoopLabel.Value := "Infinito  |  intervalo: " ivl "ms"
                else if mode = "times"
                    ClickerLoopLabel.Value := val "x  |  intervalo: " ivl "ms"
                else if mode = "minutes"
                    ClickerLoopLabel.Value := val " min  |  intervalo: " ivl "ms"
                else
                    ClickerLoopLabel.Value := "—"
            }
        }
    }
}

; Intercepta WM_SYSCOMMAND para capturar o botao minimizar.
; Quando o usuario clica em minimizar (SC_MINIMIZE = 0xF020),
; esconde a janela direto em vez de minimizar — ela sai da
; taskbar e fica apenas na bandeja.
WM_SYSCOMMAND_Handler(wParam, lParam, msg, hwnd) {
    global MainGui
    if !IsObject(MainGui)
        return
    try {
        if hwnd = MainGui.Hwnd && (wParam & 0xFFF0) = 0xF020 {
            MainGui.Hide()
            return 0
        }
    }
}

OpenRecordDialog() {
    global MainGui
    if IsObject(MainGui)
        MainGui.Hide()
    RecordDialog()
}

OpenEditDialog() {
    global MainGui, MacroLV

    ; Conta quantas linhas estao selecionadas
    selCount := 0
    firstRow := 0
    row := 0
    loop {
        row := MacroLV.GetNext(row, "F")
        if !row
            break
        selCount++
        firstRow := (selCount = 1) ? row : firstRow
    }

    if selCount = 0
        return
    if selCount > 1
        return

    selName := MacroLV.GetText(firstRow, 1)
    if IsObject(MainGui)
        MainGui.Hide()
    RecordDialog(selName)
}

OpenSettingsDialog() {
    global MainGui
    if IsObject(MainGui)
        MainGui.Hide()
    OpenSettings()
}

OpenClickerDialog() {
    global MainGui
    if IsObject(MainGui)
        MainGui.Hide()
    ShowClickerGui()
}

ReturnToMain() {
    global MainGui
    if IsObject(MainGui) {
        MainGui.Show()
        RefreshList()
    }
}

; ============================================================
;  KEYBIND BUILDER
; ============================================================
ShowKeybindBuilder(ownerGui, eHotkeyDisplay, eHotkeyAhk) {
    ownerGui.Hide()

    kb := Gui("+AlwaysOnTop +ToolWindow", "Criar Keybind")
    kb.BackColor := "FFFFFF"
    kb.SetFont("s9", "Segoe UI")

    kb.Add("Text", "x12 y12 w380 cGray", "1. Marque os modificadores desejados:")
    cbCtrl  := kb.Add("CheckBox", "x12  y30 w60", "Ctrl")
    cbShift := kb.Add("CheckBox", "x78  y30 w60", "Shift")
    cbAlt   := kb.Add("CheckBox", "x148 y30 w60", "Alt")

    kb.Add("Text", "x12 y62 w380 cGray", "2. Capturando tecla - pressione para registrar:")
    btnCapt := kb.Add("Button", "x12 y80 w200 h28", "Parar captura")

    kb.SetFont("s10 bold")
    eCaptured := kb.Add("Text", "x12 y122 w370 h28 +Center Background0xE0E0E0 0x200", "")
    kb.SetFont("s9 norm")

    kb.Add("Text", "x12 y162 w370 cGray", "3. Previa da combinacao:")
    kb.SetFont("s10 bold cBlack")
    txtPreview := kb.Add("Text", "x12 y178 w370 h26 +Center Background0xE0E0E0 0x200", "nenhuma keybind definida")
    kb.SetFont("s9 norm cBlack")

    btnOk     := kb.Add("Button", "x12  y216 w100 h28", "Inserir")
    btnCancel := kb.Add("Button", "x118 y216 w80  h28", "Fechar")

    UpdatePreview := KB_UpdatePreview.Bind(cbCtrl, cbAlt, cbShift, eCaptured, txtPreview)

    cbCtrl.OnEvent("Click",  (*) => UpdatePreview())
    cbShift.OnEvent("Click", (*) => UpdatePreview())
    cbAlt.OnEvent("Click",   (*) => UpdatePreview())

    stopCapture := [false]

    btnCapt.OnEvent("Click",   KB_ToggleCapture.Bind(btnCapt, eCaptured, UpdatePreview, stopCapture))
    btnOk.OnEvent("Click",     KB_Insert.Bind(kb, ownerGui, eHotkeyDisplay, eHotkeyAhk, cbCtrl, cbAlt, cbShift, eCaptured, stopCapture))
    btnCancel.OnEvent("Click", KB_Close.Bind(kb, ownerGui, stopCapture))
    kb.OnEvent("Close",        KB_Close.Bind(kb, ownerGui, stopCapture))

    kb.Show("w396 h260")
    SetTimer KB_CaptureLoop.Bind(btnCapt, eCaptured, UpdatePreview, stopCapture), -1
}

KB_UpdatePreview(cbCtrl, cbAlt, cbShift, eCaptured, txtPreview, *) {
    display := ""
    if cbCtrl.Value
        display .= "Ctrl + "
    if cbAlt.Value
        display .= "Alt + "
    if cbShift.Value
        display .= "Shift + "
    key := eCaptured.Value
    if key != ""
        display .= key
    if display = "" || key = ""
        txtPreview.Value := "nenhuma keybind definida"
    else
        txtPreview.Value := display
}

KB_CaptureLoop(btnCapt, eCaptured, UpdatePreview, stopCapture) {
    stopCapture[1] := false
    btnCapt.Text   := "Parar captura"
    loop {
        if stopCapture[1]
            break
        ih := InputHook("L0 B T2")
        ih.KeyOpt("{All}", "SE")
        ih.Start()
        ih.Wait()
        if stopCapture[1]
            break
        if ih.EndKey != "" && ih.EndKey != "LButton" && ih.EndKey != "RButton"
            eCaptured.Value := ih.EndKey
        try UpdatePreview()
    }
    try btnCapt.Text := "Iniciar captura"
}

KB_ToggleCapture(btnCapt, eCaptured, UpdatePreview, stopCapture, *) {
    if !stopCapture[1] {
        stopCapture[1] := true
        return
    }
    SetTimer KB_CaptureLoop.Bind(btnCapt, eCaptured, UpdatePreview, stopCapture), -1
}

KB_Close(kb, ownerGui, stopCapture, *) {
    stopCapture[1] := true
    kb.Destroy()
    ownerGui.Show()
}

KB_Insert(kb, ownerGui, eHotkeyDisplay, eHotkeyAhk, cbCtrl, cbAlt, cbShift, eCaptured, stopCapture, *) {
    key := eCaptured.Value
    if key = "" {
        return
    }
    stopCapture[1] := true
    mods    := ""
    display := ""
    if cbCtrl.Value {
        mods .= "^"
        display .= "Ctrl + "
    }
    if cbAlt.Value {
        mods .= "!"
        display .= "Alt + "
    }
    if cbShift.Value {
        mods .= "+"
        display .= "Shift + "
    }
    display .= key

    eHotkeyDisplay.Enabled := true
    eHotkeyDisplay.Value   := display
    eHotkeyDisplay.Enabled := false
    eHotkeyAhk.Value       := mods . key
    kb.Destroy()
    ownerGui.Show()
}

; ============================================================
;  UTILITARIOS DE JANELA ALVO (identificador composto)
;  Formato interno: TITLE::<titulo>||EXE::<processo>
;  Formato legado : ahk_exe <processo>  (compatibilidade)
; ============================================================

; Retorna Map com chaves "title" e "exe".
; Suporta o formato legado "ahk_exe xxx" e o novo composto.
ParseWindowTarget(winVal) {
    result := Map()
    result["title"] := ""
    result["exe"]   := ""
    if winVal = "" || winVal = "DESKTOP" {
        result["exe"] := winVal
        return result
    }
    if RegExMatch(winVal, "^TITLE::(.+)\|\|EXE::(.+)$", &m) {
        result["title"] := Trim(m[1])
        exeRaw := Trim(m[2])
        ; Se o campo EXE contiver um caminho completo (com \ ou /),
        ; extrai apenas o nome do arquivo para uso em ahk_exe.
        ; O caminho completo e preservado em "exePath" para uso no Run.
        if InStr(exeRaw, "\") || InStr(exeRaw, "/") {
            result["exePath"] := exeRaw
            if RegExMatch(exeRaw, "[^\\\\/]+$", &fn)
                result["exe"] := fn[0]
            else
                result["exe"] := exeRaw
        } else {
            result["exe"] := exeRaw
        }
        return result
    }
    ; Formato legado: "ahk_exe firefox.exe"
    if SubStr(winVal, 1, 8) = "ahk_exe " {
        result["exe"] := SubStr(winVal, 9)
        return result
    }
    ; Fallback generico
    result["exe"] := winVal
    return result
}

; Para exibicao amigavel na ListView e no campo eWindow
FormatWindowDisplay(winVal) {
    if winVal = "" || winVal = "DESKTOP"
        return winVal
    parsed := ParseWindowTarget(winVal)
    if parsed["title"] != ""
        return parsed["exe"] . " — " . SubStr(parsed["title"], 1, 40) . (StrLen(parsed["title"]) > 40 ? "…" : "")
    return "ahk_exe " parsed["exe"]
}

; Verifica se a janela alvo existe E tem o titulo correto.
; Retorna o HWND da janela correspondente, ou 0 se nao encontrada.
FindTargetWindow(winVal) {
    if winVal = "" || winVal = "DESKTOP"
        return 0
    parsed := ParseWindowTarget(winVal)
    exeName := parsed["exe"]
    title   := parsed["title"]

    if exeName = ""
        return 0

    ; Sem titulo gravado: comportamento legado (qualquer janela do processo)
    if title = "" {
        hwnd := WinExist("ahk_exe " exeName)
        return hwnd ? hwnd : 0
    }

    ; Com titulo: itera todas as janelas do processo buscando titulo compativel.
    ; Usa as primeiras palavras significativas do titulo gravado como chave de busca.
    ; Extrai a parte relevante apos " — " ou " - " (tipico de browsers) se existir,
    ; senao usa os primeiros 30 chars do titulo.
    searchKey := title
    if RegExMatch(title, "^(.+?) [—\-] ", &mm)
        searchKey := Trim(mm[1])          ; ex: "Meu Site" de "Meu Site — Firefox"
    else
        searchKey := SubStr(title, 1, 35)

    ; Busca janelas do processo que contenham a chave no titulo
    hwnd := WinExist(searchKey " ahk_exe " exeName)
    if hwnd
        return hwnd

    ; Fallback: qualquer janela do processo cujo titulo contenha searchKey
    try {
        ids := WinGetList("ahk_exe " exeName)
        for id in ids {
            try {
                t := WinGetTitle("ahk_id " id)
                if InStr(t, searchKey)
                    return id
            }
        }
    }
    return 0
}


AhkToDisplay(hkStr) {
    if hkStr = "" || hkStr = "Nenhuma"
        return "Nenhuma"
    display := ""
    if InStr(hkStr, "^")
        display .= "Ctrl + "
    if InStr(hkStr, "!")
        display .= "Alt + "
    if InStr(hkStr, "+")
        display .= "Shift + "
    key := RegExReplace(hkStr, "[<>^!#+]", "")
    display .= key
    return display
}

ValidateHotkey(hkStr) {
    if hkStr = ""
        return false
    key := RegExReplace(hkStr, "[<>^!#+*~$]", "")
    if key = ""
        return false
    return true
}

; ============================================================
;  GRAVAR / EDITAR MACRO
; ============================================================
RecordDialog(editName := "") {
    global RecSteps, Recording, Macros

    StopRecHook()
    RecSteps  := []
    Recording := false

    isEdit      := (editName != "")
    m           := isEdit ? Macros[editName] : Map()
    initHkAhk   := isEdit && m.Has("hotkey")     ? m["hotkey"]     : ""
    initWindow  := isEdit && m.Has("window")      ? m["window"]     : ""
    initRepMode := isEdit && m.Has("repeatMode")  ? m["repeatMode"] : "none"
    initRepVal  := isEdit && m.Has("repeatVal")   ? m["repeatVal"]  : 1
    initRepWait := isEdit && m.Has("repeatWait")  ? m["repeatWait"] : 500

    if isEdit {
        for s in m["steps"] {
            if !RegExMatch(s, "^WINOPEN ")
                RecSteps.Push(s)
        }
    }

    winTitle := isEdit ? "Editar: " editName : "Gravar Macro"
    g := Gui("+AlwaysOnTop", winTitle)
    g.BackColor := "FFFFFF"
    g.SetFont("s9", "Segoe UI")

    g.Add("Text",   "x12 y12",  "Nome da macro:")
    eName := g.Add("Edit", "x12 y28 w310", isEdit ? editName : "")

    g.Add("Text",   "x12 y58",  "Keybind:")
    eHotkeyDisplay := g.Add("Edit", "x12 y74 w200 +ReadOnly -TabStop", AhkToDisplay(initHkAhk))
    eHotkeyDisplay.Enabled := false
    eHotkeyAhk := g.Add("Edit", "x12 y999 w1 h1 +Hidden", initHkAhk)
    g.Add("Button", "x218 y73 h22 w90", "Criar").OnEvent("Click", (*) => ShowKeybindBuilder(g, eHotkeyDisplay, eHotkeyAhk))

    g.Add("Text", "x12 y104", "Janela alvo (preenchida automaticamente no 1o clique):")
    eWindow := g.Add("Edit", "x12 y120 w310 h22 +ReadOnly -TabStop Background0xF0F0F0", initWindow)
    eWindow.Enabled := false

    g.Add("Text", "x12 y152 w310 h1 +0x10")
    g.Add("Text", "x12 y162", "Repeticao:")
    rbRepeatNone   := g.Add("Radio", "x12  y180 w95",  "Sem repetir")
    rbRepeatTimes  := g.Add("Radio", "x112 y180 w70",  "Vezes")
    rbRepeatMin    := g.Add("Radio", "x188 y180 w70",  "Minutos")
    rbRepeatClicks := g.Add("Radio", "x12  y204 w90",  "Cliques")
    g.Add("Text",           "x112 y206 w80",           "Quantidade:")
    eRepeatVal  := g.Add("Edit", "x200 y204 w60 +Number", initRepVal)
    g.Add("Text", "x12 y232", "Espera entre ciclos (ms):")
    eRepeatWait := g.Add("Edit", "x200 y230 w60 +Number", initRepWait)

    if initRepMode = "times"
        rbRepeatTimes.Value := 1
    else if initRepMode = "minutes"
        rbRepeatMin.Value := 1
    else if initRepMode = "clicks"
        rbRepeatClicks.Value := 1
    else
        rbRepeatNone.Value := 1

    isRepeat := (initRepMode != "none")
    eRepeatVal.Enabled  := isRepeat
    eRepeatWait.Enabled := isRepeat

    ToggleRepeatFields := ToggleRepeat.Bind(rbRepeatNone, eRepeatVal, eRepeatWait)
    rbRepeatNone.OnEvent("Click",   ToggleRepeatFields)
    rbRepeatTimes.OnEvent("Click",  ToggleRepeatFields)
    rbRepeatMin.OnEvent("Click",    ToggleRepeatFields)
    rbRepeatClicks.OnEvent("Click", ToggleRepeatFields)

    g.Add("Text", "x12 y260 w310 h1 +0x10")
    g.Add("Text", "x12 y270 w310", "1. Clique em Iniciar gravacao" . "`n" . "2. Clique nas posicoes desejadas" . "`n" . "3. Clique em Parar para encerrar")
    g.SetFont("s8 cGray")
    g.Add("Text", "x12 y316 w310", "Apenas cliques sao gravados.")
    g.SetFont("s9 cBlack")

    btnRec  := g.Add("Button", "x12  y348 w148 h30", "Iniciar gravacao")
    btnStop := g.Add("Button", "x166 y348 w100 h30", "Parar")
    btnStop.Enabled := false

    ePreview := g.Add("Edit", "x12 y388 w250 h80 +ReadOnly -TabStop +Multi Background0xF0F0F0 -WantReturn")
    btnClear := g.Add("Button", "x268 y388 w54 h80", "Limpar")

    previewTxt := ""
    for s in RecSteps
        previewTxt .= s "`n"
    if previewTxt != ""
        ePreview.Value := previewTxt

    btnSave := g.Add("Button", "x12  y478 w100 h28", "Salvar")
    btnSave.Enabled := isEdit
    g.Add("Button", "x118 y478 w80 h28", "Fechar").OnEvent("Click", (*) => RecCancel(g))

    checkFn := CheckSaveReady.Bind(eName, eHotkeyAhk, btnSave)
    eName.OnEvent("Change", checkFn)
    eHotkeyAhk.OnEvent("Change", checkFn)

    btnClear.OnEvent("Click", (*) => ClearRecSteps(ePreview))
    btnRec.OnEvent("Click",  (*) => StartRec(g, btnRec, btnStop, ePreview, eWindow, btnSave, checkFn))
    btnStop.OnEvent("Click", (*) => StopRec(btnRec, btnStop, ePreview))
    btnSave.OnEvent("Click", (*) => SaveRecMacro(g, eName, eHotkeyAhk, eWindow, rbRepeatNone, rbRepeatTimes, rbRepeatMin, rbRepeatClicks, eRepeatVal, eRepeatWait, isEdit ? editName : ""))
    g.OnEvent("Close", (*) => RecCancel(g))
    g.Show("w336 h520")
}

ClearRecSteps(ePreview) {
    global RecSteps
    RecSteps       := []
    ePreview.Value := ""
}

CheckSaveReady(eName, eHotkeyAhk, btnSave, *) {
    hasName := (Trim(eName.Value) != "")
    hasHK   := (Trim(eHotkeyAhk.Value) != "")
    try btnSave.Enabled := (hasName || hasHK)
}

ToggleRepeat(rbRepeatNone, eRepeatVal, eRepeatWait, *) {
    isRepeat := !rbRepeatNone.Value
    eRepeatVal.Enabled  := isRepeat
    eRepeatWait.Enabled := isRepeat
}

; ============================================================
;  ENGINE DE GRAVACAO
; ============================================================
StopRecHook() {
    global Recording, G_RecCallback
    Recording     := false
    G_RecCallback := 0
    try HotKey "~LButton Up", "Off"
}

StartRec(recGui, btnRec, btnStop, ePreview, eWindow, btnSave, checkFn) {
    global Recording, RecSteps, G_RecCallback

    StopRecHook()
    RecSteps        := []
    Recording       := true
    btnRec.Enabled  := false
    btnStop.Enabled := true
    ePreview.Value  := "Gravando... clique nas posicoes desejadas." . "`n"

    recHwnd := recGui.Hwnd

    G_RecCallback := RecClick_Make(ePreview, eWindow, recHwnd, btnSave, checkFn)
    HotKey "~LButton Up", "On"
}

RecClick_Make(ePreview, eWindow, recHwnd, btnSave, checkFn) {
    return () => RecClick_Core(ePreview, eWindow, recHwnd, btnSave, checkFn)
}

StopRec(btnRec, btnStop, ePreview) {
    global Recording, RecSteps
    if !Recording
        return
    StopRecHook()
    btnRec.Enabled  := true
    btnStop.Enabled := false
    if RecSteps.Length = 0
        ePreview.Value := "(nenhum clique gravado)"
}

RecClick_Core(ePreview, eWindow, recHwnd, btnSave, checkFn) {
    global Recording, RecSteps, G_RecCallback
    if !Recording || G_RecCallback = 0
        return

    MouseGetPos &mx, &my, &winHwnd

    if (winHwnd = recHwnd)
        return

    isDesktop := false
    try {
        winClass := WinGetClass("ahk_id " winHwnd)
        if (winClass = "WorkerW" || winClass = "Progman")
            isDesktop := true
    }

    if RecSteps.Length = 0 {
        eWindow.Enabled := true
        if isDesktop {
            eWindow.Value := "DESKTOP"
        } else {
            try {
                exeName  := WinGetProcessName("ahk_id " winHwnd)
                winTitle := WinGetTitle("ahk_id " winHwnd)
                ; Tenta obter o caminho completo do exe para que Run funcione
                ; mesmo apos reinicio, sem depender do PATH do sistema.
                exePath := ""
                try exePath := WinGetProcessPath("ahk_id " winHwnd)
                ; Usa caminho completo se disponivel, senao usa nome simples
                exeRef := (exePath != "") ? exePath : exeName
                ; Armazena identificador composto: titulo + caminho do exe
                ; Formato: TITLE::<titulo>||EXE::<caminho_ou_nome>
                eWindow.Value := "TITLE::" winTitle "||EXE::" exeRef
            }
        }
        eWindow.Enabled := false
        SetTimer checkFn, -50
    }

    if isDesktop {
        step := "CLICK_ABS " mx " " my
    } else {
        try {
            WinGetPos &wx, &wy, &ww, &wh, "ahk_id " winHwnd
            relX := mx - wx
            relY := my - wy
            step := "CLICK_REL " relX " " relY
        } catch {
            step := "CLICK_ABS " mx " " my
        }
    }

    RecSteps.Push(step)

    ePreview.Value .= step . "`n"
    len := StrLen(ePreview.Value)
    SendMessage 0x00B1, len, len,, ePreview.Hwnd
    SendMessage 0x00B7, 0, 0,, ePreview.Hwnd
}

RecCancel(g) {
    StopRecHook()
    g.Destroy()
    ReturnToMain()
}

SaveRecMacro(g, eName, eHotkeyAhk, eWindow, rbRepeatNone, rbRepeatTimes, rbRepeatMin, rbRepeatClicks, eRepeatVal, eRepeatWait, oldName) {
    global Macros, RecSteps

    StopRecHook()

    name := Trim(eName.Value)
    hkStr := Trim(eHotkeyAhk.Value)

    ; Se nome vazio, usa a keybind como nome default
    if name = "" {
        if hkStr != ""
            name := AhkToDisplay(hkStr)
        if name = ""
            return
    }

    if hkStr != "" && !ValidateHotkey(hkStr)
        return

    repeatMode := "none"
    repeatVal  := 1
    repeatWait := 500
    if rbRepeatTimes.Value {
        repeatMode := "times"
        repeatVal  := Integer(eRepeatVal.Value) > 0 ? Integer(eRepeatVal.Value) : 1
        repeatWait := Integer(eRepeatWait.Value)
    } else if rbRepeatMin.Value {
        repeatMode := "minutes"
        repeatVal  := Integer(eRepeatVal.Value) > 0 ? Integer(eRepeatVal.Value) : 1
        repeatWait := Integer(eRepeatWait.Value)
    } else if rbRepeatClicks.Value {
        repeatMode := "clicks"
        repeatVal  := Integer(eRepeatVal.Value) > 0 ? Integer(eRepeatVal.Value) : 1
        repeatWait := Integer(eRepeatWait.Value)
    }

    if oldName != "" && oldName != name && Macros.Has(oldName)
        Macros.Delete(oldName)

    winVal := Trim(eWindow.Value)
    m := Map()
    m["hotkey"]     := hkStr
    m["window"]     := winVal
    m["repeatMode"] := repeatMode
    m["repeatVal"]  := repeatVal
    m["repeatWait"] := repeatWait
    m["steps"]      := []

    if winVal != ""
        m["steps"].Push("WINOPEN " winVal)
    for s in RecSteps
        m["steps"].Push(s)

    Macros[name] := m
    SaveMacros()
    ApplyHotkeys()
    g.Destroy()
    ReturnToMain()
}

; ============================================================
;  EXCLUIR / EXECUTAR
; ============================================================
DeleteMacro() {
    global Macros, MacroLV

    ; Coleta todos os nomes selecionados antes de apagar qualquer um
    selectedNames := []
    row := 0
    loop {
        row := MacroLV.GetNext(row, "F")
        if !row
            break
        selectedNames.Push(MacroLV.GetText(row, 1))
    }

    if selectedNames.Length = 0
        return

    for name in selectedNames {
        if Macros.Has(name)
            Macros.Delete(name)
    }

    SaveMacros()
    ApplyHotkeys()
    RefreshList()
}

RunSelected() {
    global MacroLV
    row := MacroLV.GetNext(0, "F")
    if !row {
        MsgBox "O botão Executar serve para acionar manualmente uma macro salva.`n`nSelecione uma macro na lista e clique em Executar novamente.", "Executar Macro", "Icon!"
        return
    }
    ExecuteMacroOnce(MacroLV.GetText(row, 1))
}

; ============================================================
;  HOTKEYS DINAMICOS
;  - Macros SEM repeticao: executa uma vez ao pressionar.
;  - Macros COM repeticao: a mesma keybind inicia o loop na
;    primeira vez e PARA o loop na segunda vez (toggle).
; ============================================================
ApplyHotkeys(*) {
    global Macros, ActiveHKs, RunningLoops

    ; Para todos os loops ativos
    for loopName, running in RunningLoops
        RunningLoops[loopName] := false
    RunningLoops := Map()

    ; Desativa hotkeys anteriores.
    ; IMPORTANTE: "Delete" NAO e um segundo parametro valido no AHKv2 —
    ; usar HotKey(hk, "Delete") lanca excecao e corrompe o estado do hotkey,
    ; fazendo com que na proxima carga do script o registro falhe silenciosamente.
    ; A unica forma correta e HotKey(hk, "Off").
    for hk, fn in ActiveHKs {
        try HotKey hk, "Off"
    }
    ActiveHKs := Map()

    ; Garante hooks instalados para hotkeys dinamicos com BoundFunc
    InstallKeybdHook
    InstallMouseHook

    for name, m in Macros {
        hk := Trim(m["hotkey"])
        if hk = "" || hk = "Nenhuma"
            continue
        fn := MacroHotkeyHandler.Bind(name)
        try {
            HotKey hk, fn
            HotKey hk, "On"
            ActiveHKs[hk] := fn
        }
    }
}

; Handler unificado da keybind.
; Sem repeticao: executa uma vez.
; Com repeticao: toggle (inicia / para o loop).
MacroHotkeyHandler(macroName, *) {
    global Macros, RunningLoops

    if !Macros.Has(macroName)
        return

    m          := Macros[macroName]
    repeatMode := m.Has("repeatMode") ? m["repeatMode"] : "none"

    if repeatMode = "none" {
        ExecuteMacroOnce(macroName)
        return
    }

    ; Toggle do loop
    if RunningLoops.Has(macroName) && RunningLoops[macroName] {
        RunningLoops[macroName] := false
    } else {
        RunningLoops[macroName] := true
        SetTimer RunMacroLoop.Bind(macroName), -1
    }
}

; Loop do macro em thread separada (SetTimer -1).
; Verifica RunningLoops[macroName] a cada ciclo.
RunMacroLoop(macroName) {
    global Macros, ConfigFile, RunningLoops

    if !Macros.Has(macroName) {
        if RunningLoops.Has(macroName)
            RunningLoops[macroName] := false
        return
    }

    m          := Macros[macroName]
    repeatMode := m.Has("repeatMode") ? m["repeatMode"] : "none"
    repeatVal  := m.Has("repeatVal")  ? m["repeatVal"]  : 1
    repeatWait := m.Has("repeatWait") ? m["repeatWait"] : 500
    delay := 0
    rawDelay := IniRead(ConfigFile, "Settings", "StepDelay", "150")
    delay := (rawDelay != "") ? Integer(rawDelay) : 150
    if delay < 1
        delay := 1

    if Trim(m["window"]) = "" {
        RunningLoops[macroName] := false
        return
    }

    ; NAO bloqueia aqui se a janela nao existe:
    ; o passo WINOPEN dentro dos steps ja cuida de abrir a janela.
    ; Bloquear aqui impedia o WINOPEN de executar apos reinicio do PC.

    Send "{Shift up}{Ctrl up}{Alt up}{LWin up}{RWin up}"

    if repeatMode = "times" || repeatMode = "clicks" {
        i := 0
        while i < repeatVal {
            if !RunningLoops.Has(macroName) || !RunningLoops[macroName]
                break
            RunMacroSteps(m, delay)
            i++
            if i < repeatVal {
                if !RunningLoops.Has(macroName) || !RunningLoops[macroName]
                    break
                Sleep repeatWait
            }
        }
    } else if repeatMode = "minutes" {
        endTime := A_TickCount + (repeatVal * 60000)
        while A_TickCount < endTime {
            if !RunningLoops.Has(macroName) || !RunningLoops[macroName]
                break
            RunMacroSteps(m, delay)
            if A_TickCount < endTime {
                if !RunningLoops.Has(macroName) || !RunningLoops[macroName]
                    break
                Sleep repeatWait
            }
        }
    }

    RunningLoops[macroName] := false
}

; ============================================================
;  EXECUTAR MACRO (uma vez, sem loop — botao Executar da GUI)
; ============================================================
ExecuteMacroOnce(macroName) {
    global Macros, ConfigFile

    if !Macros.Has(macroName)
        return

    m := Macros[macroName]

    if Trim(m["window"]) = ""
        return

    ; NAO bloqueia aqui se a janela nao existe:
    ; o passo WINOPEN dentro dos steps ja cuida de abrir a janela
    ; caso ela nao esteja aberta (ex: apos reinicio do PC).
    ; Bloquear aqui impedia o WINOPEN de executar, causando o erro
    ; "Get an app to open this 'title' link" no Windows.

    Send "{Shift up}{Ctrl up}{Alt up}{LWin up}{RWin up}"
    rawDelay := IniRead(ConfigFile, "Settings", "StepDelay", "150")
    delay := (rawDelay != "") ? Integer(rawDelay) : 150
    if delay < 1
        delay := 1
    RunMacroSteps(m, delay)
}

RunMacroSteps(m, delay) {
    winTarget := m["window"]

    for step in m["steps"] {
        step := Trim(step)
        if step = "" || SubStr(step, 1, 1) = ";"
            continue
        parts := StrSplit(step, " ",, 3)
        cmd   := parts[1]
        p2    := parts.Length >= 2 ? parts[2] : ""
        p3    := parts.Length >= 3 ? parts[3] : ""

        if cmd = "CLICK_REL" {
            if winTarget != "" && winTarget != "DESKTOP" {
                ; Localiza a janela correta (titulo + exe) em qualquer monitor
                hwnd := FindTargetWindow(winTarget)
                if !hwnd {
                    ; Janela/aba alvo nao encontrada — aborta o macro
                    return
                }
                try {
                    WinActivate "ahk_id " hwnd
                    WinWaitActive "ahk_id " hwnd,, 2
                    WinGetPos &wx, &wy,, , "ahk_id " hwnd
                    absX := wx + Integer(p2)
                    absY := wy + Integer(p3)
                    Click absX, absY
                } catch {
                    Click Integer(p2), Integer(p3)
                }
            } else {
                Click Integer(p2), Integer(p3)
            }
        } else if cmd = "CLICK_ABS" {
            Click Integer(p2), Integer(p3)
        } else if cmd = "CLICK" {
            Click Integer(p2), Integer(p3)
        } else if cmd = "KEY" {
            Send "{" p2 "}"
        } else if cmd = "SEND" {
            Send SubStr(step, 6)
        } else if cmd = "URL" {
            Run p2
        } else if cmd = "WAIT" {
            Sleep Integer(p2)
        } else if cmd = "COPY" {
            A_Clipboard := SubStr(step, 6)
        } else if cmd = "RUN" {
            Run SubStr(step, 5)
        } else if cmd = "WINOPEN" {
            winTarget := SubStr(step, 9)
            if winTarget = "DESKTOP" {
                Send "#d"
                Sleep 400
            } else {
                ; Tenta localizar janela existente com titulo+exe
                hwnd := FindTargetWindow(winTarget)
                if hwnd {
                    WinActivate "ahk_id " hwnd
                    WinWaitActive "ahk_id " hwnd,, 3
                } else {
                    ; Janela nao encontrada: tenta abrir o processo.
                    ; Usa apenas o exeName extraido (ex: "chrome.exe").
                    ; Run com nome de exe simples pode falhar no Win11 se o exe
                    ; nao estiver no PATH — por isso tentamos primeiro obter
                    ; o caminho completo via ProcessGetPath (AHK v2 built-in),
                    ; e so como fallback usamos o nome simples.
                    parsed  := ParseWindowTarget(winTarget)
                    exeName := parsed["exe"]
                    ; Usa o caminho completo (exePath) se foi salvo ao gravar a macro,
                    ; senao tenta obter de um processo em execucao,
                    ; e como ultimo recurso usa o nome simples do exe.
                    exePath := parsed.Has("exePath") ? parsed["exePath"] : ""
                    if exePath = "" {
                        try {
                            ; ProcessGetList nao existe no AHK v2.
                            ; Usa ProcessExist para obter o PID do exe se ele ja estiver rodando,
                            ; e ProcessGetPath(pid) para recuperar o caminho completo.
                            pid := ProcessExist(exeName)
                            if pid
                                exePath := ProcessGetPath(pid)
                        }
                    }
                    if exePath != "" {
                        try Run exePath
                    } else {
                        try Run exeName
                    }
                    Sleep 1500
                    ; Aguarda qualquer janela do processo
                    try WinWaitActive "ahk_exe " exeName,, 3
                }
            }
        }
        if delay > 1
            Sleep delay
        else if delay = 1
            Sleep 0
    }
}

; ============================================================
;  CLICKER SIMPLES
; ============================================================

LoadClickerCfg() {
    global ConfigFile, ClickerCfg, ClickerHK, ClickerEnabled
    ClickerCfg := Map()
    ClickerCfg["hk"]         := IniRead(ConfigFile, "Clicker", "Hotkey",      "F3")
    ClickerCfg["hkDisplay"]  := IniRead(ConfigFile, "Clicker", "HotkeyDisp",  "F3")
    ClickerCfg["repeatMode"] := IniRead(ConfigFile, "Clicker", "RepeatMode",  "infinite")
    rVal := Integer(IniRead(ConfigFile, "Clicker", "RepeatVal", "10"))
    ClickerCfg["repeatVal"]  := (rVal >= 1) ? rVal : 10
    iVal := Integer(IniRead(ConfigFile, "Clicker", "Interval",  "100"))
    ClickerCfg["interval"]   := (iVal >= 1) ? iVal : 100
    ClickerEnabled := (IniRead(ConfigFile, "Clicker", "Enabled", "1") = "1")
    ClickerHK := ClickerCfg["hk"]
    ApplyClickerHotkey()
}

SaveClickerCfg() {
    global ConfigFile, ClickerCfg, ClickerEnabled
    IniWrite ClickerCfg["hk"],         ConfigFile, "Clicker", "Hotkey"
    IniWrite ClickerCfg["hkDisplay"],  ConfigFile, "Clicker", "HotkeyDisp"
    IniWrite ClickerCfg["repeatMode"], ConfigFile, "Clicker", "RepeatMode"
    IniWrite ClickerCfg["repeatVal"],  ConfigFile, "Clicker", "RepeatVal"
    IniWrite ClickerCfg["interval"],   ConfigFile, "Clicker", "Interval"
    IniWrite (ClickerEnabled ? "1" : "0"), ConfigFile, "Clicker", "Enabled"
}

; Registra (ou atualiza) o hotkey global do clicker.
; A keybind funciona independente de o clicker estar aberto ou nao.
ApplyClickerHotkey() {
    global ClickerHK, ClickerCfg
    ; Remove hotkey anterior se existia
    static lastHK := ""
    if lastHK != "" {
        try HotKey lastHK, "Off"
    }
    hk := Trim(ClickerCfg["hk"])
    if hk = ""
        return
    try {
        HotKey hk, ClickerHotkeyHandler
        HotKey hk, "On"
        lastHK := hk
        ClickerHK := hk
    }
}

; Toggle: inicia ou pausa o clicker ao pressionar a keybind
ClickerHotkeyHandler(*) {
    global ClickerRunning, ClickerEnabled
    if !ClickerEnabled
        return
    if ClickerRunning
        StopClicker()
    else
        StartClicker()
}

StartClicker() {
    global ClickerRunning, ClickerCfg, ClickerGui
    ClickerRunning := true
    UpdateClickerLabel()
    SetTimer DoClick, ClickerCfg["interval"]
    ; Se for por quantidade, agenda parada
    if ClickerCfg["repeatMode"] = "times" {
        totalMs := ClickerCfg["repeatVal"] * ClickerCfg["interval"]
        SetTimer StopClicker, -totalMs
    } else if ClickerCfg["repeatMode"] = "minutes" {
        totalMs := ClickerCfg["repeatVal"] * 60000
        SetTimer StopClicker, -totalMs
    }
}

StopClicker(*) {
    global ClickerRunning
    ClickerRunning := false
    SetTimer DoClick, 0
    try SetTimer StopClicker, 0
    UpdateClickerLabel()
}

ToggleClickerEnabled() {
    global ClickerEnabled, ClickerEnabledCB, ClickerRunning
    ClickerEnabled := IsObject(ClickerEnabledCB) ? (ClickerEnabledCB.Value = 1) : !ClickerEnabled
    ; Se foi desativado enquanto corria, para imediatamente
    if !ClickerEnabled && ClickerRunning
        StopClicker()
    SaveClickerCfg()
}

DoClick() {
    global ClickerRunning
    if !ClickerRunning {
        SetTimer DoClick, 0
        return
    }
    Click
}

; Atualiza o texto do label de status na janela do clicker (se aberta)
UpdateClickerLabel() {
    global ClickerGui, ClickerRunning, ClickerCfg
    if !IsObject(ClickerGui)
        return
    try {
        hkDisp := ClickerCfg["hkDisplay"]
        if ClickerRunning
            ClickerGui["statusLbl"].Value := "Pressione [" hkDisp "] para pausar"
        else
            ClickerGui["statusLbl"].Value := "Pressione [" hkDisp "] para clicar"
    }
}

ShowClickerGui() {
    global ClickerGui, ClickerCfg, ClickerRunning

    ; Garante que clicker parado ao abrir
    StopClicker()

    g := Gui("+AlwaysOnTop", "Clicker Simples")
    g.BackColor := "FFFFFF"
    g.SetFont("s10", "Segoe UI")
    ClickerGui := g

    hkDisp := ClickerCfg["hkDisplay"]

    ; --- Status ---
    g.SetFont("s11 bold")
    g.Add("Text", "x12 y18 w320 h28 +Center vstatusLbl", "Pressione [" hkDisp "] para clicar")
    g.SetFont("s9 norm")

    ; --- Separador + titulo Configuracoes ---
    g.Add("Text", "x12 y56 w320 h1 +0x10")
    g.SetFont("s9 Bold cBlack")
    g.Add("Text", "x12 y64", "Configurações:")
    g.SetFont("s9 norm cBlack")

    ; ---- Keybind ----
    g.Add("Text", "x12 y84 w320", "Keybind (tecla ou botao do mouse):")
    eHkDisp := g.Add("Edit", "x12 y100 w200 +ReadOnly -TabStop Background0xF0F0F0", ClickerCfg["hkDisplay"])
    eHkAhk  := g.Add("Edit", "x12 y999 w1 h1 +Hidden", ClickerCfg["hk"])
    g.Add("Button", "x218 y99 w100 h22", "Alterar").OnEvent("Click", (*) => ShowClickerKeybindBuilder(g, eHkDisp, eHkAhk))

    ; ---- Repeticao ----
    g.Add("Text", "x12 y132", "Modo de repeticao:")
    rbInfinite := g.Add("Radio", "x12  y150 w110", "Ate desativar")
    rbTimes    := g.Add("Radio", "x128 y150 w70",  "Vezes")
    rbMinutes  := g.Add("Radio", "x204 y150 w70",  "Minutos")

    g.Add("Text", "x12 y180", "Quantidade (vezes ou minutos):")
    eVal := g.Add("Edit", "x12 y196 w80 +Number", ClickerCfg["repeatVal"])

    g.Add("Text", "x12 y226", "Intervalo entre cliques (ms):")
    eInterval := g.Add("Edit", "x12 y242 w80 +Number", String(ClickerCfg["interval"]))

    ; Seleciona radio conforme config atual
    if ClickerCfg["repeatMode"] = "times"
        rbTimes.Value := 1
    else if ClickerCfg["repeatMode"] = "minutes"
        rbMinutes.Value := 1
    else
        rbInfinite.Value := 1

    ; Habilita/desabilita campo de quantidade conforme modo
    eVal.Enabled := (ClickerCfg["repeatMode"] != "infinite")
    ToggleCfgVal := (*) => (eVal.Enabled := !rbInfinite.Value)
    rbInfinite.OnEvent("Click", ToggleCfgVal)
    rbTimes.OnEvent("Click",    ToggleCfgVal)
    rbMinutes.OnEvent("Click",  ToggleCfgVal)

    g.Add("Button", "x12 y278 w100 h28", "Salvar").OnEvent("Click",
        (*) => SaveClickerCfgInline(g, eHkDisp, eHkAhk, rbInfinite, rbTimes, rbMinutes, eVal, eInterval))
    g.Add("Button", "x118 y278 w80 h28", "Fechar").OnEvent("Click", (*) => CloseClickerGui(g))
    g.OnEvent("Close", (*) => CloseClickerGui(g))

    g.Show("w344 h322")
}

CloseClickerGui(g) {
    global ClickerGui
    StopClicker()
    ClickerGui := 0
    g.Destroy()
    ReturnToMain()
}

SaveClickerCfgInline(g, eHkDisp, eHkAhk, rbInfinite, rbTimes, rbMinutes, eVal, eInterval) {
    global ClickerCfg, ClickerGui

    hk     := Trim(eHkAhk.Value)
    hkDisp := Trim(eHkDisp.Value)
    if hk = ""
        hk := "F3"
    if hkDisp = ""
        hkDisp := "F3"

    mode := "infinite"
    if rbTimes.Value
        mode := "times"
    else if rbMinutes.Value
        mode := "minutes"

    valStr := Trim(eVal.Value)
    ivlStr := Trim(eInterval.Value)
    val := (valStr != "") ? Integer(valStr) : 10
    if val <= 0
        val := 10
    ivl := (ivlStr != "") ? Integer(ivlStr) : 100
    if ivl <= 0
        ivl := 1

    ClickerCfg["hk"]         := hk
    ClickerCfg["hkDisplay"]  := hkDisp
    ClickerCfg["repeatMode"] := mode
    ClickerCfg["repeatVal"]  := val
    ClickerCfg["interval"]   := ivl

    SaveClickerCfg()
    ApplyClickerHotkey()
    try RefreshList()

    ClickerGui := 0
    g.Destroy()
    ReturnToMain()
}

; ---- Configuracoes do clicker (janela separada — mantida para compatibilidade interna) ----
OpenClickerCfg(ownerGui) {
    ; Redireciona: nao abre mais janela separada, a GUI unificada ja tem tudo
    ; Este metodo nao e mais chamado pela nova ShowClickerGui
}

CloseClickerCfgGui(cfgGui, ownerGui) {
    global ClickerCfgGui
    ClickerCfgGui := 0
    cfgGui.Destroy()
    ownerGui.Show()
}


; ---- Keybind builder exclusivo do clicker (aceita mouse buttons) ----
ShowClickerKeybindBuilder(ownerGui, eHkDisp, eHkAhk) {
    ownerGui.Hide()

    kb := Gui("+AlwaysOnTop +ToolWindow", "Keybind do Clicker")
    kb.BackColor := "FFFFFF"
    kb.SetFont("s9", "Segoe UI")

    kb.Add("Text", "x12 y12 w360 cGray", "Opcoes rapidas — botoes do mouse:")

    ; Botoes simples com texto claro
    kb.SetFont("s9 norm cBlack")
    btnMid := kb.Add("Button", "x12 y30 w110 h36", "Scroll (meio)")
    btnMid.OnEvent("Click", CKB_SetMouse.Bind(kb, ownerGui, eHkDisp, eHkAhk, "MButton", "Scroll (meio)"))

    btnX1 := kb.Add("Button", "x130 y30 w110 h36", "X1 — Voltar")
    btnX1.OnEvent("Click", CKB_SetMouse.Bind(kb, ownerGui, eHkDisp, eHkAhk, "XButton1", "X1 (Voltar)"))

    btnX2 := kb.Add("Button", "x248 y30 w110 h36", "X2 — Avançar")
    btnX2.OnEvent("Click", CKB_SetMouse.Bind(kb, ownerGui, eHkDisp, eHkAhk, "XButton2", "X2 (Avancar)"))

    kb.SetFont("s9 norm cGray")
    kb.Add("Text", "x12 y76 w360 cGray", "Ou capture uma tecla do teclado:")
    kb.Add("Text", "x12 y94 w360 cGray", "  Modificadores opcionais:")
    cbCtrl  := kb.Add("CheckBox", "x12  y110 w60", "Ctrl")
    cbShift := kb.Add("CheckBox", "x78  y110 w60", "Shift")
    cbAlt   := kb.Add("CheckBox", "x148 y110 w60", "Alt")

    kb.Add("Text", "x12 y138 w360 cGray", "  Pressione a tecla desejada:")
    btnCapt := kb.Add("Button", "x12 y156 w180 h26", "Parar captura")

    kb.SetFont("s10 bold")
    eCaptured := kb.Add("Text", "x12 y194 w350 h26 +Center Background0xE0E0E0 0x200", "")
    kb.SetFont("s9 norm")

    kb.Add("Text", "x12 y230 w350 cGray", "Previa:")
    kb.SetFont("s10 bold cBlack")
    txtPreview := kb.Add("Text", "x12 y246 w350 h26 +Center Background0xE0E0E0 0x200", "nenhuma keybind")
    kb.SetFont("s9 norm cBlack")

    btnOk     := kb.Add("Button", "x12  y282 w100 h28", "Confirmar")
    btnCancel := kb.Add("Button", "x118 y282 w80  h28", "Fechar")

    UpdatePrev := CKB_UpdatePreview.Bind(cbCtrl, cbAlt, cbShift, eCaptured, txtPreview)
    cbCtrl.OnEvent("Click",  (*) => UpdatePrev())
    cbShift.OnEvent("Click", (*) => UpdatePrev())
    cbAlt.OnEvent("Click",   (*) => UpdatePrev())

    stopCapt := [false]   ; começa já capturando

    btnCapt.OnEvent("Click", CKB_ToggleCapture.Bind(btnCapt, eCaptured, UpdatePrev, stopCapt))
    btnOk.OnEvent("Click",   CKB_Insert.Bind(kb, ownerGui, eHkDisp, eHkAhk, cbCtrl, cbAlt, cbShift, eCaptured, stopCapt))
    btnCancel.OnEvent("Click", (*) => (stopCapt[1] := true, kb.Destroy(), ownerGui.Show()))
    kb.OnEvent("Close",        (*) => (stopCapt[1] := true, kb.Destroy(), ownerGui.Show()))

    kb.Show("w376 h324")
    SetTimer CKB_CaptureLoop.Bind(btnCapt, eCaptured, UpdatePrev, stopCapt), -1
}

CKB_SetMouse(kb, ownerGui, eHkDisp, eHkAhk, ahkBtn, dispName, *) {
    eHkDisp.Value := dispName
    eHkAhk.Value  := ahkBtn
    kb.Destroy()
    ownerGui.Show()
}

CKB_UpdatePreview(cbCtrl, cbAlt, cbShift, eCaptured, txtPreview, *) {
    display := ""
    if cbCtrl.Value
        display .= "Ctrl + "
    if cbAlt.Value
        display .= "Alt + "
    if cbShift.Value
        display .= "Shift + "
    key := eCaptured.Value
    if key != ""
        display .= key
    txtPreview.Value := (display = "" || key = "") ? "nenhuma keybind" : display
}

CKB_ToggleCapture(btnCapt, eCaptured, UpdatePrev, stopCapt, *) {
    if !stopCapt[1] {
        stopCapt[1] := true
        btnCapt.Text := "Iniciar captura"
        return
    }
    SetTimer CKB_CaptureLoop.Bind(btnCapt, eCaptured, UpdatePrev, stopCapt), -1
}

CKB_CaptureLoop(btnCapt, eCaptured, UpdatePrev, stopCapt) {
    stopCapt[1] := false
    try btnCapt.Text := "Parar captura"
    loop {
        if stopCapt[1]
            break
        ih := InputHook("L0 B T2")
        ih.KeyOpt("{All}", "SE")
        ih.Start()
        ih.Wait()
        if stopCapt[1]
            break
        if ih.EndKey != "" && ih.EndKey != "LButton" && ih.EndKey != "RButton"
            eCaptured.Value := ih.EndKey
        try UpdatePrev()
    }
    try btnCapt.Text := "Iniciar captura"
}

CKB_Insert(kb, ownerGui, eHkDisp, eHkAhk, cbCtrl, cbAlt, cbShift, eCaptured, stopCapt, *) {
    key := eCaptured.Value
    if key = ""
        return
    stopCapt[1] := true
    mods    := ""
    display := ""
    if cbCtrl.Value {
        mods .= "^"
        display .= "Ctrl + "
    }
    if cbAlt.Value {
        mods .= "!"
        display .= "Alt + "
    }
    if cbShift.Value {
        mods .= "+"
        display .= "Shift + "
    }
    display .= key
    eHkDisp.Value := display
    eHkAhk.Value  := mods . key
    kb.Destroy()
    ownerGui.Show()
}

; ============================================================
;  CONFIGURACOES
; ============================================================
OpenSettings() {
    global ConfigFile
    startupVal := IniRead(ConfigFile, "Settings", "Startup",      "0")
    delayVal   := IniRead(ConfigFile, "Settings", "StepDelay",    "150")
    aotVal     := IniRead(ConfigFile, "Settings", "AlwaysOnTop",  "1")

    g := Gui("+AlwaysOnTop", "Configurações - MacroEditor")
    g.BackColor := "FFFFFF"
    g.SetFont("s9", "Segoe UI")

    g.Add("Text", "x12 y12 w390", "Iniciar com o Windows:")
    cbStartup := g.Add("CheckBox", "x12 y28 Checked" (startupVal = "1" ? 1 : 0), "Iniciar MacroEditor automaticamente com o Windows")

    g.Add("Text", "x12 y62 w390", "Janelas sempre visiveis (Always on Top):")
    cbAot := g.Add("CheckBox", "x12 y78 Checked" (aotVal = "1" ? 1 : 0), "Manter janelas do MacroEditor sempre a frente")

    g.Add("Text", "x12 y110",  "Atraso padrao entre passos (ms):")
    eDelay := g.Add("Edit", "x12 y126 w80", delayVal)

    g.Add("Button", "x12  y162 w100 h28", "Salvar").OnEvent("Click",   (*) => SaveSettings(g, cbStartup, cbAot, eDelay))
    g.Add("Button", "x118 y162 w80  h28", "Fechar").OnEvent("Click", (*) => (g.Destroy(), ReturnToMain()))
    g.OnEvent("Close", (*) => (g.Destroy(), ReturnToMain()))
    g.Show("w340 h206")
}

SaveSettings(g, cbStartup, cbAot, eDelay) {
    global ConfigFile, MainGui
    stepDelay := Integer(eDelay.Value)
    if stepDelay < 1
        stepDelay := 1
    IniWrite cbStartup.Value, ConfigFile, "Settings", "Startup"
    IniWrite cbAot.Value,     ConfigFile, "Settings", "AlwaysOnTop"
    IniWrite stepDelay,       ConfigFile, "Settings", "StepDelay"
    if cbStartup.Value = 1 {
        CreateStartupShortcut()
    } else
        try FileDelete A_Startup "\MacroEditor.lnk"
    if IsObject(MainGui)
        try MainGui.Opt(cbAot.Value = 1 ? "+AlwaysOnTop" : "-AlwaysOnTop")
    g.Destroy()
    ReturnToMain()
}

; ============================================================
;  SALVAR / CARREGAR
; ============================================================
SaveMacros() {
    global Macros, MacroFile
    try FileDelete MacroFile
    for name, m in Macros {
        safeName := StrReplace(name, " ", "_")
        IniWrite m["hotkey"],                                          MacroFile, safeName, "hotkey"
        IniWrite m["window"],                                          MacroFile, safeName, "window"
        IniWrite name,                                                 MacroFile, safeName, "displayname"
        IniWrite m.Has("repeatMode") ? m["repeatMode"] : "none",      MacroFile, safeName, "repeatMode"
        IniWrite m.Has("repeatVal")  ? m["repeatVal"]  : 1,           MacroFile, safeName, "repeatVal"
        IniWrite m.Has("repeatWait") ? m["repeatWait"] : 500,         MacroFile, safeName, "repeatWait"
        stepsStr := ""
        for s in m["steps"]
            stepsStr .= s "||~~||"
        IniWrite stepsStr, MacroFile, safeName, "steps"
    }
}

LoadMacros() {
    global Macros, MacroFile
    Macros := Map()
    if !FileExist(MacroFile)
        return
    sections := IniRead(MacroFile)
    for sec in StrSplit(sections, "`n", "`r") {
        sec := Trim(sec)
        if sec = ""
            continue
        displayname := IniRead(MacroFile, sec, "displayname", sec)
        hk          := IniRead(MacroFile, sec, "hotkey",      "")
        win         := IniRead(MacroFile, sec, "window",      "")
        repeatMode  := IniRead(MacroFile, sec, "repeatMode",  "none")
        repeatVal   := IniRead(MacroFile, sec, "repeatVal",   "1")
        repeatWait  := IniRead(MacroFile, sec, "repeatWait",  "500")
        steps       := IniRead(MacroFile, sec, "steps",       "")
        m := Map()
        m["hotkey"]     := hk
        m["window"]     := win
        m["repeatMode"] := repeatMode
        m["repeatVal"]  := Integer(repeatVal)
        m["repeatWait"] := Integer(repeatWait)
        m["steps"]      := []
        ; Suporte a dois formatos de separador:
        ; Novo: ||~~|| (nao colide com TITLE::...||EXE::... do identificador de janela)
        ; Legado: || (pode corromper steps com WINOPEN — sera migrado ao salvar)
        sep := InStr(steps, "||~~||") ? "||~~||" : "||"
        for s in StrSplit(steps, sep) {
            s := Trim(s)
            if s != ""
                m["steps"].Push(s)
        }
        Macros[displayname] := m
    }
}
