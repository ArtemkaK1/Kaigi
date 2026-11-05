#!/usr/bin/env python3
"""Validate local Firebase configuration without printing its contents."""
import os
from pathlib import Path
import plistlib
import re
import sys


def validate(path, bundle_id):
    try:
        with Path(path).open('rb') as file:
            config = plistlib.load(file)
    except (OSError, plistlib.InvalidFileException, ValueError):
        raise ValueError('Missing or invalid GoogleService-Info.plist. See Docs/Analytics.md for local setup.') from None
    app_id = config.get('GOOGLE_APP_ID', '')
    sender = config.get('GCM_SENDER_ID', '')
    if config.get('BUNDLE_ID') != bundle_id:
        raise ValueError('Firebase bundle ID does not match the Kaigi target.')
    if not re.fullmatch(r'1:[0-9]+:ios:[0-9a-f]+', app_id) or app_id.split(':')[1] != sender:
        raise ValueError('Firebase application ID or sender configuration is invalid.')
    if not re.fullmatch(r'[a-z][a-z0-9-]{4,28}[a-z0-9]', config.get('PROJECT_ID', '')):
        raise ValueError('Firebase project configuration is invalid.')
    if not re.fullmatch(r'AIza[\w-]{35}', config.get('API_KEY', '')):
        raise ValueError('Firebase API configuration is invalid.')


if __name__ == '__main__':
    try:
        validate(sys.argv[1], os.environ.get('PRODUCT_BUNDLE_IDENTIFIER', 'com.volrik.kaigi'))
    except (ValueError, IndexError) as error:
        sys.exit(f'error: {error}')
    print('Firebase configuration validated (values withheld).')
