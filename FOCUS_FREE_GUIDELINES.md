# 🎯 Focus-Free UI Guidelines
## Building Non-Intrusive Overlay Applications on Linux

These guidelines ensure your overlay/tool doesn't steal focus from the user's active application.

---

## 📋 Table of Contents

1. [Window Properties](#window-properties)
2. [Window Manager Hints](#window-manager-hints)
3. [Input Handling](#input-handling)
4. [Rendering Best Practices](#rendering-best-practices)
5. [Testing Checklist](#testing-checklist)

---

## 🔧 Window Properties

### **Essential Settings (GTK3)**

```python
class OverlayWindow(Gtk.Window):
    def __init__(self):
        super().__init__()
        
        # === CRITICAL: Focus Prevention ===
        self.set_accept_focus(False)      # NEVER accept keyboard focus
        self.set_focus_on_map(False)      # Don't steal focus on show
        
        # === Window Type ===
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
        # Alternative types depending on use case:
        # - Gdk.WindowTypeHint.UTILITY (for tool palettes)
        # - Gdk.WindowTypeHint.SPLASHSCREEN (for splash screens)
        # - Gdk.WindowTypeHint.NOTIFICATION (for notifications)
        
        # === Taskbar/Pager ===
        self.set_skip_taskbar_hint(True)  # Hide from taskbar
        self.set_skip_pager_hint(True)    # Hide from workspace switcher
        
        # === Decoration ===
        self.set_decorated(False)         # No title bar, borders, buttons
        
        # === Keep Above ===
        self.set_keep_above(True)         # Stay above other windows
        
        # === Transparency Support ===
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)       # Enable alpha channel
```

### **Equivalent in Other Frameworks**

#### **Qt/PyQt5:**
```python
class OverlayWindow(QWidget):
    def __init__(self):
        super().__init__()
        
        # Frameless window
        self.setWindowFlags(
            Qt.FramelessWindowHint |      # No decorations
            Qt.WindowStaysOnTopHint |     # Keep above
            Qt.Tool |                     # Don't show in taskbar
            Qt.X11BypassWindowManagerHint # Bypass WM (use carefully)
        )
        
        # Don't accept focus
        self.setFocusPolicy(Qt.NoFocus)
        
        # Transparent background
        self.setAttribute(Qt.WA_TranslucentBackground)
```

#### **Electron (JavaScript):**
```javascript
const win = new BrowserWindow({
  width: 400,
  height: 100,
  frame: false,                    // No window decorations
  transparent: true,               // Transparent background
  alwaysOnTop: true,               // Keep above
  skipTaskbar: true,               // Hide from taskbar
  focusable: false,                // Cannot receive focus
  hasShadow: false,                // No shadow
  type: 'panel'                    // Panel type (or 'toolbar')
});

// Prevent focus
win.setIgnoreMouseEvents(true, { forward: true });
```

---

## 🎨 Window Manager Hints

### **X11 Specific (via xprop)**

Set these properties after window creation:

```bash
# Manual override using xprop
xprop -id $WINDOW_ID \
  -f _NET_WM_WINDOW_TYPE 32a \
  -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_DOCK

xprop -id $WINDOW_ID \
  -f _NET_WM_STATE 32a \
  -set _NET_WM_STATE _NET_WM_STATE_ABOVE
```

### **Programmatic (GDK/X11):**

```python
from gi.repository import GdkX11

# Get X11 window ID
gdk_window = self.get_window()
if isinstance(gdk_window, GdkX11.X11Window):
    xid = gdk_window.get_xid()
    
    # Set via GDK (requires GTK3)
    gdk_window.set_user_data(gdk_window)
```

---

## ⌨️ Input Handling

### **Mouse Events Without Focus Steal**

```python
def setup_input_region(self):
    """Create input region that passes events through"""
    
    # Option 1: Shape input region (advanced)
    # Only specific areas respond to mouse
    region = cairo.Region()
    # Define clickable areas only
    
    # Option 2: Pass-through for non-interactive overlays
    input_shape = None  # No input region = click-through
    
    # In GTK3
    self.input_shape_combine_region(input_shape)
```

### **Event Handling Best Practices:**

```python
def on_mouse_event(self, widget, event):
    """Handle mouse without stealing focus"""
    
    # Don't call grab_focus() or similar
    # Don't raise/lower the window
    # Don't change Z-order
    
    # For interactive elements:
    if event.type == Gdk.EventType.BUTTON_PRESS:
        # Handle click but don't request focus
        return True  # Event handled
    
    return False  # Let event propagate
```

---

## 🖼️ Rendering Best Practices

### **Double Buffering (Prevent Flickering)**

```python
def on_draw(self, widget, cr):
    """GTK3 automatically provides double buffering"""
    
    # Clear with transparency
    cr.set_operator(cairo.Operator.CLEAR)
    cr.paint()
    
    # Set back to normal compositing
    cr.set_operator(cairo.Operator.OVER)
    
    # Your rendering here...
```

### **Efficient Redrawing:**

```python
# DON'T: Redraw everything every frame
def bad_update(self):
    self.queue_draw()  # Redraws entire window

# DO: Only redraw changed regions
def good_update(self):
    # Calculate dirty region
    dirty_rect = Gdk.Rectangle()
    dirty_rect.x = 10
    dirty_rect.y = 10
    dirty_rect.width = 100
    dirty_rect.height = 50
    
    # Invalidate only changed area
    self.invalidate_rect(dirty_rect, True)
```

### **Animation Timing:**

```python
# Use appropriate refresh rates
REFRESH_RATES = {
    'smooth_animation': 60,   # 16ms - For motion
    'audio_visualization': 25, # 40ms - For audio bars
    'timer_update': 10,        # 100ms - For text timers
    'signal_check': 10,        # 100ms - For file checks
}

# Setup timer
GLib.timeout_add(1000 // REFRESH_RATES['smooth_animation'], 
                 self.animate_callback)
```

---

## 🛡️ Error Handling & Stability

### **Safe Callback Wrappers:**

```python
def safe_callback(func):
    """Decorator to prevent crashes from breaking the app"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            print(f"Error in {func.__name__}: {e}")
            return True  # Keep timer running
    return wrapper

@safe_callback
def update_animation(self):
    # Your animation code
    pass
```

### **Resource Cleanup:**

```python
def cleanup(self):
    """Ensure all resources are freed"""
    
    # Stop all timers
    for timer_id in self._timer_ids:
        GLib.source_remove(timer_id)
    
    # Free graphics resources
    if self.cairo_context:
        del self.cairo_context
    
    # Close file handles
    # Close audio streams
    # Remove temporary files
```

---

## 🧪 Testing Checklist

### **Focus Behavior Tests:**

- [ ] Open text editor, start typing
- [ ] Trigger overlay (hotkey/appearance)
- [ ] Continue typing WITHOUT interruption
- [ ] Verify cursor stays in text editor
- [ ] Verify keystrokes go to text editor (not overlay)

### **Window Manager Tests:**

- [ ] Overlay doesn't appear in Alt+Tab
- [ ] Overlay doesn't appear in taskbar
- [ ] Overlay doesn't appear in workspace switcher
- [ ] Overlay stays visible when other windows move
- [ ] Overlay minimizes/closes correctly

### **Visual Quality Tests:**

- [ ] No flickering during animation
- [ ] Smooth transitions (no stuttering)
- [ ] Transparency works correctly
- [ ] Renders correctly on multi-monitor setups
- [ ] Handles different DPI settings

### **Performance Tests:**

- [ ] CPU usage < 5% when idle
- [ ] CPU usage < 15% during animation
- [ ] Memory usage stable (no leaks)
- [ ] Clean shutdown (no orphan processes)

---

## 📝 Common Pitfalls to Avoid

### ❌ **DON'T:**

```python
# Never call these in overlay windows:
widget.grab_focus()           # Steals focus!
window.present()              # May steal focus
window.raise_()               # Can disrupt stacking
widget.set_can_focus(True)    # Allows focus
```

### ✅ **DO:**

```python
# Use these instead:
self.set_accept_focus(False)
self.set_focus_on_map(False)
self.set_type_hint(Gdk.WindowTypeHint.DOCK)
```

---

## 🔍 Debugging Tools

### **Check Window Properties:**

```bash
# Find your window
xwininfo -root -tree | grep -i "overlay"

# Check WM properties
xprop -id <WINDOW_ID>

# Look for:
# _NET_WM_WINDOW_TYPE(DOCK)
# _NET_WM_STATE(ABOVE)
```

### **Monitor Focus Events:**

```bash
# Watch focus changes
xev -event focus

# Monitor window state
xprop -spy -root _NET_ACTIVE_WINDOW
```

---

## 📚 Additional Resources

- [GTK3 Window Documentation](https://docs.gtk.org/gtk3/class.Window.html)
- [EWMH Specification](https://specifications.freedesktop.org/wm-spec/wm-spec-latest.html)
- [Cairo Graphics](https://www.cairographics.org/)
- [X11 Window Manager Hints](https://tronche.com/gui/x/icccm/)

---

## 🎓 Quick Reference Card

```python
# MINIMAL FOCUS-FREE OVERLAY (GTK3)
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk

class MinimalOverlay(Gtk.Window):
    def __init__(self):
        super().__init__()
        
        # Focus prevention
        self.set_accept_focus(False)
        self.set_focus_on_map(False)
        
        # Window type
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.set_keep_above(True)
        
        # Hide from taskbar
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        
        # Visual setup
        self.set_decorated(False)
        self.set_app_paintable(True)
        
        # Transparency
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        
        # Connect draw
        self.connect('draw', self.on_draw)
        
        # Show
        self.show_all()
    
    def on_draw(self, widget, cr):
        # Your rendering here
        pass

# Run
win = MinimalOverlay()
Gtk.main()
```

---

## 🏆 Summary: The Golden Rules

1. **Never Accept Focus** - `set_accept_focus(False)` is your best friend
2. **Use Correct Window Type** - DOCK/UTILITY/NOTIFICATION
3. **Hide from Taskbar** - `set_skip_taskbar_hint(True)`
4. **Stay Above** - `set_keep_above(True)`
5. **No Decorations** - `set_decorated(False)`
6. **Test Extensively** - Different WMs behave differently
7. **Handle Errors Gracefully** - Don't crash the user's workflow
8. **Clean Up Properly** - No orphan processes or resources

---

**Remember:** Your overlay should enhance the user experience, not interrupt it! 🎯
