#!/usr/bin/env python3
"""
Waveform Overlay for GNOME Wayland
Style: Cream Background, Black UI, Pill Shape
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
from gi.repository import Gtk, Gdk, GLib, Pango

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
        
        # DOCK type
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.set_startup_id("")
        
        # Transparent visual
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        
        # Connect draw signal
        self.connect('draw', self.on_draw)
        self.connect('destroy', self.on_destroy)
        
        # Container
        self.box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.box.set_valign(Gtk.Align.CENTER)
        # Margins determine the "padding" inside the pill
        self.box.set_margin_top(8)
        self.box.set_margin_bottom(8)
        self.box.set_margin_start(15)
        self.box.set_margin_end(15)
        
        self.add(self.box)
        
        # Waveform Drawing Area
        self.waveform_area = Gtk.DrawingArea()
        self.waveform_area.set_size_request(110, 24) # Smaller size
        self.waveform_area.connect('draw', self.on_draw_waveform)
        self.box.pack_start(self.waveform_area, True, True, 0)
        
        # Timer Label / Spinner Area
        self.timer_area = Gtk.DrawingArea()
        self.timer_area.set_size_request(40, 24)
        self.timer_area.connect('draw', self.on_draw_timer)
        self.box.pack_start(self.timer_area, False, False, 0)
        
        # State tracking
        self.start_time = time.time()
        self.processing_mode = False  # IMPORTANT: Start in recording mode (timer visible)
        self.is_offline = False
        self.processing_start_time = None
        self._shutting_down = False  # Prevent multiple cleanup attempts
        
        # Animation state
        self.animation_progress = 0.0  # 0.0 to 1.0
        self.is_closing = False
        self.target_y = 0
        self.current_y = 0
        
        # Waveform animation data
        self.num_bars = 16  # Reduced from 20
        self.bars = [0.1] * self.num_bars
        self.target_bars = [0.1] * self.num_bars
        
        # Spinner animation - initialize to 0, only used when processing_mode=True
        self.spinner_angle = 0.0
        
        # Audio input setup
        self.audio_input = AudioInput()
        audio_ok = self.audio_input.setup()
        if not audio_ok:
            log_warning(ErrorCategory.AUDIO_INPUT, "Audio unavailable, waveform will be static")

        self.audio_levels = [0.0] * self.num_bars
        self.overall_audio_level = 0.0  # For spacing animation
        
        # Show window (initially invisible)
        self.set_opacity(0.0)
        self.show_all()
        
        # Timers - store IDs for potential cleanup
        self._timer_ids = []
        self._timer_ids.append(GLib.timeout_add(10, self._safe_position_window))
        self._timer_ids.append(GLib.timeout_add(100, self._safe_position_window))
        self._timer_ids.append(GLib.timeout_add(40, self._safe_update_animation))  # 25 FPS for smooth bars
        self._timer_ids.append(GLib.timeout_add(100, self._safe_check_processing_mode))
        self._timer_ids.append(GLib.timeout_add(50, self._safe_update_audio_levels))  # 20 FPS for audio
        self._timer_ids.append(GLib.timeout_add(16, self._safe_animate_entrance))  # 60 FPS for smooth entrance
        self._timer_ids.append(GLib.timeout_add(100, self._safe_check_close_signal))  # Check for close signal
        
        log_debug(ErrorCategory.UI_RENDER, "WaveformOverlay initialized successfully")

    # =========================================================================
    # Safe wrapper methods for all timer callbacks
    # =========================================================================
    
    def _safe_update_audio_levels(self):
        """Safe wrapper for audio level updates"""
        if self._shutting_down:
            return False
        try:
            return self.update_audio_levels()
        except Exception as e:
            log_error(ErrorCategory.AUDIO_INPUT, f"Error updating audio levels: {e}", e)
            return True  # Keep timer running
    
    def _safe_update_animation(self):
        """Safe wrapper for animation updates"""
        if self._shutting_down:
            return False
        try:
            return self.update_animation()
        except Exception as e:
            log_error(ErrorCategory.ANIMATION, f"Error in animation update: {e}", e)
            return True  # Keep timer running
    
    def _safe_animate_entrance(self):
        """Safe wrapper for entrance animation"""
        if self._shutting_down:
            return False
        try:
            return self.animate_entrance()
        except Exception as e:
            log_error(ErrorCategory.ANIMATION, f"Error in entrance animation: {e}", e)
            # On error, just complete the animation
            self.animation_progress = 1.0
            self.set_opacity(1.0)
            return False
    
    def _safe_check_close_signal(self):
        """Safe wrapper for close signal check"""
        if self._shutting_down:
            return False
        try:
            return self.check_close_signal()
        except Exception as e:
            log_error(ErrorCategory.SIGNAL_CHECK, f"Error checking close signal: {e}", e)
            return True
    
    def _safe_check_processing_mode(self):
        """Safe wrapper for processing mode check"""
        if self._shutting_down:
            return False
        try:
            return self.check_processing_mode()
        except Exception as e:
            log_error(ErrorCategory.SIGNAL_CHECK, f"Error checking processing mode: {e}", e)
            return True
    
    def _safe_position_window(self):
        """Safe wrapper for window positioning"""
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
            return True  # Skip audio updates during processing
            
        level = self.audio_input.get_level()
        
        # Update overall level for spacing animation (smooth)
        self.overall_audio_level = (self.overall_audio_level * 0.7) + (level * 0.3)
        
        # Shift levels to the left (wave motion from right to left)
        self.audio_levels.pop(0)
        self.audio_levels.append(level)
        
        # Update target bars based on audio (reversed for right-to-left)
        for i in range(self.num_bars):
            # Read from right to left
            audio_index = self.num_bars - 1 - i
            audio_val = self.audio_levels[audio_index]
            random_factor = random.uniform(0.8, 1.2)
            self.target_bars[i] = min(audio_val * random_factor, 1.0)
            
            # Ensure minimum height
            if self.target_bars[i] < 0.1:
                self.target_bars[i] = 0.1
        
        return True
    
    def on_destroy(self, widget):
        """Cleanup on window close"""
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
            # Morph back to circle and fade out
            self.animation_progress -= 0.04  # Slower (was 0.10)
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
            # Morph from circle to pill
            if self.animation_progress < 1.0:
                self.animation_progress += 0.04  # Slower (was 0.10)
                if self.animation_progress > 1.0:
                    self.animation_progress = 1.0
        
        # Smooth easing function (ease-out)
        eased = 1 - pow(1 - self.animation_progress, 3)
        
        # Apply opacity
        self.set_opacity(eased)
        
        # Trigger redraw for morph effect
        self.queue_draw()
        
        return True
    
    def check_close_signal(self):
        """Check if we should start closing animation"""
        if safe_file_check("/tmp/groq_close_animation") and not self.is_closing:
            self.is_closing = True
            safe_file_remove("/tmp/groq_close_animation")
        return True
    
    def close_with_animation(self):
        """Start closing animation"""
        self.is_closing = True
    
    def on_draw(self, widget, cr):
        """Draw the pill background with morphing animation"""
        try:
            return renderers.draw_background(widget, cr, self.animation_progress, is_error=self.is_offline)
        except Exception as e:
            log_error(ErrorCategory.UI_RENDER, f"Background draw error: {e}", e)
            return False
    
    def on_draw_timer(self, widget, cr):
        """Draw timer text or spinner based on mode"""
        try:
            return renderers.draw_timer(
                widget, cr, 
                self.animation_progress, 
                self.processing_mode, 
                self.spinner_angle, 
                self.start_time,
                is_error=self.is_offline
            )
        except Exception as e:
            log_error(ErrorCategory.UI_RENDER, f"Timer draw error: {e}", e)
            return False
    
    def on_draw_waveform(self, widget, cr):
        """Draws the vertical bars for the waveform"""
        # Hide bars if offline
        if self.is_offline:
             return False
        
        try:
            return renderers.draw_waveform(
                widget, cr,
                self.animation_progress,
                self.bars,
                self.num_bars,
                self.overall_audio_level
            )
        except Exception as e:
            log_error(ErrorCategory.UI_RENDER, f"Waveform draw error: {e}", e)
            return False
    
    def check_processing_mode(self):
        """Check for external signals"""
        # Processing Signal
        if safe_file_check("/tmp/groq_processing_mode") and not self.processing_mode:
            self.processing_mode = True
            self.audio_input.set_processing_mode(True)
            self.processing_start_time = time.time()
            self.spinner_angle = 0.0  # Reset spinner angle when entering processing mode
            safe_file_remove("/tmp/groq_processing_mode")
            log_debug(ErrorCategory.SIGNAL_CHECK, "Entered processing mode")
        
        # Offline/Error Signal
        if safe_file_check("/tmp/groq_connection_error"):
            self.is_offline = True
            # Force redraw
            self.queue_draw()
            safe_file_remove("/tmp/groq_connection_error")
            log_warning(ErrorCategory.SIGNAL_CHECK, "Connection error signal received")
                
        return True
    
    def position_window(self):
        """Position window at bottom center"""
        allocation = self.get_allocation()
        width = allocation.width
        height = allocation.height
        
        if width <= 1:
            return True
        
        screen = self.get_screen()
        screen_width = screen.get_width()
        screen_height = screen.get_height()
        
        x = (screen_width - width) // 2
        y = screen_height - height - 150  # Pushed up more (was 100)
        
        self.target_y = y
        self.move(x, y)
        return False
    
    def update_animation(self):
        """Update bar heights and timer"""
        if self.processing_mode:
            # Rotate spinner - guard against invalid values
            self.spinner_angle += 0.15  # Rotation speed
            if self.spinner_angle > 2 * math.pi:
                self.spinner_angle -= 2 * math.pi
            # Clamp to valid range as extra safety
            self.spinner_angle = max(0.0, min(self.spinner_angle, 2 * math.pi))
            self.timer_area.queue_draw()
        else:
            # Animate Bars (smooth interpolation)
            for i in range(self.num_bars):
                # Smoothly interpolate towards target
                diff = self.target_bars[i] - self.bars[i]
                self.bars[i] += diff * 0.3  # Faster response for audio
                # Clamp values to valid range
                self.bars[i] = max(0.0, min(self.bars[i], 1.0))
            
            self.timer_area.queue_draw()
        
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
