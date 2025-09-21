
"""
Setup script for EirosAgent
"""
from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

with open("requirements.txt", "r", encoding="utf-8") as fh:
    requirements = [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="eiros-agent",
    version="2.0.0",
    author="EirosAgent Team",
    author_email="team@eirosagent.com",
    description="Advanced Web Automation and OCR System",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/ricobiz/IOSeiros",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: Internet :: WWW/HTTP :: Browsers",
        "Topic :: Scientific/Engineering :: Image Recognition",
        "Topic :: Office/Business :: Scheduling",
    ],
    python_requires=">=3.8",
    install_requires=requirements,
    extras_require={
        "dev": [
            "pytest>=7.4.3",
            "pytest-asyncio>=0.21.1",
            "pytest-mock>=3.12.0",
            "black>=23.11.0",
            "flake8>=6.1.0",
            "mypy>=1.7.1",
        ],
        "full": [
            "easyocr>=1.7.0",
            "paddleocr>=2.7.0",
            "opencv-python>=4.8.0",
            "scikit-image>=0.21.0",
            "croniter>=1.4.1",
        ]
    },
    entry_points={
        "console_scripts": [
            "eiros-agent=eiros_agent.cli:main",
        ],
    },
    include_package_data=True,
    package_data={
        "eiros_agent": ["config/*.yaml", "config/macros/*.yaml"],
    },
)
