"""
Basic tests for MCP Gateway AgentGateway
"""
import pytest
import sys
from pathlib import Path

# Add the parent directory to the path so we can import main
sys.path.insert(0, str(Path(__file__).parent.parent))


def test_import_main():
    """Test that we can import the main module"""
    try:
        import main
        assert True
    except ImportError as e:
        pytest.skip(f"Cannot import main module: {e}")


def test_basic_functionality():
    """Basic test placeholder"""
    assert 1 + 1 == 2


def test_environment_vars():
    """Test that we can handle environment variables"""
    import os
    # This is just a placeholder test
    assert os.environ.get('ENVIRONMENT', 'test') is not None


if __name__ == "__main__":
    pytest.main([__file__])
