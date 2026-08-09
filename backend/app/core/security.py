import hashlib
import hmac
import os
import secrets
import string


def generate_session_id() -> str:
    return "".join(secrets.choice(string.digits) for _ in range(5))


def generate_password() -> str:
    return "".join(secrets.choice(string.digits) for _ in range(4))


def generate_token() -> str:
    return secrets.token_urlsafe(32)


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000)
    return salt.hex() + ":" + digest.hex()


def verify_password(password: str, hashed: str) -> bool:
    try:
        salt_hex, digest_hex = hashed.split(":")
    except ValueError:
        return False
    salt = bytes.fromhex(salt_hex)
    expected = bytes.fromhex(digest_hex)
    actual = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000)
    return hmac.compare_digest(actual, expected)
