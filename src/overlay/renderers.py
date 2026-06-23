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
    """Draw the pill background with morphing animation — refined B&W"""
    width = widget.get_allocated_width()
    height = widget.get_allocated_height()
    
    # Clear
    cr.set_operator(0)
    cr.paint()
    cr.set_operator(2) # OVER
    
    # Calculate morph progress (ease-out cubic)
    eased = 1 - pow(1 - animation_progress, 3)
    
    # Morph from circle to pill
    morph_width = height + ((width - height) * eased)
    morph_x = (width - morph_width) / 2
    
    # Apply transformation
    cr.translate(morph_x, 0)
    
    # Style Constants
    if is_error:
        border_color = (1.0, 0.3, 0.3, 0.95)
    else:
        border_color = (1.0, 1.0, 1.0, 0.35)
    
    # Draw Shadow — clean and minimal (6 layers)
    for i in range(6):
        offset = 6 - i
        alpha = 0.06 - (i * 0.009)
        if alpha > 0:
            cr.set_source_rgba(0, 0, 0, alpha)
            draw_pill_path(cr, offset, offset, morph_width - (offset * 2), height - (offset * 2))
            cr.fill()
    
    # Draw Main Background — deep black
    if is_error:
        gradient = cairo.LinearGradient(0, 0, 0, height)
        gradient.add_color_stop_rgba(0, 0.18, 0.04, 0.04, 0.92)  
        gradient.add_color_stop_rgba(1, 0.08, 0.0, 0.0, 0.92)
    else:
        gradient = cairo.LinearGradient(0, 0, 0, height)
        gradient.add_color_stop_rgba(0, 0.06, 0.06, 0.06, 0.92)
        gradient.add_color_stop_rgba(1, 0.02, 0.02, 0.02, 0.90)
    
    cr.set_source(gradient)
    draw_pill_path(cr, 0, 0, morph_width, height)
    cr.fill()
    
    # Single subtle outer glow
    if is_error:
        cr.set_source_rgba(1.0, 0.2, 0.2, 0.04)
    else:
        cr.set_source_rgba(1.0, 1.0, 1.0, 0.03)
    cr.set_line_width(3.0)
    draw_pill_path(cr, 1, 1, morph_width - 2, height - 2)
    cr.stroke()
    
    # Main border — crisp white
    cr.set_source_rgba(*border_color)
    cr.set_line_width(1.5)
    draw_pill_path(cr, 1, 1, morph_width - 2, height - 2)
    cr.stroke()
    
    if is_error:
        if animation_progress < 0.7:
             return False
             
        content_alpha = min((animation_progress - 0.7) / 0.3, 1.0)
        
        text = "Check your network"
        cr.set_source_rgba(1.0, 1.0, 1.0, content_alpha)
        cr.select_font_face("Sans", 0, 1)
        cr.set_font_size(11)
        extents = cr.text_extents(text)
        
        tx = (morph_width - extents.width) / 2 - extents.x_bearing
        ty = (height - extents.height) / 2 - extents.y_bearing
        
        cr.move_to(tx, ty)
        cr.show_text(text)
    
    return False


@_safe_draw
def draw_waveform(widget, cr, animation_progress, bars, num_bars, overall_audio_level,
                  processing_mode=False, pulse_phase=0.0):
    """Draws the waveform bars — live audio or processing pulse"""
    w = widget.get_allocated_width()
    h = widget.get_allocated_height()
    
    if w <= 0 or h <= 0:
        return False
    
    if animation_progress < 0.7:
        return False
    
    # Fade in content after morph
    content_alpha = min((animation_progress - 0.7) / 0.3, 1.0)
    content_alpha = max(0.0, min(1.0, content_alpha))
    
    if not bars or num_bars <= 0:
        return False
    
    # Clamp overall_audio_level
    audio_level = float(overall_audio_level) if overall_audio_level is not None else 0.0
    if not math.isfinite(audio_level):
        audio_level = 0.0
    audio_level = max(0.0, min(1.0, audio_level))
    
    # Spacing
    if processing_mode:
        dynamic_gap = 3.0  # Fixed even spacing during processing
    else:
        base_gap = 2.5
        dynamic_gap = base_gap + (audio_level * 1.5)
    
    # Bar dimensions
    bar_w = 2.5
    total_gap = dynamic_gap * (num_bars - 1)
    total_bar_width = num_bars * bar_w
    total_w = total_bar_width + total_gap
    start_x = (w - total_w) / 2
    
    center = num_bars / 2.0
    
    for i, val in enumerate(bars):
        if i >= num_bars:
            break
            
        bar_val = float(val) if val is not None else 0.1
        if not math.isfinite(bar_val):
            bar_val = 0.1
        bar_val = max(0.0, min(1.0, bar_val))
        
        # Opacity: center bars brighter, edges dimmer
        distance_from_center = abs(i - center) / center
        
        if processing_mode:
            # Highlight the bright bars for the scanning effect
            bar_alpha = content_alpha * (0.2 + bar_val * 0.8)
        else:
            bar_alpha = content_alpha * (1.0 - distance_from_center * 0.25)
        
        cr.set_source_rgba(1.0, 1.0, 1.0, bar_alpha)
        
        # Height
        bar_h = 3 + (bar_val * (h - 5))
        bar_h = max(3, min(bar_h, h))
        
        x = start_x + i * (bar_w + dynamic_gap)
        y = (h - bar_h) / 2
        
        # Fully rounded bar tips
        radius = bar_w / 2.0
        radius = max(0.5, min(radius, bar_h / 2))
        
        cr.new_path()
        cr.arc(x + radius, y + radius, radius, math.pi, 0)
        cr.arc(x + radius, y + bar_h - radius, radius, 0, math.pi)
        cr.close_path()
        cr.fill()
    
    return False
