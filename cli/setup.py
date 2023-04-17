from setuptools import setup

setup(
    name='vault',
    version='0.1.0',
    py_modules=['vault'],
    install_requires=[
        'Click',
    ],
    entry_points={
        'console_scripts': [
            'vault = vault:cli',
        ],
    },
)