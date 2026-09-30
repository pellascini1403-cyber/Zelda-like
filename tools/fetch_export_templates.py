#!/usr/bin/env python3
"""Fetch only the named Godot export templates (HTTP range requests into the
official .tpz, so the 1.2 GB archive is never downloaded whole).

    python3 tools/fetch_export_templates.py web_nothreads_debug.zip version.txt
"""
import io
import os
import sys
import urllib.request
import zipfile

VERSION = "4.4.1"
URL = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"
OUT = os.path.expanduser(f"~/.local/share/godot/export_templates/{VERSION}.stable")


class RemoteFile(io.RawIOBase):
	def __init__(self) -> None:
		self.pos = 0
		head = urllib.request.urlopen(urllib.request.Request(URL, method="HEAD"))
		self.size = int(head.headers["Content-Length"])

	def seekable(self) -> bool:
		return True

	def readable(self) -> bool:
		return True

	def tell(self) -> int:
		return self.pos

	def seek(self, offset: int, whence: int = 0) -> int:
		self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.size + offset
		return self.pos

	def readinto(self, buf) -> int:
		if self.pos >= self.size:
			return 0
		end = min(self.pos + len(buf), self.size) - 1
		req = urllib.request.Request(URL, headers={"Range": f"bytes={self.pos}-{end}"})
		data = urllib.request.urlopen(req).read()
		buf[: len(data)] = data
		self.pos += len(data)
		return len(data)


def main(names: list[str]) -> None:
	os.makedirs(OUT, exist_ok=True)
	todo = [n for n in names if not os.path.exists(os.path.join(OUT, n))]
	if not todo:
		return
	z = zipfile.ZipFile(io.BufferedReader(RemoteFile(), buffer_size=1 << 20))
	for n in todo:
		with open(os.path.join(OUT, n), "wb") as f:
			f.write(z.read("templates/" + n))
		print("fetched", n)


if __name__ == "__main__":
	main(sys.argv[1:])
