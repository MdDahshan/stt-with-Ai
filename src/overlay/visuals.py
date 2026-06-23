import math

def draw_pill_path(cr, x, y, w, h):
    """Draws a rounded rectangle with a smaller corner radius"""
    radius = 16.0  # Increased corner radius, but still less than the full height/2
    radius = min(radius, h / 2.0)  # Safe guard
    
    cr.new_path()
    # Top right corner
    cr.arc(x + w - radius, y + radius, radius, -math.pi/2, 0)
    # Bottom right corner
    cr.arc(x + w - radius, y + h - radius, radius, 0, math.pi/2)
    # Bottom left corner
    cr.arc(x + radius, y + h - radius, radius, math.pi/2, math.pi)
    # Top left corner
    cr.arc(x + radius, y + radius, radius, math.pi, 3*math.pi/2)
    cr.close_path()
