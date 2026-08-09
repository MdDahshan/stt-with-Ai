#!/usr/bin/env /python3
"""
Waveform Overlay for GNOME Wayland
Style: Minimal Black Pill, White Waveform Only
With Real-time Audio Visualization and Comprehensive Error Handling
"""
import gi
import sys
import time
import random
import os
import math

# Add current directory to path to allow imports if run as script
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from errors import (
    ErrorCategory, error_state, log_error, log_warning, log_debug,
    safe_callback, safe_draw, safe_file_check, safe_file_remove, safe_cleanup
)
from audio import AudioInput
import renderers

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango, GdkPixbuf

class WaveformOverlay(Gtk.Window):
    def __init__(self):
        super().__init__()
        
        # Window setup
        self.set_decorated(False)
        self.set_app_paintable(True)
        self.set_keep_above(True)
        
        # Prevent focus stealing
        self.set_accept_focus(False)
        self.set_focus_on_map(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        
        # UTILITY type — stays above but can receive clicks
        self.set_type_hint(Gdk.WindowTypeHint.UTILITY)
        self.set_startup_id("")
        
        # Transparent visual
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        
        # Connect draw signal
        self.connect('draw', self.on_draw)
        self.connect('destroy', self.on_destroy)
        
        # Container — compact, close button + waveform
        self.box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.box.set_valign(Gtk.Align.CENTER)
        self.box.set_margin_top(8)
        self.box.set_margin_bottom(8)
        self.box.set_margin_start(10)
        self.box.set_margin_end(14)
        
        self.add(self.box)
        
        # Close button — filled circle with × on the left
        self.close_button = Gtk.DrawingArea()
        self.close_button.set_size_request(18, 18)
        self.close_button.connect('draw', self.on_draw_close_button)
        self.close_button.add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                                     | Gdk.EventMask.ENTER_NOTIFY_MASK
                                     | Gdk.EventMask.LEAVE_NOTIFY_MASK)
        self.close_button.connect('button-press-event', self.on_close_clicked)
        self.close_button.connect('enter-notify-event', self.on_close_hover_enter)
        self.close_button.connect('leave-notify-event', self.on_close_hover_leave)
        self.box.pack_start(self.close_button, False, False, 0)
        
        # Close button hover state
        self._close_hover = False
        
        # Waveform Drawing Area
        self.waveform_area = Gtk.DrawingArea()
        self.waveform_area.set_size_request(80, 22)
        self.waveform_area.connect('draw', self.on_draw_waveform)
        self.box.pack_start(self.waveform_area, True, True, 4)
        
        # State tracking
        self.start_time = time.time()
        self.processing_mode = False
        self.is_offline = False
        self.processing_start_time = None
        self._shutting_down = False
        
        # Animation state
        self.animation_progress = 0.0
        self.is_closing = False
        self.target_y = 0
        self.current_y = 0
        
        # Waveform animation data
        self.num_bars = 16
        self.bars = [0.1] * self.num_bars
        self.target_bars = [0.1] * self.num_bars
        
        # Processing mode pulse
        self.pulse_phase = 0.0
        
        # Audio input setup
        self.audio_input = AudioInput()
        audio_ok = self.audio_input.setup()
        if not audio_ok:
            log_warning(ErrorCategory.AUDIO_INPUT, "Audio unavailable, waveform will be static")

        self.audio_levels = [0.0] * self.num_bars
        self.overall_audio_level = 0.0
        
        # Show window (initially invisible)
        self.set_opacity(0.0)
        self.show_all()
        
        # Timers — 4 lean callbacks
        self._timer_ids = []
        self._timer_ids.append(GLib.timeout_add(10, self._safe_position_window))
        self._timer_ids.append(GLib.timeout_add(40, self._safe_update_animation))
        self._timer_ids.append(GLib.timeout_add(50, self._safe_update_audio_levels))
        self._timer_ids.append(GLib.timeout_add(16, self._safe_animate_entrance))
        self._timer_ids.append(GLib.timeout_add(100, self._safe_check_signals))
        
        log_debug(ErrorCategory.UI_RENDER, "WaveformOverlay initialized successfully")

    # =========================================================================
    # Safe wrapper methods
    # =========================================================================
    
    def _safe_update_audio_levels(self):
        if self._shutting_down:
            return False
        try:
            return self.update_audio_levels()
        except Exception as e:
            log_error(ErrorCategory.AUDIO_INPUT, f"Error updating audio levels: {e}", e)
            return True
    
    def _safe_update_animation(self):
        if self._shutting_down:
            return False
        try:
            return self.update_animation()
        except Exception as e:
            log_error(ErrorCategory.ANIMATION, f"Error in animation update: {e}", e)
            return True
    
    def _safe_animate_entrance(self):
        if self._shutting_down:
            return False
        try:
            return self.animate_entrance()
        except Exception as e:
            log_error(ErrorCategory.ANIMATION, f"Error in entrance animation: {e}", e)
            self.animation_progress = 1.0
            self.set_opacity(1.0)
            return False
    
    def _safe_check_signals(self):
        if self._shutting_down:
            return False
        try:
            self.check_processing_mode()
            self.check_close_signal()
            return True
        except Exception as e:
            log_error(ErrorCategory.SIGNAL_CHECK, f"Error checking signals: {e}", e)
            return True
    
    def _safe_position_window(self):
        if self._shutting_down:
            return False
        try:
            return self.position_window()
        except Exception as e:
            log_error(ErrorCategory.WINDOW_MGMT, f"Error positioning window: {e}", e)
            return False
    
    def update_audio_levels(self):
        """Update audio levels for each bar with wave motion"""
        if self.processing_mode:
            return True
            
        level = self.audio_input.get_level()
        
        # Update overall level for spacing animation
        self.overall_audio_level = (self.overall_audio_level * 0.7) + (level * 0.3)
        
        # Shift levels to the left (wave motion)
        self.audio_levels.pop(0)
        self.audio_levels.append(level)
        
        # Update target bars based on audio (center outwards)
        center = (self.num_bars - 1) / 2.0
        for i in range(self.num_bars):
            # Calculate distance from center
            distance = abs(i - center)
            # Map distance to history delay
            delay = int(distance * 2.0)
            
            audio_index = (self.num_bars - 1) - delay
            audio_index = max(0, min(audio_index, self.num_bars - 1))
            
            audio_val = self.audio_levels[audio_index]
            
            # Prevent "silence echo" but keep it smooth
            live_val = self.audio_levels[-1]
            max_allowed = (live_val * 2.0) + 0.15
            audio_val = min(audio_val, max_allowed)
            
            # Removed random jitter for a buttery smooth wave
            self.target_bars[i] = min(audio_val, 1.0)
            
            if self.target_bars[i] < 0.1:
                self.target_bars[i] = 0.1
        
        return True
    
    def on_destroy(self, widget):
        if self._shutting_down:
            return
        self._shutting_down = True
        
        log_debug(ErrorCategory.CLEANUP, "Window destroy triggered, cleaning up")
        safe_cleanup(
            self.audio_input.cleanup,
            lambda: Gtk.main_quit()
        )
    
    def animate_entrance(self):
        """Smooth morphing animation from circle to pill"""
        if self.is_closing:
            self.animation_progress -= 0.04
            if self.animation_progress <= 0:
                self.animation_progress = 0
                if not self._shutting_down:
                    self._shutting_down = True
                    safe_cleanup(
                        self.audio_input.cleanup,
                        lambda: Gtk.main_quit()
                    )
                return False
        else:
            if self.animation_progress < 1.0:
                self.animation_progress += 0.04
                if self.animation_progress > 1.0:
                    self.animation_progress = 1.0
        
        eased = 1 - pow(1 - self.animation_progress, 3)
        self.set_opacity(eased)
        self.queue_draw()
        
        return True
    
    def check_close_signal(self):
        if safe_file_check("/tmp/groq_close_animation") and not self.is_closing:
            self.is_closing = True
            safe_file_remove("/tmp/groq_close_animation")
        return True
    
    def close_with_animation(self):
        self.is_closing = True
    
    # =========================================================================
    # Close button handlers
    # =========================================================================
    
    def on_draw_close_button(self, widget, cr):
        """Draw a filled circle with a clean × icon"""
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        
        if self.animation_progress < 0.7:
            return False
        
        content_alpha = min((self.animation_progress - 0.7) / 0.3, 1.0)
        
        cx = w / 2.0
        cy = h / 2.0
        radius = min(w, h) / 2.0 - 1.0
        
        # Filled circular background — matches pill border color
        if self._close_hover:
            cr.set_source_rgba(1.0, 1.0, 1.0, 0.50 * content_alpha)
        else:
            cr.set_source_rgba(1.0, 1.0, 1.0, 0.35 * content_alpha)
        cr.arc(cx, cy, radius, 0, 2 * math.pi)
        cr.fill()
        
        # Subtle border ring
        cr.set_source_rgba(1.0, 1.0, 1.0, 0.15 * content_alpha)
        cr.set_line_width(1.0)
        cr.arc(cx, cy, radius, 0, 2 * math.pi)
        cr.stroke()
        
        # × icon — clean, rounded strokes
        if self._close_hover:
            icon_alpha = 1.0 * content_alpha
        else:
            icon_alpha = 0.85 * content_alpha
        
        cr.set_source_rgba(1.0, 1.0, 1.0, icon_alpha)
        cr.set_line_width(2.0)
        cr.set_line_cap(1)  # ROUND
        
        # Size the × proportionally inside the circle
        arm = radius * 0.42
        
        cr.move_to(cx - arm, cy - arm)
        cr.line_to(cx + arm, cy + arm)
        cr.stroke()
        
        cr.move_to(cx + arm, cy - arm)
        cr.line_to(cx - arm, cy + arm)
        cr.stroke()
        
        return False
    
    def on_close_clicked(self, widget, event):
        """Handle close button click — cancel request and close overlay"""
        if self.is_closing:
            return True
        
        log_debug(ErrorCategory.SIGNAL_CHECK, "Close button clicked — cancelling request")
        
        # Write cancel signal for the shell script
        try:
            with open('/tmp/groq_cancel_request', 'w') as f:
                f.write('cancel')
        except Exception as e:
            log_error(ErrorCategory.FILE_IO, f"Failed to write cancel signal: {e}", e)
        
        # Trigger close animation
        self.close_with_animation()
        return True
    
    def on_close_hover_enter(self, widget, event):
        self._close_hover = True
        widget.queue_draw()
        return False
    
    def on_close_hover_leave(self, widget, event):
        self._close_hover = False
        widget.queue_draw()
        return False
    
    def on_draw(self, widget, cr):
        try:
            return renderers.draw_background(widget, cr, self.animation_progress, is_error=self.is_offline)
        except Exception as e:
            log_error(ErrorCategory.UI_RENDER, f"Background draw error: {e}", e)
            return False
    
    def on_draw_waveform(self, widget, cr):
        """Draws the waveform — live audio or pulsing processing animation"""
        if self.is_offline:
             return False
        
        try:
            return renderers.draw_waveform(
                widget, cr,
                self.animation_progress,
                self.bars,
                self.num_bars,
                self.overall_audio_level,
                self.processing_mode,
                self.pulse_phase
            )
        except Exception as e:
            log_error(ErrorCategory.UI_RENDER, f"Waveform draw error: {e}", e)
            return False
    
    def check_processing_mode(self):
        if safe_file_check("/tmp/groq_processing_mode") and not self.processing_mode:
            self.processing_mode = True
            self.audio_input.set_processing_mode(True)
            self.processing_start_time = time.time()
            self.pulse_phase = 0.0
            safe_file_remove("/tmp/groq_processing_mode")
            log_debug(ErrorCategory.SIGNAL_CHECK, "Entered processing mode")
        
        if safe_file_check("/tmp/groq_connection_error"):
            self.is_offline = True
            self.queue_draw()
            safe_file_remove("/tmp/groq_connection_error")
            log_warning(ErrorCategory.SIGNAL_CHECK, "Connection error signal received")
                
        return True
    
    def position_window(self):
        allocation = self.get_allocation()
        width = allocation.width
        height = allocation.height
        
        if width <= 1:
            return True
        
        screen = self.get_screen()
        screen_width = screen.get_width()
        screen_height = screen.get_height()
        
        x = (screen_width - width) // 2
        y = screen_height - height - 60
        
        self.target_y = y
        self.move(x, y)
        return False
    
    def update_animation(self):
        """Update bar heights — live audio or processing pulse"""
        if self.processing_mode:
            # Scanning "Knight Rider" loading effect
            self.pulse_phase += 0.35  # Speed of the scan
            
            # Calculate position using a triangle wave
            period = 2.0 * max(1, self.num_bars - 1)
            # This creates a value that bounces between 0 and (num_bars - 1)
            scan_pos = abs((self.pulse_phase % period) - (self.num_bars - 1))
            
            for i in range(self.num_bars):
                # Distance from the scan head
                dist = abs(i - scan_pos)
                
                # Sharp peak that falls off quickly
                intensity = max(0.0, 1.0 - (dist * 0.45))
                self.bars[i] = 0.15 + (intensity * 0.65)
        else:
            # Animate bars (buttery smooth interpolation)
            center = (self.num_bars - 1) / 2.0
            for i in range(self.num_bars):
                diff = self.target_bars[i] - self.bars[i]
                
                if diff > 0:
                    # Rising: gentle and fluid
                    self.bars[i] += diff * 0.18
                else:
                    # Falling: edges fall slightly faster than the center, but still very smooth
                    dist = abs(i - center)
                    fall_speed = 0.06 + (dist * 0.015) # Center falls slowly (0.06), edges gently faster (~0.17)
                    self.bars[i] += diff * fall_speed
                    
                self.bars[i] = max(0.0, min(self.bars[i], 1.0))
        
        self.waveform_area.queue_draw()
        return True

if __name__ == "__main__":
    try:
        log_debug(ErrorCategory.UI_RENDER, "Starting WaveformOverlay application")
        win = WaveformOverlay()
        Gtk.main()
    except Exception as e:
        log_error(ErrorCategory.UI_RENDER, f"Fatal error in main: {e}", e)
        sys.exit(1)
