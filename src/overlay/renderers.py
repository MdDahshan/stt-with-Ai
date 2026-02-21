import math
import time
import cairo
from visuals import draw_pill_path

# Safe imports for error handling (optional dependency)
try:
    from errors import ErrorCategory, log_error, log_warning
    _has_errors = True
except ImportError:
    _has_errors = False
    def log_error(*args, **kwargs): pass
    def log_warning(*args, **kwargs): pass
    class ErrorCategory:
        UI_RENDER = None


def _safe_draw(func):
    """Decorator to catch and log drawing errors"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            if _has_errors:
                log_error(ErrorCategory.UI_RENDER, f"Draw error in {func.__name__}: {e}", e)
            return False
    return wrapper


@_safe_draw
def draw_background(widget, cr, animation_progress, is_error=False):
    """Draw the pill background with morphing animation"""
    width = widget.get_allocated_width()
    height = widget.get_allocated_height()
    
    # Clear
    cr.set_operator(0)
    cr.paint()
    cr.set_operator(2) # OVER
    
    # Calculate morph progress (ease-out cubic)
    eased = 1 - pow(1 - animation_progress, 3)
    
    # Morph from circle to pill
    # Start as circle (width = height), end as full pill
    morph_width = height + ((width - height) * eased)
    morph_x = (width - morph_width) / 2
    
    # Apply transformation
    cr.translate(morph_x, 0)
    
    # Style Constants
    if is_error:
        # Reddish tint for error state
        border_color = (1.0, 0.3, 0.3, 1.0)
    else:
        border_color = (1.0, 1.0, 1.0, 1.0)
    
    # Draw Shadow (Subtle) - simulates blur
    for i in range(12):
        offset = 12 - i
        alpha = 0.08 - (i * 0.006)
        cr.set_source_rgba(0, 0, 0, alpha)
        draw_pill_path(cr, offset, offset, morph_width - (offset * 2), height - (offset * 2))
        cr.fill()
    
    # Additional blur effect layers
    for i in range(8):
        offset = 8 - i
        alpha = 0.05 - (i * 0.005)
        cr.set_source_rgba(0.2, 0.2, 0.2, alpha)
        draw_pill_path(cr, offset, offset, morph_width - (offset * 2), height - (offset * 2))
        cr.fill()
    
    # Draw Main Background
    if is_error:
        # Dark Red Gradient
        gradient = cairo.LinearGradient(0, 0, 0, height)
        gradient.add_color_stop_rgba(0, 0.2, 0.05, 0.05, 0.90)  
        gradient.add_color_stop_rgba(1, 0.1, 0.0, 0.0, 0.90)
    else:
        # Create subtle vertical gradient - very dark with slight variation
        gradient = cairo.LinearGradient(0, 0, 0, height)
        gradient.add_color_stop_rgba(0, 0.08, 0.08, 0.08, 0.85)  # Very dark gray top
        gradient.add_color_stop_rgba(0.5, 0.02, 0.02, 0.02, 0.82)  # Almost black middle
        gradient.add_color_stop_rgba(1, 0, 0, 0, 0.80)  # Pure black bottom
    
    cr.set_source(gradient)
    draw_pill_path(cr, 0, 0, morph_width, height)
    cr.fill()
    
    # Draw Border with minimal glow effect
    # Minimal glow layers (reduced from 10 to 3)
    for i in range(3, 0, -1):
        alpha = 0.015 * (4 - i) / 3  # Very subtle glow
        line_width = 2 + (i * 0.4)
        if is_error:
             cr.set_source_rgba(1.0, 0.2, 0.2, alpha)
        else:
             cr.set_source_rgba(1.0, 1.0, 1.0, alpha)
        cr.set_line_width(line_width)
        draw_pill_path(cr, 1, 1, morph_width - 2, height - 2)
        cr.stroke()
    
    # Draw main border
    cr.set_source_rgba(*border_color)
    cr.set_line_width(2)
    draw_pill_path(cr, 1, 1, morph_width - 2, height - 2)
    cr.stroke()
    
    if is_error:
        # Only draw if animation is mostly complete (> 70%) to prevent floating text
        if animation_progress < 0.7:
             return False
             
        # Fade in/out content based on animation progress
        content_alpha = min((animation_progress - 0.7) / 0.3, 1.0)
        
        # Draw Error Message Centered in the Pill
        text = "Check your network"
        cr.set_source_rgba(1.0, 1.0, 1.0, content_alpha) # White text with fade
        cr.select_font_face("monospace", 0, 1)  # Bold
        cr.set_font_size(11)
        extents = cr.text_extents(text)
        
        # Center relative to the pill shape (context is already translated)
        tx = (morph_width - extents.width) / 2 - extents.x_bearing
        ty = (height - extents.height) / 2 - extents.y_bearing
        
        cr.move_to(tx, ty)
        cr.show_text(text)
    
    return False # Propagate to children


@_safe_draw
def draw_timer(widget, cr, animation_progress, processing_mode, spinner_angle, start_time, is_error=False):
    """Draw timer text or spinner based on mode"""
    w = widget.get_allocated_width()
    h = widget.get_allocated_height()
    
    # Validate dimensions
    if w <= 0 or h <= 0:
        return False
    
    # Only draw if animation is mostly complete (> 70%)
    if animation_progress < 0.7:
        return False
    
    # Fade in content after morph
    content_alpha = min((animation_progress - 0.7) / 0.3, 1.0)
    content_alpha = max(0.0, min(1.0, content_alpha))  # Clamp to valid range
    
    # White color with fade
    cr.set_source_rgba(1.0, 1.0, 1.0, content_alpha)
    
    if is_error:
        return False

    if processing_mode:
        # Draw spinning loader
        center_x = w / 2
        center_y = h / 2
        radius = 8  # Smaller spinner
        
        # Validate radius
        if radius <= 0 or radius > min(w, h) / 2:
            radius = min(w, h) / 4
        
        cr.set_line_width(2)
        cr.set_line_cap(1)  # Round cap
        
        # Validate spinner_angle
        angle = float(spinner_angle) if spinner_angle is not None else 0.0
        if not math.isfinite(angle):
            angle = 0.0
        
        # Rotating arc
        start_angle = angle
        end_angle = start_angle + (math.pi * 1.5)  # 270 degrees
        
        cr.arc(center_x, center_y, radius, start_angle, end_angle)
        cr.stroke()
    else:
        # Draw timer text
        elapsed = int(time.time() - start_time)
        # Validate elapsed time
        if elapsed < 0:
            elapsed = 0
        if elapsed > 86400:  # Cap at 24 hours
            elapsed = 86400
            
        minutes = elapsed // 60
        seconds = elapsed % 60
        timer_text = f"{minutes}:{seconds:02d}"
        
        # Setup text
        cr.select_font_face("monospace", 0, 1)  # Bold
        cr.set_font_size(12)  # Smaller font
        
        # Get text dimensions for centering
        extents = cr.text_extents(timer_text)
        x = (w - extents.width) / 2 - extents.x_bearing
        y = (h - extents.height) / 2 - extents.y_bearing
        
        cr.move_to(x, y)
        cr.show_text(timer_text)
    
    return False

    return False


@_safe_draw
def draw_waveform(widget, cr, animation_progress, bars, num_bars, overall_audio_level):
    """Draws the vertical bars for the waveform"""
    w = widget.get_allocated_width()
    h = widget.get_allocated_height()
    
    # Validate dimensions
    if w <= 0 or h <= 0:
        return False
    
    # Only draw if animation is mostly complete (> 70%)
    if animation_progress < 0.7:
        return False
    
    # Fade in content after morph
    content_alpha = min((animation_progress - 0.7) / 0.3, 1.0)
    content_alpha = max(0.0, min(1.0, content_alpha))  # Clamp
    
    # White color with fade
    cr.set_source_rgba(1.0, 1.0, 1.0, content_alpha)
    
    # Validate inputs
    if not bars or num_bars <= 0:
        return False
    
    # Clamp overall_audio_level
    audio_level = float(overall_audio_level) if overall_audio_level is not None else 0.0
    if not math.isfinite(audio_level):
        audio_level = 0.0
    audio_level = max(0.0, min(1.0, audio_level))
    
    # Dynamic spacing based on audio level
    base_gap = 2
    dynamic_gap = base_gap + (audio_level * 2)  # Gap increases with volume
    
    # Draw waveform bars with dynamic spacing
    bar_w = 3  # Thinner bars
    total_gap = dynamic_gap * (num_bars - 1)
    total_bar_width = num_bars * bar_w
    total_w = total_bar_width + total_gap
    start_x = (w - total_w) / 2
    
    for i, val in enumerate(bars):
        if i >= num_bars:
            break
            
        # Validate and clamp bar value
        bar_val = float(val) if val is not None else 0.1
        if not math.isfinite(bar_val):
            bar_val = 0.1
        bar_val = max(0.0, min(1.0, bar_val))
        
        # Calculate height based on value (0.0 to 1.0)
        # Min height 4px, Max height is container height
        bar_h = 4 + (bar_val * (h - 6))
        bar_h = max(4, min(bar_h, h))  # Clamp height
        
        x = start_x + i * (bar_w + dynamic_gap)
        y = (h - bar_h) / 2
        
        # Draw more rounded bar (increased radius)
        radius = bar_w / 1.5  # More rounded (was bar_w / 2)
        radius = max(0.5, min(radius, bar_h / 2))  # Ensure valid radius
        
        cr.new_path()
        cr.arc(x + radius, y + radius, radius, math.pi, 0)
        cr.arc(x + radius, y + bar_h - radius, radius, 0, math.pi)
        cr.close_path()
        cr.fill()
    
    return False
