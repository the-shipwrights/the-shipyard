"""Boat-scanning application package."""

import sys

from scanning import boat as _boat

# Keep legacy absolute imports in scanning modules working when run as a package.
sys.modules.setdefault("boat", _boat)
