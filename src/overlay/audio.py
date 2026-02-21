import pyaudio
import struct
import math
from errors import (
    ErrorCategory, log_error, log_warning, log_debug,
    error_state, safe_call
)


class AudioInput:
    """
    Handles real-time audio input with comprehensive error handling.
    Degrades gracefully if audio device is unavailable.
    """
    
    def __init__(self):
        self.audio = None
        self.stream = None
        self.processing_mode = False
        self._setup_failed = False
        self._read_errors = 0
        self._max_read_errors = 10  # After this many errors, stop trying

    def setup(self) -> bool:
        """
        Setup PyAudio for real-time audio input.
        
        Returns:
            True if setup succeeded, False otherwise
        """
        try:
            self.audio = pyaudio.PyAudio()
            
            # Check for available input devices
            device_count = self.audio.get_device_count()
            if device_count == 0:
                log_warning(ErrorCategory.AUDIO_INPUT, "No audio devices found")
                self._setup_failed = True
                return False
            
            # Find default input device
            try:
                default_input = self.audio.get_default_input_device_info()
                log_debug(ErrorCategory.AUDIO_INPUT, 
                         f"Using input device: {default_input.get('name', 'unknown')}")
            except IOError:
                log_warning(ErrorCategory.AUDIO_INPUT, "No default input device available")
                self._setup_failed = True
                return False
            
            self.stream = self.audio.open(
                format=pyaudio.paInt16,
                channels=1,
                rate=44100,
                input=True,
                frames_per_buffer=1024,
                stream_callback=None
            )
            
            self._setup_failed = False
            self._read_errors = 0
            log_debug(ErrorCategory.AUDIO_INPUT, "Audio setup successful")
            return True
            
        except OSError as e:
            # Common: device busy, permission denied
            log_error(ErrorCategory.AUDIO_INPUT, f"Audio device error: {e}", e)
            self._setup_failed = True
            self._cleanup_partial()
            return False
        except Exception as e:
            log_error(ErrorCategory.AUDIO_INPUT, f"Audio setup failed: {e}", e)
            self._setup_failed = True
            self._cleanup_partial()
            return False

    def _cleanup_partial(self):
        """Clean up any partially initialized resources"""
        try:
            if self.stream:
                self.stream.close()
        except:
            pass
        self.stream = None
        
        try:
            if self.audio:
                self.audio.terminate()
        except:
            pass
        self.audio = None

    def get_level(self) -> float:
        """
        Get current audio input level (0.0 to 1.0).
        
        Returns 0.0 on any error to ensure UI continues working.
        """
        # Don't try if setup failed or in processing mode
        if self._setup_failed or self.processing_mode:
            return 0.0
        
        if not self.stream:
            return 0.0
        
        # Circuit breaker: stop trying after too many errors
        if self._read_errors >= self._max_read_errors:
            if not error_state.audio_degraded:
                log_warning(ErrorCategory.AUDIO_INPUT, 
                           f"Audio input degraded after {self._read_errors} errors")
                error_state.audio_degraded = True
            return 0.0
        
        try:
            # Check if stream is active
            if not self.stream.is_active():
                self._read_errors += 1
                return 0.0
            
            data = self.stream.read(512, exception_on_overflow=False)
            
            # Convert bytes to integers
            count = len(data) // 2
            if count == 0:
                return 0.0
                
            shorts = struct.unpack(f'{count}h', data)
            
            # Calculate RMS (Root Mean Square)
            sum_squares = sum(s ** 2 for s in shorts)
            rms = math.sqrt(sum_squares / count)
            
            # Normalize to 0.0 - 1.0 range
            normalized = min(rms / 3000.0, 1.0)
            
            # Success - reset error count
            if self._read_errors > 0:
                self._read_errors = max(0, self._read_errors - 1)
            
            return normalized
            
        except IOError as e:
            # Buffer overflow or device disconnect
            self._read_errors += 1
            if self._read_errors <= 3:  # Only log first few
                log_warning(ErrorCategory.AUDIO_INPUT, f"Audio read IOError: {e}")
            return 0.0
        except struct.error as e:
            # Data format issue
            self._read_errors += 1
            log_warning(ErrorCategory.AUDIO_INPUT, f"Audio data format error: {e}")
            return 0.0
        except Exception as e:
            self._read_errors += 1
            log_error(ErrorCategory.AUDIO_INPUT, f"Unexpected audio error: {e}", e)
            return 0.0

    def set_processing_mode(self, enabled: bool):
        """Set processing mode to pause/resume audio capture"""
        self.processing_mode = enabled
        log_debug(ErrorCategory.AUDIO_INPUT, f"Processing mode: {enabled}")

    def is_available(self) -> bool:
        """Check if audio input is available and working"""
        return (
            not self._setup_failed and 
            self.stream is not None and 
            self._read_errors < self._max_read_errors
        )

    def cleanup(self):
        """Cleanup audio resources safely"""
        log_debug(ErrorCategory.AUDIO_INPUT, "Cleaning up audio resources")
        
        if self.stream:
            try:
                self.stream.stop_stream()
            except Exception as e:
                log_warning(ErrorCategory.CLEANUP, f"Error stopping stream: {e}")
            
            try:
                self.stream.close()
            except Exception as e:
                log_warning(ErrorCategory.CLEANUP, f"Error closing stream: {e}")
            
            self.stream = None
        
        if self.audio:
            try:
                self.audio.terminate()
            except Exception as e:
                log_warning(ErrorCategory.CLEANUP, f"Error terminating PyAudio: {e}")
            
            self.audio = None
