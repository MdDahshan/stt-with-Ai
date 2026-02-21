import math

def draw_pill_path(cr, x, y, w, h):
    """Draws a perfect pill shape (semicircle ends)"""
    radius = h / 2.0
    cr.new_path()
    # Right arc
    cr.arc(x + w - radius, y + radius, radius, -math.pi/2, math.pi/2)
    # Left arc
    cr.arc(x + radius, y + radius, radius, math.pi/2, 3*math.pi/2)
    cr.close_path()
