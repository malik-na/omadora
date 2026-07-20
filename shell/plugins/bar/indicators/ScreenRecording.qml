import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property bool recording: false

  active: recording
  activeText: "󰻂"
  inactiveText: "󰻂"
  activeTooltipText: "Stop recording"
  inactiveTooltipText: "Screen Recording"

  function refresh() {
    if (!root.bar || statusProc.running) return
    // Match either recorder. omarchy-capture-screenrecording falls back to
    // wf-recorder where gpu-screen-recorder cannot run (Apple Silicon), and
    // looking only for gpu-screen-recorder left the indicator hidden during a
    // wf-recorder capture - so there was nothing to press to stop it.
    statusProc.command = ["pgrep", "--quiet", "-x", "gpu-screen-recorder|wf-recorder"]
    statusProc.running = true
  }

  onBarChanged: refresh()
  Component.onCompleted: refresh()

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Process {
    id: statusProc
    onExited: function(exitCode) {
      root.recording = exitCode === 0
    }
  }

  onPressed: function() {
    if (root.bar) {
      root.bar.run(root.recording ? "omarchy-capture-screenrecording --stop-recording" : "omarchy-menu toggle trigger.capture.screenrecord")
    }
  }
}
