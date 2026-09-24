"""Exercise Chrome's framed protocol against the built helper without changing app state."""
import json
from pathlib import Path
import struct
import subprocess
import unittest

HOST = Path(__file__).resolve().parents[2] / 'dist/settime.app/Contents/MacOS/BrowserFocusHost'

class NativeHostTests(unittest.TestCase):
    def test_multiple_framed_requests_and_eof(self):
        request = json.dumps({'type': 'status'}).encode()
        frame = struct.pack('<I', len(request)) + request
        result = subprocess.run([str(HOST)], input=frame * 2, capture_output=True, check=True)
        data = result.stdout
        for _ in range(2):
            length, = struct.unpack('<I', data[:4])
            response = json.loads(data[4:4 + length])
            self.assertIsInstance(response['active'], bool)
            self.assertIsInstance(response['domains'], list)
            self.assertIn('expiresAt', response)
            data = data[4 + length:]
        self.assertEqual(data, b'')

    def test_oversized_and_truncated_input_exit_without_response(self):
        for data in [struct.pack('<I', 4097), b'\x02\x00', struct.pack('<I', 10) + b'{}']:
            result = subprocess.run([str(HOST)], input=data, capture_output=True, timeout=2)
            self.assertEqual(result.stdout, b'')

if __name__ == '__main__':
    unittest.main()
