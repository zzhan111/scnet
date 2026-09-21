import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// SCNet Token Plan 月度 Credits 剩余额度，显示在 Omarchy 顶栏。
// bin/scnet-watch 经 CDP 从运行中的浏览器拿登录 cookie，查询 SCNet 控制台
// API，输出单行 JSON；这里渲染栏条目和明细面板。
// Keys: r 换显示模式 · Enter 打开控制台 · Esc 关闭。

Panel {
  id: root
  moduleName: "local.scnet"
  ipcTarget: "local.scnet"
  manageIpc: false

  // ---------------------------------------------------------------- settings
  // What the bar shows next to the mark: remaining credits, percent, or used.
  property string display: {
    var v = String(setting("display", "remaining"))
    return displayModes.indexOf(v) >= 0 ? v : "remaining"
  }
  readonly property var displayModes: ["remaining", "percent", "used"]
  function cycleDisplay(persist) {
    display = displayModes[(displayModes.indexOf(display) + 1) % displayModes.length]
    if (persist !== false)
      Quickshell.execDetached(["omarchy", "bar", "set", "local.scnet", "display", display])
  }

  // ---------------------------------------------------------------- theme
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.45)
  readonly property color faint: Qt.rgba(fg.r, fg.g, fg.b, 0.20)
  readonly property color hilite: Qt.rgba(fg.r, fg.g, fg.b, 0.09)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ---------------------------------------------------------------- state
  property var liveSnap: null
  // demo: staged numbers for screenshots; the watcher keeps running behind it.
  property bool demoMode: false
  readonly property var demoSnap: ({
    name: "基础版", remaining: 53200, used: 6800, total: 60000,
    percent: 88.7, expire: "2026-10-18 23:59:59", ts: 0
  })
  readonly property var snap: demoMode ? demoSnap : liveSnap
  readonly property bool ok: !!snap && !snap.error
  readonly property bool needsLogin: !!snap && /no-login|no-browser-tab|401|unauthorized/i.test(String(snap.error || ""))

  readonly property string barLabel: {
    if (!ok) return ""
    if (display === "percent") return Math.round(snap.percent) + "%"
    if (display === "used") return fmtCredits(snap.used)
    return fmtCredits(snap.remaining)
  }
  function fmtCredits(v) {
    v = Number(v) || 0
    return v >= 10000 ? (v / 1000).toFixed(1).replace(/\.0$/, "") + "k" : String(Math.round(v))
  }
  readonly property string barTooltip: {
    if (demoMode) return "SCNet Token Plan · demo"
    if (!snap) return "SCNet Token Plan"
    if (snap.error) return "SCNet Token Plan · " + snap.error
    return "SCNet Token Plan · 剩余 " + fmtCredits(snap.remaining) + " / " + fmtCredits(snap.total)
      + " Credits (" + Math.round(snap.percent) + "%) · " + snap.name
  }

  // ---------------------------------------------------------------- watcher
  Process {
    id: watcherProc
    command: [root.watcher, "--interval", "300"]
    running: true
    stdout: SplitParser { onRead: function(data) { root.parseState(data) } }
    stderr: SplitParser {
      onRead: function(data) { if (String(data).trim() !== "") console.warn("scnet", String(data).trim()) }
    }
    onExited: function(code) {
      if (code !== 0) console.warn("scnet", "watcher exited", code)
      restartTimer.start()
    }
  }
  Timer { id: restartTimer; interval: 30000; onTriggered: watcherProc.running = true }
  readonly property string watcher: Qt.resolvedUrl("bin/scnet-watch").toString().replace(/^file:\/\//, "")

  function parseState(text) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (parsed && typeof parsed === "object") {
        root.liveSnap = parsed
        root.nowMs = Date.now()
      }
    } catch (e) {
      console.warn("scnet", "bad state line", e)
    }
  }
  property double nowMs: 0
  // Panel shows the age of the last fetch; keep it honest while open.
  Timer { interval: 30000; running: root.opened; repeat: true; onTriggered: root.nowMs = Date.now() }
  function fmtAgo() {
    if (!nowMs || !liveSnap) return ""
    var s = Math.max(0, Math.floor(nowMs / 1000 - (liveSnap.ts || nowMs / 1000)))
    return s < 90 ? "刚刚" : Math.floor(s / 60) + " 分钟前"
  }

  function refresh() {
    watcherProc.running = false
    watcherProc.running = true
  }

  function openLogin() {
    Quickshell.execDetached(["ma-browser", "open", "https://www.scnet.cn/sso/login"])
  }

  function openConsole() {
    // 必须 ma-browser open 而非 xdg-open：登录态在 ma-browser 拉起的 CDP 实例里，
    // 系统默认浏览器是另一个 cookie jar；且浏览器没开时它会自动拉起。
    Quickshell.execDetached(["ma-browser", "open", "https://www.scnet.cn/ui/console/index.html#/llm/token-plan"])
    root.close()
  }

  // ---------------------------------------------------------------- bar
  readonly property bool vertical: !!(bar && bar.vertical)
  // Parity with omabot's mark so the row reads as one widget.
  readonly property real markSize: Math.round(Style.bar.iconCanvas * 0.82)
  readonly property real barPull: Style.space(3)
  readonly property real textSize: {
    var h = Math.round(Style.font.caption * 1.15)
    return (h % 2) === (markSize % 2) ? h : h + 1
  }

  implicitWidth: vertical ? (bar ? bar.barSize : Style.bar.sizeHorizontal) : row.implicitWidth
  implicitHeight: vertical ? row.implicitHeight : (bar ? bar.barSize : Style.bar.sizeHorizontal)

  Grid {
    id: row
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 3
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    spacing: -root.barPull

    BarIconButton {
      id: button
      bar: root.bar
      text: "\u{f07af}" // chart-donut / data-usage glyph; mark is drawn dimmed when offline
      onPressed: function(buttonCode) { root.barPressed(buttonCode) }
    }

    Item {
      implicitWidth: barLabel.implicitWidth + Style.space(2)
      implicitHeight: root.textSize
      visible: root.barLabel !== ""
      Text {
        id: barLabel
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: root.barLabel
        color: root.ok ? (root.snap.percent <= 10 ? root.urgent : root.fg) : root.dim
        font.family: root.fontFamily
        font.pixelSize: root.textSize
      }
    }

    // Pull the text back into the icon slot's padding, matching the mark side.
    Item {
      readonly property real padding: barLabel.text !== ""
        ? Math.round((button.width - root.markSize) / 2) + root.barPull : 0
      height: root.vertical ? padding : 1
      width: root.vertical ? 1 : padding
    }
  }

  MouseArea {
    anchors.fill: row
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onClicked: function(mouse) { root.barPressed(mouse.button) }
    onEntered: if (root.bar) root.bar.showTooltip(row, root.barTooltip)
    onExited: if (root.bar) root.bar.hideTooltip(row)
  }

  function barPressed(buttonCode) {
    if (buttonCode === Qt.RightButton) root.openConsole()
    else if (buttonCode === Qt.MiddleButton) root.cycleDisplay()
    else root.toggle()
  }

  // ---------------------------------------------------------------- panel
  KeyboardPanel {
    id: panel
    anchorItem: row
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight + Style.space(16), Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.openConsole()
      onCloseRequested: root.close()
      onTextKey: function(t) { if (t === "r" || t === "R") root.cycleDisplay() }
    }

    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: column.implicitHeight + Style.space(8)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height

      Column {
        id: column
        x: Style.space(4)
        width: parent.width - Style.space(8)
        spacing: Style.space(6)

        Item {
          width: parent.width
          height: header.implicitHeight
          Column {
            id: header
            width: parent.width
            spacing: Style.space(2)
            Text {
              textFormat: Text.PlainText
              text: root.demoMode ? "SCNET TOKEN PLAN · demo" : "SCNET TOKEN PLAN"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              textFormat: Text.PlainText
              visible: root.ok
              text: root.ok ? (root.snap.name + " · " + Math.round(root.snap.percent) + "% 剩余") : ""
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        Rectangle { width: parent.width; height: 1; color: root.faint }

        Column {
          visible: root.needsLogin
          width: parent.width
          spacing: Style.space(4)

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: "未检测到 SCNet 登录态"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Button {
            width: parent.width
            text: "登录 SCNet"
            bordered: true
            foreground: root.fg
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.openLogin()
          }
        }

        // The one number that matters, large.
        Text {
          textFormat: Text.PlainText
          visible: root.ok
          anchors.left: parent.left
          anchors.leftMargin: Style.space(2)
          text: root.ok ? fmtCredits(root.snap.remaining) : "—"
          color: root.ok && root.snap.percent <= 10 ? root.urgent : root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
          font.bold: true
        }
        Text {
          textFormat: Text.PlainText
          visible: root.ok
          anchors.left: parent.left
          anchors.leftMargin: Style.space(2)
          text: root.ok ? "剩余 Credits / 共 " + fmtCredits(root.snap.total) : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        // Usage bar: filled = burned, rest = remaining.
        Item {
          visible: root.ok
          width: parent.width
          height: Style.space(6)
          Rectangle {
            anchors.fill: parent
            radius: Style.space(1.5)
            color: root.faint
          }
          Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.width * Math.max(0, Math.min(100, root.ok ? 100 - root.snap.percent : 0)) / 100
            radius: Style.space(1.5)
            color: root.ok && root.snap.percent <= 10 ? root.urgent : root.fg
            opacity: 0.55
            Behavior on width { NumberAnimation { duration: 260 } }
          }
        }

        Rectangle { width: parent.width; height: 1; color: root.faint }

        // details
        Column {
          width: parent.width
          spacing: Style.space(3)
          DetailRow {
            label: "已用"
            value: root.ok ? fmtCredits(root.snap.used) + " Credits" : ""
          }
          DetailRow {
            label: "到期"
            value: root.ok ? String(root.snap.expire || "—") : ""
          }
          DetailRow {
            label: "更新于"
            value: root.demoMode ? "demo" : (root.fmtAgo() || "…")
          }
          DetailRow {
            label: "状态"
            value: root.demoMode ? "" : (!root.snap ? "获取中…" : (root.snap.error ? "错误: " + root.snap.error : "正常"))
            alert: !!root.snap && !!root.snap.error
          }
        }
      }
    }
  }

  component DetailRow: Item {
    property string label: ""
    property string value: ""
    property bool alert: false
    width: parent ? parent.width : 0
    height: Math.max(l.implicitHeight, v.implicitHeight)
    Text {
      id: l
      anchors.left: parent.left
      anchors.leftMargin: Style.space(2)
      text: parent.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      id: v
      anchors.right: parent.right
      anchors.rightMargin: Style.space(2)
      text: parent.value
      color: parent.alert ? root.urgent : root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  // ---------------------------------------------------------------- ipc
  IpcHandler {
    // Like omabot: only the copy actually mounted in a bar takes the name.
    enabled: root.bar !== null
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
    function display(): string { root.cycleDisplay(false); return root.display }
    function demo(): string { root.demoMode = !root.demoMode; if (root.demoMode && !root.opened) root.open(); return root.demoMode ? "demo" : "live" }
    function state(): string { return JSON.stringify({ snap: root.snap, display: root.display, demo: root.demoMode }) }
  }
}
