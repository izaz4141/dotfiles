pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property string screenshotsDir: NiriService.screenshotsDir
    property var regionOverlay: null

    function shellQuote(value) {
        return "'" + value.replace(/'/g, "'\\''") + "'";
    }

    function run(command, callback) {
        Proc.runCommand("screenshot-" + Math.floor(Math.random() * 1e9), ["bash", "-c", command], callback, 0, Proc.noTimeout);
    }

    function toastSuccess(message) {
        ToastService.showInfo(message);
    }

    function toastError(message) {
        ToastService.showError(message);
    }

    function ensureDir(dir) {
        return "mkdir -p " + shellQuote(dir);
    }

    function timestamp() {
        return new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "");
    }

    function defaultSavePath() {
        return Paths.strip(Paths.pictures) + "/Screenshots/screenshot-" + timestamp() + ".png";
    }

    function parseTarget(target) {
        const raw = target || "clipboard";
        const eq = raw.indexOf("=");
        const mode = (eq > 0 ? raw.slice(0, eq) : raw).trim();
        const overridePath = eq > 0 ? raw.slice(eq + 1).trim() : "";

        if (mode !== "clipboard" && mode !== "path" && mode !== "both")
            return { mode: "clipboard", path: "" };

        return { mode: mode, path: overridePath };
    }

    function wantsClipboard(info) {
        return info.mode === "clipboard" || info.mode === "both";
    }

    function wantsPath(info) {
        return info.mode === "path" || info.mode === "both";
    }

    function resolveSavePath(path) {
        return path && path !== "" ? path : defaultSavePath();
    }

    function buildCaptureCommand(geometry, info) {
        const geom = `${geometry.x},${geometry.y} ${geometry.width}x${geometry.height}`;
        const toClipboard = wantsClipboard(info);
        const toPath = wantsPath(info);
        const savePath = resolveSavePath(info.path);

        if (toClipboard && toPath) {
            return ensureDir(Paths.strip(Paths.pictures) + "/Screenshots")
                + ` && grim -g ${shellQuote(geom)} ${shellQuote(savePath)}`
                + ` && wl-copy < ${shellQuote(savePath)}`
                + ` && echo ${shellQuote(savePath)}`;
        }
        if (toPath) {
            return ensureDir(Paths.strip(Paths.pictures) + "/Screenshots")
                + ` && grim -g ${shellQuote(geom)} ${shellQuote(savePath)}`
                + ` && echo ${shellQuote(savePath)}`;
        }
        return `grim -g ${shellQuote(geom)} - | wl-copy`;
    }

    function handleResult(command, info, callback) {
        return (output, exitCode) => {
            if (exitCode === 0) {
                if (wantsPath(info)) {
                    const clean = (output || "").trim().split("\n").pop() || "";
                    const saved = clean !== "" ? clean : "screenshot saved";
                    const msg = wantsClipboard(info)
                        ? I18n.tr("Screenshot saved and copied", "screenshot saved to disk and copied to clipboard")
                        : I18n.tr("Screenshot saved", "screenshot saved to disk");
                    toastSuccess(msg);
                    if (callback) callback(null, saved);
                } else {
                    toastSuccess(I18n.tr("Screenshot copied", "screenshot copied to clipboard"));
                    if (callback) callback(null, "clipboard");
                }
            } else {
                toastError(I18n.tr("Screenshot failed", "screenshot capture failed"));
                if (callback) callback("Screenshot failed", null);
            }
        };
    }

    function all(target, callback) {
        const output = CompositorService.getFocusedScreen();
        if (!output) {
            toastError(I18n.tr("No screen available", "no screen to capture"));
            return "ERROR: no screen";
        }
        const scale = CompositorService.getScreenScale(output) || 1;
        const geometry = {
            x: Math.round(output.x * scale),
            y: Math.round(output.y * scale),
            width: Math.round(output.width * scale),
            height: Math.round(output.height * scale)
        };
        const info = parseTarget(target);
        const command = buildCaptureCommand(geometry, info);
        run(command, handleResult(command, info, callback));
        return "CAPTURE_STARTED";
    }

    function focusedGeometry() {
        if (CompositorService.isHyprland) {
            const ht = Hyprland.activeToplevel;
            if (ht && ht.lastIpcObject) {
                const at = ht.lastIpcObject.at;
                const size = ht.lastIpcObject.size;
                if (at && size) {
                    return {
                        x: at[0],
                        y: at[1],
                        width: size[0],
                        height: size[1]
                    };
                }
            }
        }
        return null;
    }

    function window(target, callback) {
        const geometry = focusedGeometry();
        if (!geometry) {
            return all(target, callback);
        }
        const info = parseTarget(target);
        const command = buildCaptureCommand(geometry, info);
        run(command, handleResult(command, info, callback));
        return "CAPTURE_STARTED";
    }

    signal regionCaptureFinished

    function startRegionCaptureWithTarget(target) {
        if (regionOverlay) {
            regionOverlay.target = target;
            return startRegionCapture();
        }
        return "REGION_OVERLAY_NOT_FOUND";
    }

    function startRegionCapture() {
        const screen = CompositorService.getFocusedScreen();
        if (!screen) {
            toastError(I18n.tr("No screen available", "no screen to capture"));
            return "ERROR: no screen";
        }
        if (regionOverlay) {
            regionOverlay.show(screen);
            return "REGION_CAPTURE_STARTED";
        }
        return "REGION_OVERLAY_NOT_FOUND";
    }

    function activeWindow(target, callback) {
        const geometry = focusedGeometry();
        if (!geometry) {
            return all(target, callback);
        }
        const info = parseTarget(target);
        const command = buildCaptureCommand(geometry, info);
        run(command, handleResult(command, info, callback));
        return "CAPTURE_STARTED";
    }

    function captureDelayed(mode, target, delaySeconds, callback) {
        if (delaySeconds <= 0) {
            return executeCapture(mode, target, callback);
        }
        var timer = Qt.createQmlObject('import QtQuick; Timer { interval: delaySeconds * 1000; running: true; repeat: false; onTriggered: { destroy(); root.executeCapture(mode, target, callback); }}', root, "screenshot-timer");
        return "CAPTURE_DELAYED";
    }

    function executeCapture(mode, target, callback) {
        switch (mode) {
        case "activewindow":
            return activeWindow(target, callback);
        case "region":
            return startRegionCaptureWithTarget(target);
        case "all":
        default:
            return all(target, callback);
        }
    }

    function captureRegion(screen, rx, ry, rw, rh, target, callback) {
        if (!screen || rw <= 0 || rh <= 0)
            return "ERROR: invalid region";
        const scale = CompositorService.getScreenScale(screen) || 1;
        const geometry = {
            x: Math.round((screen.x + rx) * scale),
            y: Math.round((screen.y + ry) * scale),
            width: Math.round(rw * scale),
            height: Math.round(rh * scale)
        };
        const info = parseTarget(target);
        const command = buildCaptureCommand(geometry, info);
        run(command, handleResult(command, info, callback));
        return "CAPTURE_STARTED";
    }
}
