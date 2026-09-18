import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// SCNet Token Plan 剩余 Credits 显示在 Omarchy 顶栏。
// bin/scnet-watch 从浏览器 cookie 拿登录态，查询 SCNet 控制台 API，输出单行 JSON。

Panel {
  id: root
  moduleName: "local.scnet"
  ipcTarget: "local.scnet"
  manageIpc: false

  // ---------------------------------------------------------------- settings
  property string display: String(setting("display", "remaining"))
  readonly property var displayModes: ["remaining", "percent", "used"]
  function cycleDisplay() {
    display = displayModes[(displayModes.indexOf(display) + 1) % displayModes.length]
    Quickshell.execDetached(["omarchy", "bar", "set", "local.scnet", "display", display])
  }
  function setting(name, fallback) {
    var s = root.settings || ({})
    return s[name] !== undefined && s[name] !== null ? s[name] : fallback
  }

  // ---------------------------------------------------------------- theme
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ---------------------------------------------------------------- state
  property var snap: null
  readonly property bool hasData: snap && !snap.error
  readonly property string label: {
    if (!hasData) return "SCNet —"
    if (display === "percent") return Math.round(snap.percent) + "%"
    if (display === "used") return formatCredits(snap.used)
    return formatCredits(snap.remaining)
  }
  function formatCredits(v) {
    return v >= 10000 ? (v / 1000).toFixed(1) + "k" : String(Math.round(v))
  }

  // ---------------------------------------------------------------- watcher
  Process {
    id: watcherProc
    command: [Qt.resolvedUrl("bin/scnet-watch").toString().replace(/^file:\/\//, ""), "--interval", "300"]
    running: true
    stdout: SplitParser { onRead: function(data) { root.parseState(data) } }
    stderr: SplitParser {
      onRead: function(data) { if (String(data).trim() !== "") console.warn("scnet", String(data).trim()) }
    }
    onExited: function(code) { console.warn("scnet", "watcher exited", code); restartTimer.start() }
  }
  Timer { id: restartTimer; interval: 30000; onTriggered: watcherProc.running = true }

  function parseState(text) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (parsed && typeof parsed === "object") root.snap = parsed
    } catch (e) {
      console.warn("scnet", "bad state line", e)
    }
  }

  // ---------------------------------------------------------------- bar entry
  // 复用 Quickshell 的文本容器；点击打开面板，滚轮切换显示模式。
  WidgetItem {
    id: barItem
    height: bar.height
    onClicked: root.open()
    onWheel: function(up) { root.cycleDisplay() }
    Text {
      anchors.centerIn: parent
      font.family: root.fontFamily
      font.pixelSize: bar.height * 0.45
      color: root.hasData ? root.fg : root.dim
      text: root.label
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
  }

  // ---------------------------------------------------------------- panel
  PanelContent {
    id: panelContent
    width: 320
    implicitHeight: 140

    Column {
      spacing: 8
      anchors { top: parent.top; topMargin: 16; left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 16 }
      Text {
        text: "SCNet Token Plan"
        font.pixelSize: 16
        font.bold: true
        color: root.fg
      }
      Text {
        text: root.hasData ? ("剩余 " + formatCredits(snap.remaining) + " / " + formatCredits(snap.total) + " Credits") : "未登录或获取失败"
        font.pixelSize: 13
        color: root.dim
      }
      Text {
        text: root.hasData ? ("套餐: " + snap.name + " · " + Math.round(snap.percent) + "% · 到期 " + (snap.expire || "—")) : "请先在浏览器登录 scnet.cn"
        font.pixelSize: 12
        color: root.dim
        wrapMode: Text.Wrap
      }
    }
  }
}
