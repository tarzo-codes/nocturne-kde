// Nocturne panel + desktop layout (Plasma scripting API)
// Apply with: ~/.local/share/nocturne/apply-layout.sh
//
//  ┌──────────────────────────── top bar (each screen) ────────────────────────────┐
//  │ ☾ launcher  window list        Sun 11 Oct  17:52        cpu ▶ media  tray     │
//  └────────────────────────────────────────────────────────────────────────────────┘
//                        ╭──── dock (each screen, dodges windows) ────╮
//                        │  📁  ▣  🦊  ✳  ✎  ●  ⚙   │  🗑            │
//                        ╰─────────────────────────────────────────────╯

// filled in by apply-layout.sh with the apps that are actually installed
var LAUNCHERS = "__LAUNCHERS__";

function cfg(w, group, values) {
  w.currentConfigGroup = group;
  for (var k in values) w.writeConfig(k, values[k]);
}

function monitor(p, type, sensor, color) {
  var w = p.addWidget(type);
  cfg(w, ["Appearance"], { chartFace: "org.kde.ksysguard.linechart", title: "" });
  cfg(w, ["SensorColors"], (function () { var o = {}; o[sensor] = color; return o; })());
  cfg(w, ["org.kde.ksysguard.linechart", "General"], {
    lineChartFillOpacity: 35, lineChartSmooth: true, showLegend: false,
    showGridLines: false, showYAxisLabels: false,
  });
  return w;
}

function topBar(screen, primary) {
  var p = new Panel("org.kde.panel");
  p.screen = screen;
  p.location = "top";
  p.height = 34;
  p.floating = true;
  p.lengthMode = "fill";
  p.hiding = "none";

  var k = p.addWidget("org.kde.plasma.kickoff");
  cfg(k, ["General"], { icon: "nocturne-logo", favoritesDisplay: 0, applicationsDisplay: 1, showActionButtonCaptions: false });
  p.addWidget("org.kde.plasma.windowlist");
  p.addWidget("org.kde.plasma.panelspacer");

  var clock = p.addWidget("org.kde.plasma.digitalclock");
  cfg(clock, ["Appearance"], {
    showDate: true, dateDisplayFormat: 1 /* beside time */, dateFormat: "custom",
    customDateFormat: "ddd d MMM", showSeconds: 0, use24hFormat: 0 /* 12-hour */,
    autoFontAndSize: false, fontFamily: "Inter", fontWeight: 600, fontSize: 10,
  });

  p.addWidget("org.kde.plasma.panelspacer");
  if (primary) {
    monitor(p, "org.kde.plasma.systemmonitor.cpu", "cpu/all/usage", "61,219,181");
    p.addWidget("org.kde.plasma.mediacontroller");
    p.addWidget("org.kde.plasma.colorpicker");
    p.addWidget("org.kde.plasma.systemtray");
  } else {
    monitor(p, "org.kde.plasma.systemmonitor.memory", "memory/physical/usedPercent", "180,156,255");
    p.addWidget("org.kde.plasma.showdesktop");
  }
  return p;
}

function dock(screen) {
  var p = new Panel("org.kde.panel");
  p.screen = screen;
  p.location = "bottom";
  p.height = 58;
  p.floating = true;
  p.lengthMode = "fit";
  p.alignment = "center";
  p.hiding = "dodgewindows";

  var t = p.addWidget("org.kde.plasma.icontasks");
  cfg(t, ["General"], {
    launchers: LAUNCHERS, showOnlyCurrentScreen: true, indicateAudioStreams: true,
    iconSpacing: 2, maxStripes: 1, highlightWindows: true,
  });
  p.addWidget("org.kde.plasma.marginsseparator");
  p.addWidget("org.kde.plasma.trash");
  return p;
}

// ── rebuild ───────────────────────────────────────────────
panels().forEach(function (p) { p.remove(); });

var out = [];
for (var s = 0; s < screenCount; s++) {
  out.push("top " + s + " " + topBar(s, s === 0).id);
  out.push("dock " + s + " " + dock(s).id);
}

// desktop widgets: greeting clock on the primary screen, stats card on the second
// (positions are written by apply-layout.sh — the scripting API ignores x/y on Plasma 6)
var REPLACE = ["org.kde.plasma.digitalclock", "org.kde.plasma.systemmonitor.cpucore",
               "org.nocturne.clock", "org.nocturne.stats"];
desktops().forEach(function (d) {
  d.widgets().forEach(function (w) { if (REPLACE.indexOf(w.type) >= 0) w.remove(); });
  if (d.screen < 0) return;
  var g = screenGeometry(d.screen);
  out.push("desk " + d.id + " " + d.screen + " " + g.width + " " + g.height);
  if (d.screen === 0) d.addWidget("org.nocturne.clock", 96, 110, 620, 300);
  if (d.screen === 1 || screenCount === 1) d.addWidget("org.nocturne.stats", g.width - 496, 110, 400, 270);
});

print(out.join("\n"));
