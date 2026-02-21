"""
Centralized Error Handling for Waveform Overlay
Provides safe execution wrappers, logging, and error state management.
"""
import sys
import os
import traceback
import functools
from datetime import datetime
from enum import Enum, auto
from typing import Callable, Any, Optional

# ============================================================================
# Error Categories and Severity
# ============================================================================

class ErrorCategory(Enum):
    """Categories of errors for classification and handling"""
    UI_RENDER = auto()      # Drawing/rendering failures
    AUDIO_INPUT = auto()    # Microphone/audio device issues
    FILE_IO = auto()        # File read/write errors
    SIGNAL_CHECK = auto()   # External signal file checks
    ANIMATION = auto()      # Animation loop errors
    WINDOW_MGMT = auto()    # Window positioning/management
    CLEANUP = auto()        # Resource cleanup errors
    UNKNOWN = auto()        # Unclassified errors


class ErrorSeverity(Enum):
    """Severity levels for error handling decisions"""
    TRANSIENT = auto()   # Can be ignored, will likely resolve
    RECOVERABLE = auto() # Can recover with fallback behavior
    DEGRADED = auto()    # Feature disabled but app continues
    FATAL = auto()       # App must terminate


# ============================================================================
# Error State Manager (Singleton)
# ============================================================================

class ErrorState:
    """
    Centralized error state for UI reflection.
    Tracks current errors and provides state for UI to display.
    """
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        
        # Error counts by category
        self.error_counts: dict[ErrorCategory, int] = {cat: 0 for cat in ErrorCategory}
        
        # Current active errors (for UI display)
        self.active_errors: list[dict] = []
        
        # Feature degradation flags
        self.audio_degraded = False
        self.rendering_degraded = False
        
        # Last error for debugging
        self.last_error: Optional[Exception] = None
        self.last_error_category: Optional[ErrorCategory] = None
        
        # Consecutive error tracking (for circuit breaker)
        self._consecutive_errors: dict[str, int] = {}
        self._max_consecutive = 5
    
    def record_error(self, category: ErrorCategory, severity: ErrorSeverity, 
                     error: Exception, context: str = ""):
        """Record an error occurrence"""
        self.error_counts[category] += 1
        self.last_error = error
        self.last_error_category = category
        
        # Track consecutive errors by context
        key = f"{category.name}:{context}"
        self._consecutive_errors[key] = self._consecutive_errors.get(key, 0) + 1
        
        # Check for degradation threshold
        if self._consecutive_errors[key] >= self._max_consecutive:
            if category == ErrorCategory.AUDIO_INPUT:
                self.audio_degraded = True
            elif category == ErrorCategory.UI_RENDER:
                self.rendering_degraded = True
    
    def clear_consecutive(self, category: ErrorCategory, context: str = ""):
        """Clear consecutive error count after successful operation"""
        key = f"{category.name}:{context}"
        self._consecutive_errors[key] = 0
    
    def is_circuit_open(self, category: ErrorCategory, context: str = "") -> bool:
        """Check if too many consecutive errors (circuit breaker pattern)"""
        key = f"{category.name}:{context}"
        return self._consecutive_errors.get(key, 0) >= self._max_consecutive
    
    def reset(self):
        """Reset all error state"""
        self.error_counts = {cat: 0 for cat in ErrorCategory}
        self.active_errors.clear()
        self.audio_degraded = False
        self.rendering_degraded = False
        self.last_error = None
        self.last_error_category = None
        self._consecutive_errors.clear()


# Global error state instance
error_state = ErrorState()


# ============================================================================
# Logging
# ============================================================================

LOG_FILE = "/tmp/groq_overlay_errors.log"
_log_enabled = True

def _log(level: str, category: ErrorCategory, message: str, exc: Optional[Exception] = None):
    """Internal logging function"""
    if not _log_enabled:
        return
    
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    log_line = f"[{timestamp}] [{level}] [{category.name}] {message}"
    
    if exc:
        log_line += f"\n  Exception: {type(exc).__name__}: {exc}"
        # Only include traceback for non-transient errors
        if level != "DEBUG":
            tb = traceback.format_exc()
            if tb and tb != "NoneType: None\n":
                log_line += f"\n  Traceback:\n{tb}"
    
    try:
        with open(LOG_FILE, "a") as f:
            f.write(log_line + "\n")
    except:
        pass  # Don't let logging errors cause more problems
    
    # Also print to stderr for immediate visibility during development
    if level in ("ERROR", "FATAL"):
        print(log_line, file=sys.stderr)


def log_debug(category: ErrorCategory, message: str):
    """Log debug information"""
    _log("DEBUG", category, message)


def log_warning(category: ErrorCategory, message: str, exc: Optional[Exception] = None):
    """Log a warning"""
    _log("WARN", category, message, exc)


def log_error(category: ErrorCategory, message: str, exc: Optional[Exception] = None):
    """Log an error"""
    _log("ERROR", category, message, exc)
    if exc:
        error_state.record_error(category, ErrorSeverity.RECOVERABLE, exc, message)


def log_fatal(category: ErrorCategory, message: str, exc: Optional[Exception] = None):
    """Log a fatal error"""
    _log("FATAL", category, message, exc)
    if exc:
        error_state.record_error(category, ErrorSeverity.FATAL, exc, message)


# ============================================================================
# Safe Execution Wrappers
# ============================================================================

def safe_callback(category: ErrorCategory, default_return: Any = True, 
                  context: str = "") -> Callable:
    """
    Decorator for GTK callbacks that catches exceptions and prevents crashes.
    
    Args:
        category: Error category for logging
        default_return: Value to return on error (True keeps timer running)
        context: Additional context for error tracking
    
    Usage:
        @safe_callback(ErrorCategory.ANIMATION, default_return=True)
        def update_animation(self):
            ...
    """
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            try:
                result = func(*args, **kwargs)
                # Clear consecutive errors on success
                error_state.clear_consecutive(category, context or func.__name__)
                return result
            except Exception as e:
                log_error(category, f"Error in {func.__name__}: {e}", e)
                return default_return
        return wrapper
    return decorator


def safe_draw(category: ErrorCategory = ErrorCategory.UI_RENDER) -> Callable:
    """
    Decorator specifically for draw callbacks.
    Returns False on error to allow event propagation.
    """
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                log_error(category, f"Draw error in {func.__name__}: {e}", e)
                return False  # Allow propagation
        return wrapper
    return decorator


def safe_call(func: Callable, category: ErrorCategory, 
              default: Any = None, context: str = "") -> Any:
    """
    Execute a function safely with error handling.
    
    Args:
        func: Function to call (no arguments)
        category: Error category
        default: Default return value on error
        context: Error context description
    
    Returns:
        Function result or default on error
    """
    try:
        result = func()
        error_state.clear_consecutive(category, context)
        return result
    except Exception as e:
        log_error(category, f"Error in {context or 'safe_call'}: {e}", e)
        return default


# ============================================================================
# Resource Cleanup Helper
# ============================================================================

def safe_cleanup(*cleanup_funcs: Callable):
    """
    Execute multiple cleanup functions, catching errors in each.
    Ensures all cleanup attempts are made even if some fail.
    """
    for func in cleanup_funcs:
        try:
            func()
        except Exception as e:
            log_warning(ErrorCategory.CLEANUP, f"Cleanup error: {e}", e)


def safe_file_check(path: str) -> bool:
    """Safely check if a file exists"""
    try:
        return os.path.exists(path)
    except Exception as e:
        log_warning(ErrorCategory.FILE_IO, f"File check error for {path}: {e}", e)
        return False


def safe_file_remove(path: str) -> bool:
    """Safely remove a file"""
    try:
        if os.path.exists(path):
            os.remove(path)
        return True
    except Exception as e:
        log_warning(ErrorCategory.FILE_IO, f"File remove error for {path}: {e}", e)
        return False
